# 🚀 BİR ADIM UMUT - ÇALIŞMA BAŞLAMAĞI

Bu dosya projeyi geliştirmeye başlamak için gerekli adımları açıklar.

---

## ✅ ÖN KOŞULLAR

### Kurulu Olması Gereken:

1. **Flutter SDK** (3.0.0+)
   ```bash
   flutter --version
   # Eğer yüklü değilse: https://flutter.dev/docs/get-started/install
   ```

2. **Dart SDK** (Flutter ile birlikte gelir)
   ```bash
   dart --version
   ```

3. **Android Studio** veya **Visual Studio Code**
   ```bash
   # VS Code + Flutter Extension önerilir
   ```

4. **Git** (Sürüm kontrolü için)
   ```bash
   git --version
   ```

5. **Node.js** (Cloud Functions için)
   ```bash
   node --version
   npm --version
   ```

---

## 🔧 ADIM ADIM KURULUM

### 1. Proje Dosyalarını İndir

```bash
# Projeyi klonla (veya ZIP'ten çıkar)
git clone <repo-url>
cd bir_adim_umut
```

### 2. Flutter Bağımlılıklarını Yükle

```bash
flutter pub get
```

**Beklenen Çıktı:**
```
Running "flutter pub get" in bir_adim_umut...
┌─ pub.dev was down!
└─ retrying in 1 second
pubspec.yaml: Resolving dependencies...
+ cached_network_image 3.3.0
+ cloud_firestore 4.13.0
+ firebase_auth 4.14.0
+ firebase_core 2.24.0
...
Got dependencies in X seconds.
```

### 3. Firebase Konfigürasyonu

#### 3.1 Firebase Console'da Proje Oluştur

1. https://console.firebase.google.com adresine git
2. "Create Project" tıkla
3. Proje adı: "bir-adim-umut"
4. Google Analytics'i devre dışı bırak (opsiyonel)
5. "Create Project" tıkla

#### 3.2 Android Konfigürasyonu

```bash
# Firebase CLI'yi kur
npm install -g firebase-tools

# Firebase'ye giriş yap
firebase login

# Android uygulamasını Firebase'ye ekle
firebase setup:android
# Proje ID'sini gir: bir-adim-umut

# Google Services JSON'u indir
# - Firebase Console > Project Settings > Download google-services.json
# - android/app/ klasörüne koy
```

#### 3.3 iOS Konfigürasyonu

```bash
# iOS uygulamasını Firebase'ye ekle
firebase setup:ios
# Proje ID'sini gir: bir-adim-umut

# GoogleService-Info.plist'i indir
# - Firebase Console > Project Settings > Download GoogleService-Info.plist
# - ios/Runner/GoogleService-Info.plist olarak kaydet
```

### 4. .env Dosyası Oluştur

Proje kökünde `.env` dosyası oluştur:

```bash
# .env dosyasını oluştur
cat > .env << EOF
FIREBASE_API_KEY=your_api_key
FIREBASE_APP_ID=your_app_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_PROJECT_ID=bir-adim-umut
FIREBASE_AUTH_DOMAIN=bir-adim-umut.firebaseapp.com
FIREBASE_STORAGE_BUCKET=bir-adim-umut.appspot.com
EOF
```

**Değerleri nerede bulacaksın:**
- Firebase Console > Project Settings > General
- Tüm değerler orada mevcut

### 5. Cloud Functions Deploy Et

```bash
# Cloud Functions klasörüne git
cd firebase_functions/functions

# Bağımlılıkları yükle
npm install

# TypeScript'i derle
npm run build

# Deploy et
firebase deploy --only functions

# Başarılı çıktı:
# ✔  Deploy complete!
# Function URL: https://...
```

### 6. Firestore Security Rules Deploy Et

```bash
# Proje kökünde
firebase deploy --only firestore:rules

# Başarılı çıktı:
# ✔ firestore: Rules updated successfully
```

### 7. Firestore Endekslerini Oluştur

Firebase Console'da:

1. Firestore Database > Indexes tab'ını aç
2. Şu endeksleri oluştur:

**Endeks 1: teams (referral_code)**
```
Collection: teams
Field: referral_code (Ascending)
Query scope: Collection
INDEX_TYPE: Unique
```

**Endeks 2: daily_steps (user_id, date)**
```
Collection: daily_steps
Field 1: user_id (Ascending)
Field 2: date (Descending)
Query scope: Collection
```

**Endeks 3: users (current_team_id)**
```
Collection: users
Field: current_team_id (Ascending)
Query scope: Collection
```

---

## ▶️ UYGULAMAYIÇALIŞTIR

### Android'de Çalıştır

```bash
# Emulator'ü başlat (Android Studio'dan)
# veya Fiziksel cihazı bağla

# Projeyi çalıştır
flutter run
```

### iOS'da Çalıştır

```bash
# Cocoapods bağımlılıklarını yükle
cd ios
pod install
cd ..

# Çalıştır
flutter run
```

### Web'de Çalıştır (Test amaçlı)

```bash
flutter run -d chrome
```

### Beklenen Çıktı

```
Launching lib/main.dart on emulator in debug mode...
✓ Built build/app/intermediates/flutter/debug/app.jar (54.2s)
✓ Installed build/app/outputs/apk/debug/app-debug.apk (5.2s)
Waiting for emulator to report its views...
Syncing files to device emulator-5554...
I/flutter (12345): ════════════════════════════════════════════════════════════
I/flutter (12345): Welcome to Bir Adım Umut!
I/flutter (12345): ════════════════════════════════════════════════════════════
```

---

## 🧪 UYGULAMAYITESTA ET

### 1. Kayıt (Sign Up) Testini Yap

**Adımlar:**
1. Uygulamayı aç
2. "Kaydı Ol" sayfasını gör
3. Alanları doldur:
   ```
   Ad Soyad: Ahmet Yılmaz
   E-posta: ahmet@example.com
   Şifre: 123456
   Ref. Kod: ABC123 (opsiyonel)
   ```
4. [Kaydı Tamamla] tıkla

**Beklenen Sonuç:**
- ✅ Firebase Authentication'da user oluşturulur
- ✅ Firestore'da users doc oluşturulur
- ✅ Referral code girildiyse takıma eklenır
- ✅ Dashboard'a yönlendirilir

### 2. Firestore Verisini Kontrol Et

Firebase Console'da:

```
Firestore Database > Collections > users > [userId]

Beklenen Alanlar:
{
  full_name: "Ahmet Yılmaz",
  masked_name: "A* Y*",
  email: "ahmet@example.com",
  wallet_balance_hope: 0,
  current_team_id: null (veya takım ID'si),
  theme_preference: "light",
  created_at: Timestamp
}
```

### 3. Cloud Functions Testini Yap

Cloud Functions Logs:
```bash
firebase functions:log

# Beklenen çıktı:
# signUpWithReferral called with data: {...}
# User created: uid=abc123
# Team joined successfully
```

---

## 🔍 TROUBLESHOOTING (Sorun Giderme)

### Flutter Kurulumu Sorunları

```bash
# Flutter ortamını kontrol et
flutter doctor

# Çıktısı şöyle olmalı:
# ✓ Flutter (Channel stable)
# ✓ Android toolchain
# ✓ Xcode (iOS için)
# ✓ VS Code
```

### Firebase Connection Sorunları

```bash
# Firebase bağlantısını test et
firebase setup:emulators:firestore

# Emulator'ü başlat
firebase emulators:start

# Yeni terminal'de uygulamayı çalıştır
flutter run --dart-define=USE_EMULATOR=true
```

### Build Sorunları

```bash
# Cache'i temizle
flutter clean

# Pub cache'i güncelle
flutter pub upgrade

# Yeniden oluştur
flutter pub get
flutter run
```

### Android Sorunları

```bash
# Android SDK'yı güncelle
flutter doctor --android-licenses

# Emulator varsa yeniden oluştur
flutter emulators --create <name>
flutter emulators --launch <name>
```

---

## 📝 GELİŞTİRME TALIMATLAR

### Dosya Yapısını Anla

```
lib/
├── main.dart              # Entry point
├── models/                # Veri modelleri
├── services/              # Firebase services
├── screens/               # UI ekranları
└── widgets/               # Reusable widgets
```

### Yeni Feature Ekle

1. **Model oluştur** (`lib/models/`)
   ```dart
   class MyModel {
     final String id;
     // ... alanlar
     
     factory MyModel.fromFirestore(DocumentSnapshot doc) {
       // Mapping
     }
   }
   ```

2. **Service oluştur** (`lib/services/`)
   ```dart
   class MyService {
     Future<void> doSomething() {
       // Firebase işlemi
     }
   }
   ```

3. **UI oluştur** (`lib/screens/` veya `lib/widgets/`)
   ```dart
   class MyScreen extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       // UI
     }
   }
   ```

4. **Test et** (`flutter run`)

### Code Style

- Türkçe yorum ve metinler kullan (UI'da)
- Dart stil kılavuzunu izle
- Tüm fonksiyonları dokümante et (///)

---

## 📚 KAYNAKLAR

- [Flutter Dokümantasyonu](https://flutter.dev)
- [Firebase Dokümantasyonu](https://firebase.google.com/docs)
- [Dart Stil Kılavuzu](https://dart.dev/guides/language/effective-dart/style)
- [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)

---

## 💬 SORULAR & YARDIM

Bu proje hakkında sorularınız varsa:

1. **README.md** - Proje tanımı ve mimarisi
2. **TECHNICAL_SUMMARY.md** - Detaylı kod örnekleri
3. **Firebase Console Logs** - Runtime hataları

---

## ✅ HAZIRLANMA KONTROL LİSTESİ

- [ ] Flutter SDK yüklü ve güncel
- [ ] Proje klonlandı/indirildi
- [ ] `flutter pub get` çalıştırıldı
- [ ] Firebase projesi oluşturuldu
- [ ] google-services.json indirildi (Android)
- [ ] GoogleService-Info.plist indirildi (iOS)
- [ ] .env dosyası oluşturuldu
- [ ] Cloud Functions deploy edildi
- [ ] Firestore Rules deploy edildi
- [ ] Firestore Endeksleri oluşturuldu
- [ ] `flutter run` başarılı
- [ ] Sign Up ekranı görüntülendi
- [ ] Firestore'da user doc oluşturuldu

---

## 🎉 HAZIRSIN!

Tebrikler! Proje çalışmaya hazır.

Şimdi:
1. ✅ Remaining screens'i tamamla
2. ✅ AdMob entegrasyonunu yap
3. ✅ Push notifications'ı aktifleştir
4. ✅ Cloud Functions'ları test et
5. ✅ Play Store/App Store'a yükle

**Happy coding!** 🚀

---

**Son Güncelleme:** Aralık 2024
