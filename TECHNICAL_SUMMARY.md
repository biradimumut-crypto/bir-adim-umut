# 📊 Bir Adım Umut - Teknik Özet (Technical Summary)

## 🎯 Proje Özeti

"Bir Adım Umut", insanların adımlarını Hope puanlarına dönüştürdüğü ve vakıflara bağış yaparak sosyal sorumluluk kazandığı, takımlı ve kompetitif bir mobil uygulamadır.

---

## 1️⃣ TAKIM MANTIGI (Team Logic)

### **A. Takım Oluşturma Akışı**

```typescript
// Cloud Function: createTeam()

INPUT:
{
  teamName: "Ümit Gücü",
  logoUrl: "https://..."  // Optional
}

PROCESS:
1. Benzersiz 6-karakterli referral code oluştur
   generateReferralCode() → "ABC123"
   
2. Firestore'da uniqueness check (Composite Index!)
   db.collection("teams")
     .where("referral_code", "==", "ABC123")
     .get() → empty? → continue
     
3. teams/{teamId} doc oluştur:
   {
     name: "Ümit Gücü",
     logo_url: "https://...",
     referral_code: "ABC123",          // UNIQUE INDEX!
     leader_uid: "user123",
     members_count: 1,
     total_team_hope: 0,
     created_at: Timestamp.now(),
     member_ids: ["user123"]
   }
   
4. team_members/{leaderUid} alt doc oluştur:
   {
     team_id: "team123",
     user_id: "user123",
     member_status: "active",
     join_date: Timestamp.now(),
     member_total_hope: 0,
     member_daily_steps: 0
   }
   
5. users/user123 güncelle:
   current_team_id: "team123"

OUTPUT:
{
  success: true,
  teamId: "team123",
  referralCode: "ABC123",
  message: "Takım başarıyla oluşturuldu"
}
```

### **B. Referral Kodu ile Takıma Katılma**

```typescript
// Cloud Function: joinTeamByReferral()

INPUT:
{
  referralCode: "ABC123"  // User giriş yaptığı kod
}

VALIDATIONS:
1. User authenticated? ✓
2. Referral code exists?
   db.collection("teams")
     .where("referral_code", "==", "ABC123".toUpperCase())
     → Found: teamData
   
3. User already in this team?
   teamRef.collection("team_members").doc(userId).get()
   → !exists? ✓ Continue
   
4. User already in another team?
   db.collection("users").doc(userId).get()
   → current_team_id == null? ✓ Continue

PROCESS:
1. team_members/{userId} ekle:
   {
     team_id: "team123",
     user_id: "user456",
     member_status: "active",
     join_date: Timestamp.now(),
     member_total_hope: 0,
     member_daily_steps: 0
   }
   
2. users/user456 güncelle:
   current_team_id: "team123"
   
3. teams/team123 güncelle:
   {
     members_count: FieldValue.increment(1),
     member_ids: ArrayUnion(["user456"])
   }

OUTPUT:
{
  success: true,
  teamId: "team123",
  teamName: "Ümit Gücü",
  message: "Başarıyla Ümit Gücü takımına katıldınız"
}
```

### **C. Kullanıcı Davet Sistemi (Team Invites)**

```typescript
// Cloud Function: inviteUserToTeam()

INPUT:
{
  targetUserNameOrNickname: "Ahmet Yılmaz",
  teamId: "team123"
}

VALIDATIONS:
1. Requester is team leader?
   db.collection("teams").doc("team123").get()
   → leader_uid == request.auth.uid? ✓
   
2. Target user exists?
   // Search by full_name
   db.collectionGroup("users")
     .where("full_name", "==", "Ahmet Yılmaz")
     .get() → targetUserId: "user789"
     
   // OR Search by nickname
   db.collectionGroup("users")
     .where("nickname", "==", "ahmetyilmaz")
     .get() → targetUserId: "user789"
   
3. Target user already in team?
   teamRef.collection("team_members").doc("user789").get()
   → !exists? ✓ Continue

PROCESS:
1. users/user789/notifications/{notificationId} oluştur:
   {
     id: uuid(),
     receiver_uid: "user789",
     sender_team_id: "team123",
     notification_type: "team_invite",
     notification_status: "pending",     // IMPORTANT
     created_at: Timestamp.now(),
     responded_at: null,
     sender_name: "Lider Adı",            // Cache
     team_name: "Ümit Gücü"               // Cache
   }
   
2. Firebase Messaging notification gönder:
   admin.messaging().sendMulticast({
     tokens: user789DeviceTokens,
     notification: {
       title: "Ümit Gücü Takımından Davet",
       body: "Lider Adı sizi takıma davet etti"
     },
     data: {
       teamId: "team123",
       notificationId: notificationId,
       type: "team_invite"
     }
   })

OUTPUT:
{
  success: true,
  notificationId: "notif123",
  message: "Davet gönderildi"
}
```

---

## 2️⃣ KAYIT AKIŞI (Sign Up with Referral)

```dart
// Flutter: auth_service.dart
// Function: signUpWithReferral()

INPUT:
{
  fullName: "Ahmet Yılmaz",
  email: "ahmet@example.com",
  password: "123456",
  referralCode: "ABC123"  // Optional
}

PROCESS:

1️⃣ FIREBASE AUTH USER OLUŞTUR
   userCredential = await auth.createUserWithEmailAndPassword(
     email: email,
     password: password
   )
   userId = userCredential.user.uid

2️⃣ REFERRAL CODE KONTROL
   if (referralCode != null && referralCode.isNotEmpty) {
     teamsQuery = await firestore
       .collection('teams')
       .where('referral_code', 
              isEqualTo: referralCode.toUpperCase())
       .limit(1)
       .get()
     
     if (teamsQuery.docs.isNotEmpty) {
       targetTeamId = teamsQuery.docs[0].id
       // Team bulundu!
     } else {
       // Team bulunamadı → Error göster
       throw Exception("Referral kod geçersiz")
     }
   }

3️⃣ USER DOC OLUŞTUR
   maskedName = UserModel.maskName(fullName)
   // "Ahmet Yılmaz" → "A* Y*"
   
   firestore.collection('users').doc(userId).set({
     full_name: "Ahmet Yılmaz",
     masked_name: "A* Y*",
     nickname: null,
     email: "ahmet@example.com",
     profile_image_url: null,
     wallet_balance_hope: 0.0,
     current_team_id: targetTeamId,  // null veya teamId
     theme_preference: "light",
     created_at: Timestamp.now(),
     last_step_sync_time: null,
     device_tokens: []
   })

4️⃣ EĞER REFERRAL CODE VARSA → TAKIMA EKLE
   if (targetTeamId != null) {
     teamDoc = firestore.collection('teams')
       .doc(targetTeamId)
     
     // 4a. team_members altında ekle
     teamDoc.collection('team_members')
       .doc(userId)
       .set({
         team_id: targetTeamId,
         user_id: userId,
         member_status: "active",
         join_date: Timestamp.now(),
         member_total_hope: 0.0,
         member_daily_steps: 0
       })
     
     // 4b. Team'i güncelle
     teamData = teamDoc.get().data()
     newMemberIds = [...teamData['member_ids'], userId]
     
     teamDoc.update({
       members_count: FieldValue.increment(1),
       member_ids: newMemberIds
     })
   }

5️⃣ RETURN
   return {
     'success': true,
     'userId': userId,
     'teamId': targetTeamId,
     'message': targetTeamId != null
       ? 'Başarıyla kayıt oldunuz ve takıma katıldınız!'
       : 'Başarıyla kayıt oldunuz!'
   }
```

### **Sign Up Screen UI Flow**

```
┌───────────────────────────────┐
│   KAYDALı EKRANI              │
├───────────────────────────────┤
│ Ad Soyad: [Ahmet Yılmaz      ]│
│ E-posta:  [ahmet@example.com ]│
│ Şifre:    [••••••••••        ]│
│ Doğrula:  [••••••••••        ]│
│ Ref. Kod: [ABC123     ]       │ ← OPSİYONEL
│           (Arkadaş Takım Kodu)│
├───────────────────────────────┤
│    [Kaydı Tamamla]            │
└───────────────────────────────┘
           ↓
    Validasyon ✓
           ↓
  auth.createUserWithEmailAndPassword()
           ↓
    Referral sorgusu (varsa)
           ↓
      User Doc oluştur
           ↓
  Takıma ekle (varsa referral)
           ↓
  ✅ Başarı Mesajı
           ↓
  Dashboard'a Yönlendir
```

---

## 3️⃣ DAVET SİSTEMİ (Invitation System)

### **Davet Gönderme**

```
LİDER
  ↓
[Takım Detay Sayfası]
  ↓
[+ Üye Ekle] Butonu
  ↓
[İsim/Nickname Arama] Dialog
  ↓
[Ahmet Yılmaz] sonuç seçi
  ↓
[Davet Et] Butonu
  ↓
inviteUserToTeam() Cloud Function
  ↓
✅ Bildirim oluşturuldu
  ↓
Push Notification gönderildi
```

### **Davet Alma ve İşleme**

```
DAVETEdİLEN KİŞİ
  ↓
📱 Push Notification Alır
   "Ümit Gücü Takımından Davet"
  ↓
[Dialog Açılır]
┌──────────────────────────────┐
│ 🎉 Takım Daveti             │
├──────────────────────────────┤
│ Ümit Gücü                    │
│ Lider Adı sizi davet etti    │
├──────────────────────────────┤
│ [Reddet]  [Kabul Et]         │
└──────────────────────────────┘
   ↓          ↓
REDDET    KABUL ET
   ↓          ↓
[Reddedildi]  acceptTeamInvite()
              Cloud Function
                 ↓
          ✅ Takıma Katıldı
```

### **Davet Kabul Etme Detayları**

```typescript
// Cloud Function: acceptTeamInvite()

INPUT:
{
  notificationId: "notif123",
  teamId: "team123"
}

PROCESS:

1️⃣ NOTIFICATION DOĞRULA
   notifDoc = firestore
     .collection('users').doc(userId)
     .collection('notifications').doc(notificationId)
   
   if (!notifDoc.exists) throw NotFound
   
   notifData = notifDoc.data()
   if (notifData.notification_status != 'pending')
     throw AlreadyResponded

2️⃣ TEAM DOĞRULA
   teamDoc = firestore.collection('teams').doc(teamId)
   if (!teamDoc.exists) throw NotFound
   
   teamData = teamDoc.data()

3️⃣ TEAM_MEMBERS'A EKLE
   teamDoc.collection('team_members').doc(userId).set({
     team_id: teamId,
     user_id: userId,
     member_status: "active",
     join_date: Timestamp.now(),
     member_total_hope: 0.0,
     member_daily_steps: 0
   })

4️⃣ USER GÜNCELLE
   firestore.collection('users').doc(userId).update({
     current_team_id: teamId
   })

5️⃣ TEAM GÜNCELLE
   newMemberIds = [...teamData.member_ids, userId]
   
   teamDoc.update({
     members_count: FieldValue.increment(1),
     member_ids: newMemberIds
   })

6️⃣ NOTIFICATION GÜNCELLE
   notifDoc.update({
     notification_status: "accepted",
     responded_at: Timestamp.now()
   })

OUTPUT:
{
  success: true,
  teamId: "team123",
  message: "Ümit Gücü takımına başarıyla katıldınız"
}
```

---

## 4️⃣ ADIM DÖNÜŞTÜRME VE HOPE (Steps ↔ Hope)

### **Dönüştürme Kuralları**

```
1. MAKSIMUM ADIM
   Max 2500 adım tek seferde
   
   Örnek:
   ├─ 2000 adımınız varsa → 2000 dönüş, 0 kalır
   ├─ 2500 adımınız varsa → 2500 dönüş, 0 kalır
   ├─ 4000 adımınız varsa → 2500 dönüş, 1500 kalır
   └─ 5000 adımınız varsa → 2500 dönüş, 2500 kalır

2. CONVERSION RATIO (Dönüştürme Oranı)
   2500 adım = 0.10 Hope
   25000 adım = 1.00 Hope
   
   Formula: Hope = (adım / 2500) * 0.10

3. COOLDOWN (Bekleme Süresi)
   10 dakika bekleme
   
   Son dönüştürmeden 10 dakika sonra
   tekrar dönüştürebilir
   
   UI'da kalan süre gösterilir:
   "Sonraki dönüştürmeye 5 dakika kaldı"

4. ZORUNLU REKLAM
   Dönüştürmeden ÖNCE reklam izlemek zorunlu
   
   Akış:
   ├─ [Dönüştür] Butonu tıkla
   ├─ Google AdMob reklam başla
   ├─ Reklam tamamlandı?
   │  ├─ YES → Dönüştürme gerçekleş
   │  └─ NO → Dönüştürme iptal
   └─ ✅/❌ Sonuç

5. GECE 00:00 SIFLRLAMA
   Günlük adımlar sıfırlanır (Cloud Function)
   Dönüştürülen adımlar korunur
   
   Örnek:
   Bugün: 15000 adım, 5000 dönüştürüldü
   Yarın 00:00: 0 adım, 0 dönüştürüldü (yeni gün)
   
   Cloud Function (Scheduled):
   - Tüm daily_steps docs oku
   - Dünün is_reset=true yap
   - Bugün için yeni doc oluştur (total=0, converted=0)
```

### **Dönüştürme Servisi (Flutter)**

```dart
// step_service.dart
Future<Map<String, dynamic>> createStepConversionLog({
  required int stepsToConvert,
}) async {
  
  // 1. Validasyon
  if (stepsToConvert > 2500) {
    return {
      'success': false,
      'error': 'Max 2500 adım dönüştürebilirsiniz'
    };
  }
  
  // 2. Hope miktarını hesapla
  double hopeAmount = (stepsToConvert / 2500) * 0.10;
  // 2500 → 0.10 Hope
  // 1250 → 0.05 Hope
  // 500  → 0.02 Hope
  
  // 3. Activity log oluştur
  firestore.collection('users')
    .doc(userId)
    .collection('activity_logs')
    .doc()
    .set({
      'user_id': userId,
      'action_type': 'step_conversion',
      'target_name': 'Adım Dönüştürme',
      'amount': hopeAmount,
      'steps_converted': stepsToConvert,
      'timestamp': Timestamp.now()
    });
  
  // 4. Kullanıcı Hope bakiyesini güncelle
  firestore.collection('users').doc(userId).update({
    'wallet_balance_hope': FieldValue.increment(hopeAmount)
  });
  
  // 5. Günlük adım verisi güncelle
  String stepDocId = '$userId-${DateTime.now().toIso8601String().split('T')[0]}';
  
  firestore.collection('daily_steps').doc(stepDocId).set({
    'user_id': userId,
    'converted_steps': FieldValue.increment(stepsToConvert),
    'last_conversion_time': Timestamp.now()
  }, SetOptions(merge: true));
  
  // 6. Takım üyesinin Hope'ünü güncelle (varsa)
  String? teamId = userDoc.data()['current_team_id'];
  if (teamId != null) {
    firestore.collection('teams').doc(teamId)
      .collection('team_members').doc(userId)
      .update({
        'member_total_hope': FieldValue.increment(hopeAmount)
      });
    
    // Takımın toplam Hope'ünü güncelle
    firestore.collection('teams').doc(teamId).update({
      'total_team_hope': FieldValue.increment(hopeAmount)
    });
  }
  
  return {
    'success': true,
    'hopeGenerated': hopeAmount,
    'message': '✅ $stepsToConvert adım dönüştürüldü. +$hopeAmount Hope!'
  };
}

// COOLDOWN KONTROL
Future<bool> canConvertSteps() async {
  DailyStepModel? today = await getTodayDailyStepModel();
  if (today == null) return true;
  
  Duration difference = DateTime.now()
    .difference(today.lastConversionTime);
  
  return difference.inMinutes >= 10;
}

// KALAN ZAMANı AL
Future<int> getTimeUntilNextConversion() async {
  DailyStepModel? today = await getTodayDailyStepModel();
  if (today == null) return 0;
  
  Duration difference = DateTime.now()
    .difference(today.lastConversionTime);
  
  int remainingMinutes = 10 - difference.inMinutes;
  return remainingMinutes > 0 ? remainingMinutes : 0;
}
```

---

## 5️⃣ BAĞIŞ SİSTEMİ (Donation System)

### **Bağış Yapma Akışı**

```
[CHARITY SAYFASI]
  ├─ Vakıf Kartı 1
  │  ├─ [Logo]
  │  ├─ Vakıf Adı
  │  ├─ Açıklama
  │  └─ [UMUT OL] Butonu ← Tıkla
  │
  ├─ Vakıf Kartı 2
  │  └─ [UMUT OL] Butonu
  │
  └─ Vakıf Kartı 3
     └─ [UMUT OL] Butonu

[UMUT OL] TIKLANDıĞıNDA:
  ↓
BAKIYE KONTROL
  ├─ Bakiye < 5 Hope?
  │  ├─ EVET → ⚠️ Uyarı Dialog
  │  │  "Daha fazla adım atmalısın"
  │  │  Reklam AÇILMAZ ❌
  │  │  [Kapat] Butonu
  │  │
  │  └─ HAYIR → Google AdMob Reklam
  │     ↓
  │     Reklam tamamlandı?
  │     ├─ EVET → createDonationLog() çağrı
  │     │  ↓
  │     │  activity_logs oluştur
  │     │  user.wallet_balance_hope -= 5 Hope
  │     │  team.total_team_hope += 5 Hope
  │     │  teamMember.member_total_hope += 5 Hope
  │     │  ↓
  │     │  ✅ Başarı Mesajı
  │     │  "5 Hope bağışladınız!"
  │     │
  │     └─ HAYIR → Bağış İptal ❌
```

### **Bağış Servis (Flutter)**

```dart
// activity_log_service.dart
Future<Map<String, dynamic>> createDonationLog({
  required String charityName,
  required double hopeAmount,
  String? charityLogoUrl,
}) async {
  
  // 1. BAKIYE KONTROL
  UserModel? user = await getCurrentUser();
  double currentBalance = user?.walletBalanceHope ?? 0;
  
  if (currentBalance < hopeAmount) {
    return {
      'success': false,
      'error': 'Yetersiz bakiye',
      'currentBalance': currentBalance
    };
  }
  
  // 2. ACTIVITY LOG OLUŞTUR
  firestore.collection('users').doc(userId)
    .collection('activity_logs').doc().set({
      'user_id': userId,
      'action_type': 'donation',
      'target_name': charityName,
      'amount': hopeAmount,
      'timestamp': Timestamp.now(),
      'charity_logo_url': charityLogoUrl
    });
  
  // 3. BAKIYE GÜNCELLE
  firestore.collection('users').doc(userId).update({
    'wallet_balance_hope': FieldValue.increment(-hopeAmount)
  });
  
  // 4. TAKIMI GÜNCELLE (Varsa)
  String? teamId = user?.currentTeamId;
  if (teamId != null) {
    // Team'in toplam Hope'ünü güncelle
    firestore.collection('teams').doc(teamId).update({
      'total_team_hope': FieldValue.increment(hopeAmount)
    });
    
    // Team member'ın Hope'ünü güncelle
    firestore.collection('teams').doc(teamId)
      .collection('team_members').doc(userId)
      .update({
        'member_total_hope': FieldValue.increment(hopeAmount)
      });
  }
  
  return {
    'success': true,
    'message': '✅ $charityName\'a $hopeAmount Hope bağışladınız!',
    'newBalance': currentBalance - hopeAmount
  };
}
```

---

## 📚 VERİTABANı SORGU ÖRNEKLERİ

### **1. Kullanıcının Takım Üyelerini Al**

```dart
Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
  final teamDoc = firestore.collection('teams').doc(teamId);
  final membersSnapshot = await teamDoc
    .collection('team_members')
    .get();
  
  List<Map<String, dynamic>> members = [];
  
  for (var memberDoc in membersSnapshot.docs) {
    final userId = memberDoc.data()['user_id'];
    final userDoc = await firestore
      .collection('users').doc(userId).get();
    
    members.add({
      'userId': userId,
      'userName': userDoc.data()?['full_name'],
      'maskedName': userDoc.data()?['masked_name'],
      'dailySteps': memberDoc.data()['member_daily_steps'],
      'totalHope': memberDoc.data()['member_total_hope']
    });
  }
  
  return members;
}
```

### **2. Sıralama - En Çok Bağış Yapanlar**

```dart
// Sıralamada maskeli isimler kullanılır
Stream<List<Map<String, dynamic>>> getDonationLeaderboard() {
  return firestore
    .collection('donation_leaderboard')
    .orderBy('total_hope_donated', descending: true)
    .limit(100)
    .snapshots()
    .map((snapshot) {
      return snapshot.docs.map((doc) => {
        'rank': snapshot.docs.indexOf(doc) + 1,
        'maskedName': doc.data()['masked_name'],
        'totalHope': doc.data()['total_hope_donated']
      }).toList();
    });
}
```

### **3. Takım Sıralaması**

```dart
Stream<List<TeamModel>> getTeamLeaderboard() {
  return firestore
    .collection('teams')
    .orderBy('total_team_hope', descending: true)
    .limit(100)
    .snapshots()
    .map((snapshot) {
      return snapshot.docs
        .map((doc) => TeamModel.fromFirestore(doc))
        .toList();
    });
}
```

### **4. Kullanıcının Aktivite Geçmişi**

```dart
Stream<List<ActivityLogModel>> getUserActivityHistory(String userId) {
  return firestore
    .collection('users')
    .doc(userId)
    .collection('activity_logs')
    .orderBy('timestamp', descending: true)
    .limit(50)
    .snapshots()
    .map((snapshot) {
      return snapshot.docs
        .map((doc) => ActivityLogModel.fromFirestore(doc))
        .toList();
    });
}

// Örnek çıktı:
// [2024-12-15 14:30] Eğitim Vakfı'na 5.00 Hope bağışladı
// [2024-12-14 20:15] 2500 adımı 0.10 Hope'e dönüştürdü
// [2024-12-13 09:00] Yetim Evine 3.00 Hope bağışladı
```

---

## 🔐 Güvenlik Özeti

| Konu | Güvenlik Önlemi |
|------|-----------------|
| **Authentication** | Firebase Auth (Email/Password, Social Login) |
| **Authorization** | Firestore Security Rules (Row-level) |
| **Data Privacy** | Masked Names (Sıralamada) |
| **Referral Codes** | UNIQUE Composite Index |
| **Transactions** | Atomic updates (FieldValue.increment) |
| **Device Tokens** | Güvenli saklanır, GDPR compliant |
| **User Data** | TLS encrypted, Firestore encrypted at rest |

---

## 📈 Scalability

```
Daily Active Users: 10,000+
├─ Step syncing: 100k writes/day
├─ Conversions: 50k writes/day
├─ Donations: 10k writes/day
└─ Notifications: 5k writes/day

Firestore Optimization:
├─ Composite Indexes (referral_code, user_id+date)
├─ Collection sharding (daily_steps)
├─ Batch writes (bulk operations)
└─ Read replicas (leaderboards)
```

---

## 🎮 Kullanıcı Senaryoları

### **Senaryo 1: Yeni Kullanıcı Kayıt**
1. Sign Up Screen'e gider
2. Ad, e-posta, şifre girer
3. Arkadaşının referral kodunu girer: "ABC123"
4. [Kaydı Tamamla] tıklar
5. ✅ "Ümit Gücü" takımına otomatik eklenir

### **Senaryo 2: Davet Alma ve Kabul**
1. Push notification alır: "Ümit Gücü Takımından Davet"
2. Dialog açılır
3. [Kabul Et] tıklar
4. ✅ Takımın üyesi olur
5. Takım üyeleri listesine eklenir

### **Senaryo 3: Adım Dönüştürme**
1. Dashboard'da Progress Bar görür (8000/15000 adım)
2. [Adımları Hope'e Dönüştür] butonu tıklar
3. Google AdMob reklam açılır
4. Reklam tamamlanır
5. ✅ 2500 adım dönüştürülür, +0.10 Hope kazanır
6. Cooldown aktif: "10 dakika beklemelisiniz"

### **Senaryo 4: Bağış Yapma**
1. Charity sayfasına gider
2. "Eğitim Vakfı" kartının [UMUT OL] butonuna tıklar
3. Bakiye kontrolü: 15 Hope var (5 Hope gerekli)
4. Google AdMob reklam açılır
5. Reklam tamamlanır
6. ✅ 5 Hope bağışlanır
7. "Tebrikler! Eğitim Vakfı'na 5 Hope bağışladınız"
8. Activity log'a kaydedilir
9. Takım sıralaması güncellenir

---

## 🚀 Dağıtım (Deployment)

```bash
# 1. Cloud Functions deploy
cd firebase_functions/functions
npm install
npm run build
firebase deploy --only functions

# 2. Firestore Rules deploy
firebase deploy --only firestore:rules

# 3. Flutter build
flutter build apk      # Android
flutter build ios      # iOS
flutter build web      # Web (Test)

# 4. Release stores'a yükle
# Google Play Store, Apple App Store
```

---

**Son Güncelleme:** Aralık 2024 | Versiyon: 1.0.0
