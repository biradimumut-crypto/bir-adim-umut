# 🔐 FAZA 2 - ADIM 2: KEY YÖNETİMİ UYGULAMA REHBERİ

**Tarih:** 14 Ocak 2026  
**Durum:** DEVAM EDİYOR  
**Onay:** Firebase Admin SDK Key ✅ | AdMob Key ✅

---

## ✅ ONAYLAR

```
┌─────────────────────────────────────────────────────────────┐
│ KULLANICI ONAYI:                                            │
│                                                             │
│ ✅ Firebase Admin SDK Key: "ESKİ KEY SİLİNEBİLİR"           │
│ ✅ AdMob Key: "ADMOB KEY SİLİNEBİLİR"                       │
│                                                             │
│ ŞARTLAR:                                                    │
│ • Yeni riskli adım çıkarsa DUR ve ONAY iste                 │
│ • FAZA 2 kapsamında çözülebilen problemler çözülsün         │
│ • Yeni bug tespit edilirse FAZA 2 içinde ele alınsın        │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 ADIM 2.1: Firebase Admin SDK Key

### Manuel Adımlar:

1. **Firebase Console'u aç:** https://console.firebase.google.com

2. **Proje seç:** `bir-adim-umut-yeni`

3. **⚙️ Project settings** → **Service accounts** sekmesi

4. **"Generate new private key"** butonuna tıkla

5. **"Generate key"** onaylayın

6. JSON dosyası otomatik indirilecek

### Eski Key'i Silme (Opsiyonel ama Önerilen):

> ⚠️ "Generate new private key" eski key'i SİLMEZ, yeni key EKLER.
> Eski key'i silmek için Google Cloud Console'a gitmeniz gerekir.

1. Firebase Console'da **"Manage service account permissions"** linkine tıkla
2. Google Cloud Console açılacak
3. Service account'a tıkla → **KEYS** sekmesi
4. Eski key'i **DELETE** et

### İndirilen Dosyayı Taşıma:

```bash
# İndirilen dosyayı proje dizinine taşı
# NOT: Dosya adını indirilen dosyaya göre güncelleyin
mv ~/Downloads/bir-adim-umut-yeni-*.json /Users/sertaccokhamur/bir-adim-umut/serviceAccountKey.json

# Doğrula
cat /Users/sertaccokhamur/bir-adim-umut/serviceAccountKey.json | head -5
```

### Beklenen Çıktı:
```json
{
  "type": "service_account",
  "project_id": "bir-adim-umut-yeni",
  ...
}
```

---

## 📋 ADIM 2.2: AdMob Key

### Manuel Adımlar:

1. **Google Cloud Console:** https://console.cloud.google.com

2. **Proje seç:** `bir-adim-umut-yeni`

3. Sol menüden **IAM & Admin** → **Service Accounts**

4. `admob-reporter@bir-adim-umut-yeni.iam.gserviceaccount.com` hesabını bul

5. Hesaba tıkla → **KEYS** sekmesi

6. **ADD KEY** → **Create new key** → **JSON** → **CREATE**

7. Dosya otomatik indirilecek

8. (Opsiyonel) Eski key'i **DELETE** et

### Firebase Functions Config Ayarlama:

```bash
# Firebase functions dizinine git
cd /Users/sertaccokhamur/bir-adim-umut/firebase_functions/functions

# Config ayarla
# ⚠️ [DOSYA_ADI] kısmını indirilen dosya adıyla değiştirin
firebase functions:config:set admob.credentials="$(cat ~/Downloads/[DOSYA_ADI].json | base64)"

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

## 📋 ADIM 2.3: Doğrulama ve Deploy

### Cloud Functions Build & Deploy:

```bash
# Functions dizinine git
cd /Users/sertaccokhamur/bir-adim-umut/firebase_functions/functions

# Build et
npm run build

# Deploy et
firebase deploy --only functions

# Log kontrol (birkaç dakika bekleyin)
firebase functions:log --only fetchAdMobRevenue
```

### Flutter Build Test:

```bash
# Proje dizinine git
cd /Users/sertaccokhamur/bir-adim-umut

# iOS build
flutter build ios --debug

# Android build
flutter build apk --debug
```

---

## ✅ ADIM 2 CHECKLIST

| # | İşlem | Durum |
|---|-------|-------|
| 1 | Firebase Admin SDK key oluşturuldu | ⬜ |
| 2 | serviceAccountKey.json güncellendi | ⬜ |
| 3 | (Opsiyonel) Eski Firebase key silindi | ⬜ |
| 4 | AdMob key oluşturuldu | ⬜ |
| 5 | Firebase functions config ayarlandı | ⬜ |
| 6 | (Opsiyonel) Eski AdMob key silindi | ⬜ |
| 7 | Cloud Functions deploy edildi | ⬜ |
| 8 | Flutter build test edildi | ⬜ |

---

## 🎯 TAMAMLANDIĞINDA

Tüm adımlar tamamlandığında yazın:

```
"KEY YENİLEME TAMAMLANDI"
```

Sorun yaşarsanız bildirin, yardımcı olurum.

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
cd /Users/sertaccokhamur/bir-adim-umut/firebase_functions/functions
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

*Rehber Sonu*
