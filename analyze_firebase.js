const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}
const db = admin.firestore();

async function analyzeFirebase() {
  console.log('🔍 Firebase Veritabanı Analizi\n');
  console.log('='.repeat(50));
  
  // Tüm koleksiyonları listele
  const collections = await db.listCollections();
  
  for (const collection of collections) {
    const snapshot = await collection.get();
    console.log(`\n📁 ${collection.id}: ${snapshot.size} döküman`);
    
    if (snapshot.size > 0 && snapshot.size <= 10) {
      snapshot.forEach(doc => {
        const data = doc.data();
        const keys = Object.keys(data).slice(0, 5).join(', ');
        console.log(`   - ${doc.id.substring(0, 20)}... [${keys}...]`);
      });
    } else if (snapshot.size > 10) {
      // İlk 3 örnek göster
      let count = 0;
      snapshot.forEach(doc => {
        if (count < 3) {
          const data = doc.data();
          const keys = Object.keys(data).slice(0, 5).join(', ');
          console.log(`   - ${doc.id.substring(0, 20)}... [${keys}...]`);
        }
        count++;
      });
      console.log(`   ... ve ${snapshot.size - 3} döküman daha`);
    }
    
    // Subcollection'ları kontrol et (ilk döküman için)
    if (snapshot.size > 0) {
      const firstDoc = snapshot.docs[0];
      const subCollections = await firstDoc.ref.listCollections();
      if (subCollections.length > 0) {
        console.log(`   📂 Subcollections: ${subCollections.map(s => s.id).join(', ')}`);
      }
    }
  }
  
  console.log('\n' + '='.repeat(50));
  console.log('\n🔍 Detaylı Analiz:\n');
  
  // Admin users kontrolü
  console.log('👤 Admin Kullanıcıları:');
  const users = await db.collection('users').where('is_admin', '==', true).get();
  users.forEach(doc => {
    const data = doc.data();
    console.log(`   - ${data.full_name || data.email} (${doc.id})`);
  });
  
  // Boş veya gereksiz koleksiyonları tespit et
  console.log('\n⚠️ Potansiyel Gereksiz Veriler:');
  
  // sessions koleksiyonu
  const sessions = await db.collection('sessions').get();
  if (sessions.size > 0) {
    const oldSessions = [];
    const now = Date.now();
    sessions.forEach(doc => {
      const data = doc.data();
      const startTime = data.start_time?.toMillis() || 0;
      const ageInDays = (now - startTime) / (1000 * 60 * 60 * 24);
      if (ageInDays > 7) {
        oldSessions.push(doc.id);
      }
    });
    console.log(`   - sessions: ${sessions.size} kayıt (${oldSessions.length} adet 7 günden eski)`);
  }
  
  // ad_errors koleksiyonu
  const adErrors = await db.collection('ad_errors').get();
  if (adErrors.size > 0) {
    console.log(`   - ad_errors: ${adErrors.size} kayıt (reklam hataları - silinebilir)`);
  }
  
  // app_settings kontrolü
  const appSettings = await db.collection('app_settings').get();
  if (appSettings.size > 0) {
    console.log(`   - app_settings: ${appSettings.size} kayıt`);
    appSettings.forEach(doc => {
      console.log(`     ${doc.id}: ${JSON.stringify(doc.data()).substring(0, 100)}...`);
    });
  }
  
  // team_members boş kontrol
  const teams = await db.collection('teams').get();
  let emptyTeams = 0;
  for (const teamDoc of teams.docs) {
    const members = await teamDoc.ref.collection('team_members').get();
    if (members.size === 0) {
      emptyTeams++;
    }
  }
  if (emptyTeams > 0) {
    console.log(`   - teams: ${emptyTeams} boş takım (üyesiz)`);
  }
  
  // Duplicate AHBAP kontrolü
  const charities = await db.collection('charities').where('name', '==', 'AHBAP').get();
  if (charities.size > 1) {
    console.log(`   - charities: ${charities.size} adet AHBAP var (duplicate!)`);
    charities.forEach(doc => {
      const data = doc.data();
      console.log(`     ${doc.id}: logo=${data.image_url ? 'VAR' : 'YOK'}, collected=${data.collected_amount || 0}`);
    });
  }
  
  // Test/geçici kullanıcılar
  const testUsers = await db.collection('users').get();
  const potentialTestUsers = [];
  testUsers.forEach(doc => {
    const data = doc.data();
    const name = (data.full_name || '').toLowerCase();
    if (name.includes('test') || name.includes('deneme') || name === '' || name === 'anonim') {
      potentialTestUsers.push({ id: doc.id, name: data.full_name, email: data.email });
    }
  });
  if (potentialTestUsers.length > 0) {
    console.log(`   - users: ${potentialTestUsers.length} potansiyel test kullanıcı`);
    potentialTestUsers.forEach(u => console.log(`     ${u.name || 'İsimsiz'} (${u.email || u.id})`));
  }
  
  process.exit(0);
}

analyzeFirebase();
