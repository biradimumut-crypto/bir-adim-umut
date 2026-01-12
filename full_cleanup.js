const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// SİLİNECEK KOLEKSİYONLAR
const COLLECTIONS_TO_DELETE = [
  'users',
  'activity_logs',
  'donations',
  'notifications',
  'teams',
  'monthly_hope_value',
  'ad_revenue_history',
  'daily_stats',
  'step_leaderboard',
  'donation_leaderboard',
  'hope_leaderboard',
  'team_leaderboard',
  'admin_logs',
  'admin_stats',
  'broadcast_notifications',
  'ad_logs',
  'ad_errors',
  'charity_comments',
  'invitations',
  'user_badges',
  'monthly_reset_summaries'
];

// SİLİNMEYECEK KOLEKSİYONLAR (referans için)
// - admins
// - charities
// - badge_definitions
// - app_settings

async function deleteCollection(collectionPath) {
  const collectionRef = db.collection(collectionPath);
  let totalDeleted = 0;
  
  while (true) {
    const snapshot = await collectionRef.limit(500).get();
    
    if (snapshot.empty) {
      break;
    }
    
    const batch = db.batch();
    
    for (const doc of snapshot.docs) {
      // Alt koleksiyonları da sil (users için)
      if (collectionPath === 'users') {
        const subCollections = ['activity_logs', 'notifications', 'badges', 'daily_steps', 'ad_logs', 'sessions'];
        for (const subCol of subCollections) {
          await deleteSubCollection(doc.ref, subCol);
        }
      }
      
      // Teams için team_members alt koleksiyonu
      if (collectionPath === 'teams') {
        await deleteSubCollection(doc.ref, 'team_members');
      }
      
      batch.delete(doc.ref);
    }
    
    await batch.commit();
    totalDeleted += snapshot.size;
    console.log(`  📝 ${collectionPath}: ${totalDeleted} kayıt silindi...`);
  }
  
  return totalDeleted;
}

async function deleteSubCollection(parentRef, subCollectionName) {
  const subCollectionRef = parentRef.collection(subCollectionName);
  
  while (true) {
    const snapshot = await subCollectionRef.limit(500).get();
    
    if (snapshot.empty) {
      break;
    }
    
    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function resetAppStats() {
  // app_stats koleksiyonundaki sayaçları sıfırla (silmiyoruz, sıfırlıyoruz)
  const statsRef = db.collection('app_stats');
  const snapshot = await statsRef.get();
  
  const batch = db.batch();
  snapshot.docs.forEach(doc => {
    batch.update(doc.ref, {
      total_revenue: 0,
      total_users: 0,
      total_donations: 0,
      total_hope: 0,
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });
  });
  
  if (!snapshot.empty) {
    await batch.commit();
    console.log('✅ app_stats sıfırlandı');
  }
}

async function main() {
  console.log('🧹 TAM TEMİZLİK BAŞLIYOR...');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
  
  let totalDeleted = 0;
  
  for (const collection of COLLECTIONS_TO_DELETE) {
    console.log(`🗑️  ${collection} siliniyor...`);
    try {
      const count = await deleteCollection(collection);
      totalDeleted += count;
      if (count > 0) {
        console.log(`   ✅ ${collection}: ${count} kayıt silindi`);
      } else {
        console.log(`   ⚪ ${collection}: boş`);
      }
    } catch (error) {
      console.log(`   ❌ ${collection}: Hata - ${error.message}`);
    }
    console.log('');
  }
  
  // App stats'ı sıfırla
  console.log('📊 app_stats sıfırlanıyor...');
  await resetAppStats();
  
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`✅ TEMİZLİK TAMAMLANDI!`);
  console.log(`📊 Toplam ${totalDeleted} kayıt silindi`);
  console.log('');
  console.log('📌 Korunan koleksiyonlar:');
  console.log('   - admins');
  console.log('   - charities');
  console.log('   - badge_definitions');
  console.log('   - app_settings');
  console.log('');
  console.log('🔑 Şimdi uygulamaya giriş yapıp yeni test kullanıcısı oluşturabilirsin.');
  console.log('⚠️  Admin yetkisi için: Firebase Console > admins koleksiyonu > UID ekle');
  
  process.exit(0);
}

main().catch(error => {
  console.error('❌ Kritik hata:', error);
  process.exit(1);
});
