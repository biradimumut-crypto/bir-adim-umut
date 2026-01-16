# 🔐 FAZA 3 - AUTH & LEGAL REHBER

**Tarih:** 15 Ocak 2026  
**Proje:** Bir Adım Umut  
**Firebase Projesi:** bir-adim-umut-yeni  
**Durum:** ⏳ Beklemede

---

## 📋 Özet

FAZA 3, kullanıcı kimlik doğrulama ve yasal gereklilikler (GDPR/Apple App Store) ile ilgili iki kritik sorunu çözmeyi hedefler.

---

## 🎯 Hedefler

| # | Sorun Kodu | Açıklama | Öncelik |
|---|------------|----------|---------|
| 1 | **BUG-004** | Email verification eksik | 🟡 Orta |
| 2 | **BUG-006** | Hesap silme özelliği eksik (GDPR/Apple) | 🔴 Kritik |

---

## ⚠️ BLOCKER - KARAR GEREKLİ

```
┌─────────────────────────────────────────────────────────────────┐
│ ⛔ FAZA 3 BAŞLAMADAN ÖNCE AŞAĞIDAKI KARAR VERİLMELİ:            │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ HESAP SİLME POLİCY'Sİ (BUG-006)                             │ │
│ │                                                             │ │
│ │ Seçenek 1: Soft Delete                                      │ │
│ │   [ ] EVET seçildi                                          │ │
│ │   → Retention Süresi: 30 gün                                │ │
│ │   → Cloud Function gerekli (scheduledUserCleanup)           │ │
│ │   → Kullanıcı 30 gün içinde hesabı kurtarabilir             │ │
│ │   → Ek süre: +3 saat                                        │ │
│ │                                                             │ │
│ │ Seçenek 2: Hard Delete                                      │ │
│ │   [ ] EVET seçildi                                          │ │
│ │   → Anında tüm veriler silinir                              │ │
│ │   → Geri dönüş YOK                                          │ │
│ │   → Daha basit implementasyon                               │ │
│ │                                                             │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ⚠️ BU KARAR VERİLMEDEN KOD YAZILMAYACAK                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📝 GÖREV 1: Email Verification (BUG-004)

### Mevcut Durum

```dart
// ❌ YANLIŞ - Şu an email doğrulaması yapılmıyor
Future<UserCredential> signIn(String email, String password) async {
  return await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  // Email verified kontrolü YOK!
}
```

### Hedef Durum

```dart
// ✅ DOĞRU - Email doğrulaması kontrol edilecek
Future<UserCredential> signIn(String email, String password) async {
  final credential = await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  
  if (!credential.user!.emailVerified) {
    await _auth.signOut();
    throw FirebaseAuthException(
      code: 'email-not-verified',
      message: 'Lütfen email adresinizi doğrulayın.',
    );
  }
  
  return credential;
}
```

### Değişecek Dosyalar

| Dosya | Değişiklik |
|-------|------------|
| `lib/services/auth_service.dart` | `signIn` metoduna emailVerified kontrolü ekle |
| `lib/screens/auth/login_screen.dart` | Hata mesajı gösterimi |
| `lib/screens/auth/register_screen.dart` | "Email gönderildi" bilgilendirmesi |

### Akış Diyagramı

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────────┐
│   Kayıt Ol  │ ──▶ │ Email Doğrulama │ ──▶ │  Giriş Yapabilir │
│             │     │ Maili Gönderilir│     │                  │
└─────────────┘     └─────────────────┘     └──────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ Doğrulanmadan │
                    │ Giriş Engeli  │
                    └───────────────┘
```

### Tahmini Süre

**2 saat**

---

## 📝 GÖREV 2: Hesap Silme (BUG-006)

### Neden Gerekli?

| Platform | Gereklilik | Son Tarih |
|----------|------------|-----------|
| **Apple App Store** | Zorunlu | Yayında olmalı |
| **Google Play Store** | Zorunlu | 2024'ten beri |
| **GDPR (Avrupa)** | Yasal zorunluluk | Her zaman |
| **KVKK (Türkiye)** | Yasal zorunluluk | Her zaman |

### Silinecek Veriler

```
┌─────────────────────────────────────────────────────────────────┐
│ 🗑️ HESAP SİLİNDİĞİNDE KALDIRILACAK VERİLER:                    │
│                                                                 │
│ 1. users/{uid}                    → Ana kullanıcı dokümanı      │
│ 2. users/{uid}/notifications/*    → Tüm bildirimler             │
│ 3. users/{uid}/badges/*           → Kazanılan rozetler          │
│ 4. team_members (user_uid == uid) → Takım üyelikleri            │
│ 5. activity_logs (user_uid == uid)→ Aktivite geçmişi            │
│ 6. daily_steps (user_uid == uid)  → Günlük adım kayıtları       │
│ 7. Firebase Auth hesabı           → Kimlik doğrulama kaydı      │
│                                                                 │
│ ⚠️ Storage dosyaları (profil fotoğrafı vb.) da silinecek        │
└─────────────────────────────────────────────────────────────────┘
```

### Seçenek A: Hard Delete (Önerilen - Basit)

```dart
// lib/services/auth_service.dart

Future<void> deleteAccount() async {
  final user = _auth.currentUser;
  if (user == null) throw Exception('Kullanıcı bulunamadı');
  
  final uid = user.uid;
  final batch = _firestore.batch();
  
  // 1. Alt koleksiyonları sil
  await _deleteSubcollection('users/$uid/notifications');
  await _deleteSubcollection('users/$uid/badges');
  
  // 2. İlişkili dokümanları sil
  final teamMembers = await _firestore
      .collection('team_members')
      .where('user_uid', isEqualTo: uid)
      .get();
  for (var doc in teamMembers.docs) {
    batch.delete(doc.reference);
  }
  
  final activityLogs = await _firestore
      .collection('activity_logs')
      .where('user_uid', isEqualTo: uid)
      .get();
  for (var doc in activityLogs.docs) {
    batch.delete(doc.reference);
  }
  
  final dailySteps = await _firestore
      .collection('daily_steps')
      .where('user_uid', isEqualTo: uid)
      .get();
  for (var doc in dailySteps.docs) {
    batch.delete(doc.reference);
  }
  
  // 3. Ana kullanıcı dokümanını sil
  batch.delete(_firestore.collection('users').doc(uid));
  
  // 4. Batch commit
  await batch.commit();
  
  // 5. Storage dosyalarını sil
  try {
    await _storage.ref('users/$uid').listAll().then((result) async {
      for (var item in result.items) {
        await item.delete();
      }
    });
  } catch (e) {
    // Storage boş olabilir, hata yoksay
  }
  
  // 6. Firebase Auth hesabını sil
  await user.delete();
}
```

### Seçenek B: Soft Delete (Karmaşık)

```dart
// lib/services/auth_service.dart

Future<void> deleteAccount() async {
  final user = _auth.currentUser;
  if (user == null) throw Exception('Kullanıcı bulunamadı');
  
  // Hesabı "silindi" olarak işaretle
  await _firestore.collection('users').doc(user.uid).update({
    'is_deleted': true,
    'deleted_at': FieldValue.serverTimestamp(),
    'scheduled_deletion': Timestamp.fromDate(
      DateTime.now().add(Duration(days: 30)),
    ),
  });
  
  // Kullanıcıyı çıkış yaptır
  await _auth.signOut();
}

// Cloud Function: scheduledUserCleanup
// Her gün çalışır, 30 günü geçen hesapları kalıcı olarak siler
```

### UI Tasarımı

```
┌─────────────────────────────────────────┐
│           Hesabı Sil                    │
├─────────────────────────────────────────┤
│                                         │
│  ⚠️ DİKKAT                              │
│                                         │
│  Hesabınızı silmek istediğinizden       │
│  emin misiniz?                          │
│                                         │
│  Bu işlem geri alınamaz ve aşağıdaki    │
│  verileriniz kalıcı olarak silinecek:   │
│                                         │
│  • Profil bilgileriniz                  │
│  • Adım geçmişiniz                      │
│  • Takım üyelikleriniz                  │
│  • Kazandığınız rozetler                │
│  • Tüm bildirimleriniz                  │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ Şifrenizi girin: ************** │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────┐  ┌─────────────────┐   │
│  │   İPTAL     │  │  HESABI SİL 🗑️  │   │
│  └─────────────┘  └─────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

### Değişecek Dosyalar

| Dosya | Değişiklik |
|-------|------------|
| `lib/services/auth_service.dart` | `deleteAccount()` metodu ekle |
| `lib/screens/profile/profile_screen.dart` | "Hesabı Sil" butonu ekle |
| `lib/screens/profile/delete_account_dialog.dart` | Onay dialog'u (YENİ) |

### Tahmini Süre

| Seçenek | Süre |
|---------|------|
| Hard Delete | 5 saat |
| Soft Delete | 8 saat (+Cloud Function) |

---

## 📋 Uygulama Adımları

### Adım 1: Karar Ver
- [ ] Soft Delete mi Hard Delete mi?

### Adım 2: Email Verification (BUG-004)
- [ ] `auth_service.dart` güncelle
- [ ] `login_screen.dart` hata mesajı ekle
- [ ] `register_screen.dart` bilgilendirme ekle
- [ ] Test et

### Adım 3: Hesap Silme (BUG-006)
- [ ] `auth_service.dart`'a `deleteAccount()` ekle
- [ ] `delete_account_dialog.dart` oluştur
- [ ] `profile_screen.dart`'a buton ekle
- [ ] Re-authentication implementasyonu
- [ ] Test et

### Adım 4: Test
- [ ] Email verification akışını test et
- [ ] Hesap silme akışını test et
- [ ] Silinen verilen doğrulaması

### Adım 5: Deploy
- [ ] Flutter build test
- [ ] Production'a deploy

---

## ⚠️ Dikkat Edilecekler

### 1. Re-authentication Gerekli

Firebase, hassas işlemler için re-authentication ister:

```dart
// Hesap silmeden önce kullanıcı tekrar giriş yapmalı
Future<void> reauthenticate(String password) async {
  final user = _auth.currentUser!;
  final credential = EmailAuthProvider.credential(
    email: user.email!,
    password: password,
  );
  await user.reauthenticateWithCredential(credential);
}
```

### 2. Batch Limiti

Firestore batch işlemi max 500 doküman destekler. Çok fazla veri varsa:

```dart
// Büyük koleksiyonlar için chunked delete
Future<void> _deleteSubcollection(String path) async {
  const batchSize = 500;
  final query = _firestore.collection(path).limit(batchSize);
  
  while (true) {
    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) break;
    
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
```

### 3. Storage Silme

Profil fotoğrafı ve diğer dosyalar:

```dart
Future<void> _deleteUserStorage(String uid) async {
  final ref = _storage.ref('users/$uid');
  final result = await ref.listAll();
  
  for (var item in result.items) {
    await item.delete();
  }
  for (var prefix in result.prefixes) {
    await _deleteFolder(prefix);
  }
}
```

---

## 📊 Risk Analizi

| Risk | Seviye | Önlem |
|------|--------|-------|
| Yanlışlıkla hesap silme | 🟡 Orta | Şifre onayı + dialog |
| Eksik veri silme | 🟡 Orta | Kapsamlı test |
| Re-auth hatası | 🟢 Düşük | Hata mesajları |
| Email doğrulama spam | 🟢 Düşük | Rate limiting |

---

## 🕐 Zaman Çizelgesi

| Görev | Tahmini Süre |
|-------|--------------|
| Email Verification (BUG-004) | 2 saat |
| Hesap Silme - Hard Delete (BUG-006) | 5 saat |
| Test & Debug | 1 saat |
| **TOPLAM** | **8 saat** |

*Soft Delete seçilirse: +3 saat (Cloud Function)*

---

## ✅ Tamamlanma Kriterleri

- [ ] Email doğrulanmadan giriş engellenmiş
- [ ] "Hesabı Sil" butonu profil sayfasında görünür
- [ ] Hesap silme işlemi tüm verileri temizliyor
- [ ] Re-authentication çalışıyor
- [ ] Hata mesajları Türkçe ve anlaşılır
- [ ] App Store / Play Store gereklilikleri karşılanmış

---

## 🔗 Bağımlılıklar

| Bu Faza | Bağımlı Olduğu |
|---------|----------------|
| FAZA 3 | FAZA 1 ✅, FAZA 2 ✅ |

| Bu Fazaya Bağımlı |
|-------------------|
| FAZA 4 (App Security) |

---

## 📚 Referanslar

- [Apple App Store Account Deletion Requirements](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Google Play Data Deletion Policy](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Firebase Auth - Delete User](https://firebase.google.com/docs/auth/web/manage-users#delete_a_user)
- [KVKK - Kişisel Verilerin Silinmesi](https://www.kvkk.gov.tr/)

---

*Rehber Oluşturma: 15 Ocak 2026*
