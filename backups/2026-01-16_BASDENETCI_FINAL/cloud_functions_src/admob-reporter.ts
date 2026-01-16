import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { google } from "googleapis";

// NOT: admin.initializeApp() index.ts'de zaten çağrılıyor
// Burada tekrar çağırmıyoruz - çakışma önlenir

// Firestore referansı (lazy initialization)
const getDb = () => admin.firestore();

// ============================================================================
// AdMob API OAuth2 Credentials (Firebase Functions config üzerinden)
// ============================================================================
// Ayarla:
// firebase functions:config:set \
//   admob.client_id="YOUR_CLIENT_ID" \
//   admob.client_secret="YOUR_CLIENT_SECRET" \
//   admob.refresh_token="YOUR_REFRESH_TOKEN"
//
// Not: redirect_uri olarak OAuth Playground kullandıysan burada aynı olmalı:
// https://developers.google.com/oauthplayground
// ============================================================================

const getAdMobOAuthClient = () => {
  const config = functions.config();

  const clientId = config.admob?.client_id;
  const clientSecret = config.admob?.client_secret;
  const refreshToken = config.admob?.refresh_token;

  if (!clientId || !clientSecret || !refreshToken) {
    console.error("❌ AdMob OAuth config missing!");
    console.error(
      'Set: admob.client_id, admob.client_secret, admob.refresh_token (firebase functions:config:set ...)'
    );
    throw new Error(
      "AdMob OAuth config missing. Please set admob.client_id, admob.client_secret, admob.refresh_token in Firebase Functions config."
    );
  }

  const oAuth2Client = new google.auth.OAuth2(
    clientId,
    clientSecret,
    "https://developers.google.com/oauthplayground"
  );

  oAuth2Client.setCredentials({ refresh_token: refreshToken });
  return oAuth2Client;
};

/**
 * AdMob'dan gelir raporunu çeker ve Firestore'a kaydeder
 * Her gün saat 06:00'da çalışır (Türkiye saati)
 */
export const fetchAdMobRevenue = functions.pubsub
  .schedule("0 6 * * *") // Her gün 06:00
  .timeZone("Europe/Istanbul")
  .onRun(async () => {
    try {
      console.log("📊 AdMob raporu çekiliyor...");

      const authClient = getAdMobOAuthClient();
      const admob = google.admob({ version: "v1", auth: authClient as any });

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
        console.error("❌ AdMob hesabı bulunamadı (accounts.list boş döndü)");
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
            metrics: ["ESTIMATED_EARNINGS", "IMPRESSIONS", "CLICKS", "AD_REQUESTS"],
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
      const rows = (reportResponse as any).data as any[];
      if (rows && rows.length > 0) {
        for (const row of rows) {
          if (row.row) {
            const metricValues = row.row.metricValues || {};
            const dimensionValues = row.row.dimensionValues || {};

            // Gelir (mikro USD cinsinden, 1.000.000'a böl)
            const earnings = metricValues.ESTIMATED_EARNINGS?.microsValue || 0;
            const revenue = earnings / 1_000_000;

            // Gösterim
            const impressions = parseInt(metricValues.IMPRESSIONS?.integerValue || "0", 10);

            // Format türü
            const format = dimensionValues.FORMAT?.value || "";

            totalRevenue += revenue;
            totalImpressions += impressions;

            // Format bazlı ayrıştır
            if (format.includes("INTERSTITIAL")) {
              interstitialRevenue += revenue;
              interstitialImpressions += impressions;
            } else if (format.includes("BANNER")) {
              bannerRevenue += revenue;
              bannerImpressions += impressions;
            } else if (format.includes("REWARDED")) {
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

      await getDb().collection("app_stats").doc("ad_revenue").set(revenueData, { merge: true });

      // Günlük geçmiş kaydı da tut
      const dateKey = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(
        2,
        "0"
      )}-${String(yesterday.getDate()).padStart(2, "0")}`;

      await getDb().collection("ad_revenue_history").doc(dateKey).set({
        date: dateKey,
        total_revenue: totalRevenue,
        total_impressions: totalImpressions,
        interstitial_revenue: interstitialRevenue,
        banner_revenue: bannerRevenue,
        rewarded_revenue: rewardedRevenue,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ AdMob raporu kaydedildi:
   Toplam Gelir: $${totalRevenue.toFixed(2)}
   Toplam Gösterim: ${totalImpressions}
   Interstitial: $${interstitialRevenue.toFixed(2)}
   Banner: $${bannerRevenue.toFixed(2)}
   Rewarded: $${rewardedRevenue.toFixed(2)}`);

      return null;
    } catch (error) {
      console.error("❌ AdMob raporu çekilemedi:", error);
      return null;
    }
  });

/**
 * Manuel tetikleme için Callable endpoint
 * Admin panelinden "Şimdi Güncelle" butonu için
 */
export const fetchAdMobRevenueManual = functions.https.onCall(async (data, context) => {
  // Auth kontrolü
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Giriş yapmanız gerekiyor");
  }

  // Admin kontrolü
  const adminDoc = await getDb().collection("admins").doc(context.auth.uid).get();
  if (!adminDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "Admin yetkisi gerekiyor");
  }

  try {
    console.log("📊 Manuel AdMob raporu çekiliyor...");

    const authClient = getAdMobOAuthClient();
    const admob = google.admob({ version: "v1", auth: authClient as any });

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
    const rows = (reportResponse as any).data as any[];
    if (rows && rows.length > 0) {
      for (const row of rows) {
        if (row.row) {
          const metricValues = row.row.metricValues || {};
          const dimensionValues = row.row.dimensionValues || {};

          const earnings = metricValues.ESTIMATED_EARNINGS?.microsValue || 0;
          const revenue = earnings / 1_000_000;

          const impressions = parseInt(metricValues.IMPRESSIONS?.integerValue || "0", 10);
          const format = dimensionValues.FORMAT?.value || "";

          totalRevenue += revenue;
          totalImpressions += impressions;

          if (format.includes("INTERSTITIAL")) {
            interstitialRevenue += revenue;
            interstitialImpressions += impressions;
          } else if (format.includes("BANNER")) {
            bannerRevenue += revenue;
            bannerImpressions += impressions;
          } else if (format.includes("REWARDED")) {
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

    await getDb().collection("app_stats").doc("ad_revenue").set(revenueData, { merge: true });

    return {
      success: true,
      data: revenueData,
      message: `Rapor güncellendi: $${totalRevenue.toFixed(2)} toplam gelir`,
    };
  } catch (error: any) {
    console.error("❌ Manuel AdMob raporu hatası:", error);
    throw new functions.https.HttpsError("internal", error?.message || "Rapor çekilemedi");
  }
});
