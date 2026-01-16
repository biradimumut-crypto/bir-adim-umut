# 🔐 BAŞDENETÇİ BULGULARI VE DÜZELTME RAPORU

**Tarih:** 16 Ocak 2026  
**Konu:** One Hope Step – Firestore Güvenlik & Veri Yazma Denetimi  
**Durum:** ✅ TÜM DÜZELTMELER TAMAMLANDI - DEPLOY HAZIR

---

## 📋 BAŞDENETÇİ KOŞULLU ONAY KARŞILAMA DURUMU

| # | Koşul | Durum |
|---|-------|-------|
| 1 | OR riski - tek allow update | ✅ Sadece whitelist + admin |
| 2 | Notifications null kontrolü | ✅ != null eklendi |
| 3 | Teams leader pozitif whitelist | ✅ hasOnly ile sınırlandı |
| 4 | donateHope() tek transaction | ✅ Cloud Function yazıldı |
| 5 | Deploy planı onayı | ✅ Hotfix + B planı |

---

## 📋 BAŞDENETÇİ TESPİTLERİ

### 1️⃣ users/{userId} update yetkisi aşırı geniş (KRİTİK)

**Sorun:**
```javascript
match /users/{userId} {
  allow update: if isUser(userId);
}
```

Bu kural kullanıcının kendi `users/{uid}` dokümanındaki TÜM alanları güncelleyebilmesine izin veriyordu:
- `wallet_balance_hope`
- `lifetime_earned_hope`
- `carryover_*`
- `referral_*`
- `is_admin`, `ban`, `email_verified`

**Risk:** Muhasebe/yetki alanları client üzerinden manipüle edilebilir.

---

### 2️⃣ current_team_id ve referral alanlarında "başkasına yazma" riski

**Sorun:**
```javascript
allow update: if isAuthenticated() &&
  request.resource.data.diff(resource.data).affectedKeys()
    .hasOnly(['current_team_id']);
```

`isUser(userId)` kontrolü YOKTU - oturum açmış herhangi bir kullanıcı başka birinin dokümanını güncelleyebilirdi.

**Risk:**
- Takım üyelikleri dışarıdan değiştirilebilir
- Referral sayaçları şişirilebilir
- Ödül/leaderboard hesapları bozulur

---

### 3️⃣ teams/{teamId} istatistik alanları client update'e açık (KRİTİK)

**Sorun:**
```javascript
allow update: if isAuthenticated() &&
  affectedKeys hasOnly([
    'members_count',
    'member_ids',
    'total_team_hope',
    'team_bonus_steps'
  ]);
```

Her giriş yapmış kullanıcı takım istatistiklerini yazabiliyordu.

**Risk:**
- Takım üye sayıları yanlış görünür
- "1 kişi 4 kişi görünüyor" hataları
- Team leaderboard manipüle edilebilir

---

### 4️⃣ Leaderboard koleksiyonlarına client write açık (KRİTİK)

**Sorun:**
```javascript
match /hope_leaderboard/{id} {
  allow write: if isAuthenticated();
}
match /team_leaderboard/{id} {
  allow write: if isAuthenticated();
}
```

**Risk:** Client leaderboard'ı doğrudan manipüle edebilir.

---

### 5️⃣ Root notifications koleksiyonu gizlilik ihlali riski

**Sorun:**
```javascript
match /notifications/{id} {
  allow read, delete: if isAuthenticated();
}
```

**Risk:** Herkes herkesin bildirimini okuyabilir/silebilir.

---

### 6️⃣ charities collected_amount client update'e açık

**Sorun:**
```javascript
allow update: if isAuthenticated() &&
  request.resource.data.diff(resource.data).affectedKeys()
    .hasOnly(['collected_amount', 'donor_count']);
```

**Risk:** Vakıf bağış istatistikleri manipüle edilebilir.

---

## ✅ UYGULANAN DÜZELTMELER (firestore.rules)

### FIX #1: users/{userId} WHITELIST

```javascript
// 🚨 BAŞDENETÇI FIX #1: Kullanıcı update WHITELIST ile sınırlandırıldı
allow update: if isUser(userId) &&
                request.resource.data.diff(resource.data).affectedKeys()
                  .hasOnly([
                    // Profil alanları
                    'display_name', 'photo_url', 'bio', 'phone_number',
                    // Tercihler
                    'theme_mode', 'language', 'notification_preferences',
                    'daily_goal_steps', 'privacy_settings',
                    // Health Kit entegrasyonu
                    'health_data_source', 'last_health_sync',
                    // FCM token
                    'fcm_token', 'fcm_token_updated_at',
                    // Durum alanları
                    'last_active_at', 'app_version', 'device_info'
                  ]);
```

**Korunan alanlar (SERVER-ONLY):**
- `wallet_balance_hope`
- `lifetime_earned_hope`
- `carryover_*`
- `referral_*`
- `current_team_id`
- `is_admin`, `ban`, `email_verified`

---

### FIX #2: current_team_id ve referral KALDIRILDI

```javascript
// 🚨 BAŞDENETÇI FIX #2: Referral güncelleme KALDIRILDI
// referral_bonus_steps ve referral_count sadece Cloud Function yazmalı
// KALDIRILDI: allow update: if isAuthenticated() && referral alanları...

// 🚨 BAŞDENETÇI FIX #2: current_team_id güncelleme KALDIRILDI
// Sadece joinTeam(), leaveTeam() Cloud Function'ları yazmalı
// KALDIRILDI: allow update: if isAuthenticated() && current_team_id...
```

---

### FIX #3: teams/{teamId} stats SERVER-ONLY

```javascript
// 🚨 BAŞDENETÇI FIX #3 REV.2: Lider POZİTİF WHITELIST ile sınırlı
// Sadece takım profil alanlarını güncelleyebilir
allow update: if isTeamLeader(teamId) &&
                request.resource.data.diff(resource.data).affectedKeys()
                  .hasOnly([
                    // Takım profil alanları
                    'name', 'description', 'logo_url', 'cover_url',
                    // Görünürlük ayarları
                    'is_public', 'join_type', 'max_members',
                    // İletişim
                    'contact_email', 'social_links'
                  ]);

// 🚨 Korunan alanlar (SERVER-ONLY):
// members_count, member_ids, total_team_hope, team_bonus_steps
// leader_uid, created_by, referral_code = DEĞİŞTİRİLEMEZ
```

---

### FIX #4: Leaderboard WRITE FALSE

```javascript
// ========== HOPE_LEADERBOARD KOLEKSİYONU ==========
match /hope_leaderboard/{docId} {
  allow read: if isAuthenticated();
  // 🚨 BAŞDENETÇI FIX #4: Client YAZAMAZ - sadece Cloud Function (Admin SDK)
  allow write: if false;
}

// ========== TEAM_LEADERBOARD KOLEKSİYONU ==========
match /team_leaderboard/{docId} {
  allow read: if isAuthenticated();
  // 🚨 BAŞDENETÇI FIX #4: Client YAZAMAZ - sadece Cloud Function (Admin SDK)
  allow write: if false;
}
```

---

### FIX #5: Root notifications GİZLİLİK

```javascript
match /notifications/{notificationId} {
  // 🚨 BAŞDENETÇI FIX #5 REV.2: Null kontrolü eklendi
  // Eski dokümanlar için güvenli
  allow read: if isAuthenticated() && 
                (
                  (resource.data.to_user_id != null && resource.data.to_user_id == request.auth.uid) || 
                  (resource.data.from_user_id != null && resource.data.from_user_id == request.auth.uid) ||
                  (resource.data.user_id != null && resource.data.user_id == request.auth.uid)
                );
  
  // Bildirim oluşturabilir - from_user_id doğrulaması
  allow create: if isAuthenticated() && 
                   request.resource.data.from_user_id == request.auth.uid;
  
  // Sadece hedef kullanıcı güncelleyebilir (null kontrolü ile)
  allow update: if isAuthenticated() && 
                  resource.data.to_user_id != null &&
                  resource.data.to_user_id == request.auth.uid;
  
  // Sadece hedef kullanıcı veya gönderen silebilir
  allow delete: if isAuthenticated() && 
                  (
                    (resource.data.to_user_id != null && resource.data.to_user_id == request.auth.uid) || 
                    (resource.data.from_user_id != null && resource.data.from_user_id == request.auth.uid)
                  );
}
```

---

### FIX #6: charities collected_amount SERVER-ONLY

```javascript
match /charities/{charityId} {
  allow read: if isAuthenticated();
  allow write: if isAdmin();
  
  // 🚨 BAŞDENETÇI FIX #6: Client collected_amount/donor_count YAZAMAZ
  // Sadece donateHope() Cloud Function (Admin SDK) günceller
  // KALDIRILDI: allow update: if isAuthenticated() && hasOnly collected_amount...
}
```

---

## ⚠️ KIRILACAK CLIENT AKIŞLARI (Hotfix Sonrası)

| Akış | Dosya | Satır | Sorun | Çözüm |
|------|-------|-------|-------|-------|
| Takıma katıl | `teams_screen.dart` | 639 | `members_count` yazamaz | `joinTeam()` CF |
| Takımdan ayrıl | `teams_screen.dart` | 2042 | `members_count` yazamaz | `leaveTeam()` CF |
| Davet kabul | `notifications_page.dart` | 318 | `members_count` yazamaz | `joinTeam()` CF |
| Referral katıl | `dashboard_screen.dart` | 3913 | `members_count` yazamaz | `joinTeamByReferral` ✅ VAR |
| Bağış yap | `charity_screen.dart` | 795 | `wallet_balance_hope` yazamaz | `donateHope()` CF |
| Charity güncelle | `charity_screen.dart` | 846 | `collected_amount` yazamaz | `donateHope()` CF |

---

## 📋 GELİŞTİRME PLANI

### ADIM 1: DEPLOY (Hemen)
```bash
# Rules + Functions birlikte deploy
firebase deploy --only firestore:rules,functions
```

### ADIM 2: CLOUD FUNCTIONS DURUMU

**Mevcut:**
- ✅ `joinTeamByReferral` - Referral ile katılma (VAR)
- ✅ `inviteUserToTeam` - Davet gönderme (VAR)

**Yeni Eklenen (Başdenetçi Fix):**
- ✅ `donateHope()` - Bağış yapma (TEK TRANSACTION)
- ✅ `joinTeam()` - Normal takıma katılma
- ✅ `leaveTeam()` - Takımdan ayrılma

### ADIM 3: CLIENT REFACTOR (Sonraki Aşama)
- Direct Firestore write → Cloud Function call

### ADIM 4: DEPLOY SONRASI TEST
```bash
# 5 dakikalık minimum test
1. Client'tan leaderboard write → PERMISSION_DENIED ✅
2. Normal user teams.members_count update → PERMISSION_DENIED ✅
3. Normal user users.wallet_balance_hope update → PERMISSION_DENIED ✅
4. Notification read: sadece sender/receiver ✅
5. Charity collected_amount client update → PERMISSION_DENIED ✅
```

---

## 🔐 ÖNERİLEN NET PRENSİP

| Kategori | Yetki |
|----------|-------|
| Client | Sadece UI/ayar/profil yazar |
| Server | Hope, adım dönüşümü, referral, team stats, leaderboard |
| Rules | Geniş `allow update` YOK, whitelist + function mimarisi |

---

## 📝 NOTLAR

- ✅ Rules düzeltmeleri tamamlandı
- ✅ Cloud Functions yazıldı ve build başarılı
- ⚠️ Client kodu hala eski akışları kullanıyor - Runtime hataları oluşacak
- Cloud Functions deploy sonrası client refactor yapılacak
- B planı tercih edildi: Migrasyon öncelikli

**Başdenetçi Onayı:** ✅ Koşullu onay karşılandı  
**Deploy:** HAZIR  
**Cloud Functions Build:** ✅ Başarılı

---

## 🆕 YENİ CLOUD FUNCTIONS ÖZETİ

### donateHope()
```typescript
// TEK TRANSACTION İÇİNDE:
// 1. wallet_balance_hope düşür
// 2. donation kaydı oluştur
// 3. charity stats güncelle (collected_amount, donor_count)
// 4. activity_logs (global + user subcollection)
// 5. user stats (lifetime_donated_hope, total_donation_count)
```

### joinTeam()
```typescript
// TEK TRANSACTION İÇİNDE:
// 1. Kullanıcı başka takımda değilse kontrol
// 2. team_members'a ekle
// 3. user.current_team_id güncelle
// 4. team.members_count artır
// 5. team.member_ids'e ekle
```

### leaveTeam()
```typescript
// TEK TRANSACTION İÇİNDE:
// 1. Lider kontrolü (tek üye değilse ayrılamaz)
// 2. team_members'dan sil
// 3. user.current_team_id = null
// 4. team.members_count azalt
// 5. Lider ve tek üye ise takımı sil
```
