# 🔒 BİR ADIM UMUT - KAPSAMLI GÜVENLİK DENETİM RAPORU

**Denetim Tarihi:** 2025-01-15  
**Denetçi Profili:** Hostile/Paranoid Auditor  
**Proje:** OneHopeStep (Bir Adım Umut)  
**Flutter Version:** 3.x  
**Firebase Project:** bir-adim-umut-yeni

---

## 📋 İÇİNDEKİLER

1. [Proje Ağacı ve Dosya Envanteri](#1-proje-ağacı-ve-dosya-envanteri)
2. [Bağımlılık Envanteri](#2-bağımlılık-envanteri)
3. [Uygulama Bootstrap Analizi](#3-uygulama-bootstrap-analizi)
4. [Firebase Envanteri](#4-firebase-envanteri)
5. [AdMob Envanteri](#5-admob-envanteri)
6. [Health/Steps API Envanteri](#6-healthsteps-api-envanteri)
7. [Map/Location Envanteri](#7-maplocation-envanteri)
8. [Backend/API Envanteri](#8-backendapi-envanteri)
9. [Güvenlik Kontrol Listesi](#9-güvenlik-kontrol-listesi)
10. [Test & CI/CD Envanteri](#10-test--cicd-envanteri)
11. [🚨 KIRMIZI BAYRAK BULGULARI](#11-kırmızı-bayrak-bulgulari)

---

## 1. PROJE AĞACI VE DOSYA ENVANTERİ

### 1.1 Klasör Yapısı

```
bir-adim-umut/
├── lib/                          # Ana Flutter kodu
│   ├── main.dart                 # Uygulama giriş noktası
│   ├── firebase_options.dart     # Firebase yapılandırması
│   ├── models/                   # Veri modelleri
│   ├── providers/                # State yönetimi (Provider)
│   ├── screens/                  # UI ekranları
│   ├── services/                 # İş mantığı servisleri
│   └── widgets/                  # Paylaşılan widget'lar
├── android/                      # Android yapılandırması
│   └── app/src/main/AndroidManifest.xml
├── ios/                          # iOS yapılandırması
│   └── Runner/Info.plist
├── firebase_functions/           # Cloud Functions
│   └── functions/src/            # 7 TypeScript function
├── test/                         # Test dosyaları (1 adet)
├── firestore.rules               # Firestore güvenlik kuralları
├── storage.rules                 # Storage güvenlik kuralları
└── pubspec.yaml                  # Flutter bağımlılıkları
```

### 1.2 Dosya İstatistikleri

| Kategori | Sayı |
|----------|------|
| Dart dosyaları (lib/) | 73 |
| Cloud Functions (TypeScript) | 7 |
| Test dosyaları | 1 |
| Toplam proje dosyası | ~200+ |

### 1.3 Kritik Yapılandırma Dosyaları

| Dosya | Durum | Risk |
|-------|-------|------|
| `serviceAccountKey.json` | Repo root'ta (UNTRACKED) | ⚠️ Orta |
| `serviceAccountKey_OLD_2026-01-06.json` | Repo root'ta (NOT IGNORED!) | 🔴 Yüksek |
| `android/key.properties` | .gitignore'da | ✅ Güvenli |
| `google-services.json` | .gitignore'da | ✅ Güvenli |
| `firebase_options.dart` | Kod içinde (API keys) | ℹ️ Beklenen |

---

## 2. BAĞIMLILLIK ENVANTERİ

### 2.1 Firebase Paketi (Toplam: 7)

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `firebase_core` | ^4.2.1 | Temel Firebase |
| `firebase_auth` | ^6.1.2 | Kimlik doğrulama |
| `cloud_firestore` | ^6.1.0 | Veritabanı |
| `cloud_functions` | ^6.0.4 | Cloud Functions çağrıları |
| `firebase_storage` | ^13.0.4 | Dosya depolama |
| `firebase_messaging` | ^16.0.4 | Push notifications |
| `firebase_app_check` | ^0.4.1+2 | API güvenliği |

### 2.2 State Management

| Paket | Versiyon | Kullanım |
|-------|----------|----------|
| `provider` | ^6.0.0 | ✅ Aktif kullanımda |
| `riverpod` | ^2.4.0 | ❌ KULLANILMIYOR |
| `flutter_riverpod` | ^2.4.0 | ❌ KULLANILMIYOR |

**🔴 SORUN:** `riverpod` paketleri pubspec.yaml'da var ama kodda hiç import edilmiyor!

### 2.3 Navigation

| Paket | Versiyon | Kullanım |
|-------|----------|----------|
| `go_router` | ^13.0.0 | ❌ KULLANILMIYOR |

**🔴 SORUN:** `go_router` pubspec.yaml'da var ama uygulama MaterialApp'in klasik `routes:` sistemini kullanıyor!

### 2.4 Health & Fitness

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `health` | ^11.0.0 | Apple Health / Health Connect |
| `permission_handler` | ^11.3.0 | İzin yönetimi |

### 2.5 Reklam

| Paket | Versiyon | Amaç |
|-------|----------|------|
| `google_mobile_ads` | ^5.1.0 | AdMob entegrasyonu |

### 2.6 Tüm Bağımlılık Özeti

| Kategori | Toplam | Aktif Kullanım |
|----------|--------|----------------|
| Toplam dependencies | 40+ | ~35 |
| Kullanılmayan paketler | 3 | riverpod (2), go_router (1) |

---

## 3. UYGULAMA BOOTSTRAP ANALİZİ

### 3.1 Başlatma Sırası (main.dart:75-185)

```
1. WidgetsFlutterBinding.ensureInitialized()
2. Firebase.initializeApp()
3. Firestore Settings (offline persistence)
4. FirebaseAppCheck.activate() [DEBUG MODE!]
5. Push Notification handler setup
6. LocalNotificationService.initialize()
7. MobileAds.instance.initialize()
8. InterstitialAdService.loadAd()
9. RewardedAdService.loadAd()
10. ConnectivityService.startMonitoring()
11. Badge/Login streak check (if logged in)
12. SessionService.startSession()
13. HealthService.initialize()
14. runApp(MultiProvider(...))
```

### 3.2 Provider Yapılandırması

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
  ],
  child: const MyApp(),
)
```

### 3.3 Routing Yapısı

| Route | Ekran | Açıklama |
|-------|-------|----------|
| `/splash` | SplashScreen | Açılış |
| `/login` | LoginScreen | Giriş |
| `/dashboard` | DashboardScreen | Ana sayfa |
| `/sign-up` | SignUpScreen | Kayıt |
| `/notifications` | NotificationsPage | Bildirimler |
| `/admin` | AdminPanelScreen | Admin panel |

**Not:** go_router YOK - klasik Navigator.routes kullanılıyor.

### 3.4 Lifecycle Management

```dart
class _MyAppState with WidgetsBindingObserver {
  - resumed: SessionService.heartbeat()
  - paused/detached/inactive: SessionService.endSession()
}
```

---

## 4. FIREBASE ENVANTERİ

### 4.1 Firebase Proje Bilgileri

| Alan | Değer |
|------|-------|
| Project ID | `bir-adim-umut-yeni` |
| Auth Domain | `bir-adim-umut-yeni.firebaseapp.com` |
| Storage Bucket | `bir-adim-umut-yeni.firebasestorage.app` |
| Messaging Sender ID | `568696463280` |

### 4.2 Firebase API Key'leri (firebase_options.dart)

| Platform | API Key |
|----------|---------|
| Web | `AIzaSyA5EvynualJEwE9oTcXlLN0JpmNyt33Amw` |
| Android | `AIzaSyC3u8jK6JuL7BIllbBU7FuZgkftptpYwEI` |
| iOS | `AIzaSyC3u8jK6JuL7BIllbBU7FuZgkftptpYwEI` |

**Not:** Firebase API key'leri istemci tarafında görünür olması normaldir. App Check ve Firestore Rules ile korunur.

### 4.3 App Check Durumu

```dart
// main.dart:96-105
await FirebaseAppCheck.instance.activate(
  appleProvider: AppleProvider.debug,      // ⚠️ DEBUG MODE
  androidProvider: AndroidProvider.debug,  // ⚠️ DEBUG MODE
);
```

**🟡 UYARI:** App Check DEBUG modunda! Store yayınından önce şu şekilde değiştirilmeli:
- iOS: `AppleProvider.deviceCheck` veya `AppleProvider.appAttest`
- Android: `AndroidProvider.playIntegrity`

### 4.4 Firestore Rules Özeti (573 satır)

**Helper Functions:**
```javascript
function isUser(uid) { return request.auth != null && request.auth.uid == uid; }
function isAdmin() { ... users/{uid}/isAdmin == true ... }
function isTeamLeader(teamId) { ... team_role == 'leader' ... }
function isTeamMember(teamId) { ... exists(teams/{teamId}/team_members/{uid}) ... }
```

**Kritik Kurallar:**
| Path | Read | Write |
|------|------|-------|
| `users/{uid}` | Sadece sahip | Sadece sahip |
| `users/{uid}/notifications` | Sadece sahip | ✅ Düzeltildi |
| `teams/{teamId}` | Herkes | Sadece lider |
| `charities/{charityId}` | Herkes | Sadece admin |
| `admin_stats/{doc}` | Sadece admin | Sadece Cloud Functions |

**Catch-All Kuralı:**
```javascript
match /{document=**} {
  allow read, write: if false;  // ✅ Varsayılan reddetme
}
```

### 4.5 Storage Rules Özeti (55 satır)

| Path | Max Size | Allowed Types |
|------|----------|---------------|
| `profile_photos/{uid}/*` | 5MB | image/* |
| `team_logos/{teamId}/*` | 5MB | image/* |

---

## 5. ADMOB ENVANTERİ

### 5.1 App ID'leri

| Platform | App ID | Dosya |
|----------|--------|-------|
| Android | `ca-app-pub-9747218925154807~1536441273` | AndroidManifest.xml |
| iOS | `ca-app-pub-9747218925154807~9561243285` | Info.plist |

### 5.2 Ad Unit ID'leri

| Tip | Platform | ID |
|-----|----------|-----|
| Interstitial | Android | `ca-app-pub-9747218925154807/6697268612` |
| Interstitial | iOS | `ca-app-pub-9747218925154807/7781257751` |
| Rewarded | Android | `ca-app-pub-9747218925154807/4621769618` |
| Rewarded | iOS | `ca-app-pub-9747218925154807/6888840300` |

### 5.3 AdMob Servis Dosyaları

| Dosya | Satır | Amaç |
|-------|-------|------|
| `lib/services/interstitial_ad_service.dart` | 151 | Zorunlu reklamlar |
| `lib/services/rewarded_ad_service.dart` | 141 | Ödüllü reklamlar |
| `lib/services/ad_log_service.dart` | ~240 | Reklam izleme logları |
| `lib/widgets/banner_ad_widget.dart` | ~100 | Banner reklam widget |

### 5.4 Reklam Akışı

```
1. main.dart: MobileAds.instance.initialize()
2. main.dart: InterstitialAdService.instance.loadAd()
3. main.dart: RewardedAdService.instance.loadAd()
4. Kullanım noktalarında showAd() çağrılır
5. Tüm reklamlar AdLogService ile loglanır
```

### 5.5 Backend AdMob Entegrasyonu

**Dosya:** `firebase_functions/functions/src/admob-reporter.ts`

```typescript
// OAuth credentials Firebase config'den alınır
const clientId = config.admob?.client_id;
const clientSecret = config.admob?.client_secret;
const refreshToken = config.admob?.refresh_token;
```

**✅ GÜVENLİ:** Private key'ler Firebase Functions config'de saklanıyor.

---

## 6. HEALTH/STEPS API ENVANTERİ

### 6.1 Okunan Veri Tipleri

```dart
// health_service.dart:27-30
static final List<HealthDataType> _types = [
  HealthDataType.STEPS,
  HealthDataType.DISTANCE_WALKING_RUNNING,
  HealthDataType.ACTIVE_ENERGY_BURNED,
];
```

### 6.2 İzin Akışı

**iOS (Info.plist):**
```xml
<key>NSHealthShareUsageDescription</key>
<string>OneHopeStep needs access to your health data to track your daily steps...</string>
<key>NSHealthUpdateUsageDescription</key>
<string>OneHopeStep needs to update your health data...</string>
<key>NSMotionUsageDescription</key>
<string>OneHopeStep needs access to your motion data...</string>
```

**Android (AndroidManifest.xml):**
```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.health.READ_STEPS" />
<uses-permission android:name="android.permission.health.READ_DISTANCE" />
<uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED" />
```

### 6.3 Health Service Özeti

| Dosya | Satır | Amaç |
|-------|-------|------|
| `lib/services/health_service.dart` | 369 | Apple Health / Health Connect |

**Özellikler:**
- Singleton pattern
- iOS: HealthKit entegrasyonu
- Android: Health Connect (Google Fit yerine)
- Fallback: Simüle veri (izin reddedilirse veya API yoksa)

### 6.4 Simüle Veri Modu

```dart
_useSimulatedData = true;  // Web, izin reddi, veya Health Connect yoksa
_todaySteps = _generateSimulatedSteps();
```

---

## 7. MAP/LOCATION ENVANTERİ

### 7.1 İzinler

**AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### 7.2 Kullanım

- Konum izinleri mevcut ancak aktif kullanılan harita servisi YOK
- Muhtemelen gelecek özellikler için hazırlanmış

---

## 8. BACKEND/API ENVANTERİ

### 8.1 Cloud Functions Listesi

| Function | Dosya | Tetikleyici | Amaç |
|----------|-------|-------------|------|
| `createTeam` | index.ts | HTTPS Callable | Takım oluştur |
| `joinTeam` | index.ts | HTTPS Callable | Takıma katıl |
| `leaveTeam` | index.ts | HTTPS Callable | Takımdan ayrıl |
| `emailVerification` | email-verification.ts | HTTPS Callable | Email doğrulama |
| `passwordReset` | password-reset.ts | HTTPS Callable | Şifre sıfırlama |
| `deleteAccount` | delete-account.ts | HTTPS Callable | Hesap silme |
| `fetchAdMobRevenue` | admob-reporter.ts | PubSub Schedule | AdMob gelir raporu |
| `monthlyHopeCalculator` | monthly-hope-calculator.ts | PubSub Schedule | Aylık Hope hesaplama |
| `cleanup` | cleanup.ts | PubSub Schedule | Veri temizliği |

### 8.2 API Güvenlik Kontrolleri

```typescript
// Her callable function'da:
if (!context.auth?.uid) {
  throw new functions.https.HttpsError("unauthenticated", "...");
}
```

### 8.3 Harici API'ler

| API | Kullanım | Credentials |
|-----|----------|-------------|
| AdMob Reporting API | Gelir raporları | OAuth2 (Firebase config) |
| Gmail SMTP | Email gönderimi | hopesteps.app@gmail.com |

---

## 9. GÜVENLİK KONTROL LİSTESİ

### 9.1 Kimlik Doğrulama

| Kontrol | Durum | Not |
|---------|-------|-----|
| Email/Şifre auth | ✅ | Firebase Auth |
| Google Sign-In | ✅ | google_sign_in paketi |
| Email doğrulama | ✅ | 6-haneli kod sistemi |
| Şifre sıfırlama | ✅ | Cloud Function ile |
| Hesap silme | ✅ | Cloud Function + re-auth |
| Session yönetimi | ✅ | SessionService |

### 9.2 Veri Güvenliği

| Kontrol | Durum | Not |
|---------|-------|-----|
| Firestore Rules | ✅ | 573 satır, kapsamlı |
| Storage Rules | ✅ | 55 satır, boyut/tip kısıtlaması |
| App Check | ⚠️ | DEBUG modunda |
| HTTPS | ✅ | Firebase varsayılan |
| Offline persistence | ✅ | Aktif |

### 9.3 Kod Güvenliği

| Kontrol | Durum | Not |
|---------|-------|-----|
| .gitignore | ✅ | Hassas dosyalar dahil |
| Hardcoded secrets | ✅ | Yok (API keys beklenen) |
| Print statements | ⚠️ | 23 dosyada print() var |
| Error handling | ✅ | Try-catch blokları |

### 9.4 Platform Güvenliği

| Platform | Kontrol | Durum |
|----------|---------|-------|
| iOS | SKAdNetworkItems | ✅ |
| iOS | NSAppTransportSecurity | Varsayılan |
| Android | targetSdkVersion | Kontrol edilmeli |
| Android | ProGuard/R8 | Kontrol edilmeli |

---

## 10. TEST & CI/CD ENVANTERİ

### 10.1 Test Durumu

| Kategori | Dosya Sayısı | Durum |
|----------|-------------|-------|
| Unit tests | 0 | ❌ YOK |
| Widget tests | 1 | ⚠️ Minimal |
| Integration tests | 0 | ❌ YOK |
| Toplam test coverage | <1% | 🔴 KRİTİK |

**Mevcut Test:** `test/widget_test.dart` (72 satır)
- MyApp widget testi
- ThemeProvider tema değişimi testi

### 10.2 CI/CD Durumu

| Araç | Durum | Not |
|------|-------|-----|
| `.github/` klasörü | ❌ YOK | GitHub Actions yok |
| Fastlane | ❌ YOK | iOS/Android otomasyonu yok |
| Codemagic/Bitrise | ❓ Bilinmiyor | External config olabilir |

---

## 11. 🚨 KIRMIZI BAYRAK BULGULARI

### 🔴 KRİTİK SEVİYE (Acil Aksiyon Gerekli)

#### 1. OLD SERVICE ACCOUNT KEY GİT'TE İZLENMİYOR AMA IGNORE DA DEĞİL
**Dosya:** `/serviceAccountKey_OLD_2026-01-06.json`  
**Risk:** Bu dosya `.gitignore`'da yok! Commit edilirse tüm Firebase Admin erişimi açığa çıkar.

**Öneri:**
```bash
# .gitignore'a ekle:
serviceAccountKey*.json
```

#### 2. APP CHECK DEBUG MODUNDA
**Dosya:** `lib/main.dart:96-105`  
**Risk:** Production'da API'ler korumasız kalır.

**Mevcut kod:**
```dart
appleProvider: AppleProvider.debug,
androidProvider: AndroidProvider.debug,
```

**Önerilen düzeltme (store yayını için):**
```dart
appleProvider: AppleProvider.deviceCheck,
androidProvider: AndroidProvider.playIntegrity,
```

#### 3. TEST COVERAGE <%1
**Risk:** Code review ve regression detection imkansız.

**Öneri:**
- En az kritik servislerin (AuthService, HealthService, CharityScreen) unit testleri yazılmalı
- GitHub Actions ile CI/CD kurulmalı

---

### 🟡 ORTA SEVİYE (Planlı Düzeltme)

#### 4. KULLANILMAYAN BAĞIMLILIKLAR
**Dosya:** `pubspec.yaml`  
**Paketler:**
- `riverpod: ^2.4.0`
- `flutter_riverpod: ^2.4.0`
- `go_router: ^13.0.0`

**Risk:** Gereksiz bundle boyutu, karmaşıklık.

**Öneri:** pubspec.yaml'dan kaldır ve `flutter pub get` çalıştır.

#### 5. PRODUCTION'DA PRINT() KULLANIMI
**Dosya sayısı:** 23  
**Satır:** 100+ print()/debugPrint() çağrısı

**Risk:** 
- iOS/Android log'larında hassas bilgi sızabilir
- Console spam

**Öneri:**
```dart
// Yerine:
import 'package:flutter/foundation.dart';
if (kDebugMode) print('...');

// veya:
debugPrint('...');  // Release'de otomatik kaldırılır
```

#### 6. CI/CD PIPELINE YOK
**Klasör:** `.github/` mevcut değil

**Risk:**
- Manuel deployment hataları
- Test otomasyonu yok
- Code review zorunlu değil

**Öneri:** GitHub Actions workflow ekle:
```yaml
# .github/workflows/flutter.yml
name: Flutter CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

---

### 🟢 BİLGİLENDİRME (Düşük Risk)

#### 7. FIREBASE API KEY'LERİ KODDA GÖRÜNİYOR
**Dosya:** `lib/firebase_options.dart`

**Durum:** ✅ Bu NORMAL ve BEKLENENdir.
- Firebase API key'leri istemci tarafında görünür
- Güvenlik Firestore Rules + App Check ile sağlanır

#### 8. ADMOB ID'LERİ KODDA HARDCODED
**Dosyalar:**
- `lib/services/interstitial_ad_service.dart`
- `lib/services/rewarded_ad_service.dart`

**Durum:** ✅ Bu NORMAL - AdMob ID'leri gizli değildir.

#### 9. FIRESTORE RULES CATCH-ALL MEVCUT
**Dosya:** `firestore.rules:570-573`

```javascript
match /{document=**} {
  allow read, write: if false;
}
```

**Durum:** ✅ MÜKEMMEL - Varsayılan reddetme politikası.

#### 10. STORAGE BOYUT/TİP KISITLAMASI MEVCUT
**Dosya:** `storage.rules`

```javascript
request.resource.size < 5 * 1024 * 1024  // 5MB
request.resource.contentType.matches('image/.*')
```

**Durum:** ✅ MÜKEMMEL - Upload kısıtlamaları var.

---

## 📊 ÖZET TABLO

| Kategori | Skor | Detay |
|----------|------|-------|
| **Kimlik Doğrulama** | 9/10 | Kapsamlı, email doğrulama var |
| **Veritabanı Güvenliği** | 9/10 | Firestore rules mükemmel |
| **Storage Güvenliği** | 9/10 | Boyut/tip kısıtlaması var |
| **API Güvenliği** | 6/10 | App Check debug modunda |
| **Kod Kalitesi** | 7/10 | Kullanılmayan paketler, print'ler |
| **Test Coverage** | 2/10 | Neredeyse yok |
| **CI/CD** | 0/10 | Hiç yok |
| **Secret Management** | 8/10 | Çoğu doğru, OLD key risk |

### GENEL SKOR: 62/100

---

## 📋 AKSİYON PLANI

### Acil (Bu Hafta):
1. ⬜ `serviceAccountKey*.json` pattern'ini .gitignore'a ekle
2. ⬜ OLD service account key dosyasını sil
3. ⬜ Kullanılmayan paketleri kaldır (riverpod, go_router)

### Kısa Vade (2 Hafta):
4. ⬜ GitHub Actions CI/CD kurulumu
5. ⬜ Kritik servisler için unit test yaz
6. ⬜ print() çağrılarını debugPrint()/kDebugMode ile değiştir

### Orta Vade (Store Yayını Öncesi):
7. ⬜ App Check'i production moduna al
8. ⬜ ProGuard/R8 konfigürasyonu kontrol et
9. ⬜ Integration testler ekle

---

**Rapor Oluşturulma:** 2025-01-15  
**Son Güncelleme:** 2025-01-15  
**Denetçi:** AI Security Auditor (Hostile/Paranoid Mode)
