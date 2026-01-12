const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

const db = admin.firestore();

async function checkLogs() {
  // step_carryover kayıtlarını kontrol et
  const carryoverLogs = await db.collection('activity_logs')
    .where('activity_type', '==', 'step_carryover')
    .limit(5)
    .get();
  
  console.log('=== STEP_CARRYOVER LOGS (Gece yarısı taşıma) ===');
  console.log('Toplam bulundu:', carryoverLogs.size);
  
  carryoverLogs.forEach(doc => {
    const data = doc.data();
    console.log('User:', data.user_id, '| Steps:', data.steps, '| From:', data.from_date);
  });
  
  // carryover_conversion kayıtlarını kontrol et
  const conversionLogs = await db.collection('activity_logs')
    .where('activity_type', '==', 'carryover_conversion')
    .limit(5)
    .get();
  
  console.log('\n=== CARRYOVER_CONVERSION LOGS (Kullanıcı dönüşümü) ===');
  console.log('Toplam bulundu:', conversionLogs.size);
  
  conversionLogs.forEach(doc => {
    const data = doc.data();
    console.log('User:', data.user_id, '| Steps:', data.steps_converted, '| Hope:', data.hope_earned);
  });
  
  process.exit(0);
}

checkLogs();
