import * as admin from "firebase-admin";

const serviceAccount = require("../../../serviceAccountKey.json");
admin.initializeApp({ 
  credential: admin.credential.cert(serviceAccount),
  projectId: "bir-adim-umut-yeni"
});
const db = admin.firestore();
const auth = admin.auth();

// Korunacak e-postalar
const PROTECTED_EMAILS = [
  "deneme@deneme.com",
  "sercankarsli@gmail.com"
];

async function cleanup() {
  console.log("🧹 Firebase Temizlik Başlıyor...\n");

  try {
    // 1. Korunacak kullanıcıların UID'lerini bul
    const protectedUids: string[] = [];
    
    for (const email of PROTECTED_EMAILS) {
      try {
        const user = await auth.getUserByEmail(email);
        protectedUids.push(user.uid);
        console.log(`✅ Korunacak: ${email} (${user.uid})`);
      } catch (e) {
        console.log(`⚠️ Kullanıcı bulunamadı: ${email}`);
      }
    }

    console.log(`\n📋 Korunacak UID'ler: ${protectedUids.join(", ")}\n`);

    // 2. Tüm Auth kullanıcılarını listele ve silinecekleri belirle
    const listUsersResult = await auth.listUsers(1000);
    const usersToDelete = listUsersResult.users.filter(
      (user) => !protectedUids.includes(user.uid)
    );

    console.log(`🗑️ Silinecek kullanıcı sayısı: ${usersToDelete.length}`);

    // 3. Silinecek kullanıcıları Auth'dan sil
    for (const user of usersToDelete) {
      console.log(`  Siliniyor: ${user.email || user.uid}`);
      
      // Firestore'dan kullanıcı dokümanını sil
      await db.collection("users").doc(user.uid).delete();
      
      // Auth'dan sil
      await auth.deleteUser(user.uid);
    }

    console.log(`\n✅ ${usersToDelete.length} kullanıcı silindi.\n`);

    // 4. Korunan kullanıcıların verilerini sıfırla
    console.log("🔄 Korunan kullanıcıların verileri sıfırlanıyor...\n");

    for (const uid of protectedUids) {
      console.log(`  Sıfırlanıyor: ${uid}`);
      
      // Kullanıcı dokümanındaki sayısal değerleri sıfırla
      await db.collection("users").doc(uid).update({
        total_hopes: 0,
        donated_hopes: 0,
        total_steps: 0,
        current_hopes: 0,
        last_step_count: 0,
        last_synced: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Kullanıcının donations alt koleksiyonunu sil
      const donationsRef = db.collection("users").doc(uid).collection("donations");
      const donationsSnapshot = await donationsRef.get();
      
      for (const doc of donationsSnapshot.docs) {
        await doc.ref.delete();
      }
      console.log(`    - ${donationsSnapshot.size} bağış silindi`);

      // Kullanıcının steps alt koleksiyonunu sil (varsa)
      const stepsRef = db.collection("users").doc(uid).collection("steps");
      const stepsSnapshot = await stepsRef.get();
      
      for (const doc of stepsSnapshot.docs) {
        await doc.ref.delete();
      }
      console.log(`    - ${stepsSnapshot.size} adım kaydı silindi`);

      // Kullanıcının daily_steps alt koleksiyonunu sil (varsa)
      const dailyStepsRef = db.collection("users").doc(uid).collection("daily_steps");
      const dailyStepsSnapshot = await dailyStepsRef.get();
      
      for (const doc of dailyStepsSnapshot.docs) {
        await doc.ref.delete();
      }
      console.log(`    - ${dailyStepsSnapshot.size} günlük adım kaydı silindi`);
    }

    // 5. Genel donations koleksiyonunu temizle
    console.log("\n🗑️ Genel donations koleksiyonu temizleniyor...");
    const globalDonationsSnapshot = await db.collection("donations").get();
    
    for (const doc of globalDonationsSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`  - ${globalDonationsSnapshot.size} bağış silindi`);

    // 6. Campaigns koleksiyonundaki bağış sayılarını sıfırla
    console.log("\n🔄 Kampanya bağış sayıları sıfırlanıyor...");
    const campaignsSnapshot = await db.collection("campaigns").get();
    
    for (const doc of campaignsSnapshot.docs) {
      await doc.ref.update({
        current_hopes: 0,
        donor_count: 0,
      });
      console.log(`  - ${doc.data().title || doc.id} sıfırlandı`);
    }

    console.log("\n✅ Temizlik tamamlandı!");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📌 Korunan hesaplar:");
    console.log("   - deneme@deneme.com (test)");
    console.log("   - sercankarsli@gmail.com (admin)");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

  } catch (error) {
    console.error("❌ Hata:", error);
  }

  process.exit(0);
}

cleanup();
