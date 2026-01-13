const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Service account ile bağlan
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const backupDir = path.join(require('os').homedir(), 'Desktop', 'bir-adim-umut-secrets-backup', 'firestore-backup');

// Klasör yoksa oluştur
if (!fs.existsSync(backupDir)) {
  fs.mkdirSync(backupDir, { recursive: true });
}

async function backupCollection(collectionName) {
  console.log(`📦 ${collectionName} yedekleniyor...`);
  
  try {
    const snapshot = await db.collection(collectionName).get();
    const data = [];
    
    for (const doc of snapshot.docs) {
      const docData = {
        id: doc.id,
        data: doc.data()
      };
      
      // Subcollection'ları da al (users için)
      if (collectionName === 'users') {
        // activity_logs subcollection
        const activityLogs = await doc.ref.collection('activity_logs').get();
        if (!activityLogs.empty) {
          docData.activity_logs = activityLogs.docs.map(d => ({ id: d.id, data: d.data() }));
        }
        
        // notifications subcollection
        const notifications = await doc.ref.collection('notifications').get();
        if (!notifications.empty) {
          docData.notifications = notifications.docs.map(d => ({ id: d.id, data: d.data() }));
        }
        
        // daily_steps subcollection
        const dailySteps = await doc.ref.collection('daily_steps').get();
        if (!dailySteps.empty) {
          docData.daily_steps = dailySteps.docs.map(d => ({ id: d.id, data: d.data() }));
        }
      }
      
      // teams için team_members
      if (collectionName === 'teams') {
        const teamMembers = await doc.ref.collection('team_members').get();
        if (!teamMembers.empty) {
          docData.team_members = teamMembers.docs.map(d => ({ id: d.id, data: d.data() }));
        }
      }
      
      data.push(docData);
    }
    
    const filePath = path.join(backupDir, `${collectionName}.json`);
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
    console.log(`✅ ${collectionName}: ${data.length} doküman yedeklendi`);
    return data.length;
  } catch (error) {
    console.error(`❌ ${collectionName} yedekleme hatası:`, error.message);
    return 0;
  }
}

async function main() {
  console.log('🚀 Firestore Yedekleme Başlıyor...\n');
  console.log(`📁 Yedek konumu: ${backupDir}\n`);
  
  const collections = [
    'users',
    'teams', 
    'charities',
    'donations',
    'activity_logs',
    'admin_notifications',
    'app_config'
  ];
  
  let totalDocs = 0;
  
  for (const collection of collections) {
    const count = await backupCollection(collection);
    totalDocs += count;
  }
  
  // Backup info dosyası
  const backupInfo = {
    date: new Date().toISOString(),
    project: 'bir-adim-umut-yeni',
    collections: collections,
    totalDocuments: totalDocs
  };
  
  fs.writeFileSync(
    path.join(backupDir, '_backup_info.json'), 
    JSON.stringify(backupInfo, null, 2)
  );
  
  console.log(`\n✅ YEDEKLEME TAMAMLANDI!`);
  console.log(`📊 Toplam ${totalDocs} doküman yedeklendi`);
  console.log(`📁 Konum: ${backupDir}`);
  
  process.exit(0);
}

main().catch(console.error);
