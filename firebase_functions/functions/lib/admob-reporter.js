"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fetchAdMobRevenueManual = exports.fetchAdMobRevenue = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const googleapis_1 = require("googleapis");
// AdMob API için service account credentials
const SERVICE_ACCOUNT = {
    type: "service_account",
    project_id: "bir-adim-umut-yeni",
    private_key_id: "3911f037d0e709e07cf278c44dc1d79ee27afe33",
    private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDkktaAWSVit2We\nXOu637wiKP6awzfcAAG4nrhJpsBfgvsH6xRlqgZ+XBVfpP8WG+vPAWQyJqrp5Tik\nkaJDDqgg7dhWX9kVddrcFBRUWU8zBFOC2Hv2SO9hM11pw1LuMmSczrN520O8o5nY\n43alEJ3Gu8Q0PNJA8q6qRNEulrQyS8Wfdy+uVzoESEFN+0n2Nsv9rvB7wWCy8ErB\nwQW54roonMNIVeELeOeM0NT0om9NOFXxgQwzavMy+T9SFPIMjwikGfv2FAvCrqqx\n98OcfZnSGEsCB6NOZ8P3/VR6GiRFssKCgIMCi0XyulOlg+JTsbZzta+tXYRUo99E\nu5WySCwbAgMBAAECggEAEhIp3evZBiefDm4k6kQAs71Z+RJbZYv6lttgO90bHcdV\nNsMMfHJ8y5tWypZY3ylF82UWGYDvx54qZEMUo7M88kgw77iUM8Ylj3tm6rmaMVuz\niTIPBYxZS0NXAfhB+OMIYVKrjdlv+YdVr81hS/DhsxyVM9a7KLdcZ8nDtVM6MTT2\nHa4JOE3LCzlLYRlSnneRAzvl55SeD00+bSMbJ5sTlUsDmo+X89reH0ZNwc79PwG6\nqGu7woQslVXiQ9eoB3rNX8FbgYDTu8nrFg6yrsJx4z+CuS+j36EOp59apVI9aQk1\nZbrR1AIteFA/6f64RSIkJtmMoGP0lTrZWi0uhwStQQKBgQD6AOmU5pYaNX42tP9w\nGKU3C8EslG8Uc07s9Sqk6ym+TX9ydp4W+hj5/PGP86jqPFbeNGQpUOYJLClDOCvT\ncEuOi+r5GL3cRWPRFkljg7FHz00Wt2M7WiR8whJWttqu9z4qzqE2Vw0BaNU+SZsP\nbv8/oX0uiSJZz6aorU89CgzWTQKBgQDqDlb7CyFFkjsn/hIyjAk9t3NO/y0gtR/U\n63lgrGwDWQKGbnrtE3mnfoZ7SAUHeH2lnXB51LAsnrxffa+dZsNNkRDPVruCh9Ep\n+toU285Dw3t2AL4coFrQurGQ1XPDAwcue5omYxfz6csdz+vfvyjZMXYgNKv3Vwjg\ns9KvaG+QBwKBgDORKJ0MCv4Q9p22K9IlYz69b/UQEPF471i1ITyvPQcB2T309Zrr\nr2cxI2p76eWW2Jww1lAnXauarlAtL+0HBq66cZc74T2kGniwTib2rQSQ3+fFn/RI\nHaqWJU45nVXlra8Ku/oHbqlRxFp6uD8wt/maB8YnhyxbRpcYWHXQsuEpAoGAWFkl\nWAmxe3NhRQ1QjSfy7QrsSatku23jIBnqbSVoeDMHEvttB0RMrX7DAJIE4/cFZphx\nNmukPJOGg30L5xw9KHBTqhARI4pk17XK0AjQaR/G4JoTKPcWkKeIEyWfVsMz2MXr\nQAYzqmxbsVskrAaaQrG65xk6uFhwD3GRW4jOY80CgYEAnWWDPO33wgMGxWh+myKg\n92A2ZJIIswFRwIIc06kC5P8i5ctxEAQJMxFM3MV8Q07//b2mN24FJvbSZppcUBcm\nGrqBvM5CMGc+70qt7cTB7Iff1RiZrwXMEOrltW3jRpf/OMCqdz9io8+8g6vjZ0gX\ne1CyZVJJzM4ysZavYZkfpjE=\n-----END PRIVATE KEY-----\n",
    client_email: "admob-reporter@bir-adim-umut-yeni.iam.gserviceaccount.com",
    client_id: "105065950760075183601",
    auth_uri: "https://accounts.google.com/o/oauth2/auth",
    token_uri: "https://oauth2.googleapis.com/token",
};
// Firestore referansı
const db = admin.firestore();
/**
 * AdMob'dan gelir raporunu çeker ve Firestore'a kaydeder
 * Her gün saat 06:00'da çalışır (Türkiye saati)
 */
exports.fetchAdMobRevenue = functions.pubsub
    .schedule("0 6 * * *") // Her gün 06:00
    .timeZone("Europe/Istanbul")
    .onRun(async () => {
    var _a, _b, _c;
    try {
        console.log("📊 AdMob raporu çekiliyor...");
        // Google Auth client oluştur
        const auth = new googleapis_1.google.auth.GoogleAuth({
            credentials: SERVICE_ACCOUNT,
            scopes: ["https://www.googleapis.com/auth/admob.readonly"],
        });
        const authClient = await auth.getClient();
        const admob = googleapis_1.google.admob({ version: "v1", auth: authClient });
        // Bugünün ve dünün tarihini al
        const today = new Date();
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        // Son 30 günlük rapor için tarihler
        const thirtyDaysAgo = new Date(today);
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        // AdMob hesap bilgisini al
        const accountResponse = await admob.accounts.list();
        const accounts = accountResponse.data.account || [];
        if (accounts.length === 0) {
            console.error("❌ AdMob hesabı bulunamadı");
            return null;
        }
        const accountName = accounts[0].name;
        if (!accountName) {
            console.error("❌ AdMob hesap adı alınamadı");
            return null;
        }
        console.log(`✅ AdMob hesabı: ${accountName}`);
        // Network raporu oluştur (son 30 gün)
        const reportResponse = await admob.accounts.networkReport.generate({
            parent: accountName,
            requestBody: {
                reportSpec: {
                    dateRange: {
                        startDate: {
                            year: thirtyDaysAgo.getFullYear(),
                            month: thirtyDaysAgo.getMonth() + 1,
                            day: thirtyDaysAgo.getDate(),
                        },
                        endDate: {
                            year: yesterday.getFullYear(),
                            month: yesterday.getMonth() + 1,
                            day: yesterday.getDate(),
                        },
                    },
                    dimensions: ["AD_UNIT", "FORMAT"],
                    metrics: [
                        "ESTIMATED_EARNINGS",
                        "IMPRESSIONS",
                        "CLICKS",
                        "AD_REQUESTS",
                    ],
                },
            },
        });
        // Rapor verilerini işle
        let totalRevenue = 0;
        let totalImpressions = 0;
        let interstitialRevenue = 0;
        let interstitialImpressions = 0;
        let bannerRevenue = 0;
        let bannerImpressions = 0;
        let rewardedRevenue = 0;
        let rewardedImpressions = 0;
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const rows = reportResponse.data;
        if (rows && rows.length > 0) {
            for (const row of rows) {
                if (row.row) {
                    const metricValues = row.row.metricValues || {};
                    const dimensionValues = row.row.dimensionValues || {};
                    // Gelir (mikro USD cinsinden, 1.000.000'a böl)
                    const earnings = ((_a = metricValues.ESTIMATED_EARNINGS) === null || _a === void 0 ? void 0 : _a.microsValue) || 0;
                    const revenue = earnings / 1000000;
                    // Gösterim
                    const impressions = parseInt(((_b = metricValues.IMPRESSIONS) === null || _b === void 0 ? void 0 : _b.integerValue) || "0");
                    // Format türü
                    const format = ((_c = dimensionValues.FORMAT) === null || _c === void 0 ? void 0 : _c.value) || "";
                    totalRevenue += revenue;
                    totalImpressions += impressions;
                    // Format bazlı ayrıştır
                    if (format.includes("INTERSTITIAL")) {
                        interstitialRevenue += revenue;
                        interstitialImpressions += impressions;
                    }
                    else if (format.includes("BANNER")) {
                        bannerRevenue += revenue;
                        bannerImpressions += impressions;
                    }
                    else if (format.includes("REWARDED")) {
                        rewardedRevenue += revenue;
                        rewardedImpressions += impressions;
                    }
                }
            }
        }
        // Firestore'a kaydet
        const revenueData = {
            total_revenue: totalRevenue,
            total_impressions: totalImpressions,
            interstitial_revenue: interstitialRevenue,
            interstitial_impressions: interstitialImpressions,
            banner_revenue: bannerRevenue,
            banner_impressions: bannerImpressions,
            rewarded_revenue: rewardedRevenue,
            rewarded_impressions: rewardedImpressions,
            last_updated: admin.firestore.FieldValue.serverTimestamp(),
            report_period: "last_30_days",
            currency: "USD",
        };
        await db.collection("app_stats").doc("ad_revenue").set(revenueData, {
            merge: true,
        });
        // Günlük geçmiş kaydı da tut
        const dateKey = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, "0")}-${String(yesterday.getDate()).padStart(2, "0")}`;
        await db.collection("ad_revenue_history").doc(dateKey).set({
            date: dateKey,
            total_revenue: totalRevenue,
            total_impressions: totalImpressions,
            interstitial_revenue: interstitialRevenue,
            banner_revenue: bannerRevenue,
            rewarded_revenue: rewardedRevenue,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ AdMob raporu kaydedildi:`);
        console.log(`   Toplam Gelir: $${totalRevenue.toFixed(2)}`);
        console.log(`   Toplam Gösterim: ${totalImpressions}`);
        console.log(`   Interstitial: $${interstitialRevenue.toFixed(2)}`);
        console.log(`   Banner: $${bannerRevenue.toFixed(2)}`);
        console.log(`   Rewarded: $${rewardedRevenue.toFixed(2)}`);
        return null;
    }
    catch (error) {
        console.error("❌ AdMob raporu çekilemedi:", error);
        return null;
    }
});
/**
 * Manuel tetikleme için HTTP endpoint
 * Admin panelinden "Şimdi Güncelle" butonu için
 */
exports.fetchAdMobRevenueManual = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    // Admin kontrolü
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Giriş yapmanız gerekiyor");
    }
    // Admin mi kontrol et
    const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
    if (!adminDoc.exists) {
        throw new functions.https.HttpsError("permission-denied", "Admin yetkisi gerekiyor");
    }
    try {
        console.log("📊 Manuel AdMob raporu çekiliyor...");
        const auth = new googleapis_1.google.auth.GoogleAuth({
            credentials: SERVICE_ACCOUNT,
            scopes: ["https://www.googleapis.com/auth/admob.readonly"],
        });
        const authClient = await auth.getClient();
        const admob = googleapis_1.google.admob({ version: "v1", auth: authClient });
        const today = new Date();
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        const thirtyDaysAgo = new Date(today);
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        const accountResponse = await admob.accounts.list();
        const accounts = accountResponse.data.account || [];
        if (accounts.length === 0) {
            throw new functions.https.HttpsError("not-found", "AdMob hesabı bulunamadı");
        }
        const accountName = accounts[0].name;
        if (!accountName) {
            throw new functions.https.HttpsError("not-found", "AdMob hesap adı alınamadı");
        }
        const reportResponse = await admob.accounts.networkReport.generate({
            parent: accountName,
            requestBody: {
                reportSpec: {
                    dateRange: {
                        startDate: {
                            year: thirtyDaysAgo.getFullYear(),
                            month: thirtyDaysAgo.getMonth() + 1,
                            day: thirtyDaysAgo.getDate(),
                        },
                        endDate: {
                            year: yesterday.getFullYear(),
                            month: yesterday.getMonth() + 1,
                            day: yesterday.getDate(),
                        },
                    },
                    dimensions: ["FORMAT"],
                    metrics: ["ESTIMATED_EARNINGS", "IMPRESSIONS"],
                },
            },
        });
        let totalRevenue = 0;
        let totalImpressions = 0;
        let interstitialRevenue = 0;
        let interstitialImpressions = 0;
        let bannerRevenue = 0;
        let bannerImpressions = 0;
        let rewardedRevenue = 0;
        let rewardedImpressions = 0;
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const rows = reportResponse.data;
        if (rows && rows.length > 0) {
            for (const row of rows) {
                if (row.row) {
                    const metricValues = row.row.metricValues || {};
                    const dimensionValues = row.row.dimensionValues || {};
                    const earnings = ((_a = metricValues.ESTIMATED_EARNINGS) === null || _a === void 0 ? void 0 : _a.microsValue) || 0;
                    const revenue = earnings / 1000000;
                    const impressions = parseInt(((_b = metricValues.IMPRESSIONS) === null || _b === void 0 ? void 0 : _b.integerValue) || "0");
                    const format = ((_c = dimensionValues.FORMAT) === null || _c === void 0 ? void 0 : _c.value) || "";
                    totalRevenue += revenue;
                    totalImpressions += impressions;
                    if (format.includes("INTERSTITIAL")) {
                        interstitialRevenue += revenue;
                        interstitialImpressions += impressions;
                    }
                    else if (format.includes("BANNER")) {
                        bannerRevenue += revenue;
                        bannerImpressions += impressions;
                    }
                    else if (format.includes("REWARDED")) {
                        rewardedRevenue += revenue;
                        rewardedImpressions += impressions;
                    }
                }
            }
        }
        const revenueData = {
            total_revenue: totalRevenue,
            total_impressions: totalImpressions,
            interstitial_revenue: interstitialRevenue,
            interstitial_impressions: interstitialImpressions,
            banner_revenue: bannerRevenue,
            banner_impressions: bannerImpressions,
            rewarded_revenue: rewardedRevenue,
            rewarded_impressions: rewardedImpressions,
            last_updated: admin.firestore.FieldValue.serverTimestamp(),
            report_period: "last_30_days",
            currency: "USD",
        };
        await db.collection("app_stats").doc("ad_revenue").set(revenueData, {
            merge: true,
        });
        return {
            success: true,
            data: revenueData,
            message: `Rapor güncellendi: $${totalRevenue.toFixed(2)} toplam gelir`,
        };
    }
    catch (error) {
        console.error("❌ Manuel AdMob raporu hatası:", error);
        throw new functions.https.HttpsError("internal", error.message || "Rapor çekilemedi");
    }
});
//# sourceMappingURL=admob-reporter.js.map