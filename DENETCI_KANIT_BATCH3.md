# DENETÇİ KANIT PAKETİ - BATCH 3

**Tarih:** 16 Ocak 2026  
**Kapsam:** P1-2 (App Check Enforcement)

---

## ✅ P1-2: App Check Enforcement (Prod)

### Sorun Tanımı:
App Check debug provider'ları aktifti. Production'da gerçek attestation provider'ları gerekli.

### Çözüm Stratejisi:
1. **Client (Flutter):** kReleaseMode'a göre provider seçimi
2. **Cloud Functions:** v1 API için `context.app` kontrolü, v2 API için `enforceAppCheck: true`
3. **Firestore/Storage Rules:** `hasValidAppCheckToken()` helper (Firebase Console'da enforcement açıldığında aktif)
4. **Firebase Console:** Enforcement gradual rollout (ayrı adım)

---

## 1. CLIENT: Flutter App Check Provider (main.dart)

**Dosya:** `lib/main.dart` (Satır 96-111)

### Önceki Kod:
```dart
await FirebaseAppCheck.instance.activate(
  appleProvider: AppleProvider.debug,      // ❌ HER ZAMAN debug
  androidProvider: AndroidProvider.debug,  // ❌ HER ZAMAN debug
);
```

### Yeni Kod:
```dart
// 🚨 App Check başlat (güvenlik için) - Web'de devre dışı bırak
// P1-2 FIX: Production provider'ları aktif
if (!kIsWeb) {
  try {
    await FirebaseAppCheck.instance.activate(
      // 🚨 PRODUCTION PROVIDERS:
      // iOS: deviceCheck (gerçek cihaz attestation)
      // Android: playIntegrity (Play Store attestation)
      appleProvider: kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
      androidProvider: kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    );
    print('App Check başarıyla başlatıldı! (Release: $kReleaseMode)');
  } catch (e) {
    print('App Check başlatılamadı (devam ediliyor): $e');
  }
} else {
  print('Web modda App Check devre dışı');
}
```

### Davranış:
| Mod | iOS Provider | Android Provider |
|-----|--------------|------------------|
| Debug (`kReleaseMode=false`) | AppleProvider.debug | AndroidProvider.debug |
| Release (`kReleaseMode=true`) | AppleProvider.deviceCheck | AndroidProvider.playIntegrity |

---

## 2. CLOUD FUNCTIONS: App Check Enforcement

### 2.1 v2 API (firebase-functions/v2/https)

**Dosyalar:** 
- `firebase_functions/functions/src/email-verification.ts`
- `firebase_functions/functions/src/password-reset.ts`

#### Yöntem: `enforceAppCheck: true` option

```typescript
// ÖNCEKİ:
export const sendVerificationCode = onCall(async (request) => { ... });

// YENİ:
export const sendVerificationCode = onCall(
  { enforceAppCheck: true },  // 🚨 App Check zorunlu
  async (request) => { ... }
);
```

#### Güncellenen Fonksiyonlar (v2):
| Dosya | Fonksiyon | enforceAppCheck |
|-------|-----------|-----------------|
| email-verification.ts | `sendVerificationCode` | ✅ true |
| email-verification.ts | `verifyEmailCode` | ✅ true |
| password-reset.ts | `sendPasswordResetCode` | ✅ true |
| password-reset.ts | `resetPasswordWithCode` | ✅ true |

---

### 2.2 v1 API (firebase-functions/https)

**Dosyalar:**
- `firebase_functions/functions/src/index.ts`
- `firebase_functions/functions/src/delete-account.ts`

#### Yöntem: `context.app` kontrolü

```typescript
// Helper fonksiyon (dosya başında):
function assertAppCheck(context: functions.https.CallableContext) {
  if (!context.app) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "App Check token gerekli. Lütfen uygulamayı güncelleyin."
    );
  }
}

// Fonksiyon içinde kullanım:
export const createTeam = functions.https.onCall(async (data, context) => {
  assertAppCheck(context);  // 🚨 İlk satır
  // ... devam
});
```

#### Güncellenen Fonksiyonlar (v1 - Public API):
| Dosya | Fonksiyon | assertAppCheck |
|-------|-----------|----------------|
| index.ts | `createTeam` | ✅ |
| index.ts | `joinTeamByReferral` | ✅ |
| index.ts | `inviteUserToTeam` | ✅ |
| index.ts | `acceptTeamInvite` | ✅ |
| index.ts | `rejectTeamInvite` | ✅ |
| delete-account.ts | `deleteAccount` | ✅ |

#### Admin Fonksiyonları (App Check Bypass):
Admin fonksiyonları zaten `isAdmin()` kontrolü yapıyor. App Check opsiyonel bırakıldı:
- `calculateMonthlyHopeValueManual`
- `approvePendingDonations`
- `getMonthlyHopeSummary`
- `manualResetDailyTeamSteps`
- `manualResetMonthlyTeamHope`
- `manualCalculateAdminStats`
- `sendBroadcastNotification`
- `toggleUserBan`
- (ve diğer admin fonksiyonları)

**Gerekçe:** Admin paneli ayrı bir uygulama değil, aynı uygulama içinde admin kullanıcılara özel menü. App Check token zaten mevcut olacak.

---

## 3. SECURITY RULES: App Check Helper

### 3.1 Firestore Rules

**Dosya:** `firestore.rules` (Satır 12-16)

```plaintext
// 🚨 P1-2: App Check Token Kontrolü
// Firebase Console'da enforcement açıldığında aktif olur
// Soft enforcement: token yoksa da geçer (geçiş dönemi)
// Hard enforcement: sadece token ile erişim (prod)
function hasValidAppCheckToken() {
  return request.auth.token.firebase.app_check == true;
}
```

### 3.2 Storage Rules

**Dosya:** `storage.rules` (Satır 12-15)

```plaintext
// 🚨 P1-2: App Check Token Kontrolü
// Firebase Console'da enforcement açıldığında aktif olur
function hasValidAppCheckToken() {
  return request.auth.token.firebase.app_check == true;
}
```

### Kullanım Notu:
Helper fonksiyonu tanımlandı ancak rule'lara henüz eklenmedi. Firebase Console'da enforcement açıldığında:

```plaintext
// Örnek kullanım (enforcement sonrası):
allow read: if isAuthenticated() && hasValidAppCheckToken();
```

**Gerekçe:** Önce client'ların güncellenmesi, sonra Console'da gradual rollout yapılması gerekiyor.

---

## 4. ROLLOUT PLANI

### Aşama 1: Kod Deployment (ŞİMDİ)
```bash
# 1. Cloud Functions deploy
firebase deploy --only functions

# 2. Firestore rules deploy
firebase deploy --only firestore:rules

# 3. Storage rules deploy
firebase deploy --only storage

# 4. Flutter build (App Store / Play Store güncellemesi)
flutter build ios --release
flutter build appbundle --release
```

### Aşama 2: Firebase Console Yapılandırması (DEPLOYMENT SONRASI)

**Adım 1:** Firebase Console → App Check → Apps sekmesi
- iOS: DeviceCheck attestation provider ekle
- Android: Play Integrity attestation provider ekle

**Adım 2:** Enforcement sekmesi
- Cloud Firestore: "Unenforced" → "Enforced" (gradual rollout önerisi: 1%, 10%, 50%, 100%)
- Cloud Functions: "Unenforced" → "Enforced"
- Cloud Storage: "Unenforced" → "Enforced"
- Realtime Database: Kullanılmıyor, skip

### Aşama 3: Monitoring (1-2 HAFTA)
- Firebase Console → App Check → Metrics
- "Unverified requests" oranını izle
- Oran %5 altına düşünce enforcement'ı sıkılaştır

### Rollout Timeline:
| Gün | Aksiyon | Risk |
|-----|---------|------|
| 0 | Kod deploy + Console soft enforcement (%1) | Düşük |
| 3 | Metrics kontrol, sorun yoksa %10 | Düşük |
| 7 | Metrics kontrol, sorun yoksa %50 | Orta |
| 14 | Metrics kontrol, sorun yoksa %100 | - |

---

## 5. DOĞRULAMA KOMUTLARI

### 5.1 Flutter Provider Kontrolü:
```bash
$ grep -A5 "AppleProvider\|AndroidProvider" lib/main.dart
        appleProvider: kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
        androidProvider: kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
```

### 5.2 v2 Functions enforceAppCheck:
```bash
$ grep -n "enforceAppCheck: true" firebase_functions/functions/src/*.ts
email-verification.ts:28:  { enforceAppCheck: true },
email-verification.ts:161:  { enforceAppCheck: true },
password-reset.ts:40:  { enforceAppCheck: true },
password-reset.ts:168:  { enforceAppCheck: true },
```

### 5.3 v1 Functions assertAppCheck:
```bash
$ grep -n "assertAppCheck(context)" firebase_functions/functions/src/*.ts
delete-account.ts:135:  assertAppCheck(context);
index.ts:40:  assertAppCheck(context);
index.ts:139:    assertAppCheck(context);
index.ts:255:    assertAppCheck(context);
index.ts:403:    assertAppCheck(context);
index.ts:507:    assertAppCheck(context);
```

### 5.4 TypeScript Build:
```bash
$ cd firebase_functions/functions && npm run build
> build
> tsc
(hata yok)
```

### 5.5 Flutter Analyze:
```bash
$ flutter analyze lib/main.dart
Analyzing lib/main.dart...
No issues found!
```

---

## 📋 KABUL KRİTERLERİ KONTROLÜ

| Kriter | Durum |
|--------|-------|
| Client: Production provider'ları (deviceCheck, playIntegrity) | ✅ kReleaseMode conditional |
| Cloud Functions v2: enforceAppCheck:true | ✅ 4 fonksiyon |
| Cloud Functions v1: context.app kontrolü | ✅ 6 fonksiyon (public API) |
| Firestore Rules: hasValidAppCheckToken() helper | ✅ Tanımlı |
| Storage Rules: hasValidAppCheckToken() helper | ✅ Tanımlı |
| TypeScript build başarılı | ✅ |
| Flutter analyze başarılı | ✅ |
| Rollout planı belgelenmiş | ✅ |

---

## 📋 DEPLOYMENT CHECKLIST

- [ ] Firebase Console → App Check → iOS DeviceCheck provider ekle
- [ ] Firebase Console → App Check → Android Play Integrity provider ekle
- [ ] `firebase deploy --only functions`
- [ ] `firebase deploy --only firestore:rules`
- [ ] `firebase deploy --only storage`
- [ ] Flutter release build → App Store / Play Store
- [ ] Console → App Check → Enforcement → Firestore %1 başlat
- [ ] 1 hafta sonra metrics kontrol → %100'e çık

---

**BATCH 3 (P1-2) TAMAMLANDI**

Kalan iş:
- P2-1: conversion ledger (denetim izi / muhasebe bütünlüğü)

---

## 📋 REV.2 EKİ (Kritik Düzeltmeler)

### Düzeltme 1: Fail-Open → Fail-Closed (Kısıtlı Mod)

**Sorun:** Release'de App Check init hata verirse uygulama devam ediyordu (fail-open).

**Çözüm:** `AppSecurityService` singleton ile kritik aksiyonlar kilitlenir.

#### Yeni Dosya: `lib/services/app_security_service.dart`
```dart
class AppSecurityService {
  static final AppSecurityService _instance = AppSecurityService._internal();
  factory AppSecurityService() => _instance;
  AppSecurityService._internal();

  bool _appCheckInitialized = false;
  String? _initError;

  void setAppCheckStatus({required bool initialized, String? error}) {
    _appCheckInitialized = initialized;
    _initError = error;
  }

  bool get isAppCheckInitialized => _appCheckInitialized;

  /// Debug modda: Her zaman true
  /// Release modda: App Check init başarılı ise true
  bool canPerformCriticalAction({bool isReleaseMode = true}) {
    if (!isReleaseMode) return true;  // Debug'da fail-open
    return _appCheckInitialized;       // Release'de fail-closed
  }

  String get securityErrorMessage => _appCheckInitialized 
    ? '' 
    : 'Güvenlik doğrulaması başarısız. Lütfen uygulamayı güncelleyin.';
}
```

#### main.dart Değişikliği (Satır 96-128):
```dart
final appSecurity = AppSecurityService();

if (!kIsWeb) {
  try {
    await FirebaseAppCheck.instance.activate(...);
    // ✅ Başarılı
    appSecurity.setAppCheckStatus(initialized: true);
  } catch (e) {
    // 🚨 FAIL-CLOSED
    appSecurity.setAppCheckStatus(initialized: false, error: e.toString());
    
    if (kReleaseMode) {
      print('🔒 RELEASE MODE: Kritik aksiyonlar kısıtlı modda');
    } else {
      print('🔓 DEBUG MODE: Fail-open - geliştirme devam ediyor');
    }
  }
}
```

#### StepConversionService Değişikliği (3 fonksiyon):
```dart
// convertSteps, convertCarryOverSteps, convertBonusSteps içinde:
if (!_appSecurity.canPerformCriticalAction(isReleaseMode: kReleaseMode)) {
  return {
    'success': false,
    'error': 'app_check_failed',
    'message': _appSecurity.securityErrorMessage,
  };
}
```

#### Davranış Tablosu:
| Mod | App Check Init | Kritik Aksiyonlar |
|-----|---------------|-------------------|
| Debug | Başarılı | ✅ Açık |
| Debug | Başarısız | ✅ Açık (fail-open) |
| Release | Başarılı | ✅ Açık |
| Release | Başarısız | ❌ KİLİTLİ (fail-closed) |

---

### Düzeltme 2: Rules Helper Kaldırıldı

**Sorun:** `request.auth.token.firebase.app_check == true` ifadesi yanlış API kullanıyordu.

**Çözüm:** Helper tamamen kaldırıldı. App Check enforcement Firebase Console'dan yönetilecek.

#### firestore.rules (Satır 12-14):
```plaintext
// 🚨 P1-2 REV.2: App Check enforcement Firebase Console'dan yönetilir
// Rules içinde claim kontrolü YAPILMAZ (yanlış API)
// Console → App Check → Enforcement → Firestore → Enforced
```

#### storage.rules (Satır 12-14):
```plaintext
// 🚨 P1-2 REV.2: App Check enforcement Firebase Console'dan yönetilir
// Rules içinde claim kontrolü YAPILMAZ (yanlış API)
// Console → App Check → Enforcement → Storage → Enforced
```

#### Doğrulama:
```bash
$ grep -n "hasValidAppCheckToken" firestore.rules storage.rules
(sonuç yok - helper kaldırıldı ✅)
```

---

### Düzeltme 3: Admin Fonksiyonlarına App Check Eklendi

**Sorun:** "Admin fonksiyonları bypass" mantığı hatalıydı. Admin panel aynı app ise token zaten var.

**Çözüm:** Tüm onCall fonksiyonlarına `assertAppCheck(context)` eklendi.

#### Güncellenen Fonksiyonlar (v1 API - index.ts):
| Fonksiyon | assertAppCheck |
|-----------|----------------|
| `createTeam` | ✅ |
| `joinTeamByReferral` | ✅ |
| `inviteUserToTeam` | ✅ |
| `acceptTeamInvite` | ✅ |
| `rejectTeamInvite` | ✅ |
| `migrateUsersFullNameLowercase` | ✅ |
| `manualResetDailyTeamSteps` | ✅ |
| `manualResetMonthlyTeamHope` | ✅ |
| `manualCalculateAdminStats` | ✅ |
| `sendBroadcastNotification` | ✅ |
| `toggleUserBan` | ✅ |
| `getMonthlyStepReport` | ✅ |
| `getDonationReport` | ✅ |
| `triggerMonthlyReset` | ✅ |
| `manualDistributeLeaderboardRewards` | ✅ |

#### Güncellenen Fonksiyonlar (v1 API - delete-account.ts):
| Fonksiyon | assertAppCheck |
|-----------|----------------|
| `deleteAccount` | ✅ |

#### Güncellenen Fonksiyonlar (v1 API - monthly-hope-calculator.ts):
| Fonksiyon | assertAppCheck |
|-----------|----------------|
| `calculateMonthlyHopeValueManual` | ✅ |
| `approvePendingDonations` | ✅ |
| `getMonthlyHopeSummary` | ✅ |

#### Doğrulama:
```bash
$ grep -n "assertAppCheck" firebase_functions/functions/src/*.ts | wc -l
22
```

---

## 📋 REV.2 DOĞRULAMA KOMUTLARI

### 1. AppSecurityService Kullanımı:
```bash
$ grep -n "canPerformCriticalAction" lib/services/step_conversion_service.dart
203:    if (!_appSecurity.canPerformCriticalAction(isReleaseMode: kReleaseMode)) {
322:    if (!_appSecurity.canPerformCriticalAction(isReleaseMode: kReleaseMode)) {
497:    if (!_appSecurity.canPerformCriticalAction(isReleaseMode: kReleaseMode)) {
```

### 2. Fail-Closed main.dart:
```bash
$ grep -n "setAppCheckStatus" lib/main.dart
110:        appSecurity.setAppCheckStatus(initialized: true);
116:        appSecurity.setAppCheckStatus(initialized: false, error: e.toString());
127:      appSecurity.setAppCheckStatus(initialized: false, error: 'Web mode');
```

### 3. Rules Helper Kaldırıldı:
```bash
$ grep -n "hasValidAppCheckToken" firestore.rules storage.rules
(sonuç yok ✅)
```

### 4. TypeScript Build:
```bash
$ cd firebase_functions/functions && npm run build
> tsc
(hata yok ✅)
```

### 5. Flutter Analyze:
```bash
$ flutter analyze lib/main.dart lib/services/app_security_service.dart lib/services/step_conversion_service.dart
56 issues found (sadece info seviyesi - error yok ✅)
```

---

## 📋 REV.2 KABUL KRİTERLERİ

| Kriter | Durum |
|--------|-------|
| Release'de App Check init fail → kısıtlı mod | ✅ AppSecurityService |
| Debug'da fail-open devam | ✅ canPerformCriticalAction |
| convertSteps App Check kontrolü | ✅ |
| convertCarryOverSteps App Check kontrolü | ✅ |
| convertBonusSteps App Check kontrolü | ✅ |
| Rules helper kaldırıldı | ✅ |
| Console enforcement notu eklendi | ✅ |
| Admin fonksiyonlarına App Check eklendi | ✅ 19 fonksiyon |
| TypeScript build başarılı | ✅ |
| Flutter analyze error yok | ✅ |

---

**BATCH 3 REV.2 TAMAMLANDI**
