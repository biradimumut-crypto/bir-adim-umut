# 🔐 FAZA 2 - ADIM 2: KEY YÖNETİMİ (v2 - Güncellendi)

**Tarih:** 14 Ocak 2026  
**Durum:** DEVAM EDİYOR  
**Versiyon:** 2.0 (Kullanıcı netleştirmeleri uygulandı)

---

## ✅ TEYİT EDİLEN GÜVENLİK KONTROLLER

```
┌─────────────────────────────────────────────────────────────┐
│ serviceAccountKey.json GÜVENLİK DURUMU:                     │
│                                                             │
│ ✅ .gitignore'da VAR (satır 53)                             │
│ ✅ Git ignore kuralı AKTİF                                  │
│ ✅ Git'te tracked DEĞİL                                     │
│ ✅ Bu dosya Git'e ASLA GİRMEYECEK                           │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚠️ ÖNEMLİ KURALLAR

```
┌─────────────────────────────────────────────────────────────┐
│ 🛑 ESKİ KEY SİLME KURALI:                                   │
│                                                             │
│ Eski key'ler ANCAK aşağıdaki koşullar sağlandığında         │
│ silinebilir:                                                │
│                                                             │
│ □ Yeni key oluşturuldu                                      │
│ □ Config ayarlandı                                          │
│ □ Deploy BAŞARILI                                           │
│ □ Log doğrulaması TAMAMLANDI                                │
│ □ KULLANICI ONAYI ALINDI                                    │
│                                                             │
│ Bu koşullar sağlanmadan ESKİ KEY SİLİNMEYECEK!              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 ADIM 2.1: Firebase Admin SDK Key Oluşturma

### Manuel Adımlar:

1. **Firebase Console'u aç:** https://console.firebase.google.com

2. **Proje seç:** `bir-adim-umut-yeni`

3. **⚙️ Project settings** → **Service accounts** sekmesi

4. **"Generate new private key"** butonuna tıkla

5. **"Generate key"** onaylayın

6. JSON dosyası otomatik indirilecek

> ℹ️ "Generate new private key" eski key'i SİLMEZ, yeni key EKLER.  
> Eski key silme için ayrıca ONAY istenecek.

### İndirilen Dosyayı Taşıma:

```bash
# Proje dizinine git
cd ~/bir-adim-umut

# İndirilen dosyayı taşı (dosya adını güncelleyin)
mv ~/Downloads/bir-adim-umut-yeni-firebase-adminsdk-*.json ./serviceAccountKey.json

# Doğrula
head -5 ./serviceAccountKey.json
```

### Beklenen Çıktı:
```json
{
  "type": "service_account",
  "project_id": "bir-adim-umut-yeni",
  ...
}
```

### Git Kontrolü (Opsiyonel):
```bash
# Dosyanın Git'e girmediğini doğrula
git status | grep serviceAccountKey || echo "✅ serviceAccountKey.json Git'te görünmüyor"
```

---

## 📋 ADIM 2.2: AdMob Key Oluşturma

### Manuel Adımlar:

1. **Google Cloud Console:** https://console.cloud.google.com

2. **Proje seç:** `bir-adim-umut-yeni`

3. Sol menüden **IAM & Admin** → **Service Accounts**

4. `admob-reporter@bir-adim-umut-yeni.iam.gserviceaccount.com` hesabını bul

5. Hesaba tıkla → **KEYS** sekmesi

6. **ADD KEY** → **Create new key** → **JSON** → **CREATE**

7. Dosya otomatik indirilecek

> ℹ️ Eski key şimdilik SİLİNMEYECEK. Deploy doğrulaması sonrası ayrıca onay istenecek.

### Firebase Functions Config Ayarlama:

```bash
# Functions dizinine git
cd ~/bir-adim-umut/firebase_functions/functions

# İndirilen AdMob key dosyasını base64'e çevir ve config'e ekle
# ⚠️ Dosya adını indirilen dosyaya göre güncelleyin
firebase functions:config:set admob.credentials="$(cat ~/Downloads/admob-reporter-*.json | base64)"

# Doğrula
firebase functions:config:get
```

### Beklenen Çıktı:
```json
{
  "admob": {
    "credentials": "eyJ0eXBlIjoic2VydmljZV9hY2NvdW50Ii..."
  }
}
```

---

## 📋 ADIM 2.3: Deploy ve Doğrulama

### Cloud Functions Build & Deploy:

```bash
# Functions dizinine git
cd ~/bir-adim-umut/firebase_functions/functions

# Build et
npm run build

# Deploy et
firebase deploy --only functions
```

### Log Doğrulaması:

```bash
# Deploy sonrası log kontrol (birkaç dakika bekleyin)
firebase functions:log --only fetchAdMobRevenue

# Veya tüm functions logları
firebase functions:log
```

### Flutter Build Test:

```bash
# Proje dizinine git
cd ~/bir-adim-umut

# iOS build
flutter build ios --debug

# Android build
flutter build apk --debug
```

---

## ✅ ADIM 2 CHECKLIST

### Yeni Key Oluşturma:

| # | İşlem | Durum |
|---|-------|-------|
| 1 | Firebase Admin SDK key oluşturuldu | ⬜ |
| 2 | serviceAccountKey.json güncellendi | ⬜ |
| 3 | AdMob key oluşturuldu | ⬜ |
| 4 | Firebase functions config ayarlandı | ⬜ |

### Deploy & Doğrulama:

| # | İşlem | Durum |
|---|-------|-------|
| 5 | npm run build BAŞARILI | ⬜ |
| 6 | firebase deploy BAŞARILI | ⬜ |
| 7 | Log doğrulaması TAMAMLANDI | ⬜ |
| 8 | Flutter build test BAŞARILI | ⬜ |

### Eski Key Silme (AYRI ONAY GEREKLİ):

| # | İşlem | Durum |
|---|-------|-------|
| 9 | Eski Firebase key silme | ⏸️ ONAY BEKLİYOR |
| 10 | Eski AdMob key silme | ⏸️ ONAY BEKLİYOR |

---

## 🎯 TAMAMLANDIĞINDA

### Adım 1-8 tamamlandığında:
```
"KEY OLUŞTURMA VE DEPLOY TAMAMLANDI"
```

### Eski key silme onayı için (ayrıca sorulacak):
```
"ESKİ KEY'LER SİLİNEBİLİR"
```

---

## ⚠️ SORUN GİDERME

### Problem: firebase functions:config:set çalışmıyor

```bash
# Firebase CLI giriş kontrolü
firebase login:list

# Yeniden giriş yap
firebase login --reauth
```

### Problem: npm run build hata veriyor

```bash
# Node modules temizle ve yeniden kur
cd ~/bir-adim-umut/firebase_functions/functions
rm -rf node_modules
npm install
npm run build
```

### Problem: Deploy sonrası function çalışmıyor

```bash
# Config'i local'e al (emulator için)
firebase functions:config:get > .runtimeconfig.json

# Logs kontrol
firebase functions:log
```

---

*Rehber Sonu - v2.0*
