import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { v4 as uuidv4 } from "uuid";

admin.initializeApp();
const db = admin.firestore();

// 🚨 P1-2: App Check Helper (v1 API için)
// context.app undefined ise App Check token yok demektir
function assertAppCheck(context: functions.https.CallableContext) {
  if (!context.app) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "App Check token gerekli. Lütfen uygulamayı güncelleyin."
    );
  }
}

/**
 * BULUT FONKSİYONU 1: Takım Oluşturma
 * 
 * İş Mantığı:
 * 1. Benzersiz referral_code oluştur
 * 2. Team koleksiyonuna yaz
 * 3. team_members alt koleksiyonuna lider'i ekle
 * 4. User'ın current_team_id'sini güncelle
 * 
 * @param data.teamName - Takım adı
 * @param data.logoUrl - Takım logosu URL'i (opsiyonel)
 * @param context.auth.uid - Takım kurucusu (Lider)
 * 🚨 P1-2: App Check enforcement aktif
 */
export const createTeam = functions.https.onCall(async (data, context) => {
  // 🚨 App Check kontrolü
  assertAppCheck(context);
  
  // Kimlik doğrulama kontrolü
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Kullanıcı oturum açmış olmalıdır."
    );
  }

  const leaderUid = context.auth.uid;
  const { teamName, logoUrl } = data;

  // Validasyon
  if (!teamName || teamName.trim().length < 3) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Takım adı en az 3 karakter olmalıdır."
    );
  }

  try {
    // Benzersiz referral code oluştur (6 karakterlik)
    let referralCode = generateReferralCode();
    let isUnique = false;

    // Referral code benzersizliğini kontrol et
    while (!isUnique) {
      const existingTeam = await db
        .collection("teams")
        .where("referral_code", "==", referralCode)
        .limit(1)
        .get();

      isUnique = existingTeam.empty;
      if (!isUnique) {
        referralCode = generateReferralCode();
      }
    }

    // Yeni takım belgesi oluştur
    const teamData = {
      name: teamName.trim(),
      logo_url: logoUrl || null,
      referral_code: referralCode,
      leader_uid: leaderUid,
      members_count: 1,
      total_team_hope: 0,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      member_ids: [leaderUid],
    };

    // Takım koleksiyonuna yaz
    const teamRef = await db.collection("teams").add(teamData);
    const teamId = teamRef.id;

    // team_members alt koleksiyonuna lider'i ekle
    await teamRef.collection("team_members").doc(leaderUid).set({
      team_id: teamId,
      user_id: leaderUid,
      member_status: "active",
      join_date: admin.firestore.FieldValue.serverTimestamp(),
      member_total_hope: 0,
      member_daily_steps: 0,
    });

    // Lider'in current_team_id'sini güncelle
    await db.collection("users").doc(leaderUid).update({
      current_team_id: teamId,
    });

    return {
      success: true,
      message: "Takım başarıyla oluşturuldu.",
      teamId,
      referralCode,
    };
  } catch (error: any) {
    console.error("createTeam hatası:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * BULUT FONKSİYONU 2: Referral Kodu ile Takıma Katılma
 * 
 * İş Mantığı:
 * 1. Referral code ile takımı bul
 * 2. Kullanıcıyı team_members'a ekle
 * 3. User'ın current_team_id'sini güncelle
 * 4. Team'in members_count'ını artır
 * 5. Lider'e bildirim gönder (opsiyonel)
 * 
 * @param data.referralCode - Takımın referral kodu
 * @param context.auth.uid - Katılan kullanıcı
 * 🚨 P1-2: App Check enforcement aktif
 */
export const joinTeamByReferral = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    const userId = context.auth.uid;
    const { referralCode } = data;

    if (!referralCode || referralCode.trim().length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Referral kod gereklidir."
      );
    }

    try {
      // Referral code ile takımı bul
      const teamQuery = await db
        .collection("teams")
        .where("referral_code", "==", referralCode.trim().toUpperCase())
        .limit(1)
        .get();

      if (teamQuery.empty) {
        throw new functions.https.HttpsError(
          "not-found",
          "Bu referral kod ile bir takım bulunamadı."
        );
      }

      const teamDoc = teamQuery.docs[0];
      const teamId = teamDoc.id;
      const teamData = teamDoc.data();

      // Kullanıcı zaten takımda mı kontrol et
      const existingMember = await teamDoc.ref
        .collection("team_members")
        .doc(userId)
        .get();

      if (existingMember.exists) {
        throw new functions.https.HttpsError(
          "already-exists",
          "Siz zaten bu takımın üyesisiniz."
        );
      }

      // Kullanıcı başka bir takımda mı kontrol et
      const userDoc = await db.collection("users").doc(userId).get();
      if (userDoc.data()?.current_team_id) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Siz zaten başka bir takımın üyesisiniz. Lütfen önce o takımdan ayrılın."
        );
      }

      // team_members'a kullanıcıyı ekle
      await teamDoc.ref.collection("team_members").doc(userId).set({
        team_id: teamId,
        user_id: userId,
        member_status: "active",
        join_date: admin.firestore.FieldValue.serverTimestamp(),
        member_total_hope: 0,
        member_daily_steps: 0,
      });

      // User'ın current_team_id'sini güncelle
      await db.collection("users").doc(userId).update({
        current_team_id: teamId,
      });

      // Team'in members_count'ını ve member_ids'i güncelle
      const newMemberIds = [...(teamData.member_ids || []), userId];
      await teamDoc.ref.update({
        members_count: admin.firestore.FieldValue.increment(1),
        member_ids: newMemberIds,
      });

      return {
        success: true,
        message: `Başarıyla ${teamData.name} takımına katıldınız.`,
        teamId,
        teamName: teamData.name,
      };
    } catch (error: any) {
      console.error("joinTeamByReferral hatası:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * BULUT FONKSİYONU 3: Kullanıcıyı Takıma Davet Et
 * 
 * İş Mantığı:
 * 1. Daveti gönderenin takım lideri olup olmadığını kontrol et
 * 2. Hedef kullanıcıyı bul (isim/nickname ile)
 * 3. notifications koleksiyonuna davet kaydı oluştur
 * 4. Davet edilen kullanıcıya Firebase Messaging bildirimi gönder
 * 
 * @param data.targetUserNameOrNickname - Davet edilecek kişinin adı/nickname
 * @param data.teamId - Daveti gönderen takım
 * @param context.auth.uid - Lider
 * 🚨 P1-2: App Check enforcement aktif
 */
export const inviteUserToTeam = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    const leaderUid = context.auth.uid;
    const { targetUserNameOrNickname, teamId } = data;

    if (!targetUserNameOrNickname || !teamId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Gerekli parametreler eksik."
      );
    }

    try {
      // Takım bilgisini al ve lider kontrolü yap
      const teamDoc = await db.collection("teams").doc(teamId).get();
      if (!teamDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Takım bulunamadı."
        );
      }

      const teamData = teamDoc.data()!;
      if (teamData.leader_uid !== leaderUid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Sadece takım lideri üye davet edebilir."
        );
      }

      // Hedef kullanıcıyı bul
      const userQuery = await db
        .collectionGroup("users")
        .where("full_name", "==", targetUserNameOrNickname)
        .limit(1)
        .get();

      let targetUserId: string | null = null;

      if (!userQuery.empty) {
        targetUserId = userQuery.docs[0].id;
      } else {
        // Nickname ile ara
        const nickQuery = await db
          .collectionGroup("users")
          .where("nickname", "==", targetUserNameOrNickname)
          .limit(1)
          .get();

        if (!nickQuery.empty) {
          targetUserId = nickQuery.docs[0].id;
        }
      }

      if (!targetUserId) {
        throw new functions.https.HttpsError(
          "not-found",
          "Kullanıcı bulunamadı."
        );
      }

      // Hedef kullanıcının zaten takımda olup olmadığını kontrol et
      const existingMember = await teamDoc.ref
        .collection("team_members")
        .doc(targetUserId)
        .get();

      if (existingMember.exists) {
        throw new functions.https.HttpsError(
          "already-exists",
          "Bu kullanıcı zaten takımda."
        );
      }

      // Lider bilgisini al
      const leaderDoc = await db.collection("users").doc(leaderUid).get();
      const leaderData = leaderDoc.data();

      // Bildirim belgesini oluştur
      const notificationId = uuidv4();
      await db
        .collection("users")
        .doc(targetUserId)
        .collection("notifications")
        .doc(notificationId)
        .set({
          id: notificationId,
          receiver_uid: targetUserId,
          sender_team_id: teamId,
          notification_type: "team_invite",
          notification_status: "pending",
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          responded_at: null,
          sender_name: leaderData?.full_name || "Bilinmiyor",
          team_name: teamData.name,
        });

      // Firebase Messaging bildirimi gönder (opsiyonel)
      const targetUserTokens = await getDeviceTokens(targetUserId);
      if (targetUserTokens.length > 0) {
        await admin.messaging().sendMulticast({
          tokens: targetUserTokens,
          notification: {
            title: `${teamData.name} Takımından Davet`,
            body: `${leaderData?.full_name} sizi takıma davet etti.`,
          },
          data: {
            teamId,
            notificationId,
            type: "team_invite",
          },
        });
      }

      return {
        success: true,
        message: "Davet başarıyla gönderildi.",
        notificationId,
      };
    } catch (error: any) {
      console.error("inviteUserToTeam hatası:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * BULUT FONKSİYONU 4: Daveti Kabul Et
 * 
 * İş Mantığı:
 * 1. Bildirimi 'accepted' olarak işaretle
 * 2. Kullanıcıyı team_members'a ekle
 * 3. User'ın current_team_id'sini güncelle
 * 4. Team'in members_count'ını artır
 * 
 * @param data.notificationId - Bildirimin ID'si
 * @param data.teamId - Takım ID'si
 * @param context.auth.uid - Kabul eden kullanıcı
 * 🚨 P1-2: App Check enforcement aktif
 */
export const acceptTeamInvite = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    const userId = context.auth.uid;
    const { notificationId, teamId } = data;

    try {
      // Bildirimi al ve doğrula
      const notificationRef = db
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .doc(notificationId);

      const notificationDoc = await notificationRef.get();
      if (!notificationDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Bildirim bulunamadı."
        );
      }

      const notificationData = notificationDoc.data()!;
      if (notificationData.notification_status !== "pending") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Bu bildirim zaten cevap alınmış."
        );
      }

      // Takımı al
      const teamDoc = await db.collection("teams").doc(teamId).get();
      if (!teamDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Takım bulunamadı."
        );
      }

      const teamData = teamDoc.data()!;

      // team_members'a kullanıcıyı ekle
      await teamDoc.ref.collection("team_members").doc(userId).set({
        team_id: teamId,
        user_id: userId,
        member_status: "active",
        join_date: admin.firestore.FieldValue.serverTimestamp(),
        member_total_hope: 0,
        member_daily_steps: 0,
      });

      // User'ın current_team_id'sini güncelle
      await db.collection("users").doc(userId).update({
        current_team_id: teamId,
      });

      // Team'in members_count'ını ve member_ids'i güncelle
      const newMemberIds = [...(teamData.member_ids || []), userId];
      await teamDoc.ref.update({
        members_count: admin.firestore.FieldValue.increment(1),
        member_ids: newMemberIds,
      });

      // Bildirimi 'accepted' olarak işaretle
      await notificationRef.update({
        notification_status: "accepted",
        responded_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        message: `${teamData.name} takımına başarıyla katıldınız.`,
        teamId,
      };
    } catch (error: any) {
      console.error("acceptTeamInvite hatası:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * BULUT FONKSİYONU 5: Daveti Reddet
 * 
 * İş Mantığı:
 * 1. Bildirimi 'rejected' olarak işaretle
 * 2. responded_at zamanını kaydet
 * 
 * @param data.notificationId - Bildirimin ID'si
 * @param context.auth.uid - Davet edilen kullanıcı
 * 🚨 P1-2: App Check enforcement aktif
 */
export const rejectTeamInvite = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    const userId = context.auth.uid;
    const { notificationId } = data;

    try {
      const notificationRef = db
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .doc(notificationId);

      const notificationDoc = await notificationRef.get();
      if (!notificationDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Bildirim bulunamadı."
        );
      }

      // Bildirimi 'rejected' olarak işaretle
      await notificationRef.update({
        notification_status: "rejected",
        responded_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        message: "Davet reddedildi.",
      };
    } catch (error: any) {
      console.error("rejectTeamInvite hatası:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * Yardımcı Fonksiyon: Benzersiz Referral Code Oluştur
 */
function generateReferralCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

/**
 * Yardımcı Fonksiyon: Kullanıcının Device Token'larını Al
 */
async function getDeviceTokens(userId: string): Promise<string[]> {
  const userDoc = await db.collection("users").doc(userId).get();
  const tokens = userDoc.data()?.device_tokens || [];
  return Array.isArray(tokens) ? tokens : [];
}

/**
 * BULUT FONKSİYONU: Mevcut Kullanıcıların full_name_lowercase Alanını Güncelle
 * 
 * Bu fonksiyon bir kerelik çalıştırılır.
 * Tüm kullanıcıların full_name alanını lowercase olarak full_name_lowercase alanına yazar.
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const migrateUsersFullNameLowercase = functions.https.onCall(async (data, context) => {
  // 🚨 App Check kontrolü
  assertAppCheck(context);
  
  // Admin kontrolü - sadece auth uid'si olan kullanıcılar çalıştırabilir
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Kullanıcı oturum açmış olmalıdır."
    );
  }

  try {
    const usersSnapshot = await db.collection("users").get();
    const batch = db.batch();
    let updatedCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fullName = userData.full_name;
      
      // full_name_lowercase yoksa veya güncellenmesi gerekiyorsa
      if (fullName && !userData.full_name_lowercase) {
        batch.update(userDoc.ref, {
          full_name_lowercase: fullName.toLowerCase(),
        });
        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      await batch.commit();
    }

    return {
      success: true,
      message: `${updatedCount} kullanıcı güncellendi.`,
      updatedCount: updatedCount,
    };
  } catch (error: any) {
    console.error("migrateUsersFullNameLowercase hatası:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ==================== GÜNLÜK CARRYOVER AKTARIMI ====================

/**
 * BULUT FONKSİYONU: Günlük Dönüştürülmemiş Adımları Carryover'a Aktar
 * 
 * Her gece 00:00'da (Türkiye saati) çalışır ve dünün dönüştürülmemiş
 * adımlarını carryover_pending'e ekler.
 * 
 * İşlem:
 * 1. Dünün tarihini hesapla
 * 2. Her kullanıcının daily_steps koleksiyonundaki dünün verisini oku
 * 3. (daily_steps - converted_steps) farkını carryover_pending'e ekle
 * 
 * Cron: Her gün gece yarısı Türkiye saati
 * "0 0 * * *" = Her gün 00:00 Türkiye saati
 */
export const carryOverDailySteps = functions.pubsub
  .schedule("0 0 * * *") // Her gün 00:00 Türkiye saati
  .timeZone("Europe/Istanbul")
  .onRun(async (context) => {
    console.log("🔄 Günlük adım taşıma işlemi başladı...");

    try {
      // Türkiye saatine göre dünü hesapla (UTC+3)
      // Fonksiyon Europe/Istanbul timezone ile çalışıyor ama Date() UTC kullanıyor
      const now = new Date();
      const turkeyTime = new Date(now.getTime() + (3 * 60 * 60 * 1000)); // UTC+3
      const yesterday = new Date(turkeyTime);
      yesterday.setDate(yesterday.getDate() - 1);
      const yesterdayKey = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, "0")}-${String(yesterday.getDate()).padStart(2, "0")}`;

      console.log(`📅 Dün (TR): ${yesterdayKey}`);

      // Tüm kullanıcıları al
      const usersSnapshot = await db.collection("users").get();
      let carryOverCount = 0;
      let totalCarriedSteps = 0;

      for (const userDoc of usersSnapshot.docs) {
        try {
          // Kullanıcının dünkü adım verisini al
          const yesterdayStepsDoc = await db
            .collection("users")
            .doc(userDoc.id)
            .collection("daily_steps")
            .doc(yesterdayKey)
            .get();

          if (yesterdayStepsDoc.exists) {
            const stepData = yesterdayStepsDoc.data();
            const dailySteps = stepData?.daily_steps || 0;
            const convertedSteps = stepData?.converted_steps || 0;
            const unconvertedSteps = dailySteps - convertedSteps;

            // Dönüştürülmemiş adım varsa carryover'a ekle
            if (unconvertedSteps > 0) {
              const userData = userDoc.data();
              const currentCarryoverPending = userData.carryover_pending || 0;

              const currentTotalCarryover = userData.total_carryover_steps || 0;
              await userDoc.ref.update({
                carryover_pending: currentCarryoverPending + unconvertedSteps,
                total_carryover_steps: currentTotalCarryover + unconvertedSteps, // Tarihsel toplam
                last_carryover_update: admin.firestore.FieldValue.serverTimestamp(),
              });

              // 📝 Aktivite geçmişine kayıt ekle
              try {
                const now = new Date();
                const carryoverTimestamp = admin.firestore.Timestamp.fromDate(now);
                
                // Global activity_logs'a ekle (profil ekranı için)
                await db.collection("activity_logs").add({
                  user_id: userDoc.id,
                  activity_type: "step_carryover",
                  steps: unconvertedSteps,
                  from_date: yesterdayKey,
                  created_at: carryoverTimestamp,
                  timestamp: carryoverTimestamp,
                });

                // User subcollection'a da ekle
                await db.collection("users").doc(userDoc.id).collection("activity_logs").add({
                  user_id: userDoc.id,
                  activity_type: "step_carryover",
                  steps: unconvertedSteps,
                  from_date: yesterdayKey,
                  created_at: carryoverTimestamp,
                  timestamp: carryoverTimestamp,
                });
                
                console.log(`📝 ${userDoc.id}: activity_log eklendi`);
              } catch (logError) {
                console.error(`⚠️ ${userDoc.id}: activity_log eklenemedi:`, logError);
              }

              carryOverCount++;
              totalCarriedSteps += unconvertedSteps;

              console.log(`✅ ${userDoc.id}: ${unconvertedSteps} adım carryover'a eklendi`);
            }
          }
        } catch (userError) {
          console.error(`❌ Kullanıcı ${userDoc.id} işlenirken hata:`, userError);
        }
      }

      // Admin log kaydı
      await db.collection("admin_logs").add({
        action: "daily_carryover",
        date: yesterdayKey,
        users_affected: carryOverCount,
        total_steps_carried: totalCarriedSteps,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        note: `${carryOverCount} kullanıcının ${totalCarriedSteps} adımı carryover'a aktarıldı`,
      });

      console.log(`✅ Günlük carryover tamamlandı: ${carryOverCount} kullanıcı, ${totalCarriedSteps} adım`);
      return null;
    } catch (error: any) {
      console.error("❌ Günlük carryover hatası:", error);
      return null;
    }
  });

// ==================== GÜNLÜK TAKIM ADIM SIFIRLAMA ====================

/**
 * BULUT FONKSİYONU: Günlük Takım Üye Adımlarını Sıfırlama
 * 
 * Her gece 00:00'da (Türkiye saati) çalışır ve tüm takım üyelerinin
 * member_daily_steps değerlerini sıfırlar.
 * 
 * Cron: Her gün gece yarısı Türkiye saati (UTC+3)
 * "0 21 * * *" = UTC 21:00 = Türkiye 00:00
 */
export const resetDailyTeamSteps = functions.pubsub
  .schedule("0 21 * * *") // UTC 21:00 = Türkiye 00:00
  .timeZone("Europe/Istanbul")
  .onRun(async (context) => {
    console.log("🔄 Günlük takım adım sıfırlama başladı...");
    
    try {
      // Tüm takımları al
      const teamsSnapshot = await db.collection("teams").get();
      
      let totalReset = 0;
      const batchSize = 500; // Firestore batch limiti
      let currentBatch = db.batch();
      let operationCount = 0;

      for (const teamDoc of teamsSnapshot.docs) {
        // Her takımın üyelerini al
        const membersSnapshot = await teamDoc.ref
          .collection("team_members")
          .get();

        for (const memberDoc of membersSnapshot.docs) {
          currentBatch.update(memberDoc.ref, {
            member_daily_steps: 0,
          });
          operationCount++;
          totalReset++;

          // Batch dolduğunda commit et ve yeni batch oluştur
          if (operationCount >= batchSize) {
            await currentBatch.commit();
            currentBatch = db.batch();
            operationCount = 0;
          }
        }
      }

      // Kalan işlemleri commit et
      if (operationCount > 0) {
        await currentBatch.commit();
      }

      console.log(`✅ Günlük sıfırlama tamamlandı. ${totalReset} üye sıfırlandı.`);
      return null;
    } catch (error: any) {
      console.error("❌ resetDailyTeamSteps hatası:", error);
      return null;
    }
  });

/**
 * BULUT FONKSİYONU: Aylık Takım Hope Sıfırlama
 * 
 * Her ayın 1'inde gece 00:00'da (Türkiye saati) çalışır ve tüm takımların
 * total_team_hope ve üyelerin member_total_hope değerlerini sıfırlar.
 * 
 * Bu sayede takım yarışması her ay yeniden başlar.
 * 
 * Cron: Her ayın 1'i gece yarısı Türkiye saati
 * "0 21 1 * *" = UTC 21:00 ayın 1'i = Türkiye 00:00 ayın 1'i
 */
export const resetMonthlyTeamHope = functions.pubsub
  .schedule("0 21 1 * *") // Her ayın 1'i UTC 21:00 = Türkiye 00:00
  .timeZone("Europe/Istanbul")
  .onRun(async (context) => {
    console.log("🔄 Aylık takım Hope sıfırlama başladı...");
    
    try {
      const teamsSnapshot = await db.collection("teams").get();
      
      let teamsReset = 0;
      let membersReset = 0;
      const batchSize = 500;
      let currentBatch = db.batch();
      let operationCount = 0;

      for (const teamDoc of teamsSnapshot.docs) {
        // Takımın total_team_hope'unu sıfırla
        currentBatch.update(teamDoc.ref, {
          total_team_hope: 0,
        });
        operationCount++;
        teamsReset++;

        if (operationCount >= batchSize) {
          await currentBatch.commit();
          currentBatch = db.batch();
          operationCount = 0;
        }

        // Her takımın üyelerinin member_total_hope'unu sıfırla
        const membersSnapshot = await teamDoc.ref
          .collection("team_members")
          .get();

        for (const memberDoc of membersSnapshot.docs) {
          currentBatch.update(memberDoc.ref, {
            member_total_hope: 0,
          });
          operationCount++;
          membersReset++;

          if (operationCount >= batchSize) {
            await currentBatch.commit();
            currentBatch = db.batch();
            operationCount = 0;
          }
        }
      }

      // Kalan işlemleri commit et
      if (operationCount > 0) {
        await currentBatch.commit();
      }

      console.log(`✅ Aylık sıfırlama tamamlandı. ${teamsReset} takım, ${membersReset} üye sıfırlandı.`);
      return null;
    } catch (error: any) {
      console.error("❌ resetMonthlyTeamHope hatası:", error);
      return null;
    }
  });

/**
 * BULUT FONKSİYONU: Manuel Günlük Sıfırlama (Test/Admin için)
 * 
 * Admin tarafından manuel olarak çağrılabilir.
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const manualResetDailyTeamSteps = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    // Admin kontrolü - isteğe bağlı
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    try {
      const teamsSnapshot = await db.collection("teams").get();
      
      let totalReset = 0;
      const batchSize = 500;
      let currentBatch = db.batch();
      let operationCount = 0;

      for (const teamDoc of teamsSnapshot.docs) {
        const membersSnapshot = await teamDoc.ref
          .collection("team_members")
          .get();

        for (const memberDoc of membersSnapshot.docs) {
          currentBatch.update(memberDoc.ref, {
            member_daily_steps: 0,
          });
          operationCount++;
          totalReset++;

          if (operationCount >= batchSize) {
            await currentBatch.commit();
            currentBatch = db.batch();
            operationCount = 0;
          }
        }
      }

      if (operationCount > 0) {
        await currentBatch.commit();
      }

      return {
        success: true,
        message: `${totalReset} takım üyesinin günlük adımları sıfırlandı.`,
        totalReset,
      };
    } catch (error: any) {
      console.error("manualResetDailyTeamSteps hatası:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * BULUT FONKSİYONU: Manuel Aylık Sıfırlama (Test/Admin için)
 * 
 * Admin tarafından manuel olarak çağrılabilir.
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const manualResetMonthlyTeamHope = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    try {
      const teamsSnapshot = await db.collection("teams").get();
      
      let teamsReset = 0;
      let membersReset = 0;
      const batchSize = 500;
      let currentBatch = db.batch();
      let operationCount = 0;

      for (const teamDoc of teamsSnapshot.docs) {
        currentBatch.update(teamDoc.ref, {
          total_team_hope: 0,
        });
        operationCount++;
        teamsReset++;

        if (operationCount >= batchSize) {
          await currentBatch.commit();
          currentBatch = db.batch();
          operationCount = 0;
        }

        const membersSnapshot = await teamDoc.ref
          .collection("team_members")
          .get();

        for (const memberDoc of membersSnapshot.docs) {
          currentBatch.update(memberDoc.ref, {
            member_total_hope: 0,
          });
          operationCount++;
          membersReset++;

          if (operationCount >= batchSize) {
            await currentBatch.commit();
            currentBatch = db.batch();
            operationCount = 0;
          }
        }
      }

      if (operationCount > 0) {
        await currentBatch.commit();
      }

      return {
        success: true,
        message: `${teamsReset} takım ve ${membersReset} üyenin aylık Hope'ları sıfırlandı.`,
        teamsReset,
        membersReset,
      };
    } catch (error: any) {
      console.error("manualResetMonthlyTeamHope hatası:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// ==================== ADMIN FONKSİYONLARI ====================

/**
 * Admin kontrolü yardımcı fonksiyonu
 */
async function isAdmin(uid: string): Promise<boolean> {
  const adminDoc = await db.collection("admins").doc(uid).get();
  return adminDoc.exists && adminDoc.data()?.is_active === true;
}

/**
 * Admin işlem logları kayıt fonksiyonu
 */
async function logAdminAction(
  adminId: string,
  action: string,
  targetType: string,
  targetId: string,
  details: Record<string, any>
) {
  await db.collection("admin_logs").add({
    admin_id: adminId,
    action,
    target_type: targetType,
    target_id: targetId,
    details,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * ADMIN FONKSİYON 1: Dashboard İstatistiklerini Hesapla
 * Günlük olarak çalışır veya manuel tetiklenebilir
 */
export const calculateAdminStats = functions.pubsub
  .schedule("0 0 * * *") // Her gün gece yarısı
  .timeZone("Europe/Istanbul")
  .onRun(async () => {
    try {
      const now = new Date();
      const today = now.toISOString().split("T")[0];
      // yesterday değişkeni gerekirse kullanılabilir
      const _yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000)
        .toISOString()
        .split("T")[0];
      console.log(`Stats calculation for ${today}, previous day: ${_yesterday}`);

      // Toplam kullanıcı sayısı
      const usersSnapshot = await db.collection("users").get();
      const totalUsers = usersSnapshot.size;

      // Günlük aktif kullanıcı (son 24 saatte giriş yapan)
      const oneDayAgo = admin.firestore.Timestamp.fromDate(
        new Date(now.getTime() - 24 * 60 * 60 * 1000)
      );
      const activeUsersSnapshot = await db
        .collection("users")
        .where("last_login", ">=", oneDayAgo)
        .get();
      const dailyActiveUsers = activeUsersSnapshot.size;

      // Toplam adım ve Hope hesaplama
      let totalSteps = 0;
      let totalHope = 0;
      usersSnapshot.forEach((doc) => {
        const data = doc.data();
        totalSteps += data.total_steps || 0;
        totalHope += data.total_hope || 0;
      });

      // Toplam bağış miktarı
      const donationsSnapshot = await db.collection("donations").get();
      let totalDonations = 0;
      let totalDonationAmount = 0;
      donationsSnapshot.forEach((doc) => {
        totalDonations++;
        totalDonationAmount += doc.data().amount || 0;
      });

      // Toplam takım sayısı
      const teamsSnapshot = await db.collection("teams").get();
      const totalTeams = teamsSnapshot.size;

      // Aktif vakıf sayısı
      const charitiesSnapshot = await db
        .collection("charities")
        .where("is_active", "==", true)
        .get();
      const totalActiveCharities = charitiesSnapshot.size;

      // İstatistikleri kaydet
      await db.collection("admin_stats").doc("current").set({
        total_users: totalUsers,
        daily_active_users: dailyActiveUsers,
        total_steps: totalSteps,
        total_hope: totalHope,
        total_donations: totalDonations,
        total_donation_amount: totalDonationAmount,
        total_teams: totalTeams,
        total_active_charities: totalActiveCharities,
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Günlük istatistikleri de kaydet
      await db.collection("daily_stats").doc(today).set({
        date: today,
        total_users: totalUsers,
        daily_active_users: dailyActiveUsers,
        total_steps: totalSteps,
        total_hope: totalHope,
        total_donations: totalDonations,
        total_donation_amount: totalDonationAmount,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Admin stats calculated for ${today}`);
      return null;
    } catch (error) {
      console.error("calculateAdminStats error:", error);
      return null;
    }
  });

/**
 * ADMIN FONKSİYON 2: Manuel İstatistik Hesaplama (Admin tarafından tetiklenir)
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const manualCalculateAdminStats = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    if (!(await isAdmin(context.auth.uid))) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Bu işlem için admin yetkisi gereklidir."
      );
    }

    try {
      const now = new Date();
      const today = now.toISOString().split("T")[0];

      // Toplam kullanıcı sayısı
      const usersSnapshot = await db.collection("users").get();
      const totalUsers = usersSnapshot.size;

      // Günlük aktif kullanıcı
      const oneDayAgo = admin.firestore.Timestamp.fromDate(
        new Date(now.getTime() - 24 * 60 * 60 * 1000)
      );
      const activeUsersSnapshot = await db
        .collection("users")
        .where("last_login", ">=", oneDayAgo)
        .get();
      const dailyActiveUsers = activeUsersSnapshot.size;

      // Toplam adım ve Hope
      let totalSteps = 0;
      let totalHope = 0;
      usersSnapshot.forEach((doc) => {
        const data = doc.data();
        totalSteps += data.total_steps || 0;
        totalHope += data.total_hope || 0;
      });

      // Toplam bağış
      const donationsSnapshot = await db.collection("donations").get();
      let totalDonations = 0;
      let totalDonationAmount = 0;
      donationsSnapshot.forEach((doc) => {
        totalDonations++;
        totalDonationAmount += doc.data().amount || 0;
      });

      // Takım ve vakıf sayısı
      const teamsSnapshot = await db.collection("teams").get();
      const totalTeams = teamsSnapshot.size;

      const charitiesSnapshot = await db
        .collection("charities")
        .where("is_active", "==", true)
        .get();
      const totalActiveCharities = charitiesSnapshot.size;

      // Kaydet
      await db.collection("admin_stats").doc("current").set({
        total_users: totalUsers,
        daily_active_users: dailyActiveUsers,
        total_steps: totalSteps,
        total_hope: totalHope,
        total_donations: totalDonations,
        total_donation_amount: totalDonationAmount,
        total_teams: totalTeams,
        total_active_charities: totalActiveCharities,
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
      });

      await logAdminAction(
        context.auth.uid,
        "calculate_stats",
        "admin_stats",
        "current",
        { date: today }
      );

      return {
        success: true,
        message: "İstatistikler başarıyla hesaplandı.",
        stats: {
          totalUsers,
          dailyActiveUsers,
          totalSteps,
          totalHope,
          totalDonations,
          totalDonationAmount,
          totalTeams,
          totalActiveCharities,
        },
      };
    } catch (error: any) {
      console.error("manualCalculateAdminStats error:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * ADMIN FONKSİYON 3: Toplu Bildirim Gönderme
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const sendBroadcastNotification = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    if (!(await isAdmin(context.auth.uid))) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Bu işlem için admin yetkisi gereklidir."
      );
    }

    const { title, body, targetAudience, data: notificationData } = data;

    if (!title || !body) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Başlık ve içerik gereklidir."
      );
    }

    try {
      // Broadcast kaydı oluştur
      const broadcastRef = await db.collection("broadcast_notifications").add({
        title,
        body,
        target_audience: targetAudience || "all",
        data: notificationData || {},
        sent_by: context.auth.uid,
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
        status: "sending",
        success_count: 0,
        failure_count: 0,
      });

      // FCM token'larını al
      let usersQuery: admin.firestore.Query = db.collection("users");
      
      if (targetAudience === "premium") {
        usersQuery = usersQuery.where("is_premium", "==", true);
      } else if (targetAudience === "team_leaders") {
        // Takım liderlerini bul
        const teamsSnapshot = await db.collection("teams").get();
        const leaderIds = teamsSnapshot.docs.map((doc) => doc.data().leader_uid);
        usersQuery = usersQuery.where(
          admin.firestore.FieldPath.documentId(),
          "in",
          leaderIds.slice(0, 10) // Firestore 'in' limiti
        );
      }

      const usersSnapshot = await usersQuery.get();
      const tokens: string[] = [];
      
      usersSnapshot.forEach((doc) => {
        const fcmToken = doc.data().fcm_token;
        if (fcmToken) {
          tokens.push(fcmToken);
        }
      });

      if (tokens.length === 0) {
        await broadcastRef.update({
          status: "completed",
          success_count: 0,
          failure_count: 0,
        });
        return {
          success: true,
          message: "Gönderilecek token bulunamadı.",
          sentCount: 0,
        };
      }

      // FCM mesajı gönder (batch)
      let successCount = 0;
      let failureCount = 0;

      // 500'erli batch'ler halinde gönder
      const batchSize = 500;
      for (let i = 0; i < tokens.length; i += batchSize) {
        const batch = tokens.slice(i, i + batchSize);
        const message: admin.messaging.MulticastMessage = {
          tokens: batch,
          notification: {
            title,
            body,
          },
          data: notificationData || {},
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        successCount += response.successCount;
        failureCount += response.failureCount;
      }

      // Broadcast kaydını güncelle
      await broadcastRef.update({
        status: "completed",
        success_count: successCount,
        failure_count: failureCount,
      });

      await logAdminAction(
        context.auth.uid,
        "send_broadcast",
        "broadcast_notifications",
        broadcastRef.id,
        { title, targetAudience, successCount, failureCount }
      );

      return {
        success: true,
        message: `${successCount} kullanıcıya bildirim gönderildi.`,
        sentCount: successCount,
        failedCount: failureCount,
      };
    } catch (error: any) {
      console.error("sendBroadcastNotification error:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * ADMIN FONKSİYON 4: Kullanıcı Banla/Unban
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const toggleUserBan = functions.https.onCall(async (data, context) => {
  // 🚨 App Check kontrolü
  assertAppCheck(context);
  
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Kullanıcı oturum açmış olmalıdır."
    );
  }

  if (!(await isAdmin(context.auth.uid))) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Bu işlem için admin yetkisi gereklidir."
    );
  }

  const { userId, isBanned, reason } = data;

  if (!userId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Kullanıcı ID gereklidir."
    );
  }

  try {
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Kullanıcı bulunamadı.");
    }

    await userRef.update({
      is_banned: isBanned,
      ban_reason: isBanned ? reason || "Kural ihlali" : null,
      banned_at: isBanned
        ? admin.firestore.FieldValue.serverTimestamp()
        : null,
      banned_by: isBanned ? context.auth.uid : null,
    });

    // Firebase Auth'da da disable et
    if (isBanned) {
      await admin.auth().updateUser(userId, { disabled: true });
    } else {
      await admin.auth().updateUser(userId, { disabled: false });
    }

    await logAdminAction(
      context.auth.uid,
      isBanned ? "ban_user" : "unban_user",
      "users",
      userId,
      { reason }
    );

    return {
      success: true,
      message: isBanned
        ? "Kullanıcı başarıyla banlandı."
        : "Kullanıcı banı kaldırıldı.",
    };
  } catch (error: any) {
    console.error("toggleUserBan error:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * ADMIN FONKSİYON 5: Aylık Adım/Hope Raporları
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const getMonthlyStepReport = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    if (!(await isAdmin(context.auth.uid))) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Bu işlem için admin yetkisi gereklidir."
      );
    }

    const { year, month } = data;
    const targetYear = year || new Date().getFullYear();
    const targetMonth = month || new Date().getMonth() + 1;

    try {
      // Aylık daily_stats verilerini al
      const startDate = `${targetYear}-${String(targetMonth).padStart(2, "0")}-01`;
      const endDate = `${targetYear}-${String(targetMonth).padStart(2, "0")}-31`;

      const statsSnapshot = await db
        .collection("daily_stats")
        .where("date", ">=", startDate)
        .where("date", "<=", endDate)
        .orderBy("date")
        .get();

      const dailyData: any[] = [];
      let totalMonthlySteps = 0;
      let totalMonthlyHope = 0;

      statsSnapshot.forEach((doc) => {
        const data = doc.data();
        dailyData.push({
          date: data.date,
          totalSteps: data.total_steps || 0,
          totalHope: data.total_hope || 0,
          activeUsers: data.daily_active_users || 0,
        });
        totalMonthlySteps += data.total_steps || 0;
        totalMonthlyHope += data.total_hope || 0;
      });

      return {
        success: true,
        year: targetYear,
        month: targetMonth,
        totalMonthlySteps,
        totalMonthlyHope,
        dailyData,
      };
    } catch (error: any) {
      console.error("getMonthlyStepReport error:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * ADMIN FONKSİYON 6: Bağış Raporu (Detaylı)
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const getDonationReport = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Kullanıcı oturum açmış olmalıdır."
      );
    }

    if (!(await isAdmin(context.auth.uid))) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Bu işlem için admin yetkisi gereklidir."
      );
    }

    const { startDate, endDate, recipientId, recipientType } = data;

    try {
      let query: admin.firestore.Query = db.collection("donations");

      if (startDate) {
        query = query.where(
          "created_at",
          ">=",
          admin.firestore.Timestamp.fromDate(new Date(startDate))
        );
      }

      if (endDate) {
        query = query.where(
          "created_at",
          "<=",
          admin.firestore.Timestamp.fromDate(new Date(endDate))
        );
      }

      if (recipientId) {
        query = query.where("recipient_id", "==", recipientId);
      }

      if (recipientType) {
        query = query.where("recipient_type", "==", recipientType);
      }

      const donationsSnapshot = await query.get();

      const donations: any[] = [];
      let totalAmount = 0;
      const recipientSummary: Record<string, { count: number; amount: number }> = {};

      donationsSnapshot.forEach((doc) => {
        const data = doc.data();
        donations.push({
          id: doc.id,
          userId: data.user_id,
          recipientId: data.recipient_id,
          recipientName: data.recipient_name,
          recipientType: data.recipient_type,
          amount: data.amount,
          hopeSpent: data.hope_spent,
          createdAt: data.created_at?.toDate?.()?.toISOString() || null,
        });

        totalAmount += data.amount || 0;

        const key = data.recipient_id;
        if (!recipientSummary[key]) {
          recipientSummary[key] = { count: 0, amount: 0 };
        }
        recipientSummary[key].count++;
        recipientSummary[key].amount += data.amount || 0;
      });

      return {
        success: true,
        totalDonations: donations.length,
        totalAmount,
        donations,
        recipientSummary,
      };
    } catch (error: any) {
      console.error("getDonationReport error:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// ==================== AYLIK ADIM SIFIRLAMA ====================

/**
 * Her ayın son günü gece yarısı (Türkiye saati) çalışır
 * Tüm kullanıcıların aktarılan adımlarını sıfırlar (referral bonus hariç)
 * 
 * Sıfırlanan alanlar:
 * - carryover_steps: Önceki günlerden aktarılan adımlar
 * - carryover_converted: Aktarılandan dönüştürülen
 * - carryover_pending: Aktarılandan bekleyen
 * 
 * Korunan alanlar:
 * - referral_bonus_steps: Davet bonusu adımları (SÜRESİZ)
 * - referral_bonus_converted: Kullanılan bonus
 * - referral_bonus_pending: Bekleyen bonus
 */
export const resetMonthlyCarryoverSteps = functions.pubsub
  .schedule("0 0 1 * *") // Her ayın 1'i 00:00'da çalışır (UTC)
  .timeZone("Europe/Istanbul")
  .onRun(async (context) => {
    console.log("🔄 Aylık aktarılan adım sıfırlama başladı...");

    try {
      const usersSnapshot = await db.collection("users").get();
      const batch = db.batch();
      let resetCount = 0;
      let totalExpiredSteps = 0; // Toplam süresi dolan adımlar

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        
        // Sadece carryover değerleri olan kullanıcıları işle
        if (userData.carryover_steps > 0 || userData.carryover_pending > 0) {
          // Süresi dolan adımları hesapla (pending = dönüştürülmemiş)
          const expiredSteps = userData.carryover_pending || 0;
          totalExpiredSteps += expiredSteps;
          
          // Ay sonu logu kaydet
          const monthEndLog = {
            user_id: userDoc.id,
            reset_date: admin.firestore.FieldValue.serverTimestamp(),
            before_carryover_steps: userData.carryover_steps || 0,
            before_carryover_pending: userData.carryover_pending || 0,
            before_carryover_converted: userData.carryover_converted || 0,
            expired_steps: expiredSteps,
            // Referral bonus korunuyor
            referral_bonus_steps: userData.referral_bonus_steps || 0,
            referral_bonus_pending: userData.referral_bonus_pending || 0,
          };

          // Log koleksiyonuna kaydet
          await db.collection("monthly_reset_logs").add(monthEndLog);

          // 📝 Aktivite geçmişine silinen adımları kaydet (sadece > 0 ise)
          if (expiredSteps > 0) {
            const expiredTimestamp = admin.firestore.FieldValue.serverTimestamp();
            const currentDate = new Date();
            const lastMonth = currentDate.getMonth() === 0 ? 12 : currentDate.getMonth(); // 0=Ocak
            const lastMonthYear = currentDate.getMonth() === 0 ? currentDate.getFullYear() - 1 : currentDate.getFullYear();
            
            // Global activity_logs'a ekle
            await db.collection("activity_logs").add({
              user_id: userDoc.id,
              activity_type: "steps_expired",
              steps: expiredSteps,
              month: lastMonth,
              year: lastMonthYear,
              created_at: expiredTimestamp,
              timestamp: expiredTimestamp,
            });

            // User subcollection'a da ekle
            await db.collection("users").doc(userDoc.id).collection("activity_logs").add({
              user_id: userDoc.id,
              activity_type: "steps_expired",
              steps: expiredSteps,
              month: lastMonth,
              year: lastMonthYear,
              created_at: expiredTimestamp,
              timestamp: expiredTimestamp,
            });
            
            console.log(`📝 ${userDoc.id}: ${expiredSteps} adım silindi logu eklendi`);
          }

          // Kullanıcının carryover değerlerini sıfırla
          batch.update(userDoc.ref, {
            carryover_steps: 0,
            carryover_pending: 0,
            carryover_converted: 0,
            last_monthly_reset: admin.firestore.FieldValue.serverTimestamp(),
          });

          resetCount++;
        }
      }

      await batch.commit();

      // Aylık toplam özet kaydı - ay ve yıl bazında ID ile
      const now = new Date();
      const summaryId = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
      await db.collection("monthly_reset_summaries").doc(summaryId).set({
        reset_date: admin.firestore.FieldValue.serverTimestamp(),
        reset_count: resetCount,
        total_carryover_expired: totalExpiredSteps,
        year: now.getFullYear(),
        month: now.getMonth() + 1,
      });

      // Admin log kaydı
      await db.collection("admin_logs").add({
        action: "monthly_carryover_reset",
        reset_count: resetCount,
        total_expired_steps: totalExpiredSteps,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        note: `${resetCount} kullanıcının aktarılan adımları sıfırlandı, ${totalExpiredSteps} adım süresi doldu`,
      });

      console.log(`✅ Aylık sıfırlama tamamlandı: ${resetCount} kullanıcı, ${totalExpiredSteps} expired adım`);
      return null;
    } catch (error: any) {
      console.error("❌ Aylık sıfırlama hatası:", error);
      return null;
    }
  });

/**
 * Admin tarafından manuel aylık sıfırlama tetikleme
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const triggerMonthlyReset = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    // Admin kontrolü
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Oturum açmanız gerekiyor"
      );
    }

    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
    if (!adminDoc.exists || !adminDoc.data()?.is_active) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Bu işlem için admin yetkisi gerekiyor"
      );
    }

    try {
      const usersSnapshot = await db.collection("users").get();
      const batch = db.batch();
      let resetCount = 0;
      let totalExpiredSteps = 0;

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();

        if (userData.carryover_steps > 0 || userData.carryover_pending > 0) {
          const expiredSteps = userData.carryover_pending || 0;
          totalExpiredSteps += expiredSteps;
          
          await db.collection("monthly_reset_logs").add({
            user_id: userDoc.id,
            reset_date: admin.firestore.FieldValue.serverTimestamp(),
            triggered_by: context.auth.uid,
            manual_trigger: true,
            before_carryover_steps: userData.carryover_steps || 0,
            before_carryover_pending: userData.carryover_pending || 0,
            expired_steps: expiredSteps,
            referral_bonus_steps: userData.referral_bonus_steps || 0,
          });

          batch.update(userDoc.ref, {
            carryover_steps: 0,
            carryover_pending: 0,
            carryover_converted: 0,
            last_monthly_reset: admin.firestore.FieldValue.serverTimestamp(),
          });

          resetCount++;
        }
      }

      await batch.commit();

      // Aylık toplam özet kaydı
      const now = new Date();
      const summaryId = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
      await db.collection("monthly_reset_summaries").doc(summaryId).set({
        reset_date: admin.firestore.FieldValue.serverTimestamp(),
        reset_count: resetCount,
        total_carryover_expired: totalExpiredSteps,
        year: now.getFullYear(),
        month: now.getMonth() + 1,
        triggered_by: context.auth.uid,
        manual_trigger: true,
      });

      await db.collection("admin_logs").add({
        action: "manual_monthly_reset",
        triggered_by: context.auth.uid,
        reset_count: resetCount,
        total_expired_steps: totalExpiredSteps,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        message: `${resetCount} kullanıcının aktarılan adımları sıfırlandı, ${totalExpiredSteps} adım süresi doldu`,
        resetCount,
        totalExpiredSteps,
      };
    } catch (error: any) {
      console.error("Manual monthly reset error:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// ==================== ZAMANLANMIŞ BİLDİRİM GÖNDERİCİ ====================

/**
 * Her dakika çalışarak zamanlanmış bildirimleri kontrol eder ve gönderir
 */
export const processScheduledNotifications = functions.pubsub
  .schedule("every 1 minutes")
  .timeZone("Europe/Istanbul")
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    try {
      // Zamanı gelmiş pending bildirimleri bul
      const pendingSnapshot = await db
        .collection("scheduled_notifications")
        .where("status", "==", "pending")
        .where("scheduled_time", "<=", now)
        .get();

      if (pendingSnapshot.empty) {
        return null;
      }

      for (const doc of pendingSnapshot.docs) {
        const notification = doc.data();

        try {
          // Tüm kullanıcılara bildirim gönder
          const usersSnapshot = await db.collection("users").get();
          const batch = db.batch();

          for (const userDoc of usersSnapshot.docs) {
            const notificationRef = db
              .collection("users")
              .doc(userDoc.id)
              .collection("notifications")
              .doc();

            batch.set(notificationRef, {
              title: notification.title,
              body: notification.body,
              image_url: notification.image_url,
              type: "broadcast",
              is_read: false,
              created_at: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          await batch.commit();

          // Broadcast log
          await db.collection("broadcast_notifications").add({
            title: notification.title,
            body: notification.body,
            image_url: notification.image_url,
            sent_at: admin.firestore.FieldValue.serverTimestamp(),
            sent_by: notification.created_by,
            status: "sent",
            repeat_type: notification.repeat_type,
            scheduled_from: doc.id,
          });

          // Yineleme kontrolü
          const repeatType = notification.repeat_type;
          if (repeatType && repeatType !== "none") {
            // Bir sonraki zamanı hesapla
            const currentTime = notification.scheduled_time.toDate();
            let nextTime: Date;

            if (repeatType === "daily") {
              nextTime = new Date(currentTime);
              nextTime.setDate(nextTime.getDate() + 1);
            } else if (repeatType === "weekly") {
              nextTime = new Date(currentTime);
              nextTime.setDate(nextTime.getDate() + 7);
            } else if (repeatType === "monthly") {
              nextTime = new Date(currentTime);
              nextTime.setMonth(nextTime.getMonth() + 1);
            } else {
              // Bilinmeyen tip, iptal et
              await doc.ref.update({ status: "sent" });
              continue;
            }

            // Yeni zamanı güncelle
            await doc.ref.update({
              scheduled_time: admin.firestore.Timestamp.fromDate(nextTime),
              last_sent_at: admin.firestore.FieldValue.serverTimestamp(),
            });
          } else {
            // Tekil bildirim, gönderildi olarak işaretle
            await doc.ref.update({ status: "sent" });
          }
        } catch (error) {
          console.error(`Bildirim gönderme hatası (${doc.id}):`, error);
          await doc.ref.update({ status: "failed", error: String(error) });
        }
      }

      return null;
    } catch (error) {
      console.error("processScheduledNotifications error:", error);
      return null;
    }
  });

// ==================== SIRALAMA ÖDÜL SİSTEMİ ====================

/**
 * Her ayın 1'inde saat 00:05'te çalışır
 * Geçen ayın sıralamalarını hesaplar ve ödülleri dağıtır
 * 
 * Ödüller:
 * - Umut Hareketi (Bireysel Adım): 1. → 100K, 2. → 75K, 3. → 50K adım
 * - Umut Elçileri (Bireysel Bağış): 1. → 100K, 2. → 75K, 3. → 50K adım
 * - Umut Ormanı (Takım Bağış): 1. → 1M, 2. → 750K, 3. → 500K takım bonus adımı
 */
export const distributeMonthlyLeaderboardRewards = functions.pubsub
  .schedule("5 0 1 * *") // Her ayın 1'i saat 00:05
  .timeZone("Europe/Istanbul")
  .onRun(async (context) => {
    console.log("🏆 Aylık sıralama ödülleri dağıtılıyor...");
    
    const now = new Date();
    // Geçen ay
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lastMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);
    const yearMonth = `${lastMonth.getFullYear()}_${String(lastMonth.getMonth() + 1).padStart(2, "0")}`;
    
    // Ödül miktarları
    const individualRewards = [100000, 75000, 50000]; // 1., 2., 3. için
    const teamRewards = [1000000, 750000, 500000]; // Takımlar için
    
    try {
      // 1. UMUT HAREKETİ - Bireysel Adım Sıralaması
      await distributeStepRewards(lastMonth, lastMonthEnd, yearMonth, individualRewards);
      
      // 2. UMUT ELÇİLERİ - Bireysel Bağış Sıralaması
      await distributeDonationRewards(lastMonth, lastMonthEnd, yearMonth, individualRewards);
      
      // 3. UMUT ORMANI - Takım Sıralaması
      await distributeTeamRewards(lastMonth, lastMonthEnd, yearMonth, teamRewards);
      
      console.log(`✅ ${yearMonth} ödülleri başarıyla dağıtıldı!`);
      return null;
    } catch (error) {
      console.error("Ödül dağıtım hatası:", error);
      return null;
    }
  });

/**
 * Umut Hareketi ödüllerini dağıt
 * Sadece gerçek adımlar sayılır: step_conversion, step_conversion_2x, carryover_conversion
 * Flutter ile tutarlı: hem created_at hem timestamp alanları kontrol edilir
 */
async function distributeStepRewards(
  monthStart: Date,
  monthEnd: Date,
  yearMonth: string,
  rewards: number[]
) {
  const validTypes = ["step_conversion", "step_conversion_2x", "carryover_conversion"];
  const userSteps: Record<string, number> = {};
  const processedDocs = new Set<string>(); // Duplicate önleme
  
  // Her activity type için sorgula
  for (const activityType of validTypes) {
    // 1. created_at ile sorgula
    const snapshot1 = await db
      .collection("activity_logs")
      .where("activity_type", "==", activityType)
      .where("created_at", ">=", admin.firestore.Timestamp.fromDate(monthStart))
      .where("created_at", "<=", admin.firestore.Timestamp.fromDate(monthEnd))
      .get();
    
    for (const doc of snapshot1.docs) {
      if (processedDocs.has(doc.id)) continue;
      processedDocs.add(doc.id);
      
      const data = doc.data();
      const uid = data.user_id;
      const steps = data.steps_converted || 0;
      
      if (uid && steps > 0) {
        userSteps[uid] = (userSteps[uid] || 0) + steps;
      }
    }
    
    // 2. timestamp ile sorgula (eski format desteği)
    const snapshot2 = await db
      .collection("activity_logs")
      .where("activity_type", "==", activityType)
      .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(monthStart))
      .where("timestamp", "<=", admin.firestore.Timestamp.fromDate(monthEnd))
      .get();
    
    for (const doc of snapshot2.docs) {
      if (processedDocs.has(doc.id)) continue;
      processedDocs.add(doc.id);
      
      const data = doc.data();
      const uid = data.user_id;
      const steps = data.steps_converted || 0;
      
      if (uid && steps > 0) {
        userSteps[uid] = (userSteps[uid] || 0) + steps;
      }
    }
  }
  
  // Sırala ve ilk 3'ü al
  const sorted = Object.entries(userSteps)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 3);
  
  // Ödülleri dağıt
  for (let i = 0; i < sorted.length; i++) {
    const [userId, totalSteps] = sorted[i];
    const rewardSteps = rewards[i];
    
    // Kullanıcıya bonus ekle
    await db.collection("users").doc(userId).update({
      leaderboard_bonus_steps: admin.firestore.FieldValue.increment(rewardSteps),
    });
    
    // Ödül kaydı oluştur
    await db.collection("leaderboard_rewards").doc(`${yearMonth}_umut_hareketi_${i + 1}`).set({
      user_id: userId,
      category: "umut_hareketi",
      rank: i + 1,
      total_converted_steps: totalSteps,
      reward_steps: rewardSteps,
      year_month: yearMonth,
      status: "awarded",
      awarded_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Bildirim gönder
    await sendRewardNotification(userId, "umut_hareketi", i + 1, rewardSteps);
    
    console.log(`🥇 Umut Hareketi ${i + 1}. sıra: ${userId} → ${rewardSteps} adım ödülü`);
  }
}

/**
 * Umut Elçileri ödüllerini dağıt (Bireysel bağış sıralaması)
 * Flutter ile tutarlı: hem activity_type hem action_type, hem created_at hem timestamp
 */
async function distributeDonationRewards(
  monthStart: Date,
  monthEnd: Date,
  yearMonth: string,
  rewards: number[]
) {
  const userDonations: Record<string, number> = {};
  const processedDocs = new Set<string>(); // Duplicate önleme
  
  // Helper: Tarih aralığında mı kontrol et
  const isInDateRange = (data: any): boolean => {
    let logDate: Date | null = null;
    if (data.created_at) {
      logDate = data.created_at.toDate();
    } else if (data.timestamp) {
      logDate = data.timestamp.toDate();
    }
    if (!logDate) return false;
    return logDate >= monthStart && logDate <= monthEnd;
  };
  
  // 1. activity_type = 'donation' ile sorgula
  const snapshot1 = await db
    .collection("activity_logs")
    .where("activity_type", "==", "donation")
    .get();
  
  for (const doc of snapshot1.docs) {
    if (processedDocs.has(doc.id)) continue;
    const data = doc.data();
    if (!isInDateRange(data)) continue;
    processedDocs.add(doc.id);
    
    const uid = data.user_id;
    const amount = data.amount || data.hope_amount || 0;
    
    if (uid && amount > 0) {
      userDonations[uid] = (userDonations[uid] || 0) + amount;
    }
  }
  
  // 2. action_type = 'donation' ile sorgula (eski format)
  const snapshot2 = await db
    .collection("activity_logs")
    .where("action_type", "==", "donation")
    .get();
  
  for (const doc of snapshot2.docs) {
    if (processedDocs.has(doc.id)) continue;
    const data = doc.data();
    if (!isInDateRange(data)) continue;
    processedDocs.add(doc.id);
    
    const uid = data.user_id;
    const amount = data.amount || data.hope_amount || 0;
    
    if (uid && amount > 0) {
      userDonations[uid] = (userDonations[uid] || 0) + amount;
    }
  }
  
  // Sırala ve ilk 3'ü al
  const sorted = Object.entries(userDonations)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 3);
  
  // Ödülleri dağıt
  for (let i = 0; i < sorted.length; i++) {
    const [userId, totalDonation] = sorted[i];
    const rewardSteps = rewards[i];
    
    // Kullanıcıya bonus ekle
    await db.collection("users").doc(userId).update({
      leaderboard_bonus_steps: admin.firestore.FieldValue.increment(rewardSteps),
    });
    
    // Ödül kaydı oluştur
    await db.collection("leaderboard_rewards").doc(`${yearMonth}_umut_elcileri_${i + 1}`).set({
      user_id: userId,
      category: "umut_elcileri",
      rank: i + 1,
      total_donated_hope: totalDonation,
      reward_steps: rewardSteps,
      year_month: yearMonth,
      status: "awarded",
      awarded_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Bildirim gönder
    await sendRewardNotification(userId, "umut_elcileri", i + 1, rewardSteps);
    
    console.log(`💚 Umut Elçileri ${i + 1}. sıra: ${userId} → ${rewardSteps} adım ödülü`);
  }
}

/**
 * Umut Ormanı ödüllerini dağıt (Takım sıralaması)
 * Flutter ile tutarlı: hem activity_type hem action_type, hem created_at hem timestamp
 */
async function distributeTeamRewards(
  monthStart: Date,
  monthEnd: Date,
  yearMonth: string,
  rewards: number[]
) {
  const teamDonations: Record<string, number> = {};
  const processedDocs = new Set<string>(); // Duplicate önleme
  
  // Helper: Tarih aralığında mı kontrol et
  const isInDateRange = (data: any): boolean => {
    let logDate: Date | null = null;
    if (data.created_at) {
      logDate = data.created_at.toDate();
    } else if (data.timestamp) {
      logDate = data.timestamp.toDate();
    }
    if (!logDate) return false;
    return logDate >= monthStart && logDate <= monthEnd;
  };
  
  // Helper: Bağış işle
  const processDonation = async (doc: any) => {
    if (processedDocs.has(doc.id)) return;
    const data = doc.data();
    if (!isInDateRange(data)) return;
    processedDocs.add(doc.id);
    
    const uid = data.user_id;
    const amount = data.amount || data.hope_amount || 0;
    
    if (!uid || amount <= 0) return;
    
    // Kullanıcının takımını bul
    const userDoc = await db.collection("users").doc(uid).get();
    const teamId = userDoc.data()?.current_team_id;
    
    if (teamId) {
      teamDonations[teamId] = (teamDonations[teamId] || 0) + amount;
    }
  };
  
  // 1. activity_type = 'donation' ile sorgula
  const snapshot1 = await db
    .collection("activity_logs")
    .where("activity_type", "==", "donation")
    .get();
  
  for (const doc of snapshot1.docs) {
    await processDonation(doc);
  }
  
  // 2. action_type = 'donation' ile sorgula (eski format)
  const snapshot2 = await db
    .collection("activity_logs")
    .where("action_type", "==", "donation")
    .get();
  
  for (const doc of snapshot2.docs) {
    await processDonation(doc);
  }
  
  // Sırala ve ilk 3'ü al
  const sorted = Object.entries(teamDonations)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 3);
  
  // Ödülleri dağıt
  for (let i = 0; i < sorted.length; i++) {
    const [teamId, totalDonation] = sorted[i];
    const rewardSteps = rewards[i];
    
    // Takıma bonus ekle
    await db.collection("teams").doc(teamId).update({
      team_bonus_steps: admin.firestore.FieldValue.increment(rewardSteps),
    });
    
    // Ödül kaydı oluştur
    await db.collection("leaderboard_rewards").doc(`${yearMonth}_umut_ormani_${i + 1}`).set({
      team_id: teamId,
      category: "umut_ormani",
      rank: i + 1,
      total_team_donation: totalDonation,
      reward_steps: rewardSteps,
      year_month: yearMonth,
      status: "awarded",
      awarded_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Takım üyelerine bildirim gönder
    const teamDoc = await db.collection("teams").doc(teamId).get();
    const memberIds = teamDoc.data()?.member_ids || [];
    const teamName = teamDoc.data()?.name || "Takım";
    
    for (const memberId of memberIds) {
      await sendTeamRewardNotification(memberId, teamName, i + 1, rewardSteps);
    }
    
    console.log(`🌳 Umut Ormanı ${i + 1}. sıra: ${teamId} → ${rewardSteps} takım bonus adımı`);
  }
}

/**
 * Bireysel ödül bildirimi gönder
 */
async function sendRewardNotification(
  userId: string,
  category: string,
  rank: number,
  rewardSteps: number
) {
  const rankEmojis = ["🥇", "🥈", "🥉"];
  const categoryNames: Record<string, string> = {
    umut_hareketi: "Umut Hareketi",
    umut_elcileri: "Umut Elçileri",
  };
  
  const title = `${rankEmojis[rank - 1]} Tebrikler! ${rank}. Sıra`;
  const body = `${categoryNames[category]} sıralamasında ${rank}. oldunuz! ${rewardSteps.toLocaleString("tr-TR")} bonus adım kazandınız.`;
  
  await db.collection("users").doc(userId).collection("notifications").add({
    title,
    body,
    type: "leaderboard_reward",
    is_read: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Takım ödül bildirimi gönder
 */
async function sendTeamRewardNotification(
  userId: string,
  teamName: string,
  rank: number,
  rewardSteps: number
) {
  const rankEmojis = ["🥇", "🥈", "🥉"];
  
  const title = `${rankEmojis[rank - 1]} Takımınız ${rank}. Oldu!`;
  const body = `${teamName} takımı Umut Ormanı sıralamasında ${rank}. oldu! Takıma ${rewardSteps.toLocaleString("tr-TR")} bonus adım eklendi.`;
  
  await db.collection("users").doc(userId).collection("notifications").add({
    title,
    body,
    type: "team_leaderboard_reward",
    is_read: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Manuel ödül dağıtımı (Admin için test amaçlı)
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const manualDistributeLeaderboardRewards = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    // Admin kontrolü
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError("unauthenticated", "Oturum açılmalı");
    }
    
    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError("permission-denied", "Admin yetkisi gerekli");
    }
    
    const { yearMonth } = data; // Format: "2024_01"
    if (!yearMonth || !/^\d{4}_\d{2}$/.test(yearMonth)) {
      throw new functions.https.HttpsError("invalid-argument", "Geçerli yıl_ay formatı gerekli (örn: 2024_01)");
    }
    
    const [year, month] = yearMonth.split("_").map(Number);
    const monthStart = new Date(year, month - 1, 1);
    const monthEnd = new Date(year, month, 0, 23, 59, 59);
    
    const individualRewards = [100000, 75000, 50000];
    const teamRewards = [1000000, 750000, 500000];
    
    try {
      await distributeStepRewards(monthStart, monthEnd, yearMonth, individualRewards);
      await distributeDonationRewards(monthStart, monthEnd, yearMonth, individualRewards);
      await distributeTeamRewards(monthStart, monthEnd, yearMonth, teamRewards);
      
      return {
        success: true,
        message: `${yearMonth} ödülleri başarıyla dağıtıldı!`,
      };
    } catch (error: any) {
      console.error("Manuel ödül dağıtım hatası:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// ==================== ADMOB REKLAM GELİRİ RAPORLAMA ====================
export { fetchAdMobRevenue, fetchAdMobRevenueManual } from "./admob-reporter";

// ==================== AYLIK HOPE DEĞERİ HESAPLAMA ====================
export { 
  calculateMonthlyHopeValue, 
  calculateMonthlyHopeValueManual,
  approvePendingDonations,
  getMonthlyHopeSummary
} from "./monthly-hope-calculator";

// ==================== HESAP SİLME (BUG-006) ====================
export { deleteAccount } from "./delete-account";

// ==================== EMAIL DOĞRULAMA KODU ====================
export { sendVerificationCode, verifyEmailCode } from "./email-verification";

// ==================== ŞİFRE SIFIRLAMA KODU ====================
export { sendPasswordResetCode, resetPasswordWithCode } from "./password-reset";