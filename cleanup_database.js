const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Korunacak kullanıcılar
const PROTECTED_EMAILS = ['deneme@deneme.com', 'biradimumut@gmail.com'];

async function getProtectedUserIds() {
  const protectedIds = [];
  
  for (const email of PROTECTED_EMAILS) {
    const snapshot = await db.collection('users').where('email', '==', email).limit(1).get();
    if (!snapshot.empty) {
      protectedIds.push(snapshot.docs[0].id);
      console.log(`✅ Korunan kullanıcı bulundu: ${email} (${snapshot.docs[0].id})`);
    }
  }
  
  return protectedIds;
}

async function deleteCollection(collectionPath, excludeUserIds = []) {
  const collectionRef = db.collection(collectionPath);
  let query = collectionRef.limit(500);
  
  let totalDeleted = 0;
  
  while (true) {
    const snapshot = await query.get();
    
    if (snapshot.empty) {
      break;
    }
    
    const batch = db.batch();
    let batchCount = 0;
    
    snapshot.docs.forEach((doc) => {
      const data = doc.data();
      // Korunan kullanıcıların verileri hariç
      const userId = data.user_id || data.userId || null;
      
      if (excludeUserIds.length > 0 && userId && excludeUserIds.includes(userId)) {
        return; // Bu veriyi silme
      }
      
      batch.delete(doc.ref);
      batchCount++;
    });
    
    if (batchCount > 0) {
      await batch.commit();
      totalDeleted += batchCount;
      console.log(`   Silinen: ${batchCount} döküman...`);
    }
    
    // Son batch'te sadece korunan veriler kaldıysa çık
    if (batchCount === 0) {
      break;
    }
  }
  
  return totalDeleted;
}

async function deleteSubcollection(parentCollection, subcollectionName, excludeUserIds = []) {
  const parentSnapshot = await db.collection(parentCollection).get();
  let totalDeleted = 0;
  
  for (const parentDoc of parentSnapshot.docs) {
    // Korunan kullanıcıların subcollection'larını silme
    if (excludeUserIds.includes(parentDoc.id)) {
      console.log(`   Korunan: ${parentDoc.id} - ${subcollectionName}`);
      continue;
    }
    
    const subcollectionRef = parentDoc.ref.collection(subcollectionName);
    const subSnapshot = await subcollectionRef.get();
    
    if (!subSnapshot.empty) {
      const batch = db.batch();
      subSnapshot.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
      totalDeleted += subSnapshot.size;
    }
  }
  
  return totalDeleted;
}

async function cleanupDatabase() {
  console.log('🔄 Veritabanı temizliği başlıyor...\n');
  
  // Korunan kullanıcı ID'lerini al
  const protectedIds = await getProtectedUserIds();
  console.log(`\n📋 Korunan ${protectedIds.length} kullanıcı\n`);
  
  const results = [];
  
  // 1. Aktivite logları - korunan kullanıcılar hariç
  console.log('📁 activity_logs temizleniyor...');
  const activityDeleted = await deleteCollection('activity_logs', protectedIds);
  results.push({ collection: 'activity_logs', deleted: activityDeleted });
  
  // 2. Donations koleksiyonu
  console.log('📁 donations temizleniyor...');
  const donationsDeleted = await deleteCollection('donations', protectedIds);
  results.push({ collection: 'donations', deleted: donationsDeleted });
  
  // 3. Comments koleksiyonu
  console.log('📁 comments temizleniyor...');
  const commentsDeleted = await deleteCollection('comments', protectedIds);
  results.push({ collection: 'comments', deleted: commentsDeleted });
  
  // 4. Hopes koleksiyonu (eğer varsa)
  console.log('📁 hopes temizleniyor...');
  const hopesDeleted = await deleteCollection('hopes', protectedIds);
  results.push({ collection: 'hopes', deleted: hopesDeleted });
  
  // 5. Team members - tüm takımlardan
  console.log('📁 team_members temizleniyor...');
  const teamMembersDeleted = await deleteSubcollection('teams', 'team_members', protectedIds);
  results.push({ collection: 'teams/*/team_members', deleted: teamMembersDeleted });
  
  // 6. User badges subcollection
  console.log('📁 users/*/badges temizleniyor...');
  const badgesDeleted = await deleteSubcollection('users', 'badges', protectedIds);
  results.push({ collection: 'users/*/badges', deleted: badgesDeleted });
  
  // 7. User activity_logs subcollection
  console.log('📁 users/*/activity_logs temizleniyor...');
  const userActivityDeleted = await deleteSubcollection('users', 'activity_logs', protectedIds);
  results.push({ collection: 'users/*/activity_logs', deleted: userActivityDeleted });
  
  // 8. Charities koleksiyonundaki istatistikleri sıfırla (charities kalacak, sadece istatistikler sıfırlanacak)
  console.log('📁 charities istatistikleri sıfırlanıyor...');
  const charitiesSnapshot = await db.collection('charities').get();
  let charitiesReset = 0;
  
  for (const doc of charitiesSnapshot.docs) {
    await doc.ref.update({
      collected_amount: 0,
      donor_count: 0
    });
    charitiesReset++;
  }
  results.push({ collection: 'charities (istatistik reset)', deleted: charitiesReset });
  
  // 9. Korunan kullanıcıların istatistiklerini sıfırla
  console.log('📁 Korunan kullanıcıların istatistikleri sıfırlanıyor...');
  for (const uid of protectedIds) {
    await db.collection('users').doc(uid).update({
      wallet_balance_hope: 0,
      today_steps: 0,
      today_earned_hope: 0,
      lifetime_steps: 0,
      lifetime_earned_hope: 0,
      lifetime_donated_hope: 0,
      total_donation_count: 0,
      total_ad_watched: 0,
      total_ad_earnings: 0,
      weekly_steps: 0,
      weekly_earned_hope: 0,
      monthly_steps: 0,
      monthly_earned_hope: 0
    });
  }
  results.push({ collection: 'users (korunan - istatistik reset)', deleted: protectedIds.length });
  
  // Sonuçları yazdır
  console.log('\n📊 TEMİZLİK RAPORU:');
  console.log('═'.repeat(50));
  
  let totalDeleted = 0;
  for (const result of results) {
    console.log(`  ${result.collection}: ${result.deleted}`);
    totalDeleted += result.deleted;
  }
  
  console.log('═'.repeat(50));
  console.log(`  TOPLAM: ${totalDeleted} işlem yapıldı`);
  console.log('\n✅ Veritabanı temizliği tamamlandı!');
}

cleanupDatabase()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Hata:', error);
    process.exit(1);
  });
