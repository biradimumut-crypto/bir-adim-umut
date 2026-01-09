# 📱 BİR ADIM UMUT - UYGULAMA ORGANİZASYON ŞEMASI

> **Son Güncelleme:** 8 Ocak 2026
> **Uygulama Türü:** Flutter (iOS/Android) + Firebase Backend

---

## 📁 PROJE YAPISI

```
bir-adim-umut/
├── lib/                          # Flutter kaynak kodları
│   ├── main.dart                 # Uygulama giriş noktası
│   ├── firebase_options.dart     # Firebase yapılandırması
│   ├── models/                   # Veri modelleri
│   ├── providers/                # State management (Provider)
│   ├── screens/                  # Ekranlar (UI)
│   ├── services/                 # İş mantığı servisleri
│   └── widgets/                  # Yeniden kullanılabilir widget'lar
├── firebase_functions/           # Cloud Functions (TypeScript)
├── firestore.rules               # Firestore güvenlik kuralları
├── storage.rules                 # Storage güvenlik kuralları
├── assets/                       # Görseller, ikonlar, videolar
├── android/                      # Android platforma özgü
├── ios/                          # iOS platforma özgü
└── web/                          # Web platforma özgü
```

---

## 🗄️ FİREBASE KOLEKSİYONLARI (FIRESTORE)

### 1️⃣ `users` - Kullanıcılar
**Amaç:** Tüm kullanıcı bilgilerini saklar

| Alan | Tip | Açıklama |
|------|-----|----------|
| `uid` | string | Firebase Auth UID (belge ID) |
| `full_name` | string | Tam isim |
| `masked_name` | string | Sıralamada gösterilen maskeli isim (On* Ho** St**) |
| `nickname` | string? | Kullanıcı takma adı |
| `email` | string | E-posta adresi |
| `profile_image_url` | string? | Profil fotoğrafı URL'i |
| `wallet_balance_hope` | number | Cüzdandaki Hope bakiyesi |
| `current_team_id` | string? | Üye olunan takım ID'si |
| `theme_preference` | string | "dark" veya "light" |
| `created_at` | timestamp | Kayıt tarihi |
| `last_step_sync_time` | timestamp? | Son adım senkronizasyonu |
| `last_login_at` | timestamp? | Son giriş |
| `personal_referral_code` | string | 6 karakterlik kişisel davet kodu |
| `referred_by` | string? | Davet eden kullanıcının UID'si |
| `referral_count` | number | Kaç kişiyi davet ettiği |
| `referral_bonus_steps` | number | Toplam referral bonus adımlar |
| `referral_bonus_converted` | number | Dönüştürülen referral bonus |
| `leaderboard_bonus_steps` | number | Sıralama ödülü bonus adımlar |
| `leaderboard_bonus_converted` | number | Dönüştürülen sıralama bonus |
| `lifetime_steps` | number | Tüm zamanların toplam adımı |
| `lifetime_earned_hope` | number | Tüm zamanlar kazanılan Hope |
| `lifetime_donated_hope` | number | Tüm zamanlar bağışlanan Hope |
| `total_donation_count` | number | Toplam bağış sayısı |
| `is_banned` | boolean | Engellenme durumu |
| `ban_reason` | string? | Engellenme nedeni |
| `banned_at` | timestamp? | Engellenme tarihi |
| `banned_by` | string? | Engelleyen admin UID |
| `auth_provider` | string | "google", "apple", "email" |

**Alt Koleksiyonlar:**
- `users/{uid}/notifications` - Kullanıcı bildirimleri
- `users/{uid}/activity_logs` - Kullanıcı aktivite geçmişi
- `users/{uid}/badges` - Kazanılan rozetler
- `users/{uid}/daily_steps/{date}` - Günlük adım verileri
- `users/{uid}/ad_logs` - Reklam izleme geçmişi
- `users/{uid}/sessions` - Oturum geçmişi

---

### 2️⃣ `teams` - Takımlar
**Amaç:** Takım bilgilerini saklar

| Alan | Tip | Açıklama |
|------|-----|----------|
| `name` | string | Takım adı |
| `logo_url` | string? | Takım logosu |
| `referral_code` | string | 6 karakterlik benzersiz kod (ABCD12) |
| `leader_uid` | string | Takım liderinin UID'si |
| `members_count` | number | Üye sayısı |
| `total_team_hope` | number | Takımın toplam bağışı (sıralama için) |
| `created_at` | timestamp | Oluşturulma tarihi |
| `member_ids` | array | Üye UID listesi |
| `team_bonus_steps` | number | Takım bonus adım havuzu |
| `team_bonus_converted` | number | Dönüştürülen takım bonus |

**Alt Koleksiyon:**
- `teams/{teamId}/team_members/{uid}` - Takım üyeleri

---

### 3️⃣ `charities` - Bağış Alıcıları
**Amaç:** Vakıf, topluluk ve bireysel bağış alıcılarını saklar

| Alan | Tip | Açıklama |
|------|-----|----------|
| `name` | string | Kuruluş adı |
| `description` | string | Açıklama |
| `logo_url` | string | Logo URL'i |
| `banner_url` | string? | Banner görseli |
| `website_url` | string? | Web sitesi |
| `email` | string? | E-posta |
| `phone` | string? | Telefon |
| `recipient_type` | string | "charity", "community", "individual" |
| `category` | string | "education", "health", "animals", "environment", "humanitarian", "accessibility" |
| `collected_amount` | number | Toplanan Hope miktarı |
| `target_amount` | number? | Hedef miktar |
| `donor_count` | number | Bağışçı sayısı |
| `is_active` | boolean | Aktif mi? |
| `is_featured` | boolean | Öne çıkarılmış mı? |
| `created_at` | timestamp | Oluşturulma tarihi |

---

### 4️⃣ `donations` - Bağışlar
**Amaç:** Yapılan bağış kayıtlarını tutar

| Alan | Tip | Açıklama |
|------|-----|----------|
| `user_id` | string | Bağışçı UID |
| `charity_id` | string | Bağış alıcısı ID |
| `amount` | number | Bağış miktarı (Hope) |
| `created_at` | timestamp | Bağış tarihi |
| `charity_name` | string | Kuruluş adı (denormalize) |

---

### 5️⃣ `activity_logs` - Aktivite Logları
**Amaç:** Tüm kullanıcı aktivitelerini takip eder (Sıralama için)

| Alan | Tip | Açıklama |
|------|-----|----------|
| `user_id` | string | Kullanıcı UID |
| `activity_type` | string | Aktivite türü (aşağıda detaylı) |
| `steps_converted` | number? | Dönüştürülen adım |
| `hope_earned` | number? | Kazanılan Hope |
| `amount` | number? | Bağış miktarı |
| `charity_id` | string? | Bağış yapılan kuruluş |
| `created_at` | timestamp | Aktivite zamanı |

**Activity Types:**
- `step_conversion` - Normal adım dönüşümü
- `step_conversion_2x` - 2x bonus dönüşüm
- `carryover_conversion` - Taşınan adım dönüşümü
- `bonus_conversion` - Bonus adım dönüşümü
- `donation` - Bağış
- `referral_bonus` - Referral bonus kazanma

---

### 6️⃣ `notifications` - Bildirimler (Root)
**Amaç:** Takım davet bildirimleri

| Alan | Tip | Açıklama |
|------|-----|----------|
| `receiver_uid` | string | Alıcı kullanıcı UID |
| `sender_uid` | string? | Gönderen UID |
| `sender_team_id` | string? | Gönderen takım ID |
| `notification_type` | string | "team_invite", "join_request" |
| `notification_status` | string | "pending", "accepted", "rejected" |
| `created_at` | timestamp | Oluşturulma |
| `responded_at` | timestamp? | Yanıtlanma |
| `sender_name` | string | Gönderen ismi |
| `team_name` | string? | Takım adı |

---

### 7️⃣ `admins` - Admin Kullanıcıları
**Amaç:** Admin yetkili kullanıcıları tanımlar

| Alan | Tip | Açıklama |
|------|-----|----------|
| `user_id` | string | Admin UID (belge ID) |
| `is_active` | boolean | Aktif mi? |
| `role` | string | "super_admin", "admin", "moderator" |
| `created_at` | timestamp | Atanma tarihi |
| `created_by` | string? | Atayan admin |

---

### 8️⃣ `badge_definitions` - Rozet Tanımları
**Amaç:** Kazanılabilir rozetleri tanımlar

| Alan | Tip | Açıklama |
|------|-----|----------|
| `badge_id` | string | Rozet ID |
| `name_tr` | string | Türkçe isim |
| `name_en` | string | İngilizce isim |
| `description_tr` | string | Türkçe açıklama |
| `description_en` | string | İngilizce açıklama |
| `icon_url` | string | Rozet ikonu |
| `criteria_type` | string | "steps", "donations", "referrals", "streak" |
| `criteria_value` | number | Gerekli değer |
| `is_active` | boolean | Aktif mi? |

---

### 9️⃣ `app_settings` - Uygulama Ayarları
**Amaç:** Genel uygulama ayarları

| Alan | Tip | Açıklama |
|------|-----|----------|
| `conversion_rate` | number | 100 adım = 1 Hope |
| `max_daily_conversion` | number | Günlük max dönüşüm |
| `bonus_multiplier` | number | 2x bonus çarpanı |
| `referral_bonus_steps` | number | Referral bonus miktarı |
| `maintenance_mode` | boolean | Bakım modu |

---

### 🔟 Diğer Koleksiyonlar

| Koleksiyon | Amaç |
|------------|------|
| `admin_logs` | Admin işlem logları |
| `admin_stats` | Admin istatistikleri |
| `daily_stats` | Günlük istatistikler |
| `broadcast_notifications` | Toplu bildirimler |
| `ad_logs` | Reklam logları |
| `ad_errors` | Reklam hataları |
| `step_leaderboard` | Adım sıralaması |
| `donation_leaderboard` | Bağış sıralaması |
| `hope_leaderboard` | Hope sıralaması |
| `team_leaderboard` | Takım sıralaması |
| `charity_comments` | Vakıf yorumları |
| `invitations` | Davetler |
| `user_badges` | Kullanıcı rozetleri |
| `monthly_reset_summaries` | Aylık sıfırlama özetleri |

---

## ☁️ CLOUD FUNCTIONS

### 1. `createTeam`
- **Tetikleme:** HTTPS Callable
- **İşlev:** Yeni takım oluşturur
- **İşlem:** Benzersiz referral code üretir, takım oluşturur, lideri ekler

### 2. `joinTeamByReferral`
- **Tetikleme:** HTTPS Callable
- **İşlev:** Referral kodu ile takıma katılma
- **İşlem:** Takımı bulur, üyeyi ekler, sayıları günceller

### 3. `inviteUserToTeam`
- **Tetikleme:** HTTPS Callable
- **İşlev:** Kullanıcıyı takıma davet et
- **İşlem:** Davet bildirimi oluşturur, push notification gönderir

### 4. `acceptTeamInvite`
- **Tetikleme:** HTTPS Callable
- **İşlev:** Takım davetini kabul et
- **İşlem:** Bildirimi günceller, üyeyi ekler

### 5. `rejectTeamInvite`
- **Tetikleme:** HTTPS Callable
- **İşlev:** Takım davetini reddet
- **İşlem:** Bildirimi rejected yapar

### 6. `leaveTeam`
- **Tetikleme:** HTTPS Callable
- **İşlev:** Takımdan ayrıl
- **İşlem:** Üyeyi kaldırır, sayıları günceller

### 7. `sendBroadcastNotification`
- **Tetikleme:** HTTPS Callable
- **İşlev:** Toplu bildirim gönder (Admin)
- **İşlem:** Tüm/seçili kullanıcılara push notification

### 8. `monthlyReset` (Scheduled)
- **Tetikleme:** Her ayın 1'i 00:00
- **İşlev:** Aylık sıfırlama
- **İşlem:** Sıralamaları sıfırlar, ödülleri dağıtır

### 9. `dailyCleanup` (Scheduled)
- **Tetikleme:** Her gün 03:00
- **İşlev:** Günlük temizlik
- **İşlem:** Eski logları temizler

---

## 📱 FLUTTER SERVİSLERİ

### 1. `AuthService`
**Dosya:** `lib/services/auth_service.dart`
**İşlev:** Kimlik doğrulama işlemleri

| Metod | Açıklama |
|-------|----------|
| `signInWithGoogle()` | Google ile giriş |
| `signInWithApple()` | Apple ile giriş |
| `signInWithEmail()` | E-posta ile giriş |
| `signUp()` | Yeni kayıt |
| `signOut()` | Çıkış |
| `resetPassword()` | Şifre sıfırlama |
| `linkEmailPassword()` | Şifre oluşturma (sosyal → email) |

---

### 2. `StepService`
**Dosya:** `lib/services/step_service.dart`
**İşlev:** Adım verisi yönetimi

| Metod | Açıklama |
|-------|----------|
| `getTodaySteps()` | Bugünün adımlarını al |
| `getWeeklySteps()` | Haftalık adımları al |
| `syncStepsFromHealth()` | Health API'den senkronize et |

---

### 3. `StepConversionService`
**Dosya:** `lib/services/step_conversion_service.dart`
**İşlev:** Adım → Hope dönüşümü

| Metod | Açıklama |
|-------|----------|
| `convertSteps()` | Adımları Hope'a dönüştür |
| `convertCarryOverSteps()` | Taşınan adımları dönüştür |
| `convertBonusSteps()` | Bonus adımları dönüştür |
| `getDailyStepData()` | Günlük adım verisini al |
| `getRemainingSteps()` | Kalan dönüştürülebilir adım |

**Dönüşüm Oranı:** 100 adım = 1 Hope

---

### 4. `BadgeService`
**Dosya:** `lib/services/badge_service.dart`
**İşlev:** Rozet sistemi

| Metod | Açıklama |
|-------|----------|
| `checkAndAwardBadges()` | Rozet kazanım kontrolü |
| `getUserBadges()` | Kullanıcının rozetleri |
| `markBadgeAsSeen()` | Rozeti görüldü işaretle |

---

### 5. `TeamService`
**Dosya:** `lib/services/team_service.dart`
**İşlev:** Takım işlemleri

| Metod | Açıklama |
|-------|----------|
| `createTeam()` | Takım oluştur |
| `joinTeamByReferral()` | Referral ile katıl |
| `leaveTeam()` | Takımdan ayrıl |
| `getTeamMembers()` | Üyeleri getir |
| `sendJoinRequest()` | Katılma isteği gönder |

---

### 6. `NotificationService`
**Dosya:** `lib/services/notification_service.dart`
**İşlev:** Push bildirimler

| Metod | Açıklama |
|-------|----------|
| `initialize()` | FCM başlat |
| `requestPermission()` | İzin iste |
| `getToken()` | FCM token al |
| `handleMessage()` | Bildirimi işle |

---

### 7. `LocalNotificationService`
**Dosya:** `lib/services/local_notification_service.dart`
**İşlev:** Zamanlanmış yerel bildirimler

| Bildirim | Zaman | Açıklama |
|----------|-------|----------|
| Sabah Motivasyon | 11:00 | 5 farklı mesaj rastgele |
| Akşam Hatırlatma | 20:00 | 3 farklı mesaj rastgele |
| Ay Sonu Uyarısı | Son 3 gün | Sıfırlama uyarısı |
| Taşınan Adım | - | Carry-over hatırlatma |

---

### 8. `AdminService`
**Dosya:** `lib/services/admin_service.dart`
**İşlev:** Admin panel işlemleri

| Metod | Açıklama |
|-------|----------|
| `getDashboardStats()` | İstatistikleri al |
| `getAllUsers()` | Tüm kullanıcıları listele |
| `banUser()` | Kullanıcıyı engelle |
| `unbanUser()` | Engeli kaldır |
| `sendBroadcast()` | Toplu bildirim |
| `addCharity()` | Vakıf ekle |
| `updateCharity()` | Vakıf güncelle |

---

### 9. `ActivityLogService`
**Dosya:** `lib/services/activity_log_service.dart`
**İşlev:** Aktivite loglama

| Metod | Açıklama |
|-------|----------|
| `logStepConversion()` | Dönüşüm logla |
| `logDonation()` | Bağış logla |
| `logReferralBonus()` | Referral bonus logla |

---

### 10. `SocialShareService`
**Dosya:** `lib/services/social_share_service.dart`
**İşlev:** Sosyal medya paylaşımı

| Metod | Açıklama |
|-------|----------|
| `shareStats()` | İstatistikleri paylaş |
| `shareBadge()` | Rozet paylaş |
| `shareReferralCode()` | Referral kodu paylaş |

---

## 📺 EKRANLAR (SCREENS)

### Ana Ekranlar

| Ekran | Dosya | Açıklama |
|-------|-------|----------|
| Splash | `splash/splash_screen.dart` | Açılış ekranı (GIF + 2sn) |
| Login | `auth/login_screen.dart` | Giriş ekranı |
| SignUp | `auth/sign_up_screen.dart` | Kayıt ekranı |
| Dashboard | `dashboard/dashboard_screen.dart` | Ana sayfa |
| Profile | `profile/profile_screen.dart` | Profil sayfası |
| Leaderboard | `leaderboard/leaderboard_screen.dart` | Sıralama |
| Teams | `teams/teams_screen.dart` | Takımlar |
| Charity | `charity/charity_screen.dart` | Bağış ekranı |
| Badges | `badges/badges_screen.dart` | Rozetler |
| Notifications | `notifications/notifications_page.dart` | Bildirimler |

### Admin Ekranları

| Ekran | Dosya | Açıklama |
|-------|-------|----------|
| Admin Dashboard | `admin/admin_dashboard_screen.dart` | Admin ana sayfa |
| Admin Users | `admin/admin_users_screen.dart` | Kullanıcı yönetimi |
| Admin Charities | `admin/admin_charities_screen.dart` | Vakıf yönetimi |
| Admin Teams | `admin/admin_teams_screen.dart` | Takım yönetimi |
| Admin Notifications | `admin/admin_notifications_screen.dart` | Bildirim gönderme |
| Admin Stats | `admin/admin_stats_screen.dart` | Detaylı istatistikler |
| Admin Steps | `admin/admin_steps_screen.dart` | Adım istatistikleri |

---

## 🔒 GÜVENLİK KURALLARI

### Firestore Rules Özet

| Koleksiyon | Okuma | Yazma |
|------------|-------|-------|
| `users` | ✅ Auth | 🔐 Kendi verisi |
| `teams` | ✅ Auth | 🔐 Lider |
| `charities` | ✅ Auth | 🔐 Admin |
| `donations` | 🔐 Kendi/Admin | ✅ Auth |
| `activity_logs` | ✅ Auth | ✅ Auth (sadece create) |
| `admins` | ✅ Auth | 🔐 Admin |
| `admin_logs` | 🔐 Admin | 🔐 Admin |

### Storage Rules

| Path | Okuma | Yazma |
|------|-------|-------|
| `profile_photos/{uid}.jpg` | ✅ Auth | 🔐 Kendi UID |
| `team_logos/{teamId}.jpg` | ✅ Auth | ✅ Auth |

---

## 📊 ADIM/HOPE SİSTEMİ

### Dönüşüm Mantığı

```
100 adım = 1 Hope

Günlük Limit: 15.000 adım
Tek Seferde: 2.500 adım max
Cooldown: 1 saniye

2x Bonus: %50 progress'te aktif (50 Hope üstü bakiye)
```

### Adım Türleri

| Tür | Açıklama | Süre |
|-----|----------|------|
| Günlük Adım | Health API'den alınan | Gece 00:00'da sıfırlanır |
| Taşınan Adım | Dönüştürülmemiş günlük | Ay sonuna kadar geçerli |
| Referral Bonus | Davet bonusu | Süresiz |
| Sıralama Bonus | Aylık ödül | Süresiz |

### Ay Sonu Sıfırlama

- **Her ayın 1'i 00:00:** Sıralamalar sıfırlanır
- **Ödüller:** İlk 3'e bonus adım (5000/3000/1000)
- **Taşınan adımlar:** Dönüştürülmeyenler silinir

---

## 🏆 SIRALAMA SİSTEMİ

### Umut Hareketi (Adım Sıralaması)
- **Kriter:** Bu ay dönüştürülen adımlar
- **Kaynak:** `activity_logs` (step_conversion, carryover_conversion)
- **Sıfırlama:** Her ay başı

### Umut Elçileri (Bağış Sıralaması)
- **Kriter:** Bu ay yapılan bağışlar
- **Kaynak:** `activity_logs` (donation)
- **Sıfırlama:** Her ay başı

### Umut Ormanı (Takım Sıralaması)
- **Kriter:** Takım toplam bağışı
- **Kaynak:** `teams.total_team_hope`

---

## 🎖️ ROZET SİSTEMİ

| Rozet | Kriter |
|-------|--------|
| İlk Adım | İlk dönüşüm |
| 1K Adım | 1.000 adım |
| 10K Adım | 10.000 adım |
| 100K Adım | 100.000 adım |
| İlk Bağış | İlk bağış |
| Cömert Kalp | 100 Hope bağış |
| Umut Elçisi | 1.000 Hope bağış |
| Referral Master | 10 kişi davet |
| Takım Kurucusu | Takım kurma |
| 7 Gün Streak | 7 gün üst üste |

---

## 📱 BİLDİRİM TÜRLERİ

### Push Bildirimler (FCM)
- Takım daveti
- Bağış teşekkürü
- Rozet kazanımı
- Admin duyuruları

### Yerel Bildirimler
- Sabah motivasyon (11:00)
- Akşam hatırlatma (20:00)
- Ay sonu uyarıları

---

## 🔗 REFERRAL SİSTEMİ

### Kişisel Referral
- **Kod:** 6 karakterlik benzersiz kod
- **Bonus:** Davet eden: 1000 adım, Davet edilen: 500 adım
- **Limit:** Sınırsız davet

### Takım Referral
- **Kod:** 6 karakterlik takım kodu
- **İşlev:** Doğrudan takıma katılım
- **Oluşturucu:** Takım lideri

---

## 📦 KULLANILAN PAKETLER

| Paket | Versiyon | Amaç |
|-------|----------|------|
| firebase_core | - | Firebase temel |
| firebase_auth | - | Kimlik doğrulama |
| cloud_firestore | - | Veritabanı |
| firebase_storage | - | Dosya depolama |
| firebase_messaging | - | Push bildirimler |
| cloud_functions | - | Cloud Functions |
| google_sign_in | - | Google girişi |
| sign_in_with_apple | - | Apple girişi |
| health | - | Adım verisi (HealthKit/Google Fit) |
| provider | - | State management |
| flutter_local_notifications | - | Yerel bildirimler |
| google_mobile_ads | - | Reklamlar |
| share_plus | - | Paylaşım |
| image_picker | - | Fotoğraf seçimi |

---

## 🎯 ÖNEMLİ NOTLAR

1. **Adım senkronizasyonu:** Health API'den her dashboard açılışında çekilir
2. **Sıralama hesaplaması:** `activity_logs` üzerinden aylık bazda
3. **Hope birimi:** 100 adım = 1 Hope (sabit oran)
4. **Cooldown:** Dönüşümler arası 1 saniye bekleme
5. **Ay sonu:** Her ayın 1'i 00:00'da otomatik sıfırlama

---

*Bu doküman Bir Adım Umut uygulamasının teknik yapısını detaylı şekilde açıklamaktadır.*
