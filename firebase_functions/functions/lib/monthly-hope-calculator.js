"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getMonthlyHopeSummary = exports.approvePendingDonations = exports.calculateMonthlyHopeValueManual = exports.calculateMonthlyHopeValue = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const db = admin.firestore();
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
exports.calculateMonthlyHopeValue = functions.pubsub
    .schedule("0 8 7 * *") // Her ayın 7'si saat 08:00 (İstanbul)
    .timeZone("Europe/Istanbul")
    .onRun(async () => {
    var _a, _b, _c, _d;
    try {
        console.log("📊 Aylık Hope değeri hesaplaması başladı...");
        // Önceki ayın tarihlerini hesapla
        const now = new Date();
        const previousMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const monthKey = `${previousMonth.getFullYear()}-${String(previousMonth.getMonth() + 1).padStart(2, "0")}`;
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
            totalAdRevenueUsd = ((_a = data === null || data === void 0 ? void 0 : data.total_revenue) !== null && _a !== void 0 ? _a : 0);
        }
        // 2. ad_revenue_history'den o aya ait gelirleri topla (daha doğru)
        const historySnapshot = await db.collection("ad_revenue_history")
            .where("date", ">=", `${monthKey}-01`)
            .where("date", "<=", `${monthKey}-31`)
            .get();
        if (!historySnapshot.empty) {
            totalAdRevenueUsd = 0;
            historySnapshot.forEach((doc) => {
                var _a;
                totalAdRevenueUsd += ((_a = doc.data().total_revenue) !== null && _a !== void 0 ? _a : 0);
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
            currentTotalHope += ((_b = userData.lifetime_earned_hope) !== null && _b !== void 0 ? _b : 0);
        }
        // Önceki ayın kümülatif toplamını al
        const prevMonth = new Date(monthStart.getFullYear(), monthStart.getMonth() - 1, 1);
        const prevMonthKey = `${prevMonth.getFullYear()}-${String(prevMonth.getMonth() + 1).padStart(2, "0")}`;
        let previousCumulativeHope = 0;
        const prevMonthDoc = await db.collection("monthly_hope_value").doc(prevMonthKey).get();
        if (prevMonthDoc.exists) {
            previousCumulativeHope = ((_d = (_c = prevMonthDoc.data()) === null || _c === void 0 ? void 0 : _c.cumulative_hope) !== null && _d !== void 0 ? _d : 0);
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
        console.log(`✅ ${monthKey} ayı Hope değeri hesaplandı ve kaydedildi`);
        return null;
    }
    catch (error) {
        console.error("❌ Aylık Hope değeri hesaplama hatası:", error);
        return null;
    }
});
/**
 * Pending bağışların durumunu güncelle
 */
async function updatePendingDonationsStatus(monthKey, hopeValueTl) {
    var _a, _b;
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
        const hopeAmount = ((_b = (_a = data.amount) !== null && _a !== void 0 ? _a : data.hope_amount) !== null && _b !== void 0 ? _b : 0);
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
 */
exports.calculateMonthlyHopeValueManual = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    // Admin kontrolü
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Giriş yapmanız gerekiyor");
    }
    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
    if (!adminDoc.exists) {
        throw new functions.https.HttpsError("permission-denied", "Admin yetkisi gerekiyor");
    }
    const { monthKey } = data; // Format: "2026-01"
    if (!monthKey || !/^\d{4}-\d{2}$/.test(monthKey)) {
        throw new functions.https.HttpsError("invalid-argument", "Geçerli bir ay formatı girin (YYYY-MM)");
    }
    try {
        console.log(`📊 Manuel hesaplama başlatıldı: ${monthKey}`);
        // Reklam gelirini al
        const adRevenueDoc = await db.collection("app_stats").doc("ad_revenue").get();
        let totalAdRevenueUsd = 0;
        if (adRevenueDoc.exists) {
            totalAdRevenueUsd = ((_b = (_a = adRevenueDoc.data()) === null || _a === void 0 ? void 0 : _a.total_revenue) !== null && _b !== void 0 ? _b : 0);
        }
        // History'den daha doğru veri al
        const historySnapshot = await db.collection("ad_revenue_history")
            .where("date", ">=", `${monthKey}-01`)
            .where("date", "<=", `${monthKey}-31`)
            .get();
        if (!historySnapshot.empty) {
            totalAdRevenueUsd = 0;
            historySnapshot.forEach((doc) => {
                var _a;
                totalAdRevenueUsd += ((_a = doc.data().total_revenue) !== null && _a !== void 0 ? _a : 0);
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
            currentTotalHope += ((_c = userData.lifetime_earned_hope) !== null && _c !== void 0 ? _c : 0);
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
            previousCumulativeHope = ((_e = (_d = prevMonthDoc.data()) === null || _d === void 0 ? void 0 : _d.cumulative_hope) !== null && _e !== void 0 ? _e : 0);
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
    }
    catch (error) {
        console.error("❌ Manuel hesaplama hatası:", error);
        const errorMessage = error instanceof Error ? error.message : "Hesaplama yapılamadı";
        throw new functions.https.HttpsError("internal", errorMessage);
    }
});
/**
 * Admin onayı ile bağışları "completed" durumuna geçir
 * Derneğe aktarım için hazır olduğunda kullanılır
 */
exports.approvePendingDonations = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    // Admin kontrolü
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Giriş yapmanız gerekiyor");
    }
    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
    if (!adminDoc.exists) {
        throw new functions.https.HttpsError("permission-denied", "Admin yetkisi gerekiyor");
    }
    const { monthKey, charityId } = data;
    if (!monthKey) {
        throw new functions.https.HttpsError("invalid-argument", "Ay bilgisi gerekli (YYYY-MM)");
    }
    try {
        console.log(`✅ Bağış onayı başlatıldı: ${monthKey}${charityId ? ` - ${charityId}` : ""}`);
        // O aydaki pending_approval bağışları bul - donation_month alanı ile basit sorgu
        let query = db.collection("activity_logs")
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
            totalHope += ((_b = (_a = docData.amount) !== null && _a !== void 0 ? _a : docData.hope_amount) !== null && _b !== void 0 ? _b : 0);
            totalTl += ((_c = docData.total_value_tl) !== null && _c !== void 0 ? _c : 0);
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
    }
    catch (error) {
        console.error("❌ Bağış onay hatası:", error);
        const errorMessage = error instanceof Error ? error.message : "Onay yapılamadı";
        throw new functions.https.HttpsError("internal", errorMessage);
    }
});
/**
 * Aylık özet raporu getir (Admin panel için)
 */
exports.getMonthlyHopeSummary = functions.https.onCall(async (data, context) => {
    // Admin kontrolü
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Giriş yapmanız gerekiyor");
    }
    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
    if (!adminDoc.exists) {
        throw new functions.https.HttpsError("permission-denied", "Admin yetkisi gerekiyor");
    }
    try {
        // Son 12 ayın verilerini çek
        const summarySnapshot = await db.collection("monthly_hope_value")
            .orderBy("month", "desc")
            .limit(12)
            .get();
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const months = summarySnapshot.docs.map((doc) => (Object.assign(Object.assign({}, doc.data()), { id: doc.id })));
        // Her ay için pending bağış sayısını da ekle
        for (const monthData of months) {
            const monthKey = monthData.month;
            if (!monthKey)
                continue;
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
            const charityBreakdown = {};
            pendingDocs.forEach((doc) => {
                var _a, _b, _c, _d, _e;
                const docData = doc.data();
                const charityId = docData.charity_id;
                const charityName = ((_b = (_a = docData.charity_name) !== null && _a !== void 0 ? _a : docData.recipient_name) !== null && _b !== void 0 ? _b : "Bilinmeyen");
                if (!charityBreakdown[charityId]) {
                    charityBreakdown[charityId] = { hope: 0, tl: 0, count: 0, charityName };
                }
                charityBreakdown[charityId].hope += ((_d = (_c = docData.amount) !== null && _c !== void 0 ? _c : docData.hope_amount) !== null && _d !== void 0 ? _d : 0);
                charityBreakdown[charityId].tl += ((_e = docData.total_value_tl) !== null && _e !== void 0 ? _e : 0);
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
    }
    catch (error) {
        console.error("❌ Özet rapor hatası:", error);
        const errorMessage = error instanceof Error ? error.message : "Rapor alınamadı";
        throw new functions.https.HttpsError("internal", errorMessage);
    }
});
//# sourceMappingURL=monthly-hope-calculator.js.map