import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

// 🚨 P1-2 REV.2: App Check Helper (v1 API için)
function assertAppCheck(context: functions.https.CallableContext) {
  if (!context.app) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "App Check token gerekli. Lütfen uygulamayı güncelleyin."
    );
  }
}

/**
 * Aylık Hope Değeri Hesaplama Sistemi
 * 
 * Her ayın 7'sinde çalışır ve önceki ayın Hope/TL değerini hesaplar.
 * 
 * Formül: 1 Hope = (Aylık Reklam Geliri × 0.60) / Üretilen Toplam Hope
 * 
 * Örnek:
 * - Ocak reklam geliri: 100,000 TL
 * - Bağış havuzu (%60): 60,000 TL
 * - Ocak üretilen Hope: 10,000,000 Hope
 * - 1 Hope = 60,000 / 10,000,000 = 0.006 TL
 */

// Bağış havuzu oranı (%60)
const DONATION_POOL_RATIO = 0.60;

// Varsayılan USD/TL kuru (API'den alınamazsa)
const DEFAULT_USD_TL_RATE = 35.0;

/**
 * Her ayın 7'sinde önceki ayın Hope değerini hesaplar
 * Örn: 7 Şubat'ta Ocak ayını hesaplar
 */
export const calculateMonthlyHopeValue = functions.pubsub
  .schedule("0 8 7 * *") // Her ayın 7'si saat 08:00 (İstanbul)
  .timeZone("Europe/Istanbul")
  .onRun(async () => {
    try {
      console.log("📊 Aylık Hope değeri hesaplaması başladı...");

      // Önceki ayın tarihlerini hesapla
      const now = new Date();
      const previousMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      const monthKey = `${previousMonth.getFullYear()}-${String(previousMonth.getMonth() + 1).padStart(2, "0")}`;
      
      // 🚨 IDEMPOTENCY CHECK: Bu ay zaten işlendiyse tekrar çalışma
      const existingDoc = await db.collection("monthly_hope_value").doc(monthKey).get();
      if (existingDoc.exists) {
        const existingData = existingDoc.data();
        const existingStatus = existingData?.status;
        const completedAt = existingData?.completed_at;
        
        // approved veya completed ise kesinlikle çık
        if (["approved", "completed"].includes(existingStatus)) {
          console.log(`⚠️ ${monthKey} zaten onaylandı/tamamlandı (status: ${existingStatus}), çıkılıyor...`);
          return null;
        }
        
        // calculated ise: completed_at var mı kontrol et
        // Eğer completed_at varsa = tam bitti, çık
        // Eğer completed_at yoksa = yarım kalmış olabilir, tekrar çalış
        if (existingStatus === "calculated") {
          if (completedAt) {
            console.log(`⚠️ ${monthKey} zaten hesaplandı ve tamamlandı, çıkılıyor...`);
            console.log(`📋 Mevcut veri: calculated_at=${existingData?.calculated_at?.toDate()?.toISOString()}`);
            return null;
          } else {
            console.log(`⚠️ ${monthKey} yarım kalmış (calculated ama completed_at yok), tekrar hesaplanıyor...`);
          }
        }
      }
      console.log(`✅ ${monthKey} henüz işlenmemiş veya yarım kalmış, hesaplamaya devam...`);
      
      const monthStart = new Date(previousMonth.getFullYear(), previousMonth.getMonth(), 1);
      const monthEnd = new Date(previousMonth.getFullYear(), previousMonth.getMonth() + 1, 0, 23, 59, 59);

      console.log(`📅 Hesaplanan ay: ${monthKey}`);
      console.log(`📅 Başlangıç: ${monthStart.toISOString()}`);
      console.log(`📅 Bitiş: ${monthEnd.toISOString()}`);

      // 1. O aydaki toplam reklam gelirini al (app_stats/ad_revenue)
      const adRevenueDoc = await db.collection("app_stats").doc("ad_revenue").get();
      let totalAdRevenueUsd = 0;
      
      if (adRevenueDoc.exists) {
        const data = adRevenueDoc.data();
        totalAdRevenueUsd = (data?.total_revenue ?? 0) as number;
      }

      // 2. ad_revenue_history'den o aya ait gelirleri topla (daha doğru)
      const historySnapshot = await db.collection("ad_revenue_history")
        .where("date", ">=", `${monthKey}-01`)
        .where("date", "<=", `${monthKey}-31`)
        .get();
      
      if (!historySnapshot.empty) {
        totalAdRevenueUsd = 0;
        historySnapshot.forEach((doc) => {
          totalAdRevenueUsd += (doc.data().total_revenue ?? 0) as number;
        });
      }

      // 3. USD → TL dönüşümü (şimdilik sabit kur, ileride API eklenebilir)
      const usdToTlRate = DEFAULT_USD_TL_RATE;
      const totalAdRevenueTl = totalAdRevenueUsd * usdToTlRate;

      // 4. Bağış havuzunu hesapla (%60)
      const donationPoolTl = totalAdRevenueTl * DONATION_POOL_RATIO;

      // 5. Şu anki kümülatif toplam Hope'u hesapla
      let currentTotalHope = 0;
      
      const usersSnapshot = await db.collection("users").get();
      for (const doc of usersSnapshot.docs) {
        const userData = doc.data();
        currentTotalHope += (userData.lifetime_earned_hope ?? 0) as number;
      }

      // Önceki ayın kümülatif toplamını al
      const prevMonth = new Date(monthStart.getFullYear(), monthStart.getMonth() - 1, 1);
      const prevMonthKey = `${prevMonth.getFullYear()}-${String(prevMonth.getMonth() + 1).padStart(2, "0")}`;
      
      let previousCumulativeHope = 0;
      const prevMonthDoc = await db.collection("monthly_hope_value").doc(prevMonthKey).get();
      if (prevMonthDoc.exists) {
        previousCumulativeHope = (prevMonthDoc.data()?.cumulative_hope ?? 0) as number;
      }
      
      // Bu ay üretilen Hope = Şu anki toplam - Önceki ay sonu toplam
      const totalHopeProduced = currentTotalHope - previousCumulativeHope;

      console.log(`💰 Toplam Reklam Geliri (USD): $${totalAdRevenueUsd.toFixed(2)}`);
      console.log(`💰 Toplam Reklam Geliri (TL): ₺${totalAdRevenueTl.toFixed(2)}`);
      console.log(`💰 Bağış Havuzu (TL): ₺${donationPoolTl.toFixed(2)}`);
      console.log(`🌟 Şu anki kümülatif: ${currentTotalHope.toLocaleString()}`);
      console.log(`🌟 Önceki ay sonu: ${previousCumulativeHope.toLocaleString()}`);
      console.log(`🌟 Bu ay üretilen: ${totalHopeProduced.toLocaleString()}`);

      // 6. Hope değerini hesapla
      let hopeValueTl = 0;
      if (totalHopeProduced > 0) {
        hopeValueTl = donationPoolTl / totalHopeProduced;
      }

      console.log(`📈 1 Hope = ₺${hopeValueTl.toFixed(6)}`);

      // 7. Firestore'a kaydet
      const monthlyData = {
        month: monthKey,
        total_ad_revenue_usd: totalAdRevenueUsd,
        total_ad_revenue_tl: totalAdRevenueTl,
        usd_to_tl_rate: usdToTlRate,
        donation_pool_ratio: DONATION_POOL_RATIO,
        donation_pool_tl: donationPoolTl,
        total_hope_produced: totalHopeProduced,
        cumulative_hope: currentTotalHope, // Sonraki ay için
        hope_value_tl: hopeValueTl,
        status: "calculated", // calculated -> approved -> completed
        calculated_at: admin.firestore.FieldValue.serverTimestamp(),
        approved_at: null,
        completed_at: null,
        approved_by: null,
      };

      await db.collection("monthly_hope_value").doc(monthKey).set(monthlyData);

      // 8. O aydaki pending bağışları güncelle (status: pending_calculation -> pending_approval)
      await updatePendingDonationsStatus(monthKey, hopeValueTl);
      
      // 🚨 IDEMPOTENCY: İşlem tamamen bittikten sonra completed_at'i işaretle
      await db.collection("monthly_hope_value").doc(monthKey).update({
        completed_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ ${monthKey} ayı Hope değeri hesaplandı ve kaydedildi (completed_at işaretlendi)`);

      return null;
    } catch (error) {
      console.error("❌ Aylık Hope değeri hesaplama hatası:", error);
      return null;
    }
  });

/**
 * Pending bağışların durumunu güncelle
 */
async function updatePendingDonationsStatus(monthKey: string, hopeValueTl: number) {
  // Sadece "pending" durumundaki ve bu aya ait bağışları al
  // donation_month alanını kullanarak basit ve performanslı sorgu
  const donationsSnapshot = await db.collection("activity_logs")
    .where("activity_type", "==", "donation")
    .where("donation_month", "==", monthKey)
    .where("donation_status", "==", "pending")
    .get();

  const batch = db.batch();
  let count = 0;

  for (const doc of donationsSnapshot.docs) {
    const data = doc.data();
    const hopeAmount = (data.amount ?? data.hope_amount ?? 0) as number;
    const tlValue = hopeAmount * hopeValueTl;

    batch.update(doc.ref, {
      donation_month: monthKey,
      hope_value_tl: hopeValueTl,
      total_value_tl: tlValue,
      donation_status: "pending_approval", // Admin onayı bekliyor
      value_calculated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    count++;
  }

  if (count > 0) {
    await batch.commit();
    console.log(`📝 ${count} adet bağış güncellendi`);
  }
}

/**
 * Admin manuel tetikleme - belirli bir ay için hesaplama
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const calculateMonthlyHopeValueManual = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    // Admin kontrolü
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Giriş yapmanız gerekiyor"
      );
    }

    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin yetkisi gerekiyor"
      );
    }

    const { monthKey } = data; // Format: "2026-01"
    
    if (!monthKey || !/^\d{4}-\d{2}$/.test(monthKey)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Geçerli bir ay formatı girin (YYYY-MM)"
      );
    }

    try {
      console.log(`📊 Manuel hesaplama başlatıldı: ${monthKey}`);

      // Reklam gelirini al
      const adRevenueDoc = await db.collection("app_stats").doc("ad_revenue").get();
      let totalAdRevenueUsd = 0;
      
      if (adRevenueDoc.exists) {
        totalAdRevenueUsd = (adRevenueDoc.data()?.total_revenue ?? 0) as number;
      }

      // History'den daha doğru veri al
      const historySnapshot = await db.collection("ad_revenue_history")
        .where("date", ">=", `${monthKey}-01`)
        .where("date", "<=", `${monthKey}-31`)
        .get();
      
      if (!historySnapshot.empty) {
        totalAdRevenueUsd = 0;
        historySnapshot.forEach((doc) => {
          totalAdRevenueUsd += (doc.data().total_revenue ?? 0) as number;
        });
      }

      const usdToTlRate = DEFAULT_USD_TL_RATE;
      const totalAdRevenueTl = totalAdRevenueUsd * usdToTlRate;
      const donationPoolTl = totalAdRevenueTl * DONATION_POOL_RATIO;

      // Şu anki toplam üretilen Hope'u hesapla (tüm kullanıcıların lifetime_earned_hope toplamı)
      let currentTotalHope = 0;
      
      const usersSnapshot = await db.collection("users").get();
      for (const doc of usersSnapshot.docs) {
        const userData = doc.data();
        currentTotalHope += (userData.lifetime_earned_hope ?? 0) as number;
      }
      
      // Önceki ayın kümülatif toplamını al (varsa)
      // Böylece sadece BU AY üretilen Hope'u bulabiliriz
      const [year, month] = monthKey.split("-").map(Number);
      const prevMonth = month === 1 ? 12 : month - 1;
      const prevYear = month === 1 ? year - 1 : year;
      const prevMonthKey = `${prevYear}-${String(prevMonth).padStart(2, "0")}`;
      
      let previousCumulativeHope = 0;
      const prevMonthDoc = await db.collection("monthly_hope_value").doc(prevMonthKey).get();
      if (prevMonthDoc.exists) {
        previousCumulativeHope = (prevMonthDoc.data()?.cumulative_hope ?? 0) as number;
      }
      
      // Bu ay üretilen Hope = Şu anki toplam - Önceki ay sonu toplam
      const totalHopeProduced = currentTotalHope - previousCumulativeHope;
      
      console.log(`🌟 Şu anki kümülatif Hope: ${currentTotalHope.toLocaleString()}`);
      console.log(`🌟 Önceki ay sonu kümülatif: ${previousCumulativeHope.toLocaleString()}`);
      console.log(`🌟 Bu ay üretilen Hope: ${totalHopeProduced.toLocaleString()}`);

      // Hope değerini hesapla
      let hopeValueTl = 0;
      if (totalHopeProduced > 0) {
        hopeValueTl = donationPoolTl / totalHopeProduced;
      }

      // Kaydet - cumulative_hope'u da kaydediyoruz ki sonraki ay kullanabilelim
      const monthlyData = {
        month: monthKey,
        total_ad_revenue_usd: totalAdRevenueUsd,
        total_ad_revenue_tl: totalAdRevenueTl,
        usd_to_tl_rate: usdToTlRate,
        donation_pool_ratio: DONATION_POOL_RATIO,
        donation_pool_tl: donationPoolTl,
        total_hope_produced: totalHopeProduced,
        cumulative_hope: currentTotalHope, // Ay sonu kümülatif toplam (sonraki ay için)
        hope_value_tl: hopeValueTl,
        status: "calculated",
        calculated_at: admin.firestore.FieldValue.serverTimestamp(),
        approved_at: null,
        completed_at: null,
        approved_by: null,
        manual_calculation: true,
        calculated_by: context.auth.uid,
      };

      await db.collection("monthly_hope_value").doc(monthKey).set(monthlyData);

      // Bağışları güncelle
      await updatePendingDonationsStatus(monthKey, hopeValueTl);

      return {
        success: true,
        data: {
          month: monthKey,
          totalAdRevenueUsd,
          totalAdRevenueTl,
          donationPoolTl,
          totalHopeProduced,
          hopeValueTl,
        },
        message: `${monthKey} ayı hesaplandı: 1 Hope = ₺${hopeValueTl.toFixed(6)}`,
      };
    } catch (error: unknown) {
      console.error("❌ Manuel hesaplama hatası:", error);
      const errorMessage = error instanceof Error ? error.message : "Hesaplama yapılamadı";
      throw new functions.https.HttpsError("internal", errorMessage);
    }
  }
);

/**
 * Admin onayı ile bağışları "completed" durumuna geçir
 * Derneğe aktarım için hazır olduğunda kullanılır
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const approvePendingDonations = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    // Admin kontrolü
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Giriş yapmanız gerekiyor"
      );
    }

    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin yetkisi gerekiyor"
      );
    }

    const { monthKey, charityId } = data;

    if (!monthKey) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Ay bilgisi gerekli (YYYY-MM)"
      );
    }

    try {
      console.log(`✅ Bağış onayı başlatıldı: ${monthKey}${charityId ? ` - ${charityId}` : ""}`);

      // O aydaki pending_approval bağışları bul - donation_month alanı ile basit sorgu
      let query: admin.firestore.Query = db.collection("activity_logs")
        .where("activity_type", "==", "donation")
        .where("donation_month", "==", monthKey)
        .where("donation_status", "==", "pending_approval");

      // Eğer belirli bir dernek için onay yapılıyorsa
      if (charityId) {
        query = query.where("charity_id", "==", charityId);
      }

      const donationsSnapshot = await query.get();

      if (donationsSnapshot.empty) {
        return {
          success: false,
          message: "Onaylanacak bağış bulunamadı",
        };
      }

      const batch = db.batch();
      let totalHope = 0;
      let totalTl = 0;
      let count = 0;

      for (const doc of donationsSnapshot.docs) {
        const docData = doc.data();
        batch.update(doc.ref, {
          donation_status: "completed",
          approved_at: admin.firestore.FieldValue.serverTimestamp(),
          approved_by: context.auth.uid,
        });
        
        totalHope += (docData.amount ?? docData.hope_amount ?? 0) as number;
        totalTl += (docData.total_value_tl ?? 0) as number;
        count++;
      }

      await batch.commit();

      // monthly_hope_value'ı da güncelle
      await db.collection("monthly_hope_value").doc(monthKey).update({
        status: "approved",
        approved_at: admin.firestore.FieldValue.serverTimestamp(),
        approved_by: context.auth.uid,
      });

      console.log(`✅ ${count} bağış onaylandı: ${totalHope} Hope = ₺${totalTl.toFixed(2)}`);

      return {
        success: true,
        data: {
          approvedCount: count,
          totalHope,
          totalTl,
        },
        message: `${count} bağış onaylandı (${totalHope.toLocaleString()} Hope = ₺${totalTl.toFixed(2)})`,
      };
    } catch (error: unknown) {
      console.error("❌ Bağış onay hatası:", error);
      const errorMessage = error instanceof Error ? error.message : "Onay yapılamadı";
      throw new functions.https.HttpsError("internal", errorMessage);
    }
  }
);

/**
 * Aylık özet raporu getir (Admin panel için)
 * 🚨 P1-2 REV.2: App Check enforcement aktif
 */
export const getMonthlyHopeSummary = functions.https.onCall(
  async (data, context) => {
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    
    // Admin kontrolü
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Giriş yapmanız gerekiyor"
      );
    }

    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin yetkisi gerekiyor"
      );
    }

    try {
      // Son 12 ayın verilerini çek
      const summarySnapshot = await db.collection("monthly_hope_value")
        .orderBy("month", "desc")
        .limit(12)
        .get();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const months: any[] = summarySnapshot.docs.map((doc) => ({
        ...doc.data(),
        id: doc.id,
      }));

      // Her ay için pending bağış sayısını da ekle
      for (const monthData of months) {
        const monthKey = monthData.month as string;
        if (!monthKey) continue;

        // Pending bağışları say - donation_month kullanarak daha basit sorgu
        // 'in' operatörü range ile kullanılamaz, bu yüzden donation_month alanını kullanıyoruz
        const pendingSnapshot = await db.collection("activity_logs")
          .where("activity_type", "==", "donation")
          .where("donation_month", "==", monthKey)
          .get();
        
        // Client tarafında pending ve pending_approval olanları filtrele
        const pendingDocs = pendingSnapshot.docs.filter(doc => {
          const status = doc.data().donation_status;
          return status === "pending" || status === "pending_approval";
        });

        // Dernek bazlı breakdown
        const charityBreakdown: Record<string, { 
          hope: number; 
          tl: number; 
          count: number;
          charityName: string;
        }> = {};

        pendingDocs.forEach((doc) => {
          const docData = doc.data();
          const charityId = docData.charity_id as string;
          const charityName = (docData.charity_name ?? docData.recipient_name ?? "Bilinmeyen") as string;
          
          if (!charityBreakdown[charityId]) {
            charityBreakdown[charityId] = { hope: 0, tl: 0, count: 0, charityName };
          }
          
          charityBreakdown[charityId].hope += (docData.amount ?? docData.hope_amount ?? 0) as number;
          charityBreakdown[charityId].tl += (docData.total_value_tl ?? 0) as number;
          charityBreakdown[charityId].count++;
        });

        monthData.pendingDonations = {
          totalCount: pendingDocs.length,
          charityBreakdown,
        };
      }

      return {
        success: true,
        data: months,
      };
    } catch (error: unknown) {
      console.error("❌ Özet rapor hatası:", error);
      const errorMessage = error instanceof Error ? error.message : "Rapor alınamadı";
      throw new functions.https.HttpsError("internal", errorMessage);
    }
  }
);
