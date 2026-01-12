const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setup() {
  // 1. Admin ekle
  await db.collection('admins').doc('5IWNVdVz5kezNR13gcljAvG6xHQ2').set({
    email: 'admin@biradimumut.com',
    role: 'super_admin',
    created_at: admin.firestore.FieldValue.serverTimestamp()
  });
  console.log('✅ Admin eklendi');

  // 2. Charities ekle
  const charities = [
    { id: 'ahbap', name: 'AHBAP', logo_url: 'https://firebasestorage.googleapis.com/v0/b/bir-adim-umut.firebasestorage.app/o/charity_logos%2Fahbap.png?alt=media', description: 'AHBAP Derneği', is_active: true },
    { id: 'tema', name: 'TEMA Vakfı', logo_url: 'https://firebasestorage.googleapis.com/v0/b/bir-adim-umut.firebasestorage.app/o/charity_logos%2Ftema.png?alt=media', description: 'TEMA Vakfı', is_active: true },
    { id: 'losev', name: 'LÖSEV', logo_url: 'https://firebasestorage.googleapis.com/v0/b/bir-adim-umut.firebasestorage.app/o/charity_logos%2Flosev.png?alt=media', description: 'Lösemili Çocuklar Vakfı', is_active: true },
    { id: 'tegv', name: 'TEGV', logo_url: 'https://firebasestorage.googleapis.com/v0/b/bir-adim-umut.firebasestorage.app/o/charity_logos%2Ftegv.png?alt=media', description: 'Türkiye Eğitim Gönüllüleri Vakfı', is_active: true },
    { id: 'kizilay', name: 'Kızılay', logo_url: 'https://firebasestorage.googleapis.com/v0/b/bir-adim-umut.firebasestorage.app/o/charity_logos%2Fkizilay.png?alt=media', description: 'Türk Kızılay', is_active: true }
  ];

  for (const c of charities) {
    await db.collection('charities').doc(c.id).set({
      ...c,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  console.log('✅ 5 hayır kurumu eklendi');

  // 3. İlk ay Hope değeri
  const now = new Date();
  const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  await db.collection('monthly_hope_value').doc(monthKey).set({
    month: monthKey,
    hope_value_tl: 0.01,
    total_hope_produced: 0,
    ad_revenue: 0,
    calculated_at: admin.firestore.FieldValue.serverTimestamp()
  });
  console.log('✅ Aylık Hope değeri oluşturuldu');

  console.log('\n🎉 Kurulum tamamlandı!');
  process.exit(0);
}

setup().catch(e => { console.error(e); process.exit(1); });
