const admin = require('firebase-admin');

// Firebase Admin'i başlat
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateDonationLogos() {
  console.log('🔄 Bağış kayıtlarına logo URL ekleniyor...\n');
  
  try {
    // 1. Önce tüm charity'leri al
    const charitiesSnapshot = await db.collection('charities').get();
    const charityMap = {};
    
    charitiesSnapshot.forEach(doc => {
      const data = doc.data();
      charityMap[doc.id] = {
        name: data.name,
        imageUrl: data.image_url || null
      };
    });
    
    console.log(`📦 ${Object.keys(charityMap).length} vakıf/topluluk/birey bulundu\n`);
    
    // Her vakfın logosunu göster
    for (const [id, charity] of Object.entries(charityMap)) {
      console.log(`  - ${charity.name}: ${charity.imageUrl ? '✅ Logo var' : '❌ Logo yok'}`);
    }
    console.log('');
    
    // 2. Global activity_logs'daki donation kayıtlarını güncelle
    console.log('🔄 Global activity_logs güncelleniyor...');
    const globalLogsSnapshot = await db.collection('activity_logs')
      .where('activity_type', '==', 'donation')
      .get();
    
    let globalUpdated = 0;
    const globalBatch = db.batch();
    
    globalLogsSnapshot.forEach(doc => {
      const data = doc.data();
      const charityId = data.charity_id;
      
      if (charityId && charityMap[charityId] && charityMap[charityId].imageUrl) {
        if (!data.charity_logo_url) {
          globalBatch.update(doc.ref, {
            charity_logo_url: charityMap[charityId].imageUrl
          });
          globalUpdated++;
        }
      }
    });
    
    if (globalUpdated > 0) {
      await globalBatch.commit();
    }
    console.log(`  ✅ ${globalUpdated} global kayıt güncellendi\n`);
    
    // 3. Her kullanıcının activity_logs subcollection'ını güncelle
    console.log('🔄 Kullanıcı activity_logs güncelleniyor...');
    const usersSnapshot = await db.collection('users').get();
    
    let userLogUpdated = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      const userLogsSnapshot = await db.collection('users')
        .doc(userDoc.id)
        .collection('activity_logs')
        .where('activity_type', '==', 'donation')
        .get();
      
      if (userLogsSnapshot.empty) continue;
      
      const userBatch = db.batch();
      let batchCount = 0;
      
      userLogsSnapshot.forEach(logDoc => {
        const data = logDoc.data();
        const charityId = data.charity_id;
        
        if (charityId && charityMap[charityId] && charityMap[charityId].imageUrl) {
          if (!data.charity_logo_url) {
            userBatch.update(logDoc.ref, {
              charity_logo_url: charityMap[charityId].imageUrl
            });
            batchCount++;
            userLogUpdated++;
          }
        }
      });
      
      if (batchCount > 0) {
        await userBatch.commit();
      }
    }
    
    console.log(`  ✅ ${userLogUpdated} kullanıcı kaydı güncellendi\n`);
    
    console.log('✅ Tüm bağış kayıtları güncellendi!');
    console.log(`📊 Toplam: ${globalUpdated + userLogUpdated} kayıt`);
    
  } catch (error) {
    console.error('❌ Hata:', error);
  }
  
  process.exit(0);
}

updateDonationLogos();
