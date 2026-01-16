# 🔐 FAZA 2: GÜVENLİK CREDENTIALS - REHBER

**Tarih:** 14 Ocak 2026  
**Hazırlayan:** GitHub Copilot (Claude Opus 4.5)  
**Referans:** YOL_HARITASI_v1.1.md

---

## 📋 FAZA 2 İÇERİĞİ

| Bug | Açıklama | Risk |
|-----|----------|------|
| BUG-003 | AdMob private key açıkta | 🔴 Kritik |
| BUG-009 | serviceAccountKey.json Git'te | 🔴 Kritik |
| BUG-010 | Zayıf keystore şifresi | 🟡 Orta |

---

## 🚨 ADIM 1: serviceAccountKey.json (BUG-009)

### 1.1 Mevcut Key'i REVOKE Et

1. **Firebase Console'a git:** https://console.firebase.google.com
2. **Proje Ayarları** → **Service accounts** sekmesi
3. **"Manage service account permissions"** linkine tıkla (Google Cloud Console açılır)
4. Sol menüden **"IAM & Admin"** → **"Service Accounts"**
5. `firebase-adminsdk-...` service account'u bul
6. **"Keys"** sekmesine git
7. Mevcut key'i **DELETE** et (⚠️ Bu key artık çalışmayacak!)

### 1.2 Yeni Key Oluştur

1. Aynı sayfada **"ADD KEY"** → **"Create new key"**
2. **JSON** formatını seç → **CREATE**
3. Dosya otomatik indirilecek
4. İndirilen dosyayı `serviceAccountKey.json` olarak **proje kök dizinine** taşı

### 1.3 .gitignore Durumu

✅ `.gitignore`'da zaten mevcut:
```
serviceAccountKey.json
```

Ancak Git history'de hala mevcut olduğu için temizlenmeli.

### 1.4 Git History Temizleme

**⚠️ ÖNEMLİ:** Bu işlem Git history'yi değiştirir. Önce backup alın!

#### Yöntem 1: BFG (Önerilen)
```bash
# 1. Backup al
git branch backup-before-history-clean

# 2. BFG'yi indir
brew install bfg

# 3. Sensitive dosyaları temizle
bfg --delete-files serviceAccountKey.json

# 4. Git garbage collection
git reflog expire --expire=now --all && git gc --prune=now --aggressive

# 5. Force push (DİKKAT!)
git push origin --force --all
```

#### Yöntem 2: git filter-branch (Alternatif)
```bash
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch serviceAccountKey.json' \
  --prune-empty --tag-name-filter cat -- --all
```

---

## 🚨 ADIM 2: AdMob Private Key (BUG-003)

### 2.1 Mevcut Durum (KRİTİK GÜVENLİK AÇIĞI!)

**Dosya:** `firebase_functions/functions/src/admob-reporter.ts`

```typescript
// ⚠️ YANLIŞ - Private key açıkta!
const SERVICE_ACCOUNT = {
  type: "service_account",
  project_id: "bir-adim-umut-yeni",
  private_key_id: "3911f037d0e709e07cf278c44dc1d79ee27afe33",
  private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBg...",
  client_email: "admob-reporter@bir-adim-umut-yeni.iam.gserviceaccount.com",
  // ...
};
```

### 2.2 Google Cloud'da Eski Key'i REVOKE Et

1. **Google Cloud Console:** https://console.cloud.google.com
2. **"bir-adim-umut-yeni"** projesini seç
3. **IAM & Admin** → **Service Accounts**
4. `admob-reporter@bir-adim-umut-yeni.iam.gserviceaccount.com` hesabını bul
5. **Keys** sekmesi → Mevcut key'i **DELETE** et
6. **ADD KEY** → **Create new key** → **JSON** → **CREATE**

### 2.3 Firebase Functions Config Ayarla

```bash
# Firebase functions dizinine git
cd firebase_functions/functions

# Service account JSON dosyasını config olarak ayarla
firebase functions:config:set admob.credentials="$(cat /path/to/new-admob-service-account.json | base64)"

# Config'i doğrula
firebase functions:config:get
```

### 2.4 Kod Güncellemesi (Onay Gerekli)

**ESKİ (YANLIŞ - Private key açıkta):**
```typescript
const SERVICE_ACCOUNT = {
  private_key: "-----BEGIN PRIVATE KEY-----\n...",
  // ...
};
```

**YENİ (GÜVENLİ - Environment variable'dan):**
```typescript
// Firebase functions config'den credentials'ı al
const getServiceAccount = () => {
  const credentials = functions.config().admob?.credentials;
  if (!credentials) {
    throw new Error("AdMob credentials not configured. Run: firebase functions:config:set admob.credentials=<base64-encoded-json>");
  }
  return JSON.parse(Buffer.from(credentials, 'base64').toString());
};

const SERVICE_ACCOUNT = getServiceAccount();
```

---

## 🔑 ADIM 3: Keystore Şifresi (BUG-010)

### 3.1 Mevcut Durum (ZAYIF ŞİFRE!)

**Dosya:** `android/key.properties`

```properties
storePassword=hopesteps123    # ⚠️ Çok zayıf!
keyPassword=hopesteps123      # ⚠️ Çok zayıf!
keyAlias=hopesteps
storeFile=../app/hopesteps-release.jks
```

### 3.2 Yeni Güçlü Keystore Oluştur

```bash
# Yeni keystore oluştur (min 16 karakter şifre)
keytool -genkey -v -keystore hopesteps-release-new.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias hopesteps \
  -storepass 'YeniGucluSifre2026!@#$' \
  -keypass 'YeniGucluSifre2026!@#$' \
  -dname "CN=HopeSteps, OU=Development, O=BirAdimUmut, L=Istanbul, ST=Istanbul, C=TR"
```

### 3.3 key.properties Güncelle

```properties
storePassword=YeniGucluSifre2026!@#$
keyPassword=YeniGucluSifre2026!@#$
keyAlias=hopesteps
storeFile=../app/hopesteps-release-new.jks
```

### 3.4 Güçlü Şifre Kuralları

| Kural | Açıklama |
|-------|----------|
| Minimum 16 karakter | Daha uzun = daha güvenli |
| Büyük harf | A-Z |
| Küçük harf | a-z |
| Rakam | 0-9 |
| Özel karakter | !@#$%^&*() |
| Tahmin edilemez | Proje adı, doğum tarihi vb. kullanmayın |

### 3.5 Google Play Uyarısı

⚠️ **ÖNEMLİ:** 
- Google Play'de "App Signing by Google Play" kullanıyorsanız, upload key değiştirebilirsiniz
- Kullanmıyorsanız, yeni keystore ile imzalanan APK **FARKLI** sayılır
- Bu durumda Google Play Support ile iletişime geçmeniz gerekebilir

---

## 📋 FAZA 2 ÖZET CHECKLIST

### BUG-009: serviceAccountKey.json

| # | İşlem | Durum |
|---|-------|-------|
| 1 | Firebase Console'dan eski service account key'i REVOKE et | ⬜ |
| 2 | Yeni service account key oluştur | ⬜ |
| 3 | serviceAccountKey.json'u güncelle | ⬜ |
| 4 | Git history'den serviceAccountKey.json temizle (BFG) | ⬜ |

### BUG-003: AdMob Private Key

| # | İşlem | Durum |
|---|-------|-------|
| 5 | Google Cloud'dan eski AdMob key'i REVOKE et | ⬜ |
| 6 | Yeni AdMob service account key oluştur | ⬜ |
| 7 | Firebase functions config ayarla | ⬜ |
| 8 | admob-reporter.ts'i environment variable kullanacak şekilde güncelle | ⬜ Onay Bekliyor |
| 9 | Functions'ı deploy et | ⬜ |

### BUG-010: Keystore Şifresi

| # | İşlem | Durum |
|---|-------|-------|
| 10 | Yeni güçlü keystore oluştur | ⬜ |
| 11 | key.properties güncelle | ⬜ |
| 12 | Git history'den key.properties temizle | ⬜ |

---

## ❓ KARAR GEREKLİ

Aşağıdaki sorulara cevap verin:

### Soru 1: AdMob Kod Güncellemesi
`admob-reporter.ts` dosyasını environment variable kullanacak şekilde güncellememi onaylıyor musunuz?

```
[ ] EVET - Güncelle
[ ] HAYIR - Manuel yapacağım
```

### Soru 2: Git History Temizleme
Git history temizleme işlemini yapmak istiyor musunuz? (Bu işlem force push gerektirir)

```
[ ] EVET - Temizle
[ ] HAYIR - Şimdilik atlayalım
```

### Soru 3: Keystore
Yeni keystore oluşturacak mısınız yoksa mevcut şifreyi güçlendirmek mi istiyorsunuz?

```
[ ] YENİ KEYSTORE - Sıfırdan oluştur
[ ] MEVCUT - Sadece şifreyi değiştir (mümkün değil, yeni keystore gerekli)
```

---

## 🔗 FAYDALI LİNKLER

| Link | Açıklama |
|------|----------|
| https://console.firebase.google.com | Firebase Console |
| https://console.cloud.google.com | Google Cloud Console |
| https://rtyley.github.io/bfg-repo-cleaner/ | BFG Repo Cleaner |
| https://play.google.com/console | Google Play Console |

---

## 📌 SONRAKİ ADIM

FAZA 2 tamamlandığında **FAZA 3: AUTH & LEGAL** başlayacak:

- BUG-004: Email verification eksik
- BUG-006: Hesap silme özelliği eksik (GDPR/Apple)

**Soft-delete kararı:** EVET (30 gün retention) - Önceden onaylandı

---

**Cevaplarınızı bekliyorum.**

*Rapor Sonu*
