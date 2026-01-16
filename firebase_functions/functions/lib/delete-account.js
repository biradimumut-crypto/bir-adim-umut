"use strict";
/**
 * HESAP SİLME - Cloud Function (BUG-006)
 *
 * Apple App Store, Google Play Store, GDPR ve KVKK gerekliliği.
 * Kullanıcının tüm verilerini siler (Hard Delete).
 * 🚨 P1-2: App Check enforcement aktif
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteAccount = void 0;
const admin = require("firebase-admin");
const functions = require("firebase-functions");
const db = admin.firestore();
const storage = admin.storage();
const auth = admin.auth();
// 🚨 P1-2: App Check Helper (v1 API için)
function assertAppCheck(context) {
    if (!context.app) {
        throw new functions.https.HttpsError("failed-precondition", "App Check token gerekli. Lütfen uygulamayı güncelleyin.");
    }
}
/**
 * Büyük koleksiyonları chunked olarak sil (500 limit)
 */
async function deleteCollectionChunked(collectionRef, batchSize = 500) {
    let totalDeleted = 0;
    while (true) {
        const snapshot = await collectionRef.limit(batchSize).get();
        if (snapshot.empty) {
            break;
        }
        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });
        await batch.commit();
        totalDeleted += snapshot.docs.length;
        // Rate limiting - çok hızlı silme işlemlerini önle
        if (snapshot.docs.length === batchSize) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }
    return totalDeleted;
}
/**
 * Query sonuçlarını chunked olarak sil
 */
async function deleteQueryResultsChunked(query, batchSize = 500) {
    let totalDeleted = 0;
    while (true) {
        const snapshot = await query.limit(batchSize).get();
        if (snapshot.empty) {
            break;
        }
        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });
        await batch.commit();
        totalDeleted += snapshot.docs.length;
        if (snapshot.docs.length === batchSize) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }
    return totalDeleted;
}
/**
 * Storage klasörünü recursive sil
 */
async function deleteStorageFolder(folderPath) {
    try {
        const bucket = storage.bucket();
        const [files] = await bucket.getFiles({ prefix: folderPath });
        if (files.length === 0) {
            return 0;
        }
        // Dosyaları paralel olarak sil (max 10 concurrent)
        const chunkSize = 10;
        for (let i = 0; i < files.length; i += chunkSize) {
            const chunk = files.slice(i, i + chunkSize);
            await Promise.all(chunk.map(file => file.delete()));
        }
        return files.length;
    }
    catch (error) {
        console.warn(`Storage silme hatası (${folderPath}):`, error);
        return 0;
    }
}
/**
 * Hesap Silme - Callable Function
 *
 * Silinen veriler:
 * - users/{uid}
 * - users/{uid}/notifications/*
 * - users/{uid}/badges/*
 * - users/{uid}/activity_logs/*
 * - team_members (user_uid == uid)
 * - activity_logs (user_id == uid)
 * - daily_steps (user_id == uid)
 * - Storage: users/{uid}/*
 * - Firebase Auth hesabı
 * 🚨 P1-2: App Check enforcement aktif
 */
exports.deleteAccount = functions.https.onCall(async (data, context) => {
    var _a;
    // 🚨 App Check kontrolü
    assertAppCheck(context);
    // 1. Authentication kontrolü
    if (!((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid)) {
        throw new functions.https.HttpsError("unauthenticated", "Hesap silmek için giriş yapmalısınız.");
    }
    const uid = context.auth.uid;
    console.log(`🗑️ Hesap silme başlatıldı: ${uid}`);
    const deletionReport = {
        notifications: 0,
        badges: 0,
        userActivityLogs: 0,
        teamMembers: 0,
        activityLogs: 0,
        dailySteps: 0,
        storageFiles: 0,
    };
    try {
        // 2. Kullanıcı dökümanının varlığını kontrol et
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Kullanıcı bulunamadı.");
        }
        // 3. Alt koleksiyonları sil
        // 3.1 Notifications
        deletionReport.notifications = await deleteCollectionChunked(db.collection("users").doc(uid).collection("notifications"));
        console.log(`  ✓ Notifications silindi: ${deletionReport.notifications}`);
        // 3.2 Badges
        deletionReport.badges = await deleteCollectionChunked(db.collection("users").doc(uid).collection("badges"));
        console.log(`  ✓ Badges silindi: ${deletionReport.badges}`);
        // 3.3 User activity_logs (subcollection)
        deletionReport.userActivityLogs = await deleteCollectionChunked(db.collection("users").doc(uid).collection("activity_logs"));
        console.log(`  ✓ User activity_logs silindi: ${deletionReport.userActivityLogs}`);
        // 4. Global koleksiyonlardan kullanıcı verilerini sil
        // 4.1 team_members
        deletionReport.teamMembers = await deleteQueryResultsChunked(db.collection("team_members").where("user_id", "==", uid));
        // user_uid field'ı da kontrol et (eski format)
        deletionReport.teamMembers += await deleteQueryResultsChunked(db.collection("team_members").where("user_uid", "==", uid));
        console.log(`  ✓ Team members silindi: ${deletionReport.teamMembers}`);
        // 4.2 activity_logs (global)
        deletionReport.activityLogs = await deleteQueryResultsChunked(db.collection("activity_logs").where("user_id", "==", uid));
        console.log(`  ✓ Activity logs silindi: ${deletionReport.activityLogs}`);
        // 4.3 daily_steps
        deletionReport.dailySteps = await deleteQueryResultsChunked(db.collection("daily_steps").where("user_id", "==", uid));
        console.log(`  ✓ Daily steps silindi: ${deletionReport.dailySteps}`);
        // 5. Takımdan çıkar (eğer takım üyesiyse)
        const userData = userDoc.data();
        const currentTeamId = userData === null || userData === void 0 ? void 0 : userData.current_team_id;
        if (currentTeamId) {
            try {
                const teamRef = db.collection("teams").doc(currentTeamId);
                const teamDoc = await teamRef.get();
                if (teamDoc.exists) {
                    const teamData = teamDoc.data();
                    const memberIds = (teamData === null || teamData === void 0 ? void 0 : teamData.member_ids) || [];
                    const newMemberIds = memberIds.filter((id) => id !== uid);
                    // Takım lideriyse takımı sil
                    if ((teamData === null || teamData === void 0 ? void 0 : teamData.leader_uid) === uid) {
                        // Takım üyelerini sil
                        await deleteCollectionChunked(teamRef.collection("team_members"));
                        // Takımı sil
                        await teamRef.delete();
                        console.log(`  ✓ Kullanıcının takımı silindi: ${currentTeamId}`);
                    }
                    else {
                        // Sadece üye listesinden çıkar
                        await teamRef.update({
                            member_ids: newMemberIds,
                            members_count: admin.firestore.FieldValue.increment(-1),
                        });
                        // team_members subcollection'dan sil
                        await teamRef.collection("team_members").doc(uid).delete();
                        console.log(`  ✓ Takımdan çıkarıldı: ${currentTeamId}`);
                    }
                }
            }
            catch (teamError) {
                console.warn("Takım güncelleme hatası:", teamError);
            }
        }
        // 6. Storage dosyalarını sil
        deletionReport.storageFiles = await deleteStorageFolder(`users/${uid}`);
        deletionReport.storageFiles += await deleteStorageFolder(`profile_photos/${uid}`);
        console.log(`  ✓ Storage dosyaları silindi: ${deletionReport.storageFiles}`);
        // 7. Ana kullanıcı dökümanını sil
        await db.collection("users").doc(uid).delete();
        console.log(`  ✓ User dökümanı silindi`);
        // 8. Firebase Auth hesabını sil
        await auth.deleteUser(uid);
        console.log(`  ✓ Firebase Auth hesabı silindi`);
        console.log(`✅ Hesap silme tamamlandı: ${uid}`, deletionReport);
        return {
            success: true,
            message: "Hesabınız başarıyla silindi.",
            deletionReport,
        };
    }
    catch (error) {
        console.error(`❌ Hesap silme hatası (${uid}):`, error);
        // Özel hata mesajları
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", "Hesap silinirken bir hata oluştu. Lütfen tekrar deneyin.");
    }
});
//# sourceMappingURL=delete-account.js.map