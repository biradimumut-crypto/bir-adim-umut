# 🔐 FAZA 2: GÜVENLİK ADIM ADIM UYGULAMA REHBERİ

**Tarih:** 14 Ocak 2026  
**Durum:** DEVAM EDİYOR  
**Hazırlayan:** GitHub Copilot (Claude Opus 4.5)

---

## ✅ TAMAMLANAN İŞLEMLER

### 1. AdMob Kod Güncellemesi (BUG-003)

**Dosya:** `firebase_functions/functions/src/admob-reporter.ts`

**Yapılan Değişiklik:**
- Private key kaynak koddan kaldırıldı
- Environment variable'dan okuma eklendi (`functions.config().admob.credentials`)
- Base64 encoded JSON formatı kullanılıyor
- Lazy initialization ile performans optimizasyonu

**Yeni Kod Yapısı:**
```typescript
const getAdMobServiceAccount = (): Record<string, string> => {
  const config = functions.config();
  const credentials = config.admob?.credentials;
  
  if (!credentials) {
    throw new Error("AdMob credentials not configured.");
  }
  
  const decoded = Buffer.from(credentials, "base64").toString("utf-8");
  return JSON.parse(decoded);
};
```

---

## ⏳ BEKLEYEN İŞLEMLER (MANUEL)

Aşağıdaki adımları **sırasıyla** uygulayın:

---

## 📋 ADIM 1: BACKUP ALMA (ZORUNLU)

### 1.1 Local Git Backup

```bash
# Proje dizinine git
cd /Users/sertaccokhamur/bir-adim-umut

# Mevcut durumu commit et (varsa uncommitted değişiklikler)
git add -A
git commit -m "FAZA 2 öncesi: AdMob kodu güncellendi"

# Backup branch oluştur
git branch backup-before-history-clean-$(date +%Y%m%d)

# Branch'i listele ve doğrula
git branch | grep backup
```

### 1.2 Remote Backup

```bash
# Remote'a backup branch'i push et
git push origin backup-before-history-clean-$(date +%Y%m%d)

# Doğrula
git branch -r | grep backup
```

### 1.3 Fiziksel Backup (Önerilen)

```bash
# Tüm projeyi kopyala
cp -r /Users/sertaccokhamur/bir-adim-umut /Users/sertaccokhamur/bir-adim-umut-backup-faza2

# Doğrula
ls -la /Users/sertaccokhamur/bir-adim-umut-backup-faza2
```

---

## 📋 ADIM 2: GOOGLE CLOUD KEY YÖNETİMİ

### 2.1 Firebase Admin SDK Key (serviceAccountKey.json)

1. **Firebase Console'u aç:** https://console.firebase.google.com
2. **Proje seç:** `bir-adim-umut-yeni`
3. **⚙️ Project settings** → **Service accounts** sekmesi
4. **"Manage service account permissions"** linkine tıkla
5. Google Cloud Console açılacak
6. **IAM & Admin** → **Service Accounts** menüsüne git
7. `firebase-adminsdk-xxxxx@bir-adim-umut-yeni.iam.gserviceaccount.com` hesabını bul
8. Hesaba tıkla → **KEYS** sekmesi
9. Mevcut key'i **DELETE** et (⚠️ Onay kutusunu işaretle)
10. **ADD KEY** → **Create new key** → **JSON** → **CREATE**
11. Dosya otomatik indirilecek

**İndirilen dosyayı taşı:**
```bash
# İndirilen dosyayı proje dizinine taşı
mv ~/Downloads/bir-adim-umut-yeni-*.json /Users/sertaccokhamur/bir-adim-umut/serviceAccountKey.json

# Doğrula
cat /Users/sertaccokhamur/bir-adim-umut/serviceAccountKey.json | head -5
```

### 2.2 AdMob Reporter Key

1. **Google Cloud Console:** https://console.cloud.google.com
2. **Proje seç:** `bir-adim-umut-yeni`
3. **IAM & Admin** → **Service Accounts**
4. `admob-reporter@bir-adim-umut-yeni.iam.gserviceaccount.com` hesabını bul
5. Hesaba tıkla → **KEYS** sekmesi
6. Mevcut key'i **DELETE** et
7. **ADD KEY** → **Create new key** → **JSON** → **CREATE**
8. Dosya otomatik indirilecek

**Firebase Functions Config Ayarla:**
```bash
# İndirilen dosyayı base64'e çevir ve config'e ekle
cd /Users/sertaccokhamur/bir-adim-umut/firebase_functions/functions

# Config ayarla
firebase functions:config:set admob.credentials="$(cat ~/Downloads/admob-reporter-key.json | base64)"

# Doğrula
firebase functions:config:get

# Beklenen çıktı:
# {
#   "admob": {
#     "credentials": "eyJ0eXBlIjoic2VydmljZV9hY2NvdW..."
#   }
# }
```

---

## 📋 ADIM 3: GIT HISTORY TEMİZLİĞİ

### 3.1 BFG Kurulumu

```bash
# Homebrew ile BFG kur
brew install bfg

# Doğrula
bfg --version
```

### 3.2 Temizlenecek Dosyaları Listele

```bash
# Proje dizinine git
cd /Users/sertaccokhamur/bir-adim-umut

# History'de bu dosyaları ara
git log --all --full-history -- serviceAccountKey.json
git log --all --full-history -- android/key.properties
git log --all --full-history -- firebase_functions/functions/src/admob-reporter.ts
```

### 3.3 Sensitive Dosyaları Temizle

```bash
# ÖNCE: .gitignore'a ekli olduğundan emin ol
cat .gitignore | grep -E "serviceAccountKey|key.properties"

# serviceAccountKey.json'u history'den temizle
bfg --delete-files serviceAccountKey.json

# key.properties'i history'den temizle  
bfg --delete-files key.properties

# admob-reporter.ts'deki eski private key içeren commitleri temizle
# (Dosya silmiyoruz, sadece eski versiyonları temizliyoruz)
# Bu adım için --replace-text kullanacağız:

# Önce sensitive text pattern dosyası oluştur
echo "-----BEGIN PRIVATE KEY-----" >> /tmp/sensitive-patterns.txt
echo "-----END PRIVATE KEY-----" >> /tmp/sensitive-patterns.txt

# Pattern'leri temizle
bfg --replace-text /tmp/sensitive-patterns.txt

# Garbage collection
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

### 3.4 Değişiklikleri Doğrula

```bash
# History'de artık sensitive data olmamalı
git log --all -p -- serviceAccountKey.json | head -50

# Boş dönmeli (silinmiş olmalı)
```

### 3.5 Force Push

⚠️ **DİKKAT:** Bu adım geri alınamaz!

```bash
# Önce remote'u kontrol et
git remote -v

# Force push (DİKKAT!)
git push origin --force --all

# Tag'leri de push et
git push origin --force --tags
```

---

## 📋 ADIM 4: YENİ KEYSTORE OLUŞTURMA (BUG-010)

### 4.1 Güçlü Şifre Oluştur

Aşağıdaki kurallara uygun bir şifre belirleyin:
- Minimum 16 karakter
- Büyük harf (A-Z)
- Küçük harf (a-z)
- Rakam (0-9)
- Özel karakter (!@#$%^&*)

**Örnek:** `HopeSteps2026!@SecureKey`

### 4.2 Yeni Keystore Oluştur

```bash
# Android dizinine git
cd /Users/sertaccokhamur/bir-adim-umut/android/app

# Yeni keystore oluştur
keytool -genkey -v -keystore hopesteps-release-v2.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias hopesteps \
  -dname "CN=HopeSteps, OU=Development, O=BirAdimUmut, L=Istanbul, ST=Istanbul, C=TR"

# Şifre sorulacak - güçlü şifrenizi girin
# Store password: [GÜVENLİ ŞİFRENİZ]
# Key password: [AYNI ŞİFRE]
```

### 4.3 key.properties Güncelle

```bash
# Eski dosyayı yedekle
cp /Users/sertaccokhamur/bir-adim-umut/android/key.properties \
   /Users/sertaccokhamur/bir-adim-umut/android/key.properties.old

# Yeni içeriği yaz
cat > /Users/sertaccokhamur/bir-adim-umut/android/key.properties << 'EOF'
storePassword=BURAYA_GUCLU_SIFRENIZI_YAZIN
keyPassword=BURAYA_GUCLU_SIFRENIZI_YAZIN
keyAlias=hopesteps
storeFile=app/hopesteps-release-v2.jks
EOF

# Doğrula
cat /Users/sertaccokhamur/bir-adim-umut/android/key.properties
```

### 4.4 .gitignore Kontrolü

```bash
# key.properties .gitignore'da olmalı
echo "android/key.properties" >> /Users/sertaccokhamur/bir-adim-umut/.gitignore
echo "*.jks" >> /Users/sertaccokhamur/bir-adim-umut/.gitignore

# Doğrula
cat /Users/sertaccokhamur/bir-adim-umut/.gitignore | grep -E "key.properties|jks"
```

---

## 📋 ADIM 5: DEPLOY VE TEST

### 5.1 Cloud Functions Deploy

```bash
cd /Users/sertaccokhamur/bir-adim-umut/firebase_functions/functions

# Önce build et
npm run build

# Deploy et
firebase deploy --only functions

# Logs'u kontrol et
firebase functions:log --only fetchAdMobRevenue
```

### 5.2 Flutter Build Test

```bash
cd /Users/sertaccokhamur/bir-adim-umut

# iOS build
flutter build ios --debug

# Android build (yeni keystore ile)
flutter build apk --debug
```

---

## ✅ FAZA 2 CHECKLIST

| # | İşlem | Durum |
|---|-------|-------|
| 1 | AdMob kodu güncellendi | ✅ Tamamlandı |
| 2 | Local backup alındı | ⬜ Bekliyor |
| 3 | Remote backup alındı | ⬜ Bekliyor |
| 4 | Firebase Admin SDK key yenilendi | ⬜ Bekliyor |
| 5 | AdMob key yenilendi | ⬜ Bekliyor |
| 6 | Firebase functions config ayarlandı | ⬜ Bekliyor |
| 7 | BFG kuruldu | ⬜ Bekliyor |
| 8 | Git history temizlendi | ⬜ Bekliyor |
| 9 | Force push yapıldı | ⬜ Bekliyor |
| 10 | Yeni keystore oluşturuldu | ⬜ Bekliyor |
| 11 | key.properties güncellendi | ⬜ Bekliyor |
| 12 | Cloud Functions deploy edildi | ⬜ Bekliyor |
| 13 | Flutter build test edildi | ⬜ Bekliyor |

---

## ⚠️ SORUN GİDERME

### Problem: Firebase Functions config boş dönüyor
```bash
# Local emulator için .runtimeconfig.json oluştur
firebase functions:config:get > .runtimeconfig.json
```

### Problem: BFG çalışmıyor
```bash
# Alternatif: git filter-branch
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch serviceAccountKey.json' \
  --prune-empty --tag-name-filter cat -- --all
```

### Problem: Keystore şifresi unutuldu
- Maalesef keystore şifresi kurtarılamaz
- Yeni keystore oluşturulmalı
- Google Play'de "App Signing" kullanıyorsanız upload key değiştirilebilir

---

## 📌 SONRAKİ ADIM

FAZA 2 tamamlandığında **"FAZA 2 TAMAMLANDI"** yazın.

Sonra **FAZA 3: AUTH & LEGAL** başlayacak:
- BUG-004: Email verification eksik
- BUG-006: Hesap silme (Soft-delete, 30 gün retention)

---

**Manuel adımları tamamladıkça bana bildirin.**

*Rapor Sonu*
