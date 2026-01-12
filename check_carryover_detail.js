const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (admin.apps.length === 0) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

const db = admin.firestore();

async function checkAndAddCarryoverLog() {
  try {
    // Sizin user ID'niz (Firebase Console'dan bakabilirsiniz)
    // Önce tüm step_carryover loglarını kontrol et
    console.log('=== STEP_CARRYOVER LOGS KONTROL ===');
    
    const logs = await db.collection('activity_logs')
      .where('activity_type', '==', 'step_carryover')
      .orderBy('created_at', 'desc')
      .limit(10)
      .get();
    
    if (logs.empty) {
      console.log('❌ Hiç step_carryover kaydı bulunamadı!');
      console.log('   Firebase Cloud Function log eklememış olabilir.');
    } else {
      console.log('✅ step_carryover kayıtları bulundu:');
      logs.forEach(doc => {
        const data = doc.data();
        const date = data.created_at?.toDate?.() || 'N/A';
        console.log(`   User: ${data.user_id} | Steps: ${data.steps} | From: ${data.from_date} | Date: ${date}`);
      });
    }
    
    // Admin logs'tan carryover işlemlerini kontrol et
    console.log('\n=== ADMIN CARRYOVER LOGS ===');
    const adminLogs = await db.collection('admin_logs')
      .where('action', '==', 'daily_carryover')
      .orderBy('timestamp', 'desc')
      .limit(5)
      .get();
    
    if (adminLogs.empty) {
      console.log('❌ Hiç daily_carryover admin logu bulunamadı!');
      console.log('   Firebase Cloud Function hiç çalışmamış olabilir.');
    } else {
      console.log('✅ Admin carryover logları:');
      adminLogs.forEach(doc => {
        const data = doc.data();
        const date = data.timestamp?.toDate?.() || 'N/A';
        console.log(`   Date: ${data.date} | Users: ${data.users_affected} | Steps: ${data.total_steps_carried} | Time: ${date}`);
      });
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Hata:', error.message);
    process.exit(1);
  }
}

checkAndAddCarryoverLog();
