const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}
const db = admin.firestore();

async function check() {
  console.log('=== Vakıflar ===');
  const charities = await db.collection('charities').get();
  charities.forEach(doc => {
    const data = doc.data();
    console.log(doc.id + ' - ' + data.name + ': ' + (data.image_url || 'LOGO YOK'));
  });
  
  console.log('\n=== Activity Log Türleri ===');
  const logs = await db.collection('activity_logs').get();
  const types = {};
  logs.forEach(doc => {
    const data = doc.data();
    const type = data.activity_type || 'unknown';
    if (!types[type]) types[type] = { count: 0, samples: [] };
    types[type].count++;
    if (types[type].samples.length < 2) {
      types[type].samples.push({
        charity_name: data.charity_name,
        charity_logo_url: data.charity_logo_url,
        steps: data.steps_converted,
        hope: data.hope_earned || data.amount
      });
    }
  });
  
  for (const [type, info] of Object.entries(types)) {
    console.log('\n' + type + ': ' + info.count + ' kayıt');
    info.samples.forEach(s => {
      if (s.charity_name) {
        console.log('  - ' + s.charity_name + ' logo: ' + (s.charity_logo_url ? 'VAR' : 'YOK'));
      } else {
        console.log('  - ' + (s.steps || 0) + ' adım → ' + (s.hope || 0) + ' Hope');
      }
    });
  }
  
  process.exit(0);
}
check();
