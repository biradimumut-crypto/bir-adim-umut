import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { v4 as uuidv4 } from "uuid";

admin.initializeApp();
const db = admin.firestore();

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
 */
export const createTeam = functions.https.onCall(async (data, context) => {
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
 */
export const joinTeamByReferral = functions.https.onCall(
  async (data, context) => {
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
 */
export const inviteUserToTeam = functions.https.onCall(
  async (data, context) => {
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
 */
export const acceptTeamInvite = functions.https.onCall(
  async (data, context) => {
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
 */
export const rejectTeamInvite = functions.https.onCall(
  async (data, context) => {
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
