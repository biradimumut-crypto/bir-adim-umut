# 🔐 FAZA 2: GÜVENLİK ADIM ADIM UYGULAMA REHBERİ (v2.0)

**Tarih:** 14 Ocak 2026  
**Durum:** DEVAM EDİYOR  
**Hazırlayan:** GitHub Copilot (Claude Opus 4.5)  
**Versiyon:** 2.0 (Revize Edildi)

---

## 📝 v2.0 REVİZYON NOTLARI

| # | Revizyon | Gerekçe |
|---|----------|---------|
| 1️⃣ | Tüm kritik adımlara ONAY noktaları eklendi | Geri dönüşü olmayan işlemler için güvenlik |
| 2️⃣ | BFG adımları dry-run ve kontrollü hale getirildi | Beklenmeyen veri kaybı riski |
| 3️⃣ | Keystore için Google Play App Signing sorgusu eklendi | Platform uyumluluk kontrolü |
| 4️⃣ | Faz sonu onay mekanizması eklendi | Sistematik ilerleme |

---

## ✅ TAMAMLANAN İŞLEMLER

### 1. AdMob Kod Güncellemesi (BUG-003)

**Dosya:** `firebase_functions/functions/src/admob-reporter.ts`

**Yapılan Değişiklik:**
- Private key kaynak koddan kaldırıldı ✅
- Environment variable'dan okuma eklendi ✅
- Base64 encoded JSON formatı kullanılıyor ✅
- Lazy initialization ile performans optimizasyonu ✅

---

## ⏳ BEKLEYEN İŞLEMLER

Aşağıdaki adımlar **önerilen** sırayla sunulmaktadır. Her kritik adım öncesinde **ONAY** istenmektedir.

---

## 📋 ADIM 1: BACKUP ALMA

### 1.1 Local Git Backup (Önerilen)

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

### 1.2 Remote Backup (Önerilen)

```bash
# Remote'a backup branch'i push et
git push origin backup-before-history-clean-$(date +%Y%m%d)

# Doğrula
git branch -r | grep backup
```

### 1.3 Fiziksel Backup (Şiddetle Önerilen)

```bash
# Tüm projeyi kopyala
cp -r /Users/sertaccokhamur/bir-adim-umut /Users/sertaccokhamur/bir-adim-umut-backup-faza2

# Doğrula
ls -la /Users/sertaccokhamur/bir-adim-umut-backup-faza2
```

### ✅ ADIM 1 KONTROL NOKTASI

Devam etmeden önce aşağıdakileri doğrulayın:

```
[ ] Local backup branch oluşturuldu
[ ] Remote'a push edildi
[ ] Fiziksel backup alındı (önerilen)
```

**Hazır mısınız? → "ADIM 1 TAMAMLANDI" yazın**

---

## 📋 ADIM 2: GOOGLE CLOUD KEY YÖNETİMİ

### ⚠️ UYARI: GERİ DÖNÜŞÜ OLMAYAN İŞLEM

Key silme işlemi **geri alınamaz**. Silinen key ile yapılan tüm API çağrıları başarısız olur.

### 2.1 Firebase Admin SDK Key (serviceAccountKey.json)

**Önerilen Adımlar:**

1. **Firebase Console'u aç:** https://console.firebase.google.com
2. **Proje seç:** `bir-adim-umut-yeni`
3. **⚙️ Project settings** → **Service accounts** sekmesi
4. **"Manage service account permissions"** linkine tıkla
5. Google Cloud Console açılacak
6. **IAM & Admin** → **Service Accounts** menüsüne git
7. `firebase-adminsdk-xxxxx@bir-adim-umut-yeni.iam.gserviceaccount.com` hesabını bul
8. Hesaba tıkla → **KEYS** sekmesi

### 🛑 ONAY NOKTASI 2.1

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠️ KEY SİLME İŞLEMİ GERİ ALINAMAZ!                          │
│                                                             │
│ Bu key'i silmeden önce:                                     │
│ □ Yeni key oluşturmaya hazır mısınız?                       │
│ □ serviceAccountKey.json kullanan tüm sistemleri            │
│   güncelleyebilecek misiniz?                                │
│ □ Kısa süreli servis kesintisini kabul ediyor musunuz?      │
│                                                             │
│ ONAY: "ESKİ KEY SİLİNEBİLİR" yazın                          │
│ ATLA: "KEY SİLMEYİ ATLA" yazın (sonra yapılabilir)          │
└─────────────────────────────────────────────────────────────┘
```

**Onay sonrası adımlar:**
1. Mevcut key'i **DELETE** et
2. **ADD KEY** → **Create new key** → **JSON** → **CREATE**
3. Dosya otomatik indirilecek

**İndirilen dosyayı taşı:**
```bash
# İndirilen dosyayı proje dizinine taşı
mv ~/Downloads/bir-adim-umut-yeni-*.json /Users/sertaccokhamur/bir-adim-umut/serviceAccountKey.json

# Doğrula
cat /Users/sertaccokhamur/bir-adim-umut/serviceAccountKey.json | head -5
```

---

### 2.2 AdMob Reporter Key

**Önerilen Adımlar:**

1. **Google Cloud Console:** https://console.cloud.google.com
2. **Proje seç:** `bir-adim-umut-yeni`
3. **IAM & Admin** → **Service Accounts**
4. `admob-reporter@bir-adim-umut-yeni.iam.gserviceaccount.com` hesabını bul
5. Hesaba tıkla → **KEYS** sekmesi

### 🛑 ONAY NOKTASI 2.2

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠️ ADMOB KEY SİLME İŞLEMİ GERİ ALINAMAZ!                    │
│                                                             │
│ Bu key'i silmeden önce:                                     │
│ □ AdMob raporlama geçici olarak çalışmayabilir              │
│ □ Yeni key oluşturduktan sonra Firebase config              │
│   güncellenmelidir                                          │
│                                                             │
│ ONAY: "ADMOB KEY SİLİNEBİLİR" yazın                         │
│ ATLA: "ADMOB KEY SİLMEYİ ATLA" yazın                        │
└─────────────────────────────────────────────────────────────┘
```

**Onay sonrası adımlar:**
1. Mevcut key'i **DELETE** et
2. **ADD KEY** → **Create new key** → **JSON** → **CREATE**

**Firebase Functions Config Ayarla:**
```bash
# Firebase functions dizinine git
cd /Users/sertaccokhamur/bir-adim-umut/firebase_functions/functions

# Config ayarla (indirilen dosyanın yolunu güncelleyin)
firebase functions:config:set admob.credentials="$(cat ~/Downloads/[INDIRILEN_DOSYA_ADI].json | base64)"

# Doğrula
firebase functions:config:get

# Beklenen çıktı:
# {
#   "admob": {
#     "credentials": "eyJ0eXBlIjoic2VydmljZV9hY2NvdW..."
#   }
# }
```

### ✅ ADIM 2 KONTROL NOKTASI

```
[ ] Firebase Admin SDK key yenilendi (veya atlandı)
[ ] AdMob key yenilendi (veya atlandı)
[ ] Firebase functions config ayarlandı
[ ] Yeni key'ler çalışıyor (test edildi)
```

**Hazır mısınız? → "ADIM 2 TAMAMLANDI" yazın**

---

## 📋 ADIM 3: GIT HISTORY TEMİZLİĞİ

### ⚠️ KRİTİK UYARI: YÜKSEK RİSKLİ İŞLEM

```
┌─────────────────────────────────────────────────────────────┐
│ 🚨 GIT HISTORY TEMİZLİĞİ RİSKLERİ:                          │
│                                                             │
│ 1. Bu işlem TÜM commit hash'lerini değiştirir               │
│ 2. Diğer geliştiriciler force pull yapmalıdır               │
│ 3. Açık PR'lar conflict yaşayabilir                         │
│ 4. CI/CD pipeline'ları etkilenebilir                        │
│ 5. Yanlış yapılırsa veri kaybı olabilir                     │
│                                                             │
│ ÖNERİ: Bu adımı sadece gerekli görüyorsanız yapın.          │
│ Alternatif: Key'leri yenileyip history'yi olduğu gibi       │
│ bırakabilirsiniz (key'ler artık geçersiz olacak)            │
└─────────────────────────────────────────────────────────────┘
```

### 3.1 BFG Kurulumu (İsteğe Bağlı)

```bash
# Homebrew ile BFG kur
brew install bfg

# Doğrula
bfg --version
```

### 3.2 DRY-RUN: Temizlenecek Dosyaları Önizle

**Önce history'de ne olduğunu kontrol edin (veri değişmez):**

```bash
# Proje dizinine git
cd /Users/sertaccokhamur/bir-adim-umut

# serviceAccountKey.json history'de var mı?
echo "=== serviceAccountKey.json geçmişi ==="
git log --all --oneline -- serviceAccountKey.json | head -10

# key.properties history'de var mı?
echo "=== key.properties geçmişi ==="
git log --all --oneline -- android/key.properties | head -10

# Private key pattern'i history'de var mı?
echo "=== Private key pattern arama ==="
git log --all -p -S "BEGIN PRIVATE KEY" -- firebase_functions/functions/src/admob-reporter.ts | head -20
```

### 3.3 BFG ile Kontrollü Temizlik

### 🛑 ONAY NOKTASI 3.1 - DOSYA SİLME

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠️ BFG --delete-files ÇALIŞTIRMADAN ÖNCE:                   │
│                                                             │
│ Silinecek dosyalar:                                         │
│ □ serviceAccountKey.json (tüm history'den)                  │
│ □ android/key.properties (tüm history'den)                  │
│                                                             │
│ Bu dosyalar WORKING DIRECTORY'de korunacak,                 │
│ sadece GIT HISTORY'den silinecek.                           │
│                                                             │
│ DRY-RUN sonuçlarını incelediniz mi?                         │
│                                                             │
│ ONAY: "BFG DOSYA SİLME ONAYLI" yazın                        │
│ ATLA: "HISTORY TEMİZLİĞİNİ ATLA" yazın                      │
└─────────────────────────────────────────────────────────────┘
```

**Onay sonrası (sadece onay verildiyse):**

```bash
# ADIM 1: Önce mirror clone oluştur (güvenli çalışma)
cd /Users/sertaccokhamur
git clone --mirror /Users/sertaccokhamur/bir-adim-umut bir-adim-umut-mirror.git

# ADIM 2: BFG'yi mirror üzerinde çalıştır
cd bir-adim-umut-mirror.git

# serviceAccountKey.json'u temizle
bfg --delete-files serviceAccountKey.json --no-blob-protection

# key.properties'i temizle
bfg --delete-files key.properties --no-blob-protection

# ADIM 3: Sonuçları incele (henüz uygulanmadı)
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# ADIM 4: Değişiklikleri doğrula
echo "=== Temizlik sonrası kontrol ==="
git log --all --oneline -- serviceAccountKey.json
# Boş dönmeli
```

### 3.4 Private Key Pattern Temizliği (İsteğe Bağlı)

### 🛑 ONAY NOKTASI 3.2 - PATTERN TEMİZLİĞİ

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠️ BFG --replace-text YÜKSEK RİSKLİ İŞLEM!                  │
│                                                             │
│ Bu işlem TÜM dosyalarda pattern arar ve değiştirir.         │
│ Beklenmeyen dosyalar etkilenebilir.                         │
│                                                             │
│ Hedeflenen pattern:                                         │
│ - "-----BEGIN PRIVATE KEY-----"                             │
│ - "-----END PRIVATE KEY-----"                               │
│                                                             │
│ ÖNERİ: Bu adımı ATLAYIN. Key zaten koddan kaldırıldı,       │
│ eski key'ler REVOKE edildi. History'deki eski key'ler       │
│ artık işlevsiz.                                             │
│                                                             │
│ ONAY: "PATTERN TEMİZLİĞİ ONAYLI" yazın                      │
│ ATLA: "PATTERN TEMİZLİĞİNİ ATLA" yazın (ÖNERİLEN)           │
└─────────────────────────────────────────────────────────────┘
```

### 3.5 Force Push

### 🛑 ONAY NOKTASI 3.3 - FORCE PUSH

```
┌─────────────────────────────────────────────────────────────┐
│ 🚨 FORCE PUSH GERİ ALINAMAZ!                                │
│                                                             │
│ Bu işlem:                                                   │
│ □ Remote repository'yi tamamen değiştirir                   │
│ □ Diğer geliştiricilerin force pull yapması gerekir         │
│ □ Eski commit hash'leri geçersiz olur                       │
│                                                             │
│ Kontrol listesi:                                            │
│ □ Backup branch remote'a push edildi mi?                    │
│ □ Fiziksel backup alındı mı?                                │
│ □ Tek geliştirici misiniz? (Takımda başkaları var mı?)      │
│                                                             │
│ ONAY: "FORCE PUSH ONAYLI" yazın                             │
│ ATLA: "FORCE PUSH ATLA" yazın (sonra yapılabilir)           │
└─────────────────────────────────────────────────────────────┘
```

**Onay sonrası (sadece onay verildiyse):**

```bash
# Mirror'dan original repo'ya push
cd /Users/sertaccokhamur/bir-adim-umut-mirror.git

# Önce remote'u kontrol et
git remote -v

# Force push
git push --force

# Original repo'yu güncelle
cd /Users/sertaccokhamur/bir-adim-umut
git fetch origin
git reset --hard origin/main
```

### ✅ ADIM 3 KONTROL NOKTASI

```
[ ] BFG kuruldu (veya atlandı)
[ ] Dosya temizliği yapıldı (veya atlandı)
[ ] Pattern temizliği yapıldı (veya atlandı - önerilen)
[ ] Force push yapıldı (veya atlandı)
```

**Hazır mısınız? → "ADIM 3 TAMAMLANDI" yazın**

---

## 📋 ADIM 4: YENİ KEYSTORE OLUŞTURMA (BUG-010)

### ⚠️ ÖN KONTROL: GOOGLE PLAY APP SIGNING

```
┌─────────────────────────────────────────────────────────────┐
│ ❓ GOOGLE PLAY APP SIGNING KULLANILIYOR MU?                 │
│                                                             │
│ Google Play Console'da kontrol edin:                        │
│ 1. https://play.google.com/console açın                     │
│ 2. Uygulamanızı seçin                                       │
│ 3. Release > Setup > App signing                            │
│                                                             │
│ "App signing by Google Play" yazıyorsa: ✅ KULLANILIYOR     │
│ Bu seçenek yoksa veya kapalıysa: ❌ KULLANILMIYOR           │
│                                                             │
│ CEVAP: "APP SIGNING KULLANILIYOR" veya                      │
│        "APP SIGNING KULLANILMIYOR" yazın                    │
└─────────────────────────────────────────────────────────────┘
```

### Senaryo A: App Signing KULLANILIYOR ✅

```
┌─────────────────────────────────────────────────────────────┐
│ ✅ DÜŞÜK RİSK                                               │
│                                                             │
│ Google Play App Signing kullanıyorsanız:                    │
│ - Upload key'inizi değiştirebilirsiniz                      │
│ - Google, uygulamayı kendi signing key'i ile imzalar        │
│ - Kullanıcılar güncelleme alabilir                          │
│                                                             │
│ Yeni keystore oluşturabilirsiniz.                           │
└─────────────────────────────────────────────────────────────┘
```

### Senaryo B: App Signing KULLANILMIYOR ❌

```
┌─────────────────────────────────────────────────────────────┐
│ 🚨 YÜKSEK RİSK!                                             │
│                                                             │
│ App Signing KULLANMIYORSANIZ:                               │
│ - Yeni keystore = YENİ UYGULAMA (Google Play'de)            │
│ - Mevcut kullanıcılar güncelleme ALAMAZ                     │
│ - Uygulama YENİDEN yayınlanmalı                             │
│ - Mevcut yorum/puan/indirme sayısı KAYBOLUR                 │
│                                                             │
│ ÖNERİLER:                                                   │
│ 1. Önce App Signing'i aktif edin (Google Play Console)      │
│ 2. Mevcut keystore'u kullanmaya devam edin                  │
│ 3. Sadece şifreyi güçlendirmek mümkün DEĞİL                 │
│                                                             │
│ KARAR: "KEYSTORE YENİLEMEYİ ATLA" veya                      │
│        "RİSKİ KABUL EDİYORUM, YENİLE" yazın                 │
└─────────────────────────────────────────────────────────────┘
```

### 4.1 Güçlü Şifre Belirleme (Onay sonrası)

Aşağıdaki kurallara uygun bir şifre belirleyin:

| Kural | Minimum | Örnek |
|-------|---------|-------|
| Uzunluk | 16 karakter | ✅ |
| Büyük harf | 1 adet | A-Z |
| Küçük harf | 1 adet | a-z |
| Rakam | 1 adet | 0-9 |
| Özel karakter | 1 adet | !@#$%^&* |

**⚠️ Şifrenizi GÜVENLİ bir yerde saklayın!** (Password manager önerilir)

### 4.2 Yeni Keystore Oluşturma

### 🛑 ONAY NOKTASI 4.1 - KEYSTORE OLUŞTURMA

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠️ KEYSTORE OLUŞTURMA ONAYI                                 │
│                                                             │
│ Kontrol listesi:                                            │
│ □ Google Play App Signing durumunu kontrol ettim            │
│ □ Riskleri anladım                                          │
│ □ Güçlü şifre belirledim ve güvenli yere kaydettim          │
│                                                             │
│ ONAY: "KEYSTORE OLUŞTUR" yazın                              │
│ ATLA: "KEYSTORE ADIMINI ATLA" yazın                         │
└─────────────────────────────────────────────────────────────┘
```

**Onay sonrası:**

```bash
# Android app dizinine git
cd /Users/sertaccokhamur/bir-adim-umut/android/app

# Yeni keystore oluştur
keytool -genkey -v -keystore hopesteps-release-v2.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias hopesteps \
  -dname "CN=HopeSteps, OU=Development, O=BirAdimUmut, L=Istanbul, ST=Istanbul, C=TR"

# Şifre sorulacak - belirlediğiniz güçlü şifreyi girin
```

### 4.3 key.properties Güncelleme

```bash
# Eski dosyayı yedekle
cp /Users/sertaccokhamur/bir-adim-umut/android/key.properties \
   /Users/sertaccokhamur/bir-adim-umut/android/key.properties.backup

# Yeni içeriği manuel düzenleyin:
# storePassword=GUCLU_SIFRENIZ
# keyPassword=GUCLU_SIFRENIZ
# keyAlias=hopesteps
# storeFile=app/hopesteps-release-v2.jks
```

### 4.4 .gitignore Kontrolü

```bash
# .gitignore'a ekle (yoksa)
echo "android/key.properties" >> /Users/sertaccokhamur/bir-adim-umut/.gitignore
echo "*.jks" >> /Users/sertaccokhamur/bir-adim-umut/.gitignore

# Git cache'den kaldır (tracking'i durdur)
git rm --cached android/key.properties 2>/dev/null || true
git rm --cached android/app/*.jks 2>/dev/null || true
```

### ✅ ADIM 4 KONTROL NOKTASI

```
[ ] Google Play App Signing durumu kontrol edildi
[ ] Keystore oluşturuldu (veya atlandı)
[ ] key.properties güncellendi (veya atlandı)
[ ] .gitignore güncellendi
```

**Hazır mısınız? → "ADIM 4 TAMAMLANDI" yazın**

---

## 📋 ADIM 5: DEPLOY VE TEST

### 5.1 Cloud Functions Deploy (Önerilen)

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

# Android build (yeni keystore ile - eğer oluşturulduysa)
flutter build apk --debug
```

### ✅ ADIM 5 KONTROL NOKTASI

```
[ ] Cloud Functions deploy edildi (veya atlandı)
[ ] Flutter iOS build başarılı
[ ] Flutter Android build başarılı
[ ] AdMob raporu test edildi (opsiyonel)
```

**Hazır mısınız? → "ADIM 5 TAMAMLANDI" yazın**

---

## ✅ FAZA 2 CHECKLIST

| # | İşlem | Durum | Onay Gerekli? |
|---|-------|-------|---------------|
| 1 | AdMob kodu güncellendi | ✅ Tamamlandı | Hayır |
| 2 | Local backup alındı | ⬜ | Hayır |
| 3 | Remote backup alındı | ⬜ | Hayır |
| 4 | Firebase Admin SDK key yenilendi | ⬜ | ✅ EVET |
| 5 | AdMob key yenilendi | ⬜ | ✅ EVET |
| 6 | Firebase functions config ayarlandı | ⬜ | Hayır |
| 7 | BFG ile dosya temizliği | ⬜ | ✅ EVET |
| 8 | BFG ile pattern temizliği | ⬜ (Opsiyonel) | ✅ EVET |
| 9 | Force push | ⬜ | ✅ EVET |
| 10 | Google Play App Signing kontrolü | ⬜ | Hayır |
| 11 | Yeni keystore oluşturuldu | ⬜ | ✅ EVET |
| 12 | key.properties güncellendi | ⬜ | Hayır |
| 13 | Cloud Functions deploy edildi | ⬜ | Hayır |
| 14 | Flutter build test edildi | ⬜ | Hayır |

---

## 🔄 FAZA 2 SONUÇ

### Tamamlandığında Yazın:

```
┌─────────────────────────────────────────────────────────────┐
│ FAZA 2 TAMAMLANDI - DEVAM?                                  │
│                                                             │
│ Tamamlanan adımlar:                                         │
│ □ ADIM 1: Backup                                            │
│ □ ADIM 2: Key yönetimi                                      │
│ □ ADIM 3: Git history (veya atlandı)                        │
│ □ ADIM 4: Keystore (veya atlandı)                           │
│ □ ADIM 5: Deploy & Test                                     │
│                                                             │
│ Yeni sorun/bug tespit edildi mi?                            │
│ □ HAYIR → FAZA 3'e geçilebilir                              │
│ □ EVET → Sorunları listeleyin, FAZA 2.1 olarak ele alınır   │
│                                                             │
│ DEVAM: "FAZA 2 TAMAMLANDI, FAZA 3 BAŞLASIN" yazın           │
└─────────────────────────────────────────────────────────────┘
```

---

## 📌 SONRAKİ ADIM: FAZA 3

FAZA 3 tamamlandığında başlayacak konular:

- **BUG-004:** Email verification eksik
- **BUG-006:** Hesap silme (Soft-delete, 30 gün retention)

**Soft-delete kararı:** EVET (30 gün retention) - Önceden onaylandı

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
- Keystore şifresi kurtarılamaz
- Yeni keystore oluşturulmalı
- Google Play App Signing varsa: Upload key değiştirilebilir
- App Signing yoksa: Yeni uygulama olarak yayınlanmalı

---

**Her adımda sorularınız için buradayım.**

*Rapor Sonu - v2.0*
