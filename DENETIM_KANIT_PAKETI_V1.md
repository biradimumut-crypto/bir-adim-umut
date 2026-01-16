# DENETİM KANIT PAKETİ v1

**Oluşturma Tarihi:** 2025-01-13  
**Proje:** bir-adim-umut (OneHopeStep)  
**Amaç:** Harici denetçiye sunulmak üzere nötr kanıt toplama  

> ⚠️ Bu belge yorum, risk değerlendirmesi veya öneri içermez. Sadece "nerede-ne var" formatında kanıt sunar.

---

## BÖLÜM 0: PROJE KİMLİĞİ

### 0.1 SDK Versiyonu
**Dosya:** [pubspec.yaml](pubspec.yaml#L10-L11)
```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
```

### 0.2 Firebase Project ID
**Dosya:** [lib/firebase_options.dart](lib/firebase_options.dart#L37)
```dart
static const FirebaseOptions android = FirebaseOptions(
  ...
  projectId: 'bir-adim-umut-yeni',
```

### 0.3 Build Flavors
**Durum:** BULUNAMADI

---

## BÖLÜM 1: PROJE AĞACI

### 1.1 Kök Dizin Yapısı
```
├── lib/                    # Flutter kaynak kodları
├── android/                # Android platform
├── ios/                    # iOS platform
├── firebase_functions/     # Cloud Functions (TypeScript)
├── web/                    # Web platform
├── test/                   # Test dosyaları
├── assets/                 # Medya dosyaları
├── pubspec.yaml           # Bağımlılıklar
├── firestore.rules        # Firestore güvenlik kuralları
├── storage.rules          # Storage güvenlik kuralları
└── firebase.json          # Firebase konfigürasyonu
```

### 1.2 lib/ Dizini
```
lib/
├── main.dart              # Uygulama giriş noktası (315 satır)
├── firebase_options.dart  # Firebase konfigürasyonu (95 satır)
├── models/                # 11 model dosyası
│   ├── activity_log_model.dart
│   ├── admin_badge_model.dart
│   ├── admin_dashboard_stats.dart
│   ├── admin_stats_model.dart
│   ├── badge_model.dart
│   ├── charity_model.dart
│   ├── daily_step_model.dart
│   ├── notification_model.dart
│   ├── team_member_model.dart
│   ├── team_model.dart
│   └── user_model.dart
├── providers/             # 2 provider dosyası
│   ├── language_provider.dart
│   └── theme_provider.dart
├── screens/               # 12 ekran klasörü
│   ├── admin/
│   ├── auth/
│   ├── badges/
│   ├── charity/
│   ├── dashboard/
│   ├── leaderboard/
│   ├── notifications/
│   ├── permissions/
│   ├── profile/
│   ├── splash/
│   ├── steps/
│   └── teams/
├── services/              # 19 servis dosyası
│   ├── activity_log_service.dart
│   ├── ad_log_service.dart
│   ├── admin_service.dart
│   ├── auth_service.dart
│   ├── badge_service.dart
│   ├── connectivity_service.dart
│   ├── device_service.dart
│   ├── health_service.dart
│   ├── interstitial_ad_service.dart
│   ├── local_notification_service.dart
│   ├── notification_service.dart
│   ├── permission_service.dart
│   ├── rewarded_ad_service.dart
│   ├── session_service.dart
│   ├── social_share_service.dart
│   ├── step_conversion_service.dart
│   ├── step_service.dart
│   ├── team_service.dart
│   └── theme_service.dart
└── widgets/               # Widget bileşenleri
```

### 1.3 firebase_functions/ Dizini
```
firebase_functions/functions/src/
├── index.ts                    # Ana fonksiyonlar (2339 satır)
├── admob-reporter.ts           # AdMob raporlama
├── delete-account.ts           # Hesap silme (267 satır)
├── email-verification.ts       # E-posta doğrulama
├── password-reset.ts           # Şifre sıfırlama
├── monthly-hope-calculator.ts  # Aylık Hope hesaplama
└── cleanup.ts                  # Temizlik fonksiyonları
```

---

## BÖLÜM 2: BAĞIMLILIKLAR

### 2.1 pubspec.yaml Dependencies
**Dosya:** [pubspec.yaml](pubspec.yaml#L13-L82)

#### Firebase Paketleri (7 adet)
```yaml
firebase_core: ^4.2.1
firebase_auth: ^6.1.2
cloud_firestore: ^6.1.0
cloud_functions: ^6.0.4
firebase_storage: ^13.0.4
firebase_messaging: ^16.0.4
firebase_app_check: ^0.4.1+2
```

#### State Management (3 adet)
```yaml
provider: ^6.0.0
riverpod: ^2.4.0
flutter_riverpod: ^2.4.0
```

#### Health & Fitness (2 adet)
```yaml
health: ^11.0.0
permission_handler: ^11.3.0
```

#### AdMob (1 adet)
```yaml
google_mobile_ads: ^5.1.0
```

#### Diğer Paketler
```yaml
google_sign_in: ^6.2.1
fl_chart: ^0.65.0
go_router: ^13.0.0
cached_network_image: ^3.3.0
flutter_svg: ^2.0.9
intl: ^0.19.0
uuid: ^4.0.0
shared_preferences: ^2.2.2
image_picker: ^1.0.4
share_plus: ^7.2.2
url_launcher: ^6.2.2
path_provider: ^2.1.2
flutter_dotenv: ^5.1.0
percent_indicator: ^4.1.1
flutter_local_notifications: ^17.2.4
timezone: ^0.9.4
video_player: ^2.8.2
device_info_plus: ^10.1.0
package_info_plus: ^8.0.0
flutter_native_splash: ^2.3.0
google_fonts: ^6.0.0
font_awesome_flutter: 10.5.0
```

#### Dev Dependencies
```yaml
flutter_test:
  sdk: flutter
flutter_lints: ^3.0.0
```

### 2.2 Kullanılmayan Paketler (Deklare Edilmiş Ama Kullanılmamış)
- `riverpod: ^2.4.0`
- `flutter_riverpod: ^2.4.0`
- `go_router: ^13.0.0`

---

## BÖLÜM 3: BOOTSTRAP SIRASI

### 3.1 main.dart Başlatma Sırası
**Dosya:** [lib/main.dart](lib/main.dart#L82-L183)

```dart
// Satır 82-183 arası init() fonksiyonu

try {
  // 1. Firebase başlatma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Firebase başarıyla başlatıldı!');
  
  // 2. Firestore ayarları
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  print('Firestore offline cache aktif!');
  
  // 3. App Check (DEBUG)
  if (!kIsWeb) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      print('App Check başarıyla başlatıldı!');
    } catch (e) {
      print('App Check başlatılamadı (devam ediliyor): $e');
    }
  }
  
  // 4. Local Notifications
  await LocalNotificationService().init();
  print('Local bildirimler başlatıldı!');
  
  // 5. AdMob
  await MobileAds.instance.initialize();
  print('AdMob başarıyla başlatıldı!');
  
  // 6. Ad Services
  InterstitialAdService.instance.loadAd();
  RewardedAdService.instance.loadAd();
  print('Reklam servisleri başlatıldı!');
  
  // 7. Connectivity
  ConnectivityService().initialize();
  print('Bağlantı izleme başlatıldı!');
  
  // 8. Badge Service
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    if (user.emailVerified) {
      await BadgeService().checkAllBadges(user.uid);
      print('Rozet sistemi kontrol edildi!');
    }
  }
  
  // 9. Session Tracking
  try {
    await SessionService().startSession();
    print('Session takibi başlatıldı!');
  } catch (e) {
    print('Session takibi başlatılamadı: $e');
  }
  
  // 10. Health API
  if (!kIsWeb) {
    try {
      await HealthService().initialize();
      print('Health API başlatıldı!');
    } catch (e) {
      print('Health API başlatılamadı: $e');
    }
  }
} catch (e) {
  print('Başlatma hatası: $e');
}
```

### 3.2 MultiProvider Yapısı
**Dosya:** [lib/main.dart](lib/main.dart#L186-L193)

```dart
return MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
  ],
  child: Consumer<LanguageProvider>(
    // ...
  ),
);
```

---

## BÖLÜM 4: ROUTING

### 4.1 MaterialApp Routes
**Dosya:** [lib/main.dart](lib/main.dart#L268-L277)

```dart
routes: {
  '/splash': (context) => const SplashScreen(),
  '/login': (context) => const LoginScreen(),
  '/dashboard': (context) => const DashboardScreen(),
  '/sign-up': (context) => const SignUpScreen(),
  '/notifications': (context) => const NotificationsPage(),
  '/admin': (context) => const AdminDashboard(),
},
initialRoute: '/splash',
```

### 4.2 go_router Kullanımı
**Durum:** BULUNAMADI (Paket deklare edilmiş ama kullanılmamış)

---

## BÖLÜM 5: STATE MANAGEMENT

### 5.1 Provider Pattern
**Dosya:** [lib/main.dart](lib/main.dart#L186-L193)

```dart
providers: [
  ChangeNotifierProvider(create: (_) => LanguageProvider()),
  ChangeNotifierProvider(create: (_) => ThemeProvider()),
],
```

### 5.2 Riverpod Kullanımı
**Durum:** BULUNAMADI (Paket deklare edilmiş ama kullanılmamış)

---

## BÖLÜM 6: FIREBASE KONFİGÜRASYONU

### 6.1 firebase_options.dart
**Dosya:** [lib/firebase_options.dart](lib/firebase_options.dart#L1-L95)

```dart
// Satır 25-39: Web Options
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSyBwbKoxH03LRBJUyRNzh-qLqLSA-gJXcnE',
  appId: '1:568696463280:web:f2d7e06aae6ac6c2c62f9d',
  messagingSenderId: '568696463280',
  projectId: 'bir-adim-umut-yeni',
  authDomain: 'bir-adim-umut-yeni.firebaseapp.com',
  storageBucket: 'bir-adim-umut-yeni.firebasestorage.app',
);

// Satır 41-54: Android Options
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyCFqmYvmQKs0bxCdnTFLg5Cqr9A0PbJDJM',
  appId: '1:568696463280:android:ffe5d83a6bf9631fc62f9d',
  messagingSenderId: '568696463280',
  projectId: 'bir-adim-umut-yeni',
  storageBucket: 'bir-adim-umut-yeni.firebasestorage.app',
);

// Satır 56-68: iOS Options
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyD4HwIQ9P3yP-uZ-KPWS2nM56PqbYBTGrY',
  appId: '1:568696463280:ios:c2685bdf67fb19c9c62f9d',
  messagingSenderId: '568696463280',
  projectId: 'bir-adim-umut-yeni',
  storageBucket: 'bir-adim-umut-yeni.firebasestorage.app',
  iosBundleId: 'com.hopesteps.app',
);
```

### 6.2 Firestore Ayarları
**Dosya:** [lib/main.dart](lib/main.dart#L85-L88)

```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

### 6.3 App Check Konfigürasyonu
**Dosya:** [lib/main.dart](lib/main.dart#L96-L107)

```dart
if (!kIsWeb) {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,  // DEBUG PROVIDER
      appleProvider: AppleProvider.debug,      // DEBUG PROVIDER
    );
    print('App Check başarıyla başlatıldı!');
  } catch (e) {
    print('App Check başlatılamadı (devam ediliyor): $e');
  }
}
```

---

## BÖLÜM 7: FIRESTORE VERİ MODELİ

### 7.1 Koleksiyon Yolları (Tespit Edilen)

| Koleksiyon Yolu | Kaynak Dosya |
|----------------|--------------|
| `users/{uid}` | firestore.rules:37 |
| `users/{uid}/notifications/{notificationId}` | firestore.rules:68 |
| `users/{uid}/activity_logs/{logId}` | firestore.rules:80 |
| `users/{uid}/activity_log/{logId}` | firestore.rules:92 |
| `users/{uid}/badges/{badgeId}` | firestore.rules:109 |
| `users/{uid}/daily_steps/{dateKey}` | firestore.rules:123 |
| `users/{uid}/ad_logs/{logId}` | firestore.rules:136 |
| `users/{uid}/sessions/{sessionId}` | firestore.rules:151 |
| `users/{uid}/daily_sessions/{dateKey}` | firestore.rules:164 |
| `teams/{teamId}` | firestore.rules:185 |
| `teams/{teamId}/team_members/{memberId}` | index.ts:77 |
| `charities/{charityId}` | charity_screen.dart |
| `admins/{adminId}` | firestore.rules:19 |
| `activity_logs` (global) | index.ts |
| `ad_logs` (global) | ad_log_service.dart |
| `ad_errors` | ad_log_service.dart |
| `device_daily_steps` | step_service.dart |
| `admin_logs` | admin_service.dart |

---

## BÖLÜM 8: GÜVENLİK KURALLARI

### 8.1 firestore.rules
**Dosya:** [firestore.rules](firestore.rules) (573 satır)

#### Helper Fonksiyonlar (Satır 7-33)
```plaintext
/// Kullanıcı kimlik doğrulaması kontrolü
function isAuthenticated() {
  return request.auth != null;
}

/// Kullanıcının kendi verilerine erişimi
function isUser(uid) {
  return isAuthenticated() && request.auth.uid == uid;
}

/// Admin kontrolü
function isAdmin() {
  return isAuthenticated() && 
         exists(/databases/$(database)/documents/admins/$(request.auth.uid)) &&
         get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.is_active == true;
}

/// Takım liderini kontrol et
function isTeamLeader(teamId) {
  return isAuthenticated() && 
         get(/databases/$(database)/documents/teams/$(teamId)).data.leader_uid == request.auth.uid;
}

/// Kullanıcı takımda üye mi?
function isTeamMember(teamId) {
  return isAuthenticated() && 
         exists(/databases/$(database)/documents/teams/$(teamId)/team_members/$(request.auth.uid));
}
```

#### Users Koleksiyonu Kuralları (Satır 37-64)
```plaintext
match /users/{userId} {
  // Herkes okuyabilir (sıralama amaçlı)
  allow read: if isAuthenticated();
  
  // Kendi profilini güncelle
  allow update: if isUser(userId);
  
  // Admin kullanıcıları güncelleyebilir (ban, bakiye vb.)
  allow update: if isAdmin();
  
  // Admin kullanıcıyı silebilir
  allow delete: if isAdmin();
  
  // Referral bonus güncelleme
  allow update: if isAuthenticated() &&
                  request.resource.data.diff(resource.data).affectedKeys()
                    .hasAny(['referral_bonus_steps', 'referral_count']) &&
                  request.resource.data.diff(resource.data).affectedKeys()
                    .hasOnly(['referral_bonus_steps', 'referral_count']);
  
  // Yeni user doc oluştur
  allow create: if request.auth != null && request.auth.uid == userId;
}
```

#### Catch-All Kuralı (Son satır)
```plaintext
match /{allPaths=**} {
  allow read, write: if false;
}
```

### 8.2 storage.rules
**Dosya:** [storage.rules](storage.rules) (55 satır)

```plaintext
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    /// Dosya boyutu kontrolü (max 5MB)
    function isValidSize() {
      return request.resource.size < 5 * 1024 * 1024;
    }
    
    /// Dosya türü kontrolü (sadece resimler)
    function isImage() {
      return request.resource.contentType.matches('image/.*');
    }
    
    // Profile Photos
    match /profile_photos/{userId}.jpg {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() 
                   && request.auth.uid == userId
                   && isValidSize()
                   && isImage();
    }
    
    // Team Logos
    match /team_logos/{teamId}.jpg {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated()
                   && isValidSize()
                   && isImage();
    }
    
    // Catch All
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

## BÖLÜM 9: CLOUD FUNCTIONS

### 9.1 Fonksiyon Listesi (Export Edilen)

**Dosya:** [firebase_functions/functions/src/index.ts](firebase_functions/functions/src/index.ts)

| Fonksiyon | Tetikleme | Auth Check | Satır |
|-----------|-----------|------------|-------|
| `createTeam` | https.onCall | `context.auth?.uid` | 22-95 |
| `joinTeamByReferral` | https.onCall | `context.auth?.uid` | 117-209 |
| `inviteUserToTeam` | https.onCall | `context.auth?.uid` | 224-300+ |
| `acceptTeamInvite` | https.onCall | `context.auth?.uid` | 372-460 |
| `rejectTeamInvite` | https.onCall | `context.auth?.uid` | 469-510 |
| `carryOverDailySteps` | pubsub.schedule | N/A | index.ts |
| `resetDailyTeamSteps` | pubsub.schedule | N/A | index.ts |
| `resetMonthlyTeamHope` | pubsub.schedule | N/A | index.ts |
| `calculateAdminStats` | https.onCall | `context.auth?.uid` | index.ts |
| `sendBroadcastNotification` | https.onCall | admin check | index.ts |
| `toggleUserBan` | https.onCall | admin check | index.ts |
| `distributeMonthlyLeaderboardRewards` | https.onCall | admin check | index.ts |

**Dosya:** [firebase_functions/functions/src/delete-account.ts](firebase_functions/functions/src/delete-account.ts)

| Fonksiyon | Tetikleme | Auth Check | Satır |
|-----------|-----------|------------|-------|
| `deleteAccount` | https.onCall | `context.auth?.uid` | 121-267 |

**Dosya:** [firebase_functions/functions/src/admob-reporter.ts](firebase_functions/functions/src/admob-reporter.ts)

| Fonksiyon | Tetikleme | Auth Check | Satır |
|-----------|-----------|------------|-------|
| `fetchAdMobRevenue` | pubsub.schedule | N/A (cron) | - |
| `manualFetchAdMobRevenue` | https.onCall | admin check | 212+ |

**Dosya:** firebase_functions/functions/src/email-verification.ts

| Fonksiyon | Tetikleme | Auth Check |
|-----------|-----------|------------|
| `sendVerificationCode` | https.onCall | var |
| `verifyEmailCode` | https.onCall | var |

**Dosya:** firebase_functions/functions/src/password-reset.ts

| Fonksiyon | Tetikleme | Auth Check |
|-----------|-----------|------------|
| `sendPasswordResetCode` | https.onCall | var |
| `resetPasswordWithCode` | https.onCall | var |

**Dosya:** firebase_functions/functions/src/monthly-hope-calculator.ts

| Fonksiyon | Tetikleme | Auth Check | Satır |
|-----------|-----------|------------|-------|
| `calculateMonthlyHopeValue` | https.onCall | admin check | 189-327 |
| `approvePendingDonations` | https.onCall | admin check | 328-410 |
| `getMonthlyHopeSummary` | https.onCall | admin check | 427-480 |

### 9.2 Auth Check Örnekleri

**index.ts Satır 22-30:**
```typescript
export const createTeam = functions.https.onCall(async (data, context) => {
  // Kimlik doğrulama kontrolü
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Kullanıcı oturum açmış olmalıdır."
    );
  }
```

**delete-account.ts Satır 121-130:**
```typescript
export const deleteAccount = functions.https.onCall(async (data, context) => {
  // 1. Authentication kontrolü
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Hesap silmek için giriş yapmalısınız."
    );
  }
  
  const uid = context.auth.uid;
```

**monthly-hope-calculator.ts Admin Check:**
```typescript
if (!context.auth) {
  throw new functions.https.HttpsError("unauthenticated", "...");
}

const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
if (!adminDoc.exists || !adminDoc.data()?.is_active) {
  throw new functions.https.HttpsError("permission-denied", "...");
}
```

---

## BÖLÜM 10: ADMOB ENTEGRASYONU

### 10.1 Ad Unit IDs

**Dosya:** [lib/services/interstitial_ad_service.dart](lib/services/interstitial_ad_service.dart#L24-L31)
```dart
static String get _adUnitId {
  if (Platform.isAndroid) {
    return 'ca-app-pub-9747218925154807/6697268612'; // Android Interstitial
  } else if (Platform.isIOS) {
    return 'ca-app-pub-9747218925154807/7781257751'; // iOS Interstitial
  }
}
```

**Dosya:** [lib/services/rewarded_ad_service.dart](lib/services/rewarded_ad_service.dart#L26-L32)
```dart
static String get _adUnitId {
  if (Platform.isAndroid) {
    return 'ca-app-pub-9747218925154807/4621769618'; // Android Rewarded
  } else if (Platform.isIOS) {
    return 'ca-app-pub-9747218925154807/6888840300'; // iOS Rewarded
  }
}
```

**Dosya:** [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml#L22-L24)
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-9747218925154807~1536441273"/>
```

**Dosya:** [ios/Runner/Info.plist](ios/Runner/Info.plist#L36-L37)
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-9747218925154807~9561243285</string>
```

### 10.2 AdMob Reporter OAuth Config
**Dosya:** [firebase_functions/functions/src/admob-reporter.ts](firebase_functions/functions/src/admob-reporter.ts#L27-L30)

```typescript
const config = functions.config();
const CLIENT_ID = config.admob?.client_id;
const CLIENT_SECRET = config.admob?.client_secret;  // [REDACTED]
const REFRESH_TOKEN = config.admob?.refresh_token;  // [REDACTED]
```

### 10.3 Rewarded Ad Callback
**Dosya:** [lib/services/rewarded_ad_service.dart](lib/services/rewarded_ad_service.dart#L100-L120)

```dart
await _rewardedAd!.show(
  onUserEarnedReward: (ad, reward) {
    print('Kullanıcı ödül kazandı: ${reward.amount} ${reward.type}');
    wasRewarded = true;
    // ✅ Ödül logu
    _adLogService.logRewardedAd(
      context: _currentContext,
      rewardAmount: 50,
      wasCompleted: true,
    );
    // Bonus Hope miktarı (50 Hope)
    onRewarded(50);
  },
);
```

---

## BÖLÜM 11: HEALTH / ADIM SERVİSİ

### 11.1 Health Service Imports
**Dosya:** [lib/services/health_service.dart](lib/services/health_service.dart#L1-L5)

```dart
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
```

### 11.2 Health Data Tipleri
**Dosya:** [lib/services/health_service.dart](lib/services/health_service.dart#L27-L31)

```dart
static final List<HealthDataType> _types = [
  HealthDataType.STEPS,
  HealthDataType.DISTANCE_WALKING_RUNNING,
  HealthDataType.ACTIVE_ENERGY_BURNED,
];
```

### 11.3 Simulated Data Flag
**Dosya:** [lib/services/health_service.dart](lib/services/health_service.dart#L18)

```dart
bool _useSimulatedData = false;
```

### 11.4 Permission Request
**Dosya:** [lib/services/health_service.dart](lib/services/health_service.dart#L45-L73)

```dart
// Android için Activity Recognition izni
if (isAndroid) {
  final activityStatus = await Permission.activityRecognition.request();
  if (!activityStatus.isGranted) {
    debugPrint('Activity Recognition izni reddedildi');
  }

  // Health Connect durumunu kontrol et
  try {
    final sdkStatus = await _health.getHealthConnectSdkStatus();
    debugPrint('Health Connect SDK durumu: $sdkStatus');

    if (sdkStatus == HealthConnectSdkStatus.sdkUnavailable) {
      debugPrint('Health Connect yüklü değil, simüle veri kullanılacak');
      _useSimulatedData = true;
      _isAuthorized = true;
      _todaySteps = _generateSimulatedSteps();
      return true;
    }
  } catch (e) {
    debugPrint('Health Connect kontrolü başarısız: $e');
  }
}

// İzin türlerini ayarla (sadece okuma)
final permissions = _types.map((e) => HealthDataAccess.READ).toList();

// İzin iste
bool authorized = await _health.requestAuthorization(
  _types,
  permissions: permissions,
);
```

### 11.5 Simulated Steps Generator
**Dosya:** [lib/services/health_service.dart](lib/services/health_service.dart#L303-L318)

```dart
int _generateSimulatedSteps() {
  final now = DateTime.now();
  final hour = now.hour;
  
  // Günün saatine göre mantıklı bir değer
  if (hour < 8) {
    return 500 + (now.minute * 10);
  } else if (hour < 12) {
    return 2000 + (hour * 200);
  } else if (hour < 18) {
    return 5000 + (hour * 300);
  } else {
    return 7000 + (hour * 200);
  }
}
```

---

## BÖLÜM 12: HARİTA / KONUM

### 12.1 Android Manifest İzinleri
**Dosya:** [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml#L4-L15)

```xml
<!-- İnternet ve Sensor İzni -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Google Fit / Health Connect İzinleri -->
<uses-permission android:name="android.permission.health.READ_STEPS" />
<uses-permission android:name="android.permission.health.READ_DISTANCE" />
<uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED" />
```

### 12.2 iOS Info.plist İzinleri
**Dosya:** [ios/Runner/Info.plist](ios/Runner/Info.plist#L42-L48)

```xml
<key>NSHealthShareUsageDescription</key>
<string>OneHopeStep needs access to your health data to track your daily steps and convert them to Hope donations.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>OneHopeStep needs to update your health data to record your step conversion activities.</string>

<key>NSMotionUsageDescription</key>
<string>OneHopeStep needs access to your motion data to count your daily steps.</string>
```

### 12.3 Harita Widget Kullanımı
**Durum:** BULUNAMADI (Konum izinleri mevcut ama harita widget kullanımı tespit edilmedi)

---

## BÖLÜM 13: LOGLAMA / HATA YÖNETİMİ

### 13.1 print() Kullanım Örnekleri (50+ tespit edildi)

**Dosya:** [lib/main.dart](lib/main.dart)
```dart
// Satır 86
print('Firebase başarıyla başlatıldı!');

// Satır 93
print('Firestore offline cache aktif!');

// Satır 102
print('App Check başarıyla başlatıldı!');

// Satır 125
print('AdMob başarıyla başlatıldı!');

// Satır 183
print('Başlatma hatası: $e');
```

**Dosya:** [lib/services/rewarded_ad_service.dart](lib/services/rewarded_ad_service.dart)
```dart
// Satır 45
print('RewardedAd yüklendi');

// Satır 48
print('RewardedAd yüklenemedi: ${error.message}');

// Satır 110
print('Kullanıcı ödül kazandı: ${reward.amount} ${reward.type}');
```

**Dosya:** [lib/services/interstitial_ad_service.dart](lib/services/interstitial_ad_service.dart)
```dart
// Satır 38
print('🎬 InterstitialAd yükleniyor... (kDebugMode: $kDebugMode, adUnitId: $_adUnitId)');

// Satır 46
print('✅ InterstitialAd yüklendi başarıyla');
```

### 13.2 debugPrint() Kullanım Örnekleri

**Dosya:** [lib/services/health_service.dart](lib/services/health_service.dart)
```dart
// Satır 39
debugPrint('Health API web\'de desteklenmiyor');

// Satır 48
debugPrint('Activity Recognition izni reddedildi');

// Satır 54
debugPrint('Health Connect SDK durumu: $sdkStatus');

// Satır 73
debugPrint('Health API requestAuthorization sonucu: $authorized');
```

### 13.3 try/catch Kullanım Örnekleri (50+ tespit edildi)

**Dosya:** [lib/main.dart](lib/main.dart)
```dart
// Satır 82-183
try {
  await Firebase.initializeApp(...);
  // ...
} catch (e) {
  print('Başlatma hatası: $e');
}
```

**Dosya:** [lib/screens/auth/email_verification_screen.dart](lib/screens/auth/email_verification_screen.dart)
```dart
// Satır 86-108
try {
  // ...
} on FirebaseFunctionsException catch (e) {
  // Spesifik hata yönetimi
} catch (e) {
  // Genel hata yönetimi
}
```

**Dosya:** [lib/screens/charity/charity_screen.dart](lib/screens/charity/charity_screen.dart)
```dart
// Satır 76-108
try {
  // Veri yükleme
} catch (e) {
  print('❌ Veri yükleme hatası: $e');
}
```

---

## BÖLÜM 14: TEST / CI

### 14.1 Test Dizini
**Dosya:** [test/widget_test.dart](test/widget_test.dart) (72 satır)

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MyApp widget oluşturulabilir mi', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MyApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('ThemeProvider light/dark tema değiştirebilir', (WidgetTester tester) async {
    final themeProvider = ThemeProvider();
    expect(themeProvider.themeMode, ThemeMode.system);
    await themeProvider.setThemeMode(ThemeMode.light);
    expect(themeProvider.themeMode, ThemeMode.light);
    await themeProvider.setThemeMode(ThemeMode.dark);
    expect(themeProvider.themeMode, ThemeMode.dark);
  });

  testWidgets('LanguageProvider dil değiştirebilir', (WidgetTester tester) async {
    final languageProvider = LanguageProvider();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(languageProvider.languageCode, 'tr');
    await languageProvider.setLanguage('en');
    expect(languageProvider.languageCode, 'en');
  });
}
```

### 14.2 Test Sayısı
- Widget testleri: 3 adet
- Unit testleri: BULUNAMADI
- Integration testleri: BULUNAMADI

### 14.3 CI/CD Yapılandırması
**Dizin:** `.github/workflows/`
**Durum:** BULUNAMADI

---

## BÖLÜM 15: GİZLİ DOSYALAR

### 15.1 .gitignore İçeriği
**Dosya:** [.gitignore](.gitignore)

```gitignore
# Firebase
.env
google-services.json
GoogleService-Info.plist

# Misc
.env.local
.env.*.local

# Release keystore
android/key.properties
android/app/*.jks
*.jks
serviceAccountKey.json
```

### 15.2 Hassas Dosyalar (Repo'da Mevcut)

| Dosya | Durum |
|-------|-------|
| `serviceAccountKey.json` | Repo'da mevcut |
| `serviceAccountKey_OLD_2026-01-06.json` | Repo'da mevcut |
| `android/key.properties` | Repo'da mevcut |
| `android/app/google-services.json` | Repo'da mevcut |

### 15.3 .env Dosyası
**Durum:** Repo'da BULUNAMADI (.gitignore'da tanımlı)

---

## BÖLÜM 16: PAKET BOYUTU

### 16.1 Assets Klasörü
```
assets/
├── badges/     # Rozet görselleri
├── icons/      # İkon dosyaları
├── images/     # Resim dosyaları
└── videos/     # Video dosyaları
```

### 16.2 Native Splash Konfigürasyonu
**Dosya:** [pubspec.yaml](pubspec.yaml#L97-L118)

```yaml
flutter_native_splash:
  color: "#FFFFFF"
  image: assets/images/nativelogo.png
  fullscreen: false
  ios: true
  android: true
  web: false
```

---

## BÖLÜM 17: PLATFORM SPESİFİK

### 17.1 Android Package Name
**Dosya:** [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml#L2)
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.hopesteps.app">
```

### 17.2 iOS Bundle ID
**Dosya:** [lib/firebase_options.dart](lib/firebase_options.dart#L68)
```dart
iosBundleId: 'com.hopesteps.app',
```

### 17.3 iOS SKAdNetwork
**Dosya:** [ios/Runner/Info.plist](ios/Runner/Info.plist#L49-L55)
```xml
<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
</array>
```

---

## ÖZET İSTATİSTİKLER

| Metrik | Değer |
|--------|-------|
| Dart Dosyası | 73 |
| TypeScript Fonksiyon | 7 dosya |
| Model Dosyası | 11 |
| Servis Dosyası | 19 |
| Ekran Klasörü | 12 |
| Firebase Paketi | 7 |
| Toplam Dependency | 40+ |
| Test Dosyası | 1 |
| Test Sayısı | 3 |
| CI/CD Pipeline | 0 |
| print() Kullanımı | 50+ |
| try/catch Bloğu | 50+ |
| Cloud Function | 20+ |
| Firestore Koleksiyonu | 18+ |

---

**KANIT PAKETİ SONU**
