# DENETÇİ KANIT PAKETİ - BATCH 2 (REV.2)

**Tarih:** 16 Ocak 2026  
**Revizyon:** REV.2 - Denetçi düzeltmeleri uygulandı  
**Kapsam:** EK (storage team_logos) + P0-1 (transaction conversion + _isAuthorized entry check)

---

## ✅ 1. EK: Storage team_logos - Path-Based Yetkilendirme (REV.2)

**Dosya:** `storage.rules` (Satır 36-57)

### 🚨 DENETÇİ DÜZELTMESİ:
Denetçi talebi: "`write: if false` işlevi kırar. Seçenek 1 (path-based) veya Seçenek 2 (Cloud Function) gerekli."

### Seçenek 1 Uygulandı - Path-Based Yetkilendirme:

#### Yeni Kod:
```plaintext
// 🚨 SECURITY FIX (Seçenek 1): Path-based yetkilendirme
// Path: team_logos/{teamId}/{uploaderUid}.jpg
// Herkes sadece kendi uid'si ile upload yapabilir
// Uygulama tarafı: sadece takım lideri upload butonunu görür

match /team_logos/{teamId}/{fileName} {
  // Herkes takım logosunu okuyabilir
  allow read: if isAuthenticated();
  
  // Yazma: Sadece kendi uid'si ile upload yapabilir
  // fileName formatı: {uid}.jpg veya {uid}_{timestamp}.jpg
  // Bu şekilde kötü niyetli kullanıcı başkası adına yükleyemez
  allow write: if isAuthenticated()
               && fileName.matches(request.auth.uid + '.*')
               && isValidSize()
               && isImage();
}

// Eski path için geriye uyumluluk (sadece okuma)
match /team_logos/{teamId}.jpg {
  allow read: if isAuthenticated();
  allow write: if false;  // Eski path'e yazma kapalı
}
```

### Değişiklik Özeti:
| Özellik | Önceki (write:false) | Yeni (path-based) |
|---------|---------------------|-------------------|
| Normal kullanıcı upload | ❌ Engel | ✅ Sadece kendi uid'si ile |
| Başkası adına upload | - | ❌ fileName.matches() engeller |
| Admin upload | ❌ Engel | ✅ Kendi uid'si ile |
| Eski logolar okuma | ❌ - | ✅ Geriye uyumlu |

### Güvenlik Garantisi:
```
Kullanıcı A (uid: abc123):
  ✅ PUT team_logos/team1/abc123.jpg → İZİN (kendi uid'si)
  ✅ PUT team_logos/team1/abc123_1705401234.jpg → İZİN (uid prefix)
  ❌ PUT team_logos/team1/xyz789.jpg → RED (başka uid)
  ❌ PUT team_logos/team1/logo.jpg → RED (uid yok)
```

### Uygulama Tarafı Notu:
- Upload path: `team_logos/{teamId}/{currentUser.uid}.jpg`
- UI'da sadece takım lideri upload butonunu görür (mevcut davranış korunur)
- Firestore teams koleksiyonundaki `leader_id` kontrolü UI'da yapılır

---

## ✅ 2. P0-1: Transaction ile Atomik Conversion + _isAuthorized Entry Check (REV.2)

**Dosya:** `lib/services/step_conversion_service.dart`

### 🚨 DENETÇİ DÜZELTMESİ A: dailySteps Canonical Kaynağı

#### Soru: "dailySteps nereden geliyor?"

#### Cevap (Kod Snippet):
```dart
// Transaction içinde (satır 497-520):
final stepDoc = await transaction.get(stepRef);

int currentConverted = 0;
int dailySteps = 0;

if (stepDoc.exists) {
  final stepData = stepDoc.data()!;
  currentConverted = (stepData['converted_steps'] ?? 0) as int;
  // 📌 CANONICAL SOURCE: daily_steps alanı = Health API'den sync edilen değer
  dailySteps = (stepData['daily_steps'] ?? 0) as int;
}

// Double-spend kontrolü:
// 📌 availableSteps = Firestore'daki daily_steps - converted_steps
// 📌 Client'tan gelen "steps" parametresi ile kıyaslanır
final availableSteps = dailySteps - currentConverted;
if (availableSteps < steps) {
  throw Exception('Yetersiz adım: mevcut=$availableSteps, istenen=$steps');
}
```

#### Veri Akışı:
```
1. Health API → HealthService.fetchTodaySteps() → _todaySteps
2. Dashboard UI → syncTodaySteps() → Firestore: users/{uid}/daily_steps/{date}.daily_steps
3. Convert butonuna tıklanınca → convertSteps(steps: X)
4. Transaction içinde:
   - READ: Firestore daily_steps doc → dailySteps, currentConverted
   - CHECK: availableSteps = dailySteps - currentConverted >= steps?
   - WRITE: converted_steps += steps
```

#### Güvenlik Garantisi:
- `dailySteps` **HER ZAMAN** Firestore'dan okunur (transaction.get)
- Client'tan gelen `steps` parametresi sadece **talep edilen miktar**
- Karşılaştırma Firestore verisi ile yapılır, client verisi ile DEĞİL

---

### 🚨 DENETÇİ DÜZELTMESİ B: Upsert (Missing Doc Durumu)

#### Önceki Kod:
```dart
if (!stepDoc.exists) {
  throw Exception('Daily steps kaydı bulunamadı');
}
// ...
transaction.update(stepRef, stepUpdateData);  // ❌ Doc yoksa patlar
```

#### Yeni Kod:
```dart
// 🚨 UPSERT: Doc yoksa oluştur (ilk conversion senaryosu)
int currentConverted = 0;
int dailySteps = 0;

if (stepDoc.exists) {
  final stepData = stepDoc.data()!;
  currentConverted = (stepData['converted_steps'] ?? 0) as int;
  dailySteps = (stepData['daily_steps'] ?? 0) as int;
} else {
  // Doc yok - sıfırdan başla (bu durumda conversion yapılamaz)
  dailySteps = 0;
  currentConverted = 0;
}

// ... double-spend kontrolü (availableSteps = 0 olacağı için conversion başarısız)

// 🚨 SET with merge: Doc yoksa oluşturur, varsa günceller
transaction.set(stepRef, stepUpdateData, SetOptions(merge: true));
```

#### Davranış:
| Durum | Önceki | Yeni |
|-------|--------|------|
| Doc var, yeterli adım | ✅ Success | ✅ Success |
| Doc var, yetersiz adım | ❌ Exception | ❌ Exception |
| Doc yok | ❌ Exception (patlar) | ❌ Exception (yetersiz adım) |

---

### 🚨 DENETÇİ DÜZELTMESİ C: HealthService Singleton Kanıtı

#### Soru: "StepConversionService'teki HealthService instance UI'dakiyle aynı mı?"

#### Cevap - HealthService Singleton Implementasyonu:

**Dosya:** `lib/services/health_service.dart` (Satır 10-13)
```dart
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();
  
  // ... state variables
  bool _isAuthorized = false;
  // ...
  bool get isAuthorized => _isAuthorized;
}
```

#### Singleton Pattern Açıklaması:
```dart
// Her yerde aynı instance:
final service1 = HealthService();  // → _instance
final service2 = HealthService();  // → _instance (AYNI)

// Kanıt:
identical(service1, service2) == true
```

#### StepConversionService'te Kullanım:
```dart
class StepConversionService {
  final HealthService _healthService = HealthService();  // → Singleton _instance
  
  Future<Map<String, dynamic>> convertSteps(...) async {
    if (!_healthService.isAuthorized) {  // → _instance.isAuthorized
      // ...
    }
  }
}
```

#### Dashboard'da Kullanım:
```dart
class _DashboardScreenState extends State<DashboardScreen> {
  final HealthService _healthService = HealthService();  // → AYNI _instance
  
  void initState() {
    _healthService.initialize();  // _instance._isAuthorized = true/false
  }
}
```

#### Senkronizasyon Garantisi:
```
T=0:  Dashboard: HealthService().initialize() → _instance._isAuthorized = true
T=1:  User taps convert
T=2:  StepConversionService: HealthService().isAuthorized → _instance._isAuthorized = true ✅
```

---

### 2.1 Import Eklendi (Satır 5):
```dart
import 'health_service.dart';
```

### 2.2 HealthService Instance (Satır 21):
```dart
final HealthService _healthService = HealthService();  // Singleton - factory returns _instance
```

### 2.3 convertSteps() - Transaction + Entry Check (Satır 474-597):

#### Entry Check:
```dart
Future<Map<String, dynamic>> convertSteps({
  required String userId,
  required int steps,
  required double hopeEarned,
  bool isBonus = false,
}) async {
  // 🚨 ENTRY CHECK: Health API authorization kontrolü (UI-bağımsız)
  if (!_healthService.isAuthorized) {
    print('⛔ convertSteps ENGELLENDI: HealthService.isAuthorized=false');
    return {
      'success': false,
      'error': 'health_not_authorized',
      'message': 'Adım verisi doğrulanamadı. Health API yetkisi yok.',
    };
  }
  // ... devam
}
```

#### Transaction Yapısı:
```dart
// 🚨 TRANSACTION: Atomik yazma - race condition önleme
final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
  // 1. Daily steps doc'unu oku (transaction içinde)
  final stepDoc = await transaction.get(stepRef);
  
  // Double-spend kontrolü: Yeterli dönüştürülmemiş adım var mı?
  final availableSteps = dailySteps - currentConverted;
  if (availableSteps < steps) {
    throw Exception('Yetersiz adım: mevcut=$availableSteps, istenen=$steps');
  }
  
  // 2. User doc'unu oku
  final userDoc = await transaction.get(userRef);
  
  // 3. Daily steps güncelle
  transaction.update(stepRef, stepUpdateData);
  
  // 4. User wallet güncelle
  transaction.update(userRef, {...});
  
  // 5. Activity log ekle (transaction içinde)
  transaction.set(logRef, {...});
  
  return {'success': true, 'teamId': ...};
});
```

### 2.4 convertCarryOverSteps() - Aynı Pattern (Satır 200-297):
```dart
// 🚨 ENTRY CHECK: Health API authorization kontrolü (UI-bağımsız)
if (!_healthService.isAuthorized) {
  print('⛔ convertCarryOverSteps ENGELLENDI: HealthService.isAuthorized=false');
  return {...};
}

// 🚨 TRANSACTION: Atomik yazma
final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
  // Double-spend kontrolü
  if (pendingInt < steps) {
    throw Exception('Yetersiz carryover adımı: mevcut=$pendingInt, istenen=$steps');
  }
  // ...
});
```

### 2.5 convertBonusSteps() - Aynı Pattern (Satır 308-406):
```dart
// 🚨 ENTRY CHECK: Health API authorization kontrolü (UI-bağımsız)
if (!_healthService.isAuthorized) {
  print('⛔ convertBonusSteps ENGELLENDI: HealthService.isAuthorized=false');
  return {...};
}

// 🚨 TRANSACTION: Atomik yazma + double-spend check
final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
  final available = bonusInt - convertedInt;
  if (available < steps) {
    throw Exception('Yetersiz bonus adımı: mevcut=$available, istenen=$steps');
  }
  // ...
});
```

### Değişiklik Özeti:

| Fonksiyon | Önceki | Yeni |
|-----------|--------|------|
| `convertSteps()` | Batch write | Transaction + entry check |
| `convertCarryOverSteps()` | Batch write | Transaction + entry check |
| `convertBonusSteps()` | Batch write | Transaction + entry check |

### Güvenlik İyileştirmeleri:

| Kontrol | Önceki | Yeni |
|---------|--------|------|
| _isAuthorized entry check | ❌ Sadece UI | ✅ Servis girişinde |
| Atomik yazma | ❌ Batch (race risk) | ✅ Transaction |
| Double-spend kontrolü | ❌ Ayrı read+write | ✅ Transaction içinde |
| Hata durumu | ❌ Kısmi yazma olabilir | ✅ Ya hep ya hiç |

### Race Condition Senaryosu (ÖNCE):
```
T=0ms:  Client A: read daily_steps (converted=0)
T=1ms:  Client B: read daily_steps (converted=0)  
T=5ms:  Client A: batch.update(converted=2500) → Success
T=6ms:  Client B: batch.update(converted=2500) → Success ❌ DOUBLE-SPEND!
```

### Race Condition Senaryosu (SONRA):
```
T=0ms:  Client A: transaction.get(daily_steps)
T=1ms:  Client B: transaction.get(daily_steps)
T=5ms:  Client A: transaction.update() → Commit başarılı
T=6ms:  Client B: transaction.update() → CONFLICT! Retry...
T=10ms: Client B: transaction.get() (fresh read, converted=2500)
T=11ms: Client B: availableSteps=0 < 2500 → Exception ✅ ENGELLENDI
```

---

## 📋 DEPLOYMENT NOTLARI

### Storage Rules Deploy:
```bash
firebase deploy --only storage
```

### Flutter Build (step_conversion_service.dart):
- Değişiklik client-side, sonraki build'de otomatik dahil olacak
- Transaction API Firestore SDK'da mevcut

---

## ✅ KABUL KRİTERLERİ KONTROLÜ (REV.2)

| Kriter | Durum |
|--------|-------|
| EK: team_logos path-based yetkilendirme | ✅ (Seçenek 1) |
| EK: Başkası adına upload engellenir | ✅ fileName.matches(uid) |
| EK: Eski path geriye uyumlu (read only) | ✅ |
| P0-1: _isAuthorized entry check (3 fonksiyon) | ✅ |
| P0-1: HealthService singleton kanıtı | ✅ |
| P0-1: Transaction ile atomik yazma (3 fonksiyon) | ✅ |
| P0-1: dailySteps canonical kaynağı (Firestore) | ✅ |
| P0-1: Upsert - doc yoksa set(merge:true) | ✅ |
| P0-1: Double-spend kontrolü transaction içinde | ✅ |

---

## 📋 DENETÇİ DÜZELTME ÖZETİ (REV.2)

### Düzeltme A: dailySteps Canonical Kaynağı
- **Talep:** dailySteps nereden geliyor net olsun
- **Cevap:** `stepDoc.data()['daily_steps']` - Firestore transaction read
- **Garanti:** Client'tan gelen değer ile kıyas YOK, Firestore verisi kullanılır

### Düzeltme B: Upsert (Missing Doc)
- **Talep:** Doc yoksa update patlar, set(merge:true) kullan
- **Uygulama:** `transaction.set(stepRef, data, SetOptions(merge: true))`
- **Davranış:** Doc yoksa dailySteps=0, conversion başarısız (yetersiz adım)

### Düzeltme C: HealthService Singleton
- **Talep:** Aynı instance kullanıldığını kanıtla
- **Kanıt:** `static final _instance` + `factory` pattern
- **Garanti:** Tüm dosyalarda `HealthService()` aynı `_instance`'ı döndürür

### Düzeltme D: team_logos Path-Based
- **Talep:** `write:false` yerine çalışan çözüm
- **Uygulama:** Seçenek 1 - `fileName.matches(request.auth.uid + '.*')`
- **Garanti:** Kullanıcı sadece kendi uid'si ile upload yapabilir

---

**BATCH 2 REV.2 TAMAMLANDI**

---

## 📋 REV.3 EKİ (Minör Düzeltmeler)

### Düzeltme 1: team_logos regex → Seçenek A (Tam Eşleşme)

**Dosya:** `storage.rules`

```plaintext
// ÖNCEKİ (regex belirsiz):
&& fileName.matches(request.auth.uid + '.*')

// YENİ (Seçenek A - kesin format):
&& fileName == (request.auth.uid + ".jpg")
```

**Garanti:** `PUT team_logos/team1/abc123.jpg` → ✅ SADECE bu format kabul

---

### Düzeltme 2: daily_steps yoksa "SYNC_REQUIRED" hatası

**Dosya:** `lib/services/step_conversion_service.dart` (Satır 507-519)

```dart
// 🚨 SYNC KONTROLÜ: Doc yoksa veya daily_steps=0 ise kullanıcıyı bilgilendir
if (!stepDoc.exists || dailySteps == 0) {
  throw Exception('SYNC_REQUIRED: Adım verisi henüz senkronize edilmedi. Lütfen önce adımlarınızı senkronize edin.');
}
```

**Davranış:**
| Durum | Önceki | Yeni |
|-------|--------|------|
| Doc yok | "Yetersiz adım: 0" (belirsiz) | "SYNC_REQUIRED: önce sync" |
| daily_steps=0 | "Yetersiz adım: 0" | "SYNC_REQUIRED: önce sync" |

---

### Düzeltme 3: Transaction yazımı doğrulaması

**Kod kontrolü:**
```bash
$ grep -n "transaction.set(stepRef" lib/services/step_conversion_service.dart
545:        transaction.set(stepRef, stepUpdateData, SetOptions(merge: true));
```

**Onay:** Kod zaten `set(merge:true)` kullanıyor ✅

---

**BATCH 2 REV.3 TAMAMLANDI**

Kalan işler:
- P2-1: conversion ledger (activity_logs yapısı zaten mevcut)
- P1-2: App Check prod (enforceAppCheck aktif)
