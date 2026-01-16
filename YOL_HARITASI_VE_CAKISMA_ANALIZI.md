# 🗺️ YOL HARİTASI VE ÇAKIŞMA ANALİZİ

**Tarih:** 14 Ocak 2026  
**Hazırlayan:** GitHub Copilot (Claude Opus 4.5)  
**Referans:** DERINLEMESINE_ANALIZ_RAPORU.md (78+ Tespit)

---

## 📋 İÇİNDEKİLER

1. [Tespit Edilen Bağımlılıklar ve Çakışmalar](#-tespit-edilen-bağımlılıklar-ve-çakışmalar)
2. [Önerilen Uygulama Sırası (7 Faz)](#-önerilen-uygulama-sirasi)
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

### GRUP C: Firestore Rules (3 Sorun - BİRLİKTE ÇÖZÜLMELI)

| Sorun | Açıklama | Bağımlılık |
|-------|----------|-----------|
| **BUG-011** | `activity_logs` write açık | → SEC-001, SEC-002 ile birlikte |
| **SEC-001** | `daily_steps` write açık | → BUG-011 ile birlikte |
| **SEC-002** | `team_members` herkes ekleyebilir | → BUG-011 ile birlikte |

**⚠️ Çakışma Riski:**
- Tek tek değiştirmek yerine `firestore.rules` dosyasını BİR DEFADA güncellemek gerekli
- Aksi halde her deploy'da farklı kurallar çakışabilir

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
| **BUG-008** | Bağış işleminde transaction yok | ✅ Bağımsız |
| **BUG-012** | `main_new.dart` kullanılmıyor | ✅ Bağımsız |

---

## 📋 ÖNERİLEN UYGULAMA SIRASI

### FAZA 1: BİLDİRİM SİSTEMİ 🔴 (En Kritik - Sistem Çalışmıyor)

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
│     → Cloud Function (opsiyonel)                        │
│       - Tüm user verisini cascade delete                │
└─────────────────────────────────────────────────────────┘
```

| Özellik | Değer |
|---------|-------|
| **Risk Seviyesi** | 🟡 ORTA |
| **Etki Alanı** | Auth flow |
| **Rollback** | Kolay |
| **Tahmini Süre** | 7 saat |

**Silinecek Veriler (BUG-006):**
```
- users/{uid}
- users/{uid}/notifications/*
- users/{uid}/badges/*
- team_members where user_uid == uid
- activity_logs where user_uid == uid
- daily_steps where user_uid == uid
```

---

### FAZA 4: APP SECURITY 🔴

```
┌─────────────────────────────────────────────────────────┐
│ 4.1 BUG-005 (App Check production)                      │
│     → lib/main.dart                                     │
│     → debug → deviceCheck/playIntegrity                 │
│                                                         │
│ 4.2 BUG-011 + SEC-001 + SEC-002 (BERABER)              │
│     → firestore.rules: Tek seferde güncelle             │
│     → activity_logs: create kaldır/kısıtla              │
│     → daily_steps: write kısıtla                        │
│     → team_members: create kısıtla                      │
└─────────────────────────────────────────────────────────┘
```

| Özellik | Değer |
|---------|-------|
| **Risk Seviyesi** | 🟡 ORTA |
| **Etki Alanı** | API güvenliği, Database erişimi |
| **Rollback** | Rules geri alınabilir |
| **Tahmini Süre** | 4 saat |

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

### FAZA 6: VERİ BÜTÜNLÜĞÜ 🔴

```
┌─────────────────────────────────────────────────────────┐
│ 6.1 BUG-008 (Bağış transaction)                         │
│     → lib/screens/charity/charity_screen.dart           │
│     → WriteBatch → runTransaction                       │
│                                                         │
│ Edge Cases:                                             │
│ - Network hatası mid-transaction                        │
│ - Concurrent bağış işlemleri                            │
│ - Yetersiz bakiye kontrolü                              │
└─────────────────────────────────────────────────────────┘
```

| Özellik | Değer |
|---------|-------|
| **Risk Seviyesi** | 🟡 ORTA |
| **Etki Alanı** | Bağış işlemleri (kritik) |
| **Rollback** | Dikkatli test gerekir |
| **Tahmini Süre** | 2 saat |

---

### FAZA 7: DEAD CODE TEMİZLİĞİ 🟢

```
┌─────────────────────────────────────────────────────────┐
│ 7.1 BUG-012                                            │
│     → lib/main_new.dart sil                             │
│                                                         │
│ 7.2 CODE-005                                           │
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

### 2. Firestore Rules Değişikliği (FAZA 4)

**Değişecek Kurallar:**
```javascript
// activity_logs: create kaldırılacak veya kısıtlanacak
// daily_steps: write kısıtlanacak  
// team_members: create kısıtlanacak
```

**Soru:** Varolan write işlemleri Cloud Function'a taşınmalı mı?

**Etkilenen Ekranlar:**
- Dashboard (adım kaydetme)
- Teams (üye ekleme)
- Leaderboard (activity log)

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

**GDPR Sorusu:** 30 gün soft-delete uygulanacak mı?

| Seçenek | Avantaj | Dezavantaj |
|---------|---------|------------|
| **Hard Delete** | Basit implementasyon | Kullanıcı pişman olursa geri dönüş yok |
| **Soft Delete (30 gün)** | Kullanıcı geri dönebilir | Daha karmaşık, scheduled job gerekir |

---

## 📊 ÖZET TABLO

| Faz | İçerik | Risk | Süre | Öncelik |
|-----|--------|------|------|---------|
| **1** | Bildirim Sistemi | 🟢 Düşük | 3 saat | 🔴 Kritik |
| **2** | Credentials (Manuel) | 🔴 Yüksek | 1.5 saat | 🔴 Kritik |
| **3** | Auth & Legal | 🟡 Orta | 7 saat | 🔴 Kritik |
| **4** | App Security | 🟡 Orta | 4 saat | 🔴 Kritik |
| **5** | Theme Sistemi | 🟢 Düşük | 2 saat | 🟠 Yüksek |
| **6** | Veri Bütünlüğü | 🟡 Orta | 2 saat | 🔴 Kritik |
| **7** | Dead Code | 🟢 Çok Düşük | 0.5 saat | 🟢 Düşük |

**Toplam Tahmini Süre:** ~20 saat

---

## ✅ ONAY FORMATI

Aşağıdaki formatı kullanarak onay verin:

```
ONAY: [FAZA numarası]
Soft-delete: [EVET/HAYIR]
Credentials: [REHBER/KOMUT]
Başlangıç: [EVET]
```

**Örnek:**
```
ONAY: FAZA 1
Soft-delete: HAYIR
Credentials: REHBER
Başlangıç: EVET
```

---

## 📝 NOTLAR

1. Her faz tamamlandığında **"DEVAM"** onayı beklenecek
2. Kod değişiklikleri **küçük, izole ve rollback-safe** olacak
3. Mevcut mimari **KORUNACAK**
4. Her değişiklik için **test senaryoları** belirtilecek

---

**Rapor Sonu**

*Bu yol haritası, DERINLEMESINE_ANALIZ_RAPORU.md'deki 78+ tespitin güvenli ve sistematik şekilde çözülmesi için hazırlanmıştır.*
