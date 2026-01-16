# DENETİM KANIT PAKETİ v1 - EK: 3 KRİTİK AKIŞ

**Oluşturma Tarihi:** 2025-01-16  
**Proje:** bir-adim-umut (OneHopeStep)  
**Amaç:** 3 kritik akış için detaylı kanıt

> ⚠️ Bu belge yorum, risk değerlendirmesi veya öneri içermez. Sadece "nerede-ne var" formatında kanıt sunar.

---

## A) STEP → HOPE CONVERSION KANITI

### A.1 Ana Dönüşüm Fonksiyonları

**Dosya:** [lib/services/step_conversion_service.dart](lib/services/step_conversion_service.dart)

#### convertSteps() - Satır 416-510
```dart
  /// Adımları Hope'a dönüştür
  Future<Map<String, dynamic>> convertSteps({
    required String userId,
    required int steps,
    required double hopeEarned,
    bool isBonus = false, // 2x bonus dönüşümü mü?
  }) async {
    final today = _getTodayKey();
    final batch = _firestore.batch();

    try {
      // 0. Device kontrolü - Fraud önleme
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final deviceCheck = await _deviceService.canSyncSteps(userId, userEmail: userEmail);
      if (deviceCheck['canSync'] != true) {
        print('⚠️ Device fraud engellendi: ${deviceCheck['reason']}');
        return {
          'success': false,
          'error': 'device_already_used',
          'message': 'Bu cihaz bugün başka bir hesapla kullanıldı. Her cihaz günde sadece bir hesapla adım dönüştürebilir.',
          'ownerId': deviceCheck['ownerId'],
        };
      }

      // 1. Daily steps güncelle
      final stepRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(today);

      // 2x bonus dönüşüm sayısını da kaydet
      final updateData = {
        'converted_steps': FieldValue.increment(steps),
        'last_conversion_time': Timestamp.now(),
      };
      if (isBonus) {
        updateData['bonus_conversion_count'] = FieldValue.increment(1);
        updateData['bonus_steps_converted'] = FieldValue.increment(steps);
      }
      batch.update(stepRef, updateData);

      // 2. User wallet güncelle
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'wallet_balance_hope': FieldValue.increment(hopeEarned),
        'lifetime_converted_steps': FieldValue.increment(steps),
        'lifetime_earned_hope': FieldValue.increment(hopeEarned),
      });

      // 3. Activity log ekle - 2x bonus bilgisi dahil
      final now = Timestamp.now();
      
      // Global activity_logs
      final logRef = _firestore.collection('activity_logs').doc();
      batch.set(logRef, {
        'user_id': userId,
        'activity_type': isBonus ? 'step_conversion_2x' : 'step_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': isBonus,
        'created_at': now,
        'timestamp': now,
      });
      
      // User subcollection activity_logs
      final userLogRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
      batch.set(userLogRef, {
        'user_id': userId,
        'activity_type': isBonus ? 'step_conversion_2x' : 'step_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': isBonus,
        'created_at': now,
        'timestamp': now,
      });

      await batch.commit();

      // 4. Takım üyesi günlük adımını güncelle (eğer takımda ise)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final teamId = userDoc.data()?['current_team_id'];
      if (teamId != null) {
        await _firestore
            .collection('teams')
            .doc(teamId)
            .collection('team_members')
            .doc(userId)
            .update({
          'member_daily_steps': FieldValue.increment(steps),
        });
      }

      // 🎖️ Lifetime adımları güncelle ve rozet kontrol et
      await _badgeService.updateLifetimeSteps(steps);

      return {'success': true, 'hopeEarned': hopeEarned};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
```

#### convertCarryOverSteps() - Satır 190-275
```dart
  /// Taşınan adımları dönüştür (sadece carryover_pending'den)
  Future<Map<String, dynamic>> convertCarryOverSteps({
    required String userId,
    required int steps,
    required double hopeEarned,
  }) async {
    // Device kontrolü - Fraud önleme
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    final deviceCheck = await _deviceService.canSyncSteps(userId, userEmail: userEmail);
    if (deviceCheck['canSync'] != true) {
      print('⚠️ Device fraud engellendi (carryover): ${deviceCheck['reason']}');
      return {
        'success': false,
        'error': 'device_already_used',
        'message': 'Bu cihaz bugün başka bir hesapla kullanıldı.',
        'ownerId': deviceCheck['ownerId'],
      };
    }

    final batch = _firestore.batch();

    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final userData = userDoc.data();
      
      // carryover_pending'den düş
      final currentPending = userData?['carryover_pending'] ?? 0;
      final pendingInt = (currentPending is int) ? currentPending : (currentPending as num).toInt();
      
      if (pendingInt < steps) {
        return {'success': false, 'error': 'Yetersiz carryover adımı'};
      }
      
      batch.update(userRef, {
        'carryover_pending': pendingInt - steps,
        'carryover_converted': FieldValue.increment(steps),
        'wallet_balance_hope': FieldValue.increment(hopeEarned),
        'lifetime_converted_steps': FieldValue.increment(steps),
        'lifetime_earned_hope': FieldValue.increment(hopeEarned),
      });

      // Activity log ekle
      final now = Timestamp.now();
      
      // Global
      final logRef = _firestore.collection('activity_logs').doc();
      batch.set(logRef, {
        'user_id': userId,
        'activity_type': 'carryover_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': false,
        'created_at': now,
        'timestamp': now,
      });
      
      // User subcollection
      final userLogRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
      batch.set(userLogRef, {
        'user_id': userId,
        'activity_type': 'carryover_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': false,
        'created_at': now,
        'timestamp': now,
      });

      await batch.commit();
      return {'success': true, 'hopeEarned': hopeEarned};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
```

---

### A.2 UI Çağrı Noktaları

| Fonksiyon | Çağrıldığı Dosya | Satır |
|-----------|------------------|-------|
| `convertSteps()` | [lib/screens/dashboard/dashboard_screen.dart](lib/screens/dashboard/dashboard_screen.dart) | 2952 |
| `convertSteps()` (2x bonus) | [lib/screens/dashboard/dashboard_screen.dart](lib/screens/dashboard/dashboard_screen.dart) | 3007 |
| `convertCarryOverSteps()` | [lib/screens/dashboard/dashboard_screen.dart](lib/screens/dashboard/dashboard_screen.dart) | 3063 |
| `StepConversionService()` instance | [lib/screens/dashboard/dashboard_screen.dart](lib/screens/dashboard/dashboard_screen.dart) | 34 |

**dashboard_screen.dart Satır 2952-2965 (Normal Conversion):**
```dart
final result = await _stepService.convertSteps(
  userId: uid,
  steps: convertAmount,
  hopeEarned: hopeEarned,
);
```

**dashboard_screen.dart Satır 3007-3012 (2x Bonus Conversion):**
```dart
final result = await _stepService.convertSteps(
  userId: uid,
  steps: convertAmount,
  hopeEarned: hopeEarned,
  isBonus: true, // 2x BONUS dönüşümü
);
```

**dashboard_screen.dart Satır 3063-3068 (Carryover Conversion):**
```dart
final result = await _stepService.convertCarryOverSteps(
  userId: uid,
  steps: convertAmount,
  hopeEarned: hopeEarned,
);
```

---

### A.3 Firestore Yazma İşlemleri Tablosu

| Path Pattern | Fields Written | Dosya | Satır |
|--------------|----------------|-------|-------|
| `users/{uid}/daily_steps/{dateKey}` | `converted_steps`, `last_conversion_time`, `bonus_conversion_count`, `bonus_steps_converted` | step_conversion_service.dart | 443-453 |
| `users/{uid}` | `wallet_balance_hope`, `lifetime_converted_steps`, `lifetime_earned_hope` | step_conversion_service.dart | 457-461 |
| `activity_logs/{docId}` | `user_id`, `activity_type`, `steps_converted`, `hope_earned`, `is_bonus`, `created_at`, `timestamp` | step_conversion_service.dart | 466-475 |
| `users/{uid}/activity_logs/{docId}` | `user_id`, `activity_type`, `steps_converted`, `hope_earned`, `is_bonus`, `created_at`, `timestamp` | step_conversion_service.dart | 478-487 |
| `teams/{teamId}/team_members/{uid}` | `member_daily_steps` | step_conversion_service.dart | 494-502 |
| `users/{uid}` (carryover) | `carryover_pending`, `carryover_converted`, `wallet_balance_hope`, `lifetime_converted_steps`, `lifetime_earned_hope` | step_conversion_service.dart | 223-229 |

---

### A.4 Aynı Gün/Aynı Adım Çift Dönüşüm Kontrolü

**BULUNAMADI**

Açıklama: Kod taramasında `converted_steps >= daily_steps` veya benzeri bir kontrol tespit edilmedi. Mevcut akış:

1. `_remainingSteps = _dailySteps - _convertedSteps` hesaplanıyor
   - **Dosya:** [lib/screens/dashboard/dashboard_screen.dart](lib/screens/dashboard/dashboard_screen.dart#L639-L640)
   
2. Ekstra güvenlik kontrolü (client-side):
   ```dart
   // Satır 636-640
   if (_convertedSteps > _dailySteps) {
     _convertedSteps = _dailySteps;
   }
   _remainingSteps = _dailySteps - _convertedSteps;
   if (_remainingSteps < 0) _remainingSteps = 0;
   ```

3. **Server-side/Rules kontrolü:** BULUNAMADI
   - `step_conversion_service.dart` içinde `converted_steps` değerinin `daily_steps` değerini aşıp aşmadığını kontrol eden kod yok
   - `firestore.rules` içinde bu kontrolü yapan kural yok

---

## B) MONTHLY HOPE + ADMOB REVENUE JOB KANITI

### B.1 Month Key Belirleme

**Dosya:** [firebase_functions/functions/src/monthly-hope-calculator.ts](firebase_functions/functions/src/monthly-hope-calculator.ts)

**Satır 33-41:**
```typescript
export const calculateMonthlyHopeValue = functions.pubsub
  .schedule("0 8 7 * *") // Her ayın 7'si saat 08:00 (İstanbul)
  .timeZone("Europe/Istanbul")
  .onRun(async () => {
    try {
      console.log("📊 Aylık Hope değeri hesaplaması başladı...");

      // Önceki ayın tarihlerini hesapla
      const now = new Date();
      const previousMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      const monthKey = `${previousMonth.getFullYear()}-${String(previousMonth.getMonth() + 1).padStart(2, "0")}`;
```

**monthKey Formatı:** `YYYY-MM` (örn: `2026-01`)

---

### B.2 Firestore Write İşlemleri

**monthly-hope-calculator.ts Satır 121-135:**
```typescript
// 7. Firestore'a kaydet
const monthlyData = {
  month: monthKey,
  total_ad_revenue_usd: totalAdRevenueUsd,
  total_ad_revenue_tl: totalAdRevenueTl,
  usd_to_tl_rate: usdToTlRate,
  donation_pool_ratio: DONATION_POOL_RATIO,
  donation_pool_tl: donationPoolTl,
  total_hope_produced: totalHopeProduced,
  cumulative_hope: currentTotalHope,
  hope_value_tl: hopeValueTl,
  status: "calculated",
  calculated_at: admin.firestore.FieldValue.serverTimestamp(),
  approved_at: null,
  completed_at: null,
  approved_by: null,
};

await db.collection("monthly_hope_value").doc(monthKey).set(monthlyData);
```

**admob-reporter.ts Satır 162-178:**
```typescript
const revenueData = {
  total_revenue: totalRevenue,
  total_impressions: totalImpressions,
  interstitial_revenue: interstitialRevenue,
  interstitial_impressions: interstitialImpressions,
  banner_revenue: bannerRevenue,
  banner_impressions: bannerImpressions,
  rewarded_revenue: rewardedRevenue,
  rewarded_impressions: rewardedImpressions,
  last_updated: admin.firestore.FieldValue.serverTimestamp(),
  report_period: "last_30_days",
  currency: "USD",
};

await getDb().collection("app_stats").doc("ad_revenue").set(revenueData, { merge: true });
```

**admob-reporter.ts Satır 182-189 (History):**
```typescript
const dateKey = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(
  2,
  "0"
)}-${String(yesterday.getDate()).padStart(2, "0")}`;

await getDb().collection("ad_revenue_history").doc(dateKey).set({
  date: dateKey,
  total_revenue: totalRevenue,
  ...
});
```

| Path | Fields | Dosya | Satır |
|------|--------|-------|-------|
| `monthly_hope_value/{monthKey}` | `month`, `total_ad_revenue_usd`, `total_ad_revenue_tl`, `hope_value_tl`, `status`, `calculated_at` | monthly-hope-calculator.ts | 121-136 |
| `app_stats/ad_revenue` | `total_revenue`, `total_impressions`, `last_updated`, `currency` | admob-reporter.ts | 162-178 |
| `ad_revenue_history/{dateKey}` | `date`, `total_revenue`, `created_at` | admob-reporter.ts | 182-189 |
| `activity_logs/{docId}` (donation update) | `donation_month`, `hope_value_tl`, `total_value_tl`, `donation_status` | monthly-hope-calculator.ts | 165-175 |

---

### B.3 Transaction/Batch Kullanımı

**monthly-hope-calculator.ts Satır 156-177 (Batch):**
```typescript
async function updatePendingDonationsStatus(monthKey: string, hopeValueTl: number) {
  const donationsSnapshot = await db.collection("activity_logs")
    .where("activity_type", "==", "donation")
    .where("donation_month", "==", monthKey)
    .where("donation_status", "==", "pending")
    .get();

  const batch = db.batch();
  let count = 0;

  for (const doc of donationsSnapshot.docs) {
    const data = doc.data();
    const hopeAmount = (data.amount ?? data.hope_amount ?? 0) as number;
    const tlValue = hopeAmount * hopeValueTl;

    batch.update(doc.ref, {
      donation_month: monthKey,
      hope_value_tl: hopeValueTl,
      total_value_tl: tlValue,
      donation_status: "pending_approval",
      value_calculated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    count++;
  }

  if (count > 0) {
    await batch.commit();
    console.log(`📝 ${count} adet bağış güncellendi`);
  }
}
```

**monthly-hope-calculator.ts Satır 360-390 (approvePendingDonations Batch):**
```typescript
const batch = db.batch();
let totalHope = 0;
let totalTl = 0;
let count = 0;

for (const doc of donationsSnapshot.docs) {
  const docData = doc.data();
  batch.update(doc.ref, {
    donation_status: "completed",
    approved_at: admin.firestore.FieldValue.serverTimestamp(),
    approved_by: context.auth.uid,
  });
  
  totalHope += (docData.amount ?? docData.hope_amount ?? 0) as number;
  totalTl += (docData.total_value_tl ?? 0) as number;
  count++;
}

await batch.commit();
```

---

### B.4 İdempotency / Lock Mekanizması

**BULUNAMADI**

Kod taramasında şunlar tespit edilmedi:
- `status` alanı "calculated" kontrolü job başlamadan önce yapılmıyor
- Distributed lock mekanizması yok
- Transaction ile "already processed" kontrolü yok
- `monthKey` için tekrar çalışma engeli yok

**Mevcut durum:**
- Job her çalıştığında `monthly_hope_value/{monthKey}` dokümanı `.set()` ile yazılıyor (üzerine yazma)
- **Satır 136:** `await db.collection("monthly_hope_value").doc(monthKey).set(monthlyData);`

---

## C) ADMIN YETKİ + AUDIT LOG KANITI

### C.1 Client Tarafı Admin Kontrolü

**Dosya:** [lib/services/admin_service.dart](lib/services/admin_service.dart#L20-L25)

```dart
/// Mevcut kullanıcının admin olup olmadığını kontrol et
Future<bool> isCurrentUserAdmin() async {
  final user = _auth.currentUser;
  if (user == null) return false;

  final adminDoc = await _firestore.collection('admins').doc(user.uid).get();
  return adminDoc.exists && (adminDoc.data()?['is_active'] ?? false);
}
```

**Admin Panel Route Guard:**
**Dosya:** [lib/screens/admin/admin_panel_screen.dart](lib/screens/admin/admin_panel_screen.dart#L52-L63)

```dart
Future<void> _checkAdminAccess() async {
  final isAdmin = await _adminService.isCurrentUserAdmin();
  if (!isAdmin && mounted) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bu sayfaya erişim yetkiniz yok!'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

**Profile Screen Admin Check:**
**Dosya:** [lib/screens/profile/profile_screen.dart](lib/screens/profile/profile_screen.dart#L70)

```dart
final isAdmin = await _adminService.isCurrentUserAdmin();
```

---

### C.2 Admin İşlemleri ve Yazılan Koleksiyonlar

**Dosya:** [lib/services/admin_service.dart](lib/services/admin_service.dart)

| Function | Collection/Doc Path | Satır |
|----------|---------------------|-------|
| `addAdmin()` | `admins/{uid}` | 30-35 |
| `updateAdminStats()` | `admin_stats/current` | 383-389 |
| `updateAdminStats()` | `admin_logs/{docId}` | 391-404 |
| `banUser()` | `users/{uid}` | 762-768 |
| `banUser()` | `admin_logs/{docId}` | 770-776 |
| `unbanUser()` | `users/{uid}` | 782-788 |
| `unbanUser()` | `admin_logs/{docId}` | 790-795 |

**addAdmin() - Satır 28-35:**
```dart
/// Admin listesine kullanıcı ekle
Future<void> addAdmin(String uid, String role) async {
  await _firestore.collection('admins').doc(uid).set({
    'uid': uid,
    'role': role, // 'super_admin', 'admin', 'moderator'
    'is_active': true,
    'created_at': FieldValue.serverTimestamp(),
  });
}
```

**updateAdminStats() - Satır 370-406:**
```dart
Future<bool> updateAdminStats({...}) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Firestore'a kaydet
    await _firestore.collection('admin_stats').doc('current').set({
      'ios_downloads': iosDownloads,
      'android_downloads': androidDownloads,
      'ad_revenue': adRevenue,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Admin log kaydı ekle
    await _firestore.collection('admin_logs').add({
      'action': 'update_admin_stats',
      'admin_uid': user.uid,
      'admin_email': user.email,
      'timestamp': FieldValue.serverTimestamp(),
      'details': {
        'previous_ios_downloads': previousIosDownloads ?? 0,
        'new_ios_downloads': iosDownloads,
        ...
      },
    });
    return true;
  } catch (e) {
    return false;
  }
}
```

**banUser() - Satır 761-776:**
```dart
/// Kullanıcıyı banla
Future<void> banUser(String uid, String reason) async {
  await _firestore.collection('users').doc(uid).update({
    'is_banned': true,
    'ban_reason': reason,
    'banned_at': FieldValue.serverTimestamp(),
    'banned_by': _auth.currentUser?.uid,
  });

  // Ban logunu kaydet
  await _firestore.collection('admin_logs').add({
    'action': 'ban_user',
    'target_uid': uid,
    'reason': reason,
    'admin_uid': _auth.currentUser?.uid,
    'timestamp': FieldValue.serverTimestamp(),
  });
}
```

---

### C.3 Firestore Rules - admins Koleksiyonu

**Dosya:** [firestore.rules](firestore.rules#L308-L315)

```plaintext
// ========== ADMINS KOLEKSİYONU ==========

match /admins/{adminId} {
  // Herkes admin mi diye kontrol edebilir (kendi uid'si için)
  allow read: if isAuthenticated();
  
  // Admin ekleme sadece mevcut adminler (Super Admin)
  allow write: if isAdmin();
}
```

**Dosya:** [firestore.rules](firestore.rules#L327-L337) - admin_logs

```plaintext
// ========== ADMIN_LOGS KOLEKSİYONU ==========

match /admin_logs/{logId} {
  // Sadece adminler okuyabilir
  allow read: if isAdmin();
  
  // Admin işlem yaptığında log oluşturur
  allow create: if isAdmin();
  
  // Loglar silinemez/güncellenemez
  allow update, delete: if false;
}
```

**Dosya:** [firestore.rules](firestore.rules#L317-L325) - admin_stats

```plaintext
// ========== ADMIN_STATS KOLEKSİYONU ==========

match /admin_stats/{statId} {
  // Sadece adminler okuyabilir
  allow read: if isAdmin();
  
  // Cloud Function günceller
  allow write: if isAdmin();
}
```

---

### C.4 isAdmin() Helper Fonksiyonu

**Dosya:** [firestore.rules](firestore.rules#L17-L21)

```plaintext
/// Admin kontrolü
function isAdmin() {
  return isAuthenticated() && 
         exists(/databases/$(database)/documents/admins/$(request.auth.uid)) &&
         get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.is_active == true;
}
```

---

## ÖZET TABLO

| Kritik Akış | Çift Çalışma Koruması | Transaction/Batch | Audit Log |
|-------------|----------------------|-------------------|-----------|
| Step→Hope Conversion | BULUNAMADI | Batch (step_conversion_service.dart:443) | activity_logs'a yazılıyor |
| Monthly Hope Calculator | BULUNAMADI | Batch (monthly-hope-calculator.ts:156) | BULUNAMADI |
| AdMob Revenue Job | BULUNAMADI (set with merge) | Yok | BULUNAMADI |
| Admin İşlemleri | N/A | Yok | admin_logs'a yazılıyor |

---

**EK KANIT PAKETİ SONU**
