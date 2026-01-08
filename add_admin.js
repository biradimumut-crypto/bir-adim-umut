const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ 
  credential: admin.credential.cert(serviceAccount), 
  projectId: 'bir-adim-umut-yeni' 
});

const db = admin.firestore();
const uid = '5IWNVdVz5kezNR13gcljAvG6xHQ2';

db.collection('admins').doc(uid).set({
  email: 'biradimumut@gmail.com',
  role: 'super_admin',
  is_active: true,
  created_at: admin.firestore.FieldValue.serverTimestamp(),
  name: 'Bir Adım Umut Admin'
}).then(() => {
  console.log('✅ Admin eklendi: biradimumut@gmail.com');
  process.exit(0);
}).catch((e) => {
  console.log('❌ Hata:', e.message);
  process.exit(1);
});
