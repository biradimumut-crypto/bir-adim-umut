# 🎯 Bir Adım Umut - Mobil Uygulaması

Insanların yürüyerek "Hope (H)" kazandığı, takımlar kurup yarıştığı, reklam izleyerek puanlarını dönüştürdüğü ve vakıflara bağış yaparak "Umut Olduğu" kapsamlı bir sosyal sorumluluk uygulaması.

---

## 📋 İçindekiler

1. [Teknoloji Yığını](#teknoloji-yığını)
2. [Proje Yapısı](#proje-yapısı)
3. [Veri Tabanı Şeması](#veri-tabanı-şeması)
4. [Ana Özellikler ve İş Mantığı](#ana-özellikler-ve-iş-mantığı)
5. [Cloud Functions Detayları](#cloud-functions-detayları)
6. [Kayıt Akışı (Sign Up)](#kayıt-akışı--sign-up-)
7. [Davet Sistemi](#davet-sistemi)
8. [Kurulum Talimatları](#kurulum-talimatları)

---

## 🛠️ Teknoloji Yığını

```
Frontend:
├── Flutter (UI Framework)
├── Provider / Riverpod (State Management)
└── fl_chart (Grafik Gösterimi)

Backend:
├── Firebase Authentication (Kullanıcı Yönetimi)
├── Firestore (Real-time Database)
├── Cloud Functions (Business Logic)
├── Cloud Storage (Profil Resimleri, Takım Logoları)
└── Cloud Messaging (Push Notifications)

Hardware Integration:
├── Health Plugin (iOS HealthKit)
└── Pedometer (Android, iOS adım okuma)

Monetization:
└── Google AdMob (Reklam Ağı)
```

---

## 📁 Proje Yapısı

```
bir_adim_umut/
│
├── lib/
│   ├── models/                 # Veri modelleri
│   │   ├── user_model.dart
│   │   ├── team_model.dart
│   │   ├── team_member_model.dart
│   │   ├── notification_model.dart
│   │   ├── activity_log_model.dart
│   │   └── daily_step_model.dart
│   │
│   ├── services/               # Firebase & Business Logic Services
│   │   ├── auth_service.dart       # Giriş/Kayıt
│   │   ├── team_service.dart       # Takım işlemleri
│   │   ├── notification_service.dart # Bildirim yönetimi
│   │   ├── activity_log_service.dart # Bağış & Activity
│   │   └── step_service.dart        # Adım senkronizasyon
│   │
│   ├── providers/              # Provider/Riverpod State Management
│   │   ├── auth_provider.dart
│   │   ├── team_provider.dart
│   │   └── step_provider.dart
│   │
│   ├── screens/                # UI Ekranları
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── sign_up_screen.dart
│   │   │   └── forgot_password_screen.dart
│   │   ├── dashboard/
│   │   │   ├── dashboard_screen.dart
│   │   │   └── step_history_screen.dart
│   │   ├── community/
│   │   │   ├── team_list_screen.dart
│   │   │   ├── team_detail_screen.dart
│   │   │   ├── create_team_screen.dart
│   │   │   └── invite_user_screen.dart
│   │   ├── charity/
│   │   │   ├── charity_list_screen.dart
│   │   │   └── donation_history_screen.dart
│   │   ├── leaderboard/
│   │   │   ├── leaderboard_screen.dart
│   │   │   └── team_leaderboard_screen.dart
│   │   └── profile/
│   │       ├── profile_screen.dart
│   │       └── activity_history_screen.dart
│   │
│   ├── widgets/                # Reusable Widgets
│   │   ├── nested_progress_bar.dart
│   │   ├── team_invite_dialog.dart
│   │   ├── charity_card.dart
│   │   └── team_member_list.dart
│   │
│   ├── main.dart
│   └── app_config.dart
│
├── firebase_functions/         # Cloud Functions (TypeScript)
│   ├── functions/
│   │   ├── src/
│   │   │   ├── index.ts        # Ana Cloud Functions
│   │   │   └── types.ts        # TypeScript tipler
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── firestore.rules
│
├── pubspec.yaml               # Flutter Dependencies
└── README.md
```

---

## 🗄️ Veri Tabanı Şeması

### 1. **users** Koleksiyonu
```firestore
users/{uid}
├── full_name: string              # Örn: "Ahmet Yılmaz"
├── masked_name: string            # Örn: "A* Y*" (Gizlilik için)
├── nickname: string?              # Örn: "AhmetY"
├── email: string                  # Örn: "ahmet@example.com"
├── profile_image_url: string?     # Storage'taki resim URL'i
├── wallet_balance_hope: number    # Örn: 10.50
├── current_team_id: string?       # Katıldığı takım (nullable)
├── theme_preference: string       # 'dark' | 'light'
├── created_at: timestamp          # Kayıt tarihi
├── last_step_sync_time: timestamp?# Son adım senkronizasyon
└── device_tokens: array           # Firebase Messaging token'ları

Alt Koleksiyonlar:
├── activity_logs/{logId}          # Bağış ve adım dönüştürme geçmişi
└── notifications/{notificationId} # Davet ve diğer bildirimler
```

### 2. **teams** Koleksiyonu
```firestore
teams/{teamId}
├── name: string                   # Örn: "Ümit Gücü"
├── logo_url: string?              # Storage'taki logo URL'i
├── referral_code: string          # Benzersiz 6 haneli kod (INDEX!)
├── leader_uid: string             # Takım kurucusu
├── members_count: number          # Üye sayısı
├── total_team_hope: number        # Toplam bağış Hope
├── created_at: timestamp
└── member_ids: array              # Hızlı erişim için

Alt Koleksiyonlar:
└── team_members/{userId}          # Takım üye listesi
    ├── team_id: string
    ├── user_id: string
    ├── member_status: string      # 'active' | 'pending' | 'left'
    ├── join_date: timestamp
    ├── member_total_hope: number  # Üye'nin bağış tutarı (cache)
    └── member_daily_steps: number # Üye'nin günlük adım (cache)
```

### 3. **notifications** Koleksiyonu (users altında)
```firestore
users/{userId}/notifications/{notificationId}
├── id: string                     # UUID
├── receiver_uid: string
├── sender_team_id: string         # Davet gönderen takım
├── notification_type: string      # 'team_invite' | 'donation' | 'achievement'
├── notification_status: string    # 'pending' | 'accepted' | 'rejected'
├── created_at: timestamp
├── responded_at: timestamp?       # Yanıt zamanı
├── sender_name: string            # Gönderici adı (cache)
└── team_name: string              # Takım adı (cache)
```

### 4. **activity_logs** Koleksiyonu (users altında)
```firestore
users/{userId}/activity_logs/{logId}
├── user_id: string
├── action_type: string            # 'donation' | 'step_conversion' | 'team_join'
├── target_name: string            # Vakıf adı veya takım adı
├── amount: number                 # Hope miktarı
├── steps_converted: number?       # Dönüştürülen adım (step_conversion için)
├── timestamp: timestamp
└── charity_logo_url: string?      # Vakıf logosu (cache)
```

### 5. **daily_steps** Koleksiyonu
```firestore
daily_steps/{userId-YYYY-MM-DD}
├── user_id: string
├── total_steps: number            # Cihazdan okunan toplam adım
├── converted_steps: number        # Dönüştürülen adım miktarı
├── date: timestamp                # Gün başlangıcı
├── is_reset: boolean              # 00:00'de sıfırlandı mı?
└── last_conversion_time: timestamp # Son dönüştürme saati (cooldown)

Indeksler:
- Composite: (user_id, date) DESC
```

### 6. **charities** Koleksiyonu (Admin tarafından yönetilir)
```firestore
charities/{charityId}
├── name: string                   # Vakıf adı
├── description: string            # Açıklama
├── logo_url: string
├── website: string?
├── bank_account: string           # Bağış için banka hesabı
└── total_hope_received: number    # Toplam alınan Hope
```

---

## 🎯 Ana Özellikler ve İş Mantığı

### 1. **Açılış Ekranı (Splash)**
- 3 saniye logo gösterimi
- Otomatik Giriş Sayfası'na yönlendirme

### 2. **Giriş/Kayıt (Authentication)**

#### Giriş:
```
- E-posta + Şifre
- Firebase Auth ile doğrulama
- Başarılıysa Dashboard'a yönlendir
```

#### **Kayıt (Referral Code ile)**
```
AD & SOYAD → 
E-POSTA →
ŞİFRE →
ŞİFRE DOĞRULA →
REFERRAL KOD (Opsiyonel) ⭐
       ↓
1. Firebase Auth'ta kullanıcı oluştur
2. Referral code varsa, takımı sorguyla bul (INDEX!)
3. User doc oluştur (current_team_id doldur)
4. Referral code varsa:
   a) team_members/{userId} alt doc oluştur
   b) team.members_count +1
   c) team.member_ids ekle
5. Dashboard'a yönlendir
```

### 3. **Dashboard (Ana Ekran)**

#### **İç İçe Progress Bar**
```
┌─────────────────────────────────────┐
│ Günlük Adım Hedefi: 7,500 / 15,000 │
├─────────────────────────────────────┤
│ ╔═════════════════════════════════╗ │ ← Dış (Total) - Mavi
│ ║░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░║ │ ← İç (Dönüştürülen) - Yeşil
│ ║                         50%      ║ │
│ ╚═════════════════════════════════╝ │
├─────────────────────────────────────┤
│ Dönüştürülen: 5,000 adım           │
│ Dönüştürülebilir: 2,500 adım       │ (max 2500)
├─────────────────────────────────────┤
│ [Adımları Hope'e Dönüştür]          │
│  +0.10 Hope kazanabilirsin!         │
└─────────────────────────────────────┘
```

#### **Dönüştürme Kuralları**
```
1. MAX 2500 adım tek seferde
   - 4000 adım varsa → 2500 dönüş, 1500 kalır
   
2. 10 dakika Cooldown
   - Son dönüştürmeden 10 dakika sonra tekrar yapabilir
   - UI'da kalan zaman gösterilir
   
3. Zorunlu Reklam
   - Dönüştürmeden önce Google AdMob reklam gösterisi
   - Reklam tamamlanmazsa dönüştürme iptal
   
4. Dönüştürme Oranı
   - 2500 adım = 0.10 Hope
   - 1 Hope ≈ 25,000 adım
   
5. Gece 00:00 Sıfırlama
   - Günlük adımlar sıfırlanır (Cloud Function)
   - Dönüştürülen adımlar korunur
   - Yeni daily_steps doc oluşturulur (is_reset=true)
```

#### **Grafik (Haftalık)**
```
fl_chart ile 7 günlük adım gösterimi
- X Eksen: Günler (Pazartesi - Pazar)
- Y Eksen: Adım sayısı
- Touch interaksyon ile detay gösterimi
```

### 4. **Bağış Sayfası (Charity)**

```
Vakıf Kartları:
┌─────────────────────┐
│ [Logo]              │
│ Vakıf Adı           │
│ Açıklaması...       │
│ [UMUT OL] Butonu    │
└─────────────────────┘

Bakiye Kontrolü:
- Bakiye < 5 Hope → Uyarı: "Biraz daha adım atmalısın"
                  → Reklam AÇILMAZ
- Bakiye >= 5 Hope → Zorunlu Reklam göster
                  → Reklam OK → Bakiye düş
                  → Bildirim: "Tebrikler! 5 Hope bağışladınız"
```

### 5. **Takım ve Topluluk (Community)**

#### **Takım Kurma**
```
Takım İsmi → Takım Logosu (Galeri) → Referral Kod

Otomatik oluşturma:
1. 6 haneli benzersiz kod oluştur
2. teams doc ekle (referral_code INDEX!)
3. team_members/{leader_uid} ekle
4. leader'ın current_team_id güncelle
```

#### **Takım Detay Sayfası**
```
Üye Görünümü (Herkes Görebilir):
┌──────────────────────────────────┐
│ Üye Adı      │ Günlük Adım │ Hope │
├──────────────────────────────────┤
│ A* Y*        │ 12,500      │ 2.5H │
│ M* A*        │ 8,300       │ 1.2H │
│ E* S*        │ 5,600       │ 0.8H │
└──────────────────────────────────┘

Lider Butonu (Sadece Lider Görür):
[+ Üye Ekle]
  ↓
Kullanıcı aratma (isim/nickname)
Davet Et butonu
```

#### **Üye Davet Sistemi**
```
Lider Akışı:
1. "Üye Ekle" butonuna tıkla
2. İsim/Nickname ile arama yap
3. Sonuç seçip "Davet Et" tıkla
4. Cloud Function çağrılır → notification oluşturulur

Davet Edilen Kişi Akışı:
1. Uygulama bildirimi gelir
2. Dialog açılır: "[Takım Adı] Takımından Davet Aldınız"
3. [Kabul Et] / [Reddet] seçenekleri
4. Kabul → team_members ekle, current_team_id güncelle
5. Reddet → notification.status = 'rejected'
```

### 6. **Sıralama (Leaderboard) - 3 Tab**

**Tab 1: En Çok Dönüştürenler (Bireysel)**
```
1. A* Y*     - 2500 Hope
2. M* A*     - 2100 Hope
3. E* S*     - 1800 Hope
...
(Maskeli isimler, sıra ve Hope tutarı)
```

**Tab 2: En Çok Umut Olanlar (Bireysel)**
```
1. A* Y*     - 500 Hope Bağışladı
2. M* A*     - 380 Hope Bağışladı
3. E* S*     - 290 Hope Bağışladı
...
```

**Tab 3: Takım Sıralaması**
```
1. [Logo] Ümit Gücü       - 1500 Hope Toplamı
2. [Logo] Umut Ayakkabıları - 1200 Hope Toplamı
3. [Logo] Adım Kardeşliği  - 950 Hope Toplamı
...
```

### 7. **Profil ve Ayarlar**

```
KİŞİSEL BİLGİLER
├── Profil Fotoğrafı (Kamera/Galeri)
├── Ad Soyad Düzenle
└── Mevcut Hope Bakiyesi: 15.50 Hope

AYARLAR
├── Şifre Değiştir
├── Tema (Dark/Light Mode)
└── Çıkış Yap

HAREKET GEÇMİŞİ
├── [2024-12-15 14:30] - Eğitim Vakfı - 5.00 Hope
├── [2024-12-14 20:15] - Step Conversion - +0.10 Hope
└── [2024-12-13 09:00] - Yetim Evi - 3.00 Hope
```

---

## ☁️ Cloud Functions Detayları

### **1. createTeam()**
```typescript
INPUT:
  - teamName: string
  - logoUrl?: string

PROCESS:
  1. Benzersiz 6-char referralCode oluştur
  2. Firestore'da referral_code benzersizliğini kontrol et (INDEX!)
  3. teams koleksiyonuna doc ekle
  4. team_members/{leaderUid} alt doc ekle
  5. user.current_team_id = teamId güncelle

OUTPUT:
  {
    success: true,
    teamId: string,
    referralCode: string,
    message: "Takım başarıyla oluşturuldu"
  }

ERROR CASES:
  - unauthenticated: Giriş yapılmamış
  - invalid-argument: teamName < 3 karakter
  - internal: Veritabanı hatası
```

### **2. joinTeamByReferral()**
```typescript
INPUT:
  - referralCode: string

PROCESS:
  1. referral_code ile teams'i sorgula (INDEX!)
  2. Kullanıcı zaten takımda mı kontrol et
  3. Kullanıcı başka takımda mı kontrol et
  4. team_members/{userId} ekle
  5. user.current_team_id = teamId güncelle
  6. team.members_count +1, team.member_ids ekle

OUTPUT:
  {
    success: true,
    teamId: string,
    teamName: string,
    message: "Takıma katıldınız"
  }

ERROR CASES:
  - not-found: Referral code bulunamadı
  - already-exists: Kullanıcı zaten üye
  - invalid-argument: Başka takımda üye
```

### **3. inviteUserToTeam()**
```typescript
INPUT:
  - targetUserNameOrNickname: string
  - teamId: string
  
PROCESS:
  1. Lider kontrolü (teamDoc.leader_uid === context.auth.uid)
  2. Hedef kullanıcıyı bul (full_name veya nickname ile)
  3. Kullanıcı zaten takımda mı kontrol et
  4. notifications doc oluştur (status: pending)
  5. Firebase Messaging notification gönder

OUTPUT:
  {
    success: true,
    notificationId: string,
    message: "Davet gönderildi"
  }

ERROR CASES:
  - not-found: Kullanıcı veya takım bulunamadı
  - permission-denied: Sadece lider davet gönderebilir
  - already-exists: Kullanıcı zaten üye
```

### **4. acceptTeamInvite()**
```typescript
INPUT:
  - notificationId: string
  - teamId: string

PROCESS:
  1. Bildirimi al ve doğrula (status: pending)
  2. team_members/{userId} ekle
  3. user.current_team_id = teamId güncelle
  4. team.members_count +1, team.member_ids ekle
  5. notification.status = 'accepted', responded_at = now

OUTPUT:
  {
    success: true,
    teamId: string,
    message: "Takıma katıldınız"
  }
```

### **5. rejectTeamInvite()**
```typescript
INPUT:
  - notificationId: string

PROCESS:
  1. notification.status = 'rejected'
  2. notification.responded_at = now

OUTPUT:
  {
    success: true,
    message: "Davet reddedildi"
  }
```

---

## 📱 Kayıt Akışı (Sign Up)

```
┌─────────────────────────────────────────────────┐
│             SIGN UP SCREEN                      │
├─────────────────────────────────────────────────┤
│ [Ad Soyad Giriş Alanı]                          │
│ [E-posta Giriş Alanı]                           │
│ [Şifre Giriş Alanı]                             │
│ [Şifre Doğrula Alanı]                           │
│ [REFERRAL KOD (Opsiyonel)] ⭐                   │
├─────────────────────────────────────────────────┤
│        [Kaydı Tamamla Butonu]                   │
└─────────────────────────────────────────────────┘
            ↓
    Validasyon Kontrolleri:
    ✓ Tüm alanlar dolu
    ✓ Ad & Soyad alanları
    ✓ Şifre >= 6 karakter
    ✓ Şifreler uyuşmalı
            ↓
    Firebase Auth.createUserWithEmailAndPassword()
            ↓
        Başarılı
            ↓
    User Doc Oluştur:
    {
      uid: <auth_uid>,
      full_name: "Ahmet Yılmaz",
      masked_name: "A* Y*",
      email: "ahmet@example.com",
      wallet_balance_hope: 0,
      current_team_id: null, // Şimdilik
      theme_preference: "light",
      created_at: now
    }
            ↓
    REFERRAL CODE VAR MI?
       ├─→ EVET
       │    ↓
       │  teams koleksiyonunda ara
       │   (referral_code INDEX!)
       │    ↓
       │  Bulundu → targetTeamId = doc.id
       │    ↓
       │  team_members/{userId} ekle
       │    ↓
       │  teams.members_count +1
       │  teams.member_ids ekle
       │    ↓
       │  user.current_team_id = teamId
       │    ↓
       │  Bulunamadı → Error Dialog
       │
       └─→ HAYIR
            ↓
          Takım yok (OK)
            ↓
        Dashboard'a Yönlendir
            ↓
        Success Snackbar: "Başarıyla kayıt oldunuz..."
```

### **Sign Up Service (Flutter)**

```dart
Future<Map<String, dynamic>> signUpWithReferral({
  required String fullName,
  required String email,
  required String password,
  String? referralCode,
}) async {
  // 1. Firebase Auth
  UserCredential userCredential = 
      await _auth.createUserWithEmailAndPassword(...);
  final userId = userCredential.user!.uid;
  
  // 2. Referral code ile takım ara
  String? targetTeamId;
  if (referralCode != null && referralCode.isNotEmpty) {
    final teamQuery = await _firestore
        .collection('teams')
        .where('referral_code', 
               isEqualTo: referralCode.toUpperCase())
        .limit(1)
        .get();
    
    if (teamQuery.docs.isNotEmpty) {
      targetTeamId = teamQuery.docs[0].id;
    }
  }
  
  // 3. User doc oluştur
  await _firestore.collection('users').doc(userId).set({
    'full_name': fullName,
    'masked_name': UserModel.maskName(fullName),
    'email': email,
    'wallet_balance_hope': 0.0,
    'current_team_id': targetTeamId,
    // ...
  });
  
  // 4. Referral code varsa team_members ekle
  if (targetTeamId != null) {
    final teamDoc = 
        _firestore.collection('teams').doc(targetTeamId);
    
    await teamDoc
        .collection('team_members')
        .doc(userId)
        .set({
      'team_id': targetTeamId,
      'user_id': userId,
      'member_status': 'active',
      // ...
    });
    
    // Team güncelle
    await teamDoc.update({
      'members_count': FieldValue.increment(1),
    });
  }
  
  return {
    'success': true,
    'userId': userId,
    'teamId': targetTeamId,
  };
}
```

---

## 💬 Davet Sistemi

### **Akış Diyagramı**

```
LİDER SAYFASI              DAVET EDİLEN KİŞİ
│                          │
├─ Takım Detay             │
│  └─ [+ Üye Ekle]         │
│     ↓                    │
│  İsim/Nickname Arama     │
│     ↓                    │
│  [Ahmet] → [Davet Et]    │
│     ↓                    │
│  Cloud Function:         │
│  inviteUserToTeam()      │
│     ↓                    │
│  ✅ Davet Gönderildi     ├─────────────→ 📳 Bildirim Alır
│                          │
│                          ├─ Notification Dialog
│                          │  [Ümit Gücü Takımından Davet]
│                          │  [Kabul Et] [Reddet]
│                          │
│                          ├─→ Kabul Et
│                          │    │
│                          │    ├─ acceptTeamInvite() CF
│                          │    │
│                          │    ├─ team_members/{userId} ✅
│                          │    ├─ user.current_team_id ✅
│                          │    ├─ team.members_count +1 ✅
│                          │    │
│                          │    └─ ✅ Takıma Katıldı!
│                          │
│                          └─→ Reddet
│                               │
│                               ├─ rejectTeamInvite() CF
│                               │
│                               └─ notification.status=rejected
```

### **Davet Dialog Widget**

```dart
class TeamInviteDialog extends StatefulWidget {
  final NotificationModel notification;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('🎉 Takım Daveti'),
      content: Column(
        children: [
          Text(notification.teamName),
          Text('${notification.senderName} sizi davet etti'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _rejectInvite,
          child: Text('Reddet'),
        ),
        ElevatedButton(
          onPressed: _acceptInvite,
          child: Text('Kabul Et'),
        ),
      ],
    );
  }
  
  Future<void> _acceptInvite() async {
    final result = await _teamService.acceptTeamInvite(
      notificationId: widget.notification.id,
      teamId: widget.notification.senderTeamId,
    );
    
    if (result['success']) {
      // ✅ Başarı Snackbar
      // Dashboard refresh
      Navigator.pop(context);
    }
  }
}
```

### **Notification Listener (Real-time)**

```dart
class NotificationListener extends StatefulWidget {
  final String userId;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _notificationService
          .getPendingNotificationsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final notifications = snapshot.data;
          
          // Yeni bildirimi otomatik dialog ile göster
          for (var notification in notifications) {
            if (!_displayedNotifications.contains(notification.id)) {
              _displayedNotifications.add(notification.id);
              
              showDialog(
                context: context,
                builder: (_) => TeamInviteDialog(
                  notification: notification,
                  onDismiss: () {
                    _displayedNotifications
                        .remove(notification.id);
                  },
                ),
              );
            }
          }
        }
        return widget.child;
      },
    );
  }
}

// main.dart'ta wrap et:
NotificationListener(
  userId: currentUser.uid,
  child: MyApp(),
)
```

---

## 🚀 Kurulum Talimatları

### **1. Flutter Ortamını Hazırla**

```bash
# Flutter SDK'yı indir ve yükle
flutter --version

# Bağımlılıkları indir
cd bir_adim_umut
flutter pub get
```

### **2. Firebase Projesini Konfigure Et**

```bash
# Firebase CLI'yi kur
npm install -g firebase-tools

# Giriş yap
firebase login

# Proje ID'sini ayarla
firebase init

# Google Services dosyalarını indir
# Android: google-services.json
# iOS: GoogleService-Info.plist
```

### **3. Cloud Functions'ı Deploy Et**

```bash
cd firebase_functions/functions

# Bağımlılıkları indir
npm install

# TypeScript'i derle
npm run build

# Deploy et
firebase deploy --only functions
```

### **4. Firestore Veritabanını Hazırla**

```bash
# Güvenlik kurallarını deploy et
firebase deploy --only firestore:rules

# Indexleri oluştur:
# - teams(referral_code) - UNIQUE
# - daily_steps(user_id, date) DESC
# - users(current_team_id)
```

### **5. Uygulamayı Çalıştır**

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# Web (Test için)
flutter run -d chrome
```

---

## 📚 Dosya Açıklamaları

| Dosya | Amaç |
|-------|------|
| `user_model.dart` | Kullanıcı veri modeli |
| `team_model.dart` | Takım veri modeli |
| `team_member_model.dart` | Takım üyesi veri modeli |
| `notification_model.dart` | Bildirim veri modeli |
| `activity_log_model.dart` | Aktivite kaydı veri modeli |
| `daily_step_model.dart` | Günlük adım veri modeli |
| `auth_service.dart` | Giriş/Kayıt servis |
| `team_service.dart` | Takım işlemleri servis |
| `notification_service.dart` | Bildirim yönetimi servis |
| `activity_log_service.dart` | Bağış ve aktivite servis |
| `step_service.dart` | Adım senkronizasyon servis |
| `team_invite_dialog.dart` | Davet dialog widget |
| `nested_progress_bar.dart` | Progress bar widget |
| `sign_up_screen.dart` | Kayıt ekranı |
| `index.ts` | Cloud Functions |

---

## 🔒 Güvenlik Notları

1. **Firestore Security Rules**: Public'ten okuma yapılabileceğini düşünerek tasarla (sıralama vs)
2. **Cloud Functions**: Kimlik doğrulama kontrolünü her fonksiyonda yap
3. **Referral Codes**: Benzersiz ve case-insensitive
4. **Masked Names**: Sıralamada gerçek isimleri gösterme
5. **Push Tokens**: device_tokens döndürüyü güzel yönet

---

## 📞 Destek ve Katkı

Bu proje "Bir Adım Umut" sosyal sorumluluk projesinin mobil uygulaması olarak geliştirilmiştir.

Sorular ve öneriler için lütfen iletişime geçiniz.

---

**Son güncelleme:** Aralık 2024
