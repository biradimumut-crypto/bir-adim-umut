# 🗺️ YOL HARİTASI VE ÇAKIŞMA ANALİZİ v1.1

**Tarih:** 14 Ocak 2026  
**Hazırlayan:** GitHub Copilot (Claude Opus 4.5)  
**Referans:** DERINLEMESINE_ANALIZ_RAPORU.md (78+ Tespit)  
**Versiyon:** 1.1 (Revize Edildi)

---

## 📝 v1.1 REVİZYON NOTLARI

| # | Revizyon | Gerekçe |
|---|----------|---------|
| 1️⃣ | FAZA 6 (BUG-008) → FAZA 4'e taşındı | Transaction, Rules ve App Check bağımlılığı |
| 2️⃣ | FAZA 3'e BLOCKER eklendi | BUG-006 soft-delete kararı zorunlu |
| 3️⃣ | FAZA 4'e Cloud Functions listesi eklendi | Sessiz function hatalarını önlemek |
| 4️⃣ | FAZA 1'e PRE-CHECK eklendi | Eksik değişiklik riskini azaltmak |

---

## 📋 İÇİNDEKİLER

1. [Tespit Edilen Bağımlılıklar ve Çakışmalar](#-tespit-edilen-bağımlılıklar-ve-çakışmalar)
2. [Önerilen Uygulama Sırası (6 Faz)](#-önerilen-uygulama-sirasi-6-faz)
3. [Kritik Uyarılar](#️-kritik-uyarilar)
4. [Onay Formatı](#-onay-formati)

---

## 🔗 TESPİT EDİLEN BAĞIMLILIKLAR VE ÇAKIŞMALAR

### GRUP A: Bildirim Sistemi (3 Sorun - BİRLİKTE ÇÖZÜLMELI)

| Sorun | Açıklama | Bağımlılık |
|-------|----------|-----------|
| **BUG-001** | Path uyumsuzluğu (`notifications` vs `users/{uid}/notifications`) | → BUG-002'ye bağlı |
| **BUG-002** | Field isimleri (`type` vs `notification_type`) | → BUG-001 ile eşzamanlı |
| **DATA-004** | Index tutarsızlığı | → BUG-002 sonrası güncellenecek |

**⚠️ Çakışma Riski:**
- Path'i düzeltip field isimlerini düzeltmezsek → yine çalışmaz
- Field isimlerini düzeltip index'i güncellemezzsek → sorgu hatası

---

### GRUP B: Theme Sistemi (2 Sorun - BİRLİKTE ÇÖZÜLMELI)

| Sorun | Açıklama | Bağımlılık |
|-------|----------|-----------|
| **BUG-007** | ThemeProvider MultiProvider'da eksik | → DATA-003'e bağlı |
| **DATA-003** | `theme_preference` field kullanılmıyor | → BUG-007 sonrası aktif olacak |

**⚠️ Çakışma Riski:**
- ThemeProvider'ı ekleyip `theme_preference`'ı okumaz/yazmazsak → işlevsiz kalır

---

### GRUP C: Firestore Rules + Transaction (4 Sorun - BİRLİKTE ÇÖZÜLMELI) ⚡ v1.1 GÜNCELLENDİ

| Sorun | Açıklama | Bağımlılık |
|-------|----------|-----------|
| **BUG-008** | Bağış transaction eksik | → Rules değişikliğiyle birlikte |
| **BUG-011** | `activity_logs` write açık | → SEC-001, SEC-002, BUG-008 ile birlikte |
| **SEC-001** | `daily_steps` write açık | → BUG-011 ile birlikte |
| **SEC-002** | `team_members` herkes ekleyebilir | → BUG-011 ile birlikte |

**⚠️ Çakışma Riski:**
- Transaction düzeltilmeden Rules sıkılaştırılırsa → Bağış işlemleri bozulur
- Rules sıkılaştırılıp transaction düzeltilmezse → Veri tutarsızlığı devam eder
- **BU NEDENLE BUG-008, FAZA 4'E TAŞINDI** ⚡

---

### GRUP D: Güvenlik Credentials (3 Sorun - MANUEL İŞLEM)

| Sorun | Açıklama | Aksiyon |
|-------|----------|---------|
| **BUG-003** | AdMob private key açıkta | Google Cloud'dan REVOKE + Git history temizle |
| **BUG-009** | `serviceAccountKey.json` Git'te | Google Cloud'dan REVOKE + Git history temizle |
| **BUG-010** | Zayıf keystore şifresi | Yeni güçlü keystore oluştur |

**⚠️ DİKKAT:** Bu işlemler KOD DEĞİŞİKLİĞİ DEĞİL, manuel Google Cloud Console + git işlemleri gerektirir.

---

### BAĞIMSIZ SORUNLAR (Tek başına çözülebilir)

| Sorun | Açıklama | Bağımsız mı? |
|-------|----------|-------------|
| **BUG-004** | Email verification eksik | ✅ Bağımsız |
| **BUG-005** | App Check debug modda | ✅ Bağımsız |
| **BUG-006** | Hesap silme özelliği eksik (GDPR/Apple) | ✅ Bağımsız |
| **BUG-012** | `main_new.dart` kullanılmıyor | ✅ Bağımsız |

---

## 📋 ÖNERİLEN UYGULAMA SIRASI (6 FAZ)

### FAZA 1: BİLDİRİM SİSTEMİ 🔴 (En Kritik - Sistem Çalışmıyor)

#### 🔍 PRE-CHECK (FAZA 1 ÖNCESİ ZORUNLU) ⚡ v1.1 YENİ

```
┌─────────────────────────────────────────────────────────┐
│ ❓ FAZA 1 BAŞLAMADAN ÖNCE KONTROL EDİLECEKLER:          │
│                                                         │
│ □ Notification path sabitleri var mı?                   │
│   → Const/enum olarak tanımlı mı?                       │
│   → Yoksa tüm magic string'ler listelenecek             │
│                                                         │
│ □ Field name const kullanılıyor mu?                     │
│   → 'notification_type', 'notification_status'          │
│   → Const yoksa manuel değişiklik sayısı belirlenmeli   │
│                                                         │
│ □ Magic string olan yerler:                             │
│   → teams_screen.dart: 14 yer                           │
│   → notifications_page.dart: 4 yer                      │
│   → Toplam: 18 değişiklik noktası                       │
│                                                         │
│ ⚠️ BU KONTROL TAMAMLANMADAN KOD YAZILMAYACAK            │
└─────────────────────────────────────────────────────────┘
```

#### 1.1 Ana Değişiklikler

```
┌─────────────────────────────────────────────────────────┐
│ 1.1 BUG-001 + BUG-002 (BERABER)                         │
│     → notifications path + field isimleri               │
│                                                         │
│     Dosyalar:                                           │
│     - lib/screens/teams/teams_screen.dart               │
│     - lib/screens/notifications/notifications_page.dart │
│                                                         │
│ 1.2 DATA-004 (HEMEN ARDINDAN)                          │
│     → firestore.indexes.json güncelle                   │
└─────────────────────────────────────────────────────────┘
```

| Özellik | Değer |
|---------|-------|
| **Risk Seviyesi** | 🟢 DÜŞÜK |
| **Etki Alanı** | Sadece bildirim sistemi |
| **Rollback** | Kolay |
| **Tahmini Süre** | 3 saat |

---

### FAZA 2: GÜVENLİK CREDENTIALS 🔴 (Manuel - Kod Yok)

```
┌─────────────────────────────────────────────────────────┐
│ 2.1 BUG-003 + BUG-009                                   │
│     → Google Cloud Console'dan key'leri REVOKE et       │
│     → git filter-branch veya BFG ile history temizle    │
│     → .gitignore kontrolü                               │
│                                                         │
│ 2.2 BUG-010                                            │
│     → Yeni güçlü keystore oluştur (min 16 karakter)     │
└─────────────────────────────────────────────────────────┘
```

| Özellik | Değer |
|---------|-------|
| **Risk Seviyesi** | 🔴 YÜKSEK |
| **Etki Alanı** | Tüm Firebase/AdMob erişimi |
| **Rollback** | Yeni key ile devam |
| **Tahmini Süre** | 1.5 saat |

**⚠️ UYARI:** Yanlış yapılırsa production bozulur. MANUEL ve DİKKATLİ yapılmalı.

---

### FAZA 3: AUTH & LEGAL 🔴 (Apple/Google Store Gereksinimi)

#### 🚫 BLOCKER: KARAR GEREKLİ ⚡ v1.1 YENİ

```
┌─────────────────────────────────────────────────────────┐
│ ⛔ FAZA 3 BAŞLAMADAN ÖNCE AŞAĞIDAKI KARAR KİLİTLENMELİ: │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ BUG-006 HESAP SİLME POLİCY'Sİ                       │ │
│ │                                                     │ │
│ │ Soft Delete: [ ] EVET  [ ] HAYIR                    │ │
│ │                                                     │ │
│ │ Eğer EVET:                                          │ │
│ │   Retention Süresi: [ ] 30 gün  [ ] ___ gün         │ │
│ │   Scheduled Job: Gerekli (Cloud Function)           │ │
│ │                                                     │ │
│ │ Eğer HAYIR:                                         │ │
│ │   Silme Tipi: Hard Delete (Anında)                  │ │
│ │   Geri Dönüş: Yok                                   │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ⚠️ BU KARAR VERİLMEDEN FAZA 3 BAŞLATILMAYACAK          │
└─────────────────────────────────────────────────────────┘
```

#### 3.1 Ana Değişiklikler

```
┌─────────────────────────────────────────────────────────┐
│ 3.1 BUG-004 (Email verification)                        │
│     → lib/services/auth_service.dart                    │
│     → signIn metoduna emailVerified kontrolü ekle       │
│                                                         │
│ 3.2 BUG-006 (Hesap silme - GDPR/Apple)                 │
│     → lib/screens/profile/profile_screen.dart           │
│       - "Hesabı Sil" butonu ekle                        │
│     → lib/services/auth_service.dart                    │
│       - deleteAccount metodu ekle                       │
│     → Cloud Function (soft-delete EVET ise)             │
│       - scheduledUserCleanup fonksiyonu                 │
└─────────────────────────────────────────────────────────┘
```

| Özellik | Değer |
|---------|-------|
| **Risk Seviyesi** | 🟡 ORTA |
| **Etki Alanı** | Auth flow |
| **Rollback** | Kolay |
| **Tahmini Süre** | 7 saat (soft-delete: +3 saat) |

**Silinecek Veriler (BUG-006):**
```
- users/{uid}                    → Ana kullanıcı dokümanı
- users/{uid}/notifications/*    → Tüm bildirimler
- users/{uid}/badges/*           → Kazanılan rozetler
- team_members (user_uid == uid) → Takım üyelikleri
- activity_logs (user_uid == uid)→ Aktivite geçmişi
- daily_steps (user_uid == uid)  → Günlük adım kayıtları
```

---

### FAZA 4: APP SECURITY + VERİ BÜTÜNLÜĞÜ 🔴 ⚡ v1.1 BİRLEŞTİRİLDİ

#### Birleştirme Gerekçesi ⚡ v1.1 YENİ

```
┌─────────────────────────────────────────────────────────┐
│ 🔗 NEDEN BUG-008 FAZA 4'E TAŞINDI?                      │
│                                                         │
│ 1. Transaction işlemleri Firestore Rules tarafından     │
│    kontrol edilir                                       │
│                                                         │
│ 2. Rules sıkılaştırılıp transaction düzeltilmezse:      │
│    → Bağış işlemi batch.commit() başarılı olur          │
│    → Ardından gelen update() Rules tarafından ENGELLENİR│
│    → Sonuç: Bakiye düşer ama istatistik güncellenmez    │
│                                                         │
│ 3. App Check aktifken transaction'ların da token        │
│    doğrulaması gerekir                                  │
│                                                         │
│ 4. ATOMİK DEĞİŞİKLİK PRENSİBİ:                          │
│    İlişkili güvenlik değişiklikleri TEK FAZA'da olmalı  │
└─────────────────────────────────────────────────────────┘
```

#### 4.1 Ana Değişiklikler

```
┌─────────────────────────────────────────────────────────┐
│ 4.1 BUG-005 (App Check production)                      │
│     → lib/main.dart                                     │
│     → debug → deviceCheck/playIntegrity                 │
│                                                         │
│ 4.2 BUG-008 (Bağış transaction) ⚡ TAŞINDI              │
│     → lib/screens/charity/charity_screen.dart           │
│     → WriteBatch → runTransaction                       │
│                                                         │
│ 4.3 BUG-011 + SEC-001 + SEC-002 (BERABER)              │
│     → firestore.rules: Tek seferde güncelle             │
│     → activity_logs: create kaldır/kısıtla              │
│     → daily_steps: write kısıtla                        │
│     → team_members: create kısıtla                      │
└─────────────────────────────────────────────────────────┘
```

#### Etkilenen Cloud Functions ⚡ v1.1 YENİ

```
┌─────────────────────────────────────────────────────────┐
│ ☁️ FIRESTORE RULES DEĞİŞİKLİĞİNDEN ETKİLENEBİLECEK     │
│    CLOUD FUNCTIONS:                                     │
│                                                         │
│ ┌─────────────────┬────────────────────────────────────┐│
│ │ Function        │ Etki Durumu                        ││
│ ├─────────────────┼────────────────────────────────────┤│
│ │ onStepWrite     │ ⚠️ daily_steps rules değişirse     ││
│ │                 │    Admin SDK kullanıyorsa: ETKİSİZ ││
│ │                 │    Client context: ETKİLENİR       ││
│ ├─────────────────┼────────────────────────────────────┤│
│ │ onTeamJoin      │ ⚠️ team_members rules değişirse    ││
│ │                 │    Trigger context kontrol edilmeli││
│ ├─────────────────┼────────────────────────────────────┤│
│ │ onDonationCreate│ ⚠️ activity_logs rules değişirse   ││
│ │                 │    Donation log yazımı etkilenir   ││
│ ├─────────────────┼────────────────────────────────────┤│
│ │ monthlyHope     │ ✅ Admin SDK - ETKİLENMEZ          ││
│ │ Calculator      │                                    ││
│ ├─────────────────┼────────────────────────────────────┤│
│ │ sendNotification│ ✅ Admin SDK - ETKİLENMEZ          ││
│ └─────────────────┴────────────────────────────────────┘│
│                                                         │
│ ⚠️ Rules deploy'u ÖNCE, Functions test'i SONRA yapılmalı│
└─────────────────────────────────────────────────────────┘
```

#### Edge Cases (BUG-008)

```
┌─────────────────────────────────────────────────────────┐
│ 🧪 TEST EDİLMESİ GEREKEN SENARYOLAR:                    │
│                                                         │
│ 1. Network hatası mid-transaction                       │
│    → Transaction otomatik rollback yapmalı              │
│                                                         │
│ 2. Concurrent bağış işlemleri                           │
│    → Aynı anda 2 bağış: race condition testi            │
│                                                         │
│ 3. Yetersiz bakiye kontrolü                             │
│    → Transaction içinde bakiye kontrolü                 │
│    → Negatif bakiye önlenmeli                           │
│                                                         │
│ 4. Charity max_amount aşımı                             │
│    → Hedef tutarı aşan bağış engellenmeli               │
└─────────────────────────────────────────────────────────┘
```

| Özellik | Değer |
|---------|-------|
| **Risk Seviyesi** | 🟡 ORTA |
| **Etki Alanı** | API güvenliği, Database erişimi, Bağış işlemleri |
| **Rollback** | Rules geri alınabilir, transaction eski haline dönülebilir |
| **Tahmini Süre** | 6 saat (eski 4+2=6) |

**⚠️ UYARI:** App Check yanlış yapılırsa API erişimi kesilir. Önce staging'de test edin.

---

### FAZA 5: THEME SİSTEMİ 🟠

```
┌─────────────────────────────────────────────────────────┐
│ 5.1 BUG-007 + DATA-003 (BERABER)                        │
│     → lib/main.dart                                     │
│       - MultiProvider'a ThemeProvider ekle              │
│     → MaterialApp                                       │
│       - theme'i Consumer ile sarma                      │
│     → lib/screens/profile/profile_screen.dart           │
│       - Tema değiştirme UI ekle                         │
└─────────────────────────────────────────────────────────┘
```

| Özellik | Değer |
|---------|-------|
| **Risk Seviyesi** | 🟢 DÜŞÜK |
| **Etki Alanı** | UI/UX |
| **Rollback** | Çok kolay |
| **Tahmini Süre** | 2 saat |

---

### FAZA 6: DEAD CODE TEMİZLİĞİ 🟢

```
┌─────────────────────────────────────────────────────────┐
│ 6.1 BUG-012                                            │
│     → lib/main_new.dart sil                             │
│                                                         │
│ 6.2 CODE-005                                           │
│     → lib/screens/dashboard/dashboard_screen_backup.dart│
│     → lib/screens/dashboard/dashboard_screen_new.dart   │
│     → lib/screens/dashboard/dashboard_screen_orig.dart  │
│     → lib/screens/dashboard/dashboard_screen_recovered.dart│
│     → lib/screens/dashboard/dashboard_screen_simple.dart│
└─────────────────────────────────────────────────────────┘
```

| Özellik | Değer |
|---------|-------|
| **Risk Seviyesi** | 🟢 ÇOK DÜŞÜK |
| **Etki Alanı** | Yok (kullanılmayan dosyalar) |
| **Rollback** | Git history'den geri alınabilir |
| **Tahmini Süre** | 30 dakika |

---

## ⚠️ KRİTİK UYARILAR

### 1. Bildirim Sistemi Değişikliği (FAZA 1)

**Mevcut Durum:**
```dart
// YANLIŞ - Flutter Screens
.collection('notifications')
.where('type', isEqualTo: 'team_invite')
.where('status', isEqualTo: 'pending')
```

**Olması Gereken:**
```dart
// DOĞRU
.collection('users').doc(uid).collection('notifications')
.where('notification_type', isEqualTo: 'team_invite')
.where('notification_status', isEqualTo: 'pending')
```

**Etkilenen Dosyalar:**
| Dosya | Değişiklik Sayısı |
|-------|-------------------|
| `teams_screen.dart` | 14 yer |
| `notifications_page.dart` | 4 yer |
| `firestore.indexes.json` | Index güncelleme |

**Cloud Functions:** Zaten doğru path kullanıyor ✅

---

### 2. Firestore Rules + Transaction Değişikliği (FAZA 4) ⚡ v1.1 GÜNCELLENDİ

**Değişecek Kurallar:**
```javascript
// activity_logs: create kaldırılacak veya kısıtlanacak
// daily_steps: write kısıtlanacak  
// team_members: create kısıtlanacak
```

**Transaction Değişikliği:**
```dart
// ÖNCE (Tehlikeli)
await batch.commit();
await firestore.collection('users').doc(uid).update({...}); // ❌ Atomik değil

// SONRA (Güvenli)
await firestore.runTransaction((transaction) async {
  // Tüm işlemler tek transaction içinde ✅
});
```

**Etkilenen Ekranlar:**
- Dashboard (adım kaydetme)
- Teams (üye ekleme)
- Leaderboard (activity log)
- Charity (bağış işlemi) ⚡ v1.1 EKLENDİ

**Etkilenen Cloud Functions:** ⚡ v1.1 EKLENDİ
- `onStepWrite` - daily_steps trigger
- `onTeamJoin` - team_members trigger
- `onDonationCreate` - activity_logs trigger

---

### 3. Hesap Silme (FAZA 3 - BUG-006)

**Silinecek Koleksiyonlar:**
```
users/{uid}                    → Ana kullanıcı dokümanı
users/{uid}/notifications/*    → Tüm bildirimler
users/{uid}/badges/*           → Kazanılan rozetler
team_members (user_uid == uid) → Takım üyelikleri
activity_logs (user_uid == uid)→ Aktivite geçmişi
daily_steps (user_uid == uid)  → Günlük adım kayıtları
```

**Policy Karşılaştırması:** ⚡ v1.1 GÜNCELLENDİ

| Özellik | Hard Delete | Soft Delete (30 gün) |
|---------|-------------|----------------------|
| **Implementasyon** | Basit | Karmaşık |
| **Geri Dönüş** | ❌ Yok | ✅ 30 gün içinde |
| **Cloud Function** | Opsiyonel | Zorunlu (scheduled) |
| **Storage** | Anında temiz | 30 gün ekstra |
| **GDPR Uyumu** | ✅ Tam | ✅ Tam |
| **UX** | ⚠️ Riskli | ✅ Kullanıcı dostu |

---

## 📊 ÖZET TABLO ⚡ v1.1 GÜNCELLENDİ

| Faz | İçerik | Risk | Süre | Öncelik |
|-----|--------|------|------|---------|
| **1** | Bildirim Sistemi + PRE-CHECK | 🟢 Düşük | 3 saat | 🔴 Kritik |
| **2** | Credentials (Manuel) | 🔴 Yüksek | 1.5 saat | 🔴 Kritik |
| **3** | Auth & Legal + BLOCKER | 🟡 Orta | 7-10 saat | 🔴 Kritik |
| **4** | App Security + Transaction + Rules | 🟡 Orta | 6 saat | 🔴 Kritik |
| **5** | Theme Sistemi | 🟢 Düşük | 2 saat | 🟠 Yüksek |
| **6** | Dead Code | 🟢 Çok Düşük | 0.5 saat | 🟢 Düşük |

**Toplam Tahmini Süre:** ~20-23 saat

---

## ✅ ONAY FORMATI ⚡ v1.1 GÜNCELLENDİ

Aşağıdaki formatı kullanarak onay verin:

```
ONAY: [FAZA numarası]
Soft-delete: [EVET/HAYIR] (FAZA 3 için ZORUNLU)
Retention: [30 gün / 0 gün] (Soft-delete EVET ise)
Credentials: [REHBER/KOMUT]
Başlangıç: [EVET]
```

**Örnek:**
```
ONAY: FAZA 1
Soft-delete: HAYIR
Retention: 0 gün
Credentials: REHBER
Başlangıç: EVET
```

---

## 📝 NOTLAR

1. Her faz tamamlandığında **"DEVAM"** onayı beklenecek
2. Kod değişiklikleri **küçük, izole ve rollback-safe** olacak
3. Mevcut mimari **KORUNACAK**
4. Her değişiklik için **test senaryoları** belirtilecek
5. ⚡ **v1.1:** PRE-CHECK ve BLOCKER'lar atlanmayacak

---

## 🔄 VERSİYON GEÇMİŞİ

| Versiyon | Tarih | Değişiklikler |
|----------|-------|---------------|
| v1.0 | 14 Ocak 2026 | İlk versiyon |
| v1.1 | 14 Ocak 2026 | FAZA 4+6 birleştirildi, PRE-CHECK eklendi, BLOCKER eklendi, Cloud Functions listesi eklendi |

---

**Rapor Sonu**

*Bu yol haritası, DERINLEMESINE_ANALIZ_RAPORU.md'deki 78+ tespitin güvenli ve sistematik şekilde çözülmesi için hazırlanmıştır.*
