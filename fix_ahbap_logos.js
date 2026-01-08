const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}
const db = admin.firestore();

async function fixAhbapLogos() {
  console.log('🔄 AHBAP bağış kayıtlarına logo ekleniyor...\n');
  
  // Logo'su olan AHBAP'ın URL'si
  const ahbapLogoUrl = 'https://firebasestorage.googleapis.com/v0/b/bir-adim-umut-yeni.firebasestorage.app/o/charity_images%2F5dDeurUvxAxMf5rIVb3G_logo_1767776104959.jpg?alt=media&token=3e18c160-a009-4966-ad90-987aecd68558';
  
  // Global activity_logs güncelle
  const globalLogs = await db.collection('activity_logs')
    .where('activity_type', '==', 'donation')
    .where('charity_name', '==', 'AHBAP')
    .get();
  
  let updated = 0;
  for (const doc of globalLogs.docs) {
    const data = doc.data();
    if (!data.charity_logo_url) {
      await doc.ref.update({ charity_logo_url: ahbapLogoUrl });
      updated++;
      console.log('  ✅ Global log güncellendi: ' + doc.id);
    }
  }
  
  // User subcollection activity_logs güncelle
  const users = await db.collection('users').get();
  for (const userDoc of users.docs) {
    const userLogs = await db.collection('users')
      .doc(userDoc.id)
      .collection('activity_logs')
      .where('activity_type', '==', 'donation')
      .get();
    
    for (const logDoc of userLogs.docs) {
      const data = logDoc.data();
      if ((data.charity_name === 'AHBAP' || data.target_name === 'AHBAP') && !data.charity_logo_url) {
        await logDoc.ref.update({ charity_logo_url: ahbapLogoUrl });
        updated++;
        console.log('  ✅ User log güncellendi: ' + userDoc.id + '/' + logDoc.id);
      }
    }
  }
  
  console.log('\n✅ Toplam ' + updated + ' kayıt güncellendi!');
  process.exit(0);
}

fixAhbapLogos();
