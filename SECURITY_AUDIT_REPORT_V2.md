# 🛡️ GENİŞLETİLMİŞ GÜVENLİK DENETİM RAPORU V2
## Bir Adım Umut - Düşmanca/Paranoyak Perspektif

**Rapor Tarihi:** 15 Ocak 2025  
**Denetim Türü:** İş Mantığı Suistimali + Teknik Güvenlik  
**Meta-Denetim Bulguları:** ✅ Dahil Edildi  

---

# 📋 İÇİNDEKİLER

1. [Yönetici Özeti](#1-yönetici-özeti)
2. [Finansal Suistimal Denetimi](#2-finansal-suistimal-denetimi) ⚠️ YENİ
3. [Cloud Functions İdempotency](#3-cloud-functions-idempotency) ⚠️ YENİ
4. [Admin Patlama Yarıçapı Analizi](#4-admin-patlama-yarıçapı-analizi) ⚠️ YENİ
5. [Üretim Derleme Bayrakları](#5-üretim-derleme-bayrakları) ⚠️ YENİ
6. [Simüle Veri Exploit Analizi](#6-simüle-veri-exploit-analizi) ⚠️ YENİ
7. [Kritik Bulgu Özeti](#7-kritik-bulgu-özeti)
8. [Acil Eylem Planı](#8-acil-eylem-planı)

---

# 1. YÖNETİCİ ÖZETİ

## 🎯 Meta-Denetim Bulguları

Önceki rapor (V1) şu kritik boşlukları içeriyordu:

| Boşluk | Durum | Önem |
|--------|-------|------|
| Step→Hope dönüşüm suistimali | ✅ Analiz edildi | 🔴 KRİTİK |
| Cloud Functions idempotency | ✅ Analiz edildi | 🟠 YÜKSEK |
| Admin hesap ele geçirme riski | ✅ Analiz edildi | 🔴 KRİTİK |
| App Check DEBUG modu | ✅ Yükseltildi: Kritik | 🔴 KRİTİK |
| Simüle veri açığı | ✅ Analiz edildi | 🟠 YÜKSEK |

## 📊 Risk Matrisi

```
          OLASILIK
          Düşük  Orta   Yüksek
        ┌──────┬──────┬──────┐
Yüksek  │      │ ID-1 │ FA-1 │  ETKİ
        │      │ AD-2 │ FA-2 │
        ├──────┼──────┼──────┤
Orta    │      │ CF-1 │ SD-1 │
        │      │ CF-2 │      │
        ├──────┼──────┼──────┤
Düşük   │      │      │      │
        └──────┴──────┴──────┘

FA = Finansal Suistimal
ID = İdempotency
AD = Admin
CF = Cloud Functions
SD = Simüle Data
```

---

# 2. FİNANSAL SUİSTİMAL DENETİMİ

## 2.1 Step → Hope Dönüşüm Akışı Analizi

### 📍 Kaynak Kod Lokasyonu
- [step_conversion_service.dart](lib/services/step_conversion_service.dart)
- [device_service.dart](lib/services/device_service.dart)

### 🔍 Mevcut Korumalar

```dart
// 1. Device Fraud Prevention (device_service.dart:123-145)
Future<Map<String, dynamic>> canSyncSteps(String userId, {String? userEmail}) async {
  final existingOwner = await checkDeviceStepOwner(userId);
  if (existingOwner == null) {
    await registerDeviceForUser(userId);
    return {'canSync': true};
  }
  return {'canSync': false, 'reason': 'device_already_used'};
}

// 2. Dönüşüm Limiti (step_conversion_service.dart:78)
static const int maxStepsPerConversion = 2500;

// 3. Cooldown Süresi (step_conversion_service.dart:84)
static const Duration conversionCooldown = Duration(minutes: 10);

// 4. Batch Yazma (step_conversion_service.dart:450-480)
final batch = _firestore.batch();
batch.update(...); // Atomik işlem
await batch.commit();
```

### ⚠️ THREAT MODEL: Saldırı Senaryoları

#### SENARYO FA-1: Çift Dönüşüm Saldırısı
```
Saldırgan: Kötü niyetli kullanıcı
Vektör: Eşzamanlı istek gönderme
Hedef: Aynı adımları 2 kez Hope'a çevirmek

Akış:
1. Kullanıcı 2500 adım atmış
2. T=0: Cihaz A'dan convertSteps() çağrısı
3. T=0.001s: Cihaz B'den convertSteps() çağrısı (proxy ile)
4. Her iki işlem de daily_steps kontrolünden geçebilir mi?
```

**🔴 RİSK DEĞERLENDİRMESİ:**

| Kontrol | Durum | Açıklama |
|---------|-------|----------|
| Device kontrolü | ✅ VAR | `canSyncSteps()` cihaz başına günde 1 hesap |
| Cooldown kontrolü | ⚠️ CLIENT-SIDE | `canConvert()` sadece istemcide çalışır |
| Atomik işlem | ✅ VAR | Firestore batch write kullanılıyor |
| İşlem kilidi | ❌ YOK | Distributed lock mekanizması yok |

**🛠️ SÖMÜRÜ ANALİZİ:**

```dart
// step_conversion_service.dart:490-510
Future<bool> canConvert(String userId) async {
  final doc = await _firestore
      .collection('users')
      .doc(userId)
      .collection('daily_steps')
      .doc(today)
      .get();
  
  // ⚠️ SORUN: Bu kontrol race condition'a açık!
  // T=0: İstek A → doc.data()['last_conversion_time'] = null → true döner
  // T=0.001s: İstek B → doc.data()['last_conversion_time'] = null → true döner
  // Her iki istek de geçer, sonra batch.commit() çalışır
  
  final lastConversion = (data['last_conversion_time'] as Timestamp?)?.toDate();
  if (lastConversion != null) {
    final elapsed = DateTime.now().difference(lastConversion);
    return elapsed >= conversionCooldown;
  }
  return true;
}
```

**📝 ÖNERİ FA-1:** Server-Side Cooldown + Distributed Lock

```typescript
// Cloud Function ile güvenli dönüşüm
export const safeConvertSteps = functions.https.onCall(async (data, context) => {
  const userId = context.auth?.uid;
  const lockRef = db.collection('conversion_locks').doc(userId);
  
  // Firestore Transaction ile kilitleme
  return db.runTransaction(async (transaction) => {
    const lockDoc = await transaction.get(lockRef);
    
    if (lockDoc.exists) {
      const lastConversion = lockDoc.data()?.last_conversion?.toDate();
      const elapsed = Date.now() - lastConversion.getTime();
      if (elapsed < 10 * 60 * 1000) { // 10 dakika
        throw new functions.https.HttpsError('failed-precondition', 'Cooldown aktif');
      }
    }
    
    // Kilidi güncelle ve dönüşümü yap
    transaction.set(lockRef, {
      last_conversion: admin.firestore.FieldValue.serverTimestamp(),
      in_progress: true
    });
    
    // ... dönüşüm mantığı ...
    
    transaction.update(lockRef, { in_progress: false });
    return { success: true };
  });
});
```

---

#### SENARYO FA-2: Simüle Adım Enjeksiyonu
```
Saldırgan: Root erişimli cihaz sahibi
Vektör: Health API sahte veri enjeksiyonu
Hedef: Sınırsız sahte adım → Hope

Akış:
1. Saldırgan rootlu cihazda Health Connect'i manipüle eder
2. Sahte adım verisi (günde 500.000 adım) enjekte eder
3. Uygulama bu veriyi gerçek kabul eder
4. Hope çiftliği kurar
```

**🔍 KAYNAK KOD ANALİZİ:**

```dart
// health_service.dart:118-135
Future<int> fetchTodaySteps() async {
  // iOS'ta her zaman gerçek veri almayı dene
  if (isIOS) {
    int? steps = await _health.getTotalStepsInInterval(midnight, now);
    _todaySteps = steps ?? 0;
    _useSimulatedData = false; // ✅ iOS'ta simüle veri devre dışı
    return _todaySteps;
  }
  
  // Android için simüle veri modundaysa
  if (_useSimulatedData) {
    _todaySteps = _generateSimulatedSteps(); // ⚠️ SORUN!
    return _todaySteps;
  }
  // ...
}
```

**🔴 RİSK DEĞERLENDİRMESİ:**

| Platform | Gerçek Veri | Simüle Veri | Risk |
|----------|-------------|-------------|------|
| iOS | ✅ HealthKit | ❌ Kapalı | DÜŞÜK |
| Android | ⚠️ Koşullu | ⚠️ Fallback | ORTA |
| Web | ❌ Yok | ✅ Açık | YÜKSEK |

**📝 ÖNERİ FA-2:** Makul Olmayan Adım Tespiti

```dart
// Günlük maksimum makul adım limiti
static const int MAX_REASONABLE_DAILY_STEPS = 50000;

// Dönüşüm öncesi doğrulama
Future<bool> validateStepCount(int steps, String userId) async {
  // 1. Makul limit kontrolü
  if (steps > MAX_REASONABLE_DAILY_STEPS) {
    await _logSuspiciousActivity(userId, 'unreasonable_steps', steps);
    return false;
  }
  
  // 2. Ani artış tespiti (önceki 7 günün ortalamasının 3 katı)
  final weeklyAvg = await _getWeeklyAverageSteps(userId);
  if (steps > weeklyAvg * 3 && weeklyAvg > 1000) {
    await _logSuspiciousActivity(userId, 'suspicious_spike', steps);
    // Uyarı ver ama engelleme (manuel inceleme için işaretle)
  }
  
  return true;
}
```

---

#### SENARYO FA-3: Rewarded Ad Callback Spoofing
```
Saldırgan: Reverse engineering yapan kullanıcı
Vektör: Sahte reklam tamamlama callback'i
Hedef: Reklam izlemeden Hope kazanmak

Akış:
1. Saldırgan uygulamayı decompile eder
2. onUserEarnedReward callback'ini bulur
3. Kendi kodundan bu callback'i tetikler
4. Ücretsiz Hope kazanır
```

**🔍 KAYNAK KOD ANALİZİ:**

```dart
// rewarded_ad_service.dart:107-115
await _rewardedAd!.show(
  onUserEarnedReward: (ad, reward) {
    print('Kullanıcı ödül kazandı: ${reward.amount} ${reward.type}');
    wasRewarded = true;
    _adLogService.logRewardedAd(
      context: _currentContext,
      rewardAmount: 50,
      wasCompleted: true,
    );
    onRewarded(50); // ⚠️ Direkt Hope ekleme
  },
);
```

**🟠 RİSK DEĞERLENDİRMESİ:**

| Kontrol | Durum | Açıklama |
|---------|-------|----------|
| Google SDK doğrulaması | ✅ VAR | AdMob SDK callback'i doğrular |
| Server-side doğrulama | ❌ YOK | SSV (Server-Side Verification) yok |
| Loglama | ✅ VAR | `logRewardedAd()` çağrılıyor |

**📝 ÖNERİ FA-3:** AdMob Server-Side Verification

```typescript
// Cloud Function: Rewarded Ad SSV endpoint
export const verifyRewardedAd = functions.https.onRequest(async (req, res) => {
  const { ad_network, ad_unit, custom_data, reward_amount, reward_item, 
          signature, timestamp, transaction_id, user_id } = req.query;
  
  // Google'ın imzasını doğrula
  const isValid = await verifyGoogleSignature(signature, {
    ad_network, ad_unit, custom_data, reward_amount, reward_item,
    timestamp, transaction_id, user_id
  });
  
  if (!isValid) {
    console.warn('Invalid reward callback', { user_id, transaction_id });
    return res.status(403).send('Invalid signature');
  }
  
  // İşlem tekrarını önle
  const txRef = db.collection('reward_transactions').doc(transaction_id);
  const txDoc = await txRef.get();
  
  if (txDoc.exists) {
    return res.status(409).send('Already processed');
  }
  
  // Ödülü ver ve işlemi kaydet
  await db.runTransaction(async (t) => {
    t.set(txRef, { 
      user_id, 
      reward_amount, 
      processed_at: admin.firestore.FieldValue.serverTimestamp() 
    });
    t.update(db.collection('users').doc(user_id), {
      wallet_balance_hope: admin.firestore.FieldValue.increment(50)
    });
  });
  
  res.status(200).send('Reward granted');
});
```

---

# 3. CLOUD FUNCTIONS İDEMPOTENCY

## 3.1 İdempotency Nedir?

> Aynı işlem N kez çalıştırıldığında, sonuç hep aynı kalmalıdır.
> Örn: "X kullanıcısına 50 Hope ekle" → Her seferinde +50 DEĞİL, sadece 1 kez +50

## 3.2 Mevcut Cloud Functions Analizi

### 📍 İncelenen Fonksiyonlar

| Fonksiyon | Dosya | İdempotent? | Risk |
|-----------|-------|-------------|------|
| `createTeam` | index.ts:22 | ⚠️ Kısmen | ORTA |
| `joinTeamByReferral` | index.ts:108 | ✅ Evet | DÜŞÜK |
| `carryOverDailySteps` | index.ts:593 | ❌ Hayır | YÜKSEK |
| `distributeMonthlyLeaderboardRewards` | index.ts:1886 | ⚠️ Kısmen | YÜKSEK |
| `sendBroadcastNotification` | index.ts:1199 | ❌ Hayır | ORTA |

### 🔴 İDEMPOTENT OLMAYAN FONKSİYONLAR

#### CF-1: carryOverDailySteps

```typescript
// index.ts:593-680
export const carryOverDailySteps = functions.pubsub
  .schedule("0 0 * * *")
  .onRun(async (context) => {
    // ...
    for (const userDoc of usersSnapshot.docs) {
      // ⚠️ SORUN: Aynı gün için 2 kez çalışırsa?
      await userDoc.ref.update({
        carryover_pending: currentCarryoverPending + unconvertedSteps,
        total_carryover_steps: currentTotalCarryover + unconvertedSteps,
      });
      
      // ⚠️ SORUN: Duplicate activity log
      await db.collection("activity_logs").add({
        activity_type: "step_carryover",
        steps: unconvertedSteps,
        // ...
      });
    }
  });
```

**SÖMÜRÜ:** Scheduled function yeniden deneme mekanizması veya manuel tetikleme ile çift yazma.

**📝 ÖNERİ CF-1:**

```typescript
export const carryOverDailySteps = functions.pubsub
  .schedule("0 0 * * *")
  .onRun(async (context) => {
    const yesterday = getYesterdayKey();
    const lockDoc = await db.collection('daily_carryover_locks').doc(yesterday).get();
    
    if (lockDoc.exists && lockDoc.data()?.completed) {
      console.log(`Carryover for ${yesterday} already completed, skipping`);
      return null;
    }
    
    // Kilidi al
    await db.collection('daily_carryover_locks').doc(yesterday).set({
      started_at: admin.firestore.FieldValue.serverTimestamp(),
      completed: false
    });
    
    try {
      // ... mevcut mantık ...
      
      // Başarılı tamamlama
      await db.collection('daily_carryover_locks').doc(yesterday).update({
        completed: true,
        completed_at: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      // Hata durumunda kilit kaldırılsın ki yeniden denenebilsin
      await db.collection('daily_carryover_locks').doc(yesterday).delete();
      throw error;
    }
  });
```

#### CF-2: distributeMonthlyLeaderboardRewards

```typescript
// index.ts:1950-2000 (distributeStepRewards içinde)
await db.collection("users").doc(userId).update({
  leaderboard_bonus_steps: admin.firestore.FieldValue.increment(rewardSteps),
});

await db.collection("leaderboard_rewards")
  .doc(`${yearMonth}_umut_hareketi_${i + 1}`)
  .set({...}); // ✅ Bu kısım idempotent (doc ID sabit)
```

**🟢 KISMEN İDEMPOTENT:**
- `leaderboard_rewards` dokümanı sabit ID ile yazılıyor → İdempotent
- Ama `FieldValue.increment()` her çalışmada ekler → İdempotent DEĞİL

**📝 ÖNERİ CF-2:**

```typescript
// Önce ödül verilmiş mi kontrol et
const rewardDoc = await db.collection("leaderboard_rewards")
  .doc(`${yearMonth}_umut_hareketi_${i + 1}`)
  .get();

if (rewardDoc.exists && rewardDoc.data()?.status === 'awarded') {
  console.log(`Reward already awarded for ${yearMonth}, rank ${i + 1}`);
  continue; // Atla
}

// Transaction ile atomik işlem
await db.runTransaction(async (t) => {
  const userRef = db.collection("users").doc(userId);
  const rewardRef = db.collection("leaderboard_rewards")
    .doc(`${yearMonth}_umut_hareketi_${i + 1}`);
  
  const userDoc = await t.get(userRef);
  const currentBonus = userDoc.data()?.leaderboard_bonus_steps || 0;
  
  // Mutlak değer ataması (increment yerine)
  t.update(userRef, {
    leaderboard_bonus_steps: currentBonus + rewardSteps
  });
  
  t.set(rewardRef, {
    status: 'awarded',
    // ...
  });
});
```

---

# 4. ADMİN PATLAMA YARICAPI ANALİZİ

## 4.1 Admin Yetki Yapısı

### 📍 Kaynak Dosyalar
- [admin_service.dart](lib/services/admin_service.dart) (4193 satır)
- [admin_panel_screen.dart](lib/screens/admin/admin_panel_screen.dart) (914 satır)
- [index.ts](firebase_functions/functions/src/index.ts) - Admin functions

### 🔍 Admin Kontrol Mekanizması

```dart
// admin_service.dart:18-25
Future<bool> isCurrentUserAdmin() async {
  final user = _auth.currentUser;
  if (user == null) return false;

  final adminDoc = await _firestore.collection('admins').doc(user.uid).get();
  return adminDoc.exists && (adminDoc.data()?['is_active'] ?? false);
}
```

```typescript
// index.ts:975-978
async function isAdmin(uid: string): Promise<boolean> {
  const adminDoc = await db.collection("admins").doc(uid).get();
  return adminDoc.exists && adminDoc.data()?.is_active === true;
}
```

### 📊 Admin Yetki Matrisi

| Yetki | Flutter Client | Cloud Function | Firestore Rules |
|-------|----------------|----------------|-----------------|
| Kullanıcı listele | ✅ | ✅ | ✅ |
| Kullanıcı banla | ✅ | ✅ | ✅ |
| Hope değeri ayarla | ✅ | ✅ | ✅ |
| Toplu bildirim | ✅ | ✅ | N/A |
| Tüm verileri sil | ❌ | ⚠️ Sınırlı | ❌ |
| Başka admin ekle | ✅ | ✅ | ✅ |

### 🔴 BLAST RADIUS: Admin Hesap Ele Geçirme

```
SENARYO AD-1: Admin hesabı çalınırsa ne olur?

Timeline:
T=0: Saldırgan admin şifresini ele geçirir (phishing, veri sızıntısı vb)
T+1: Admin paneline giriş yapar
T+2: Şunları yapabilir:
  ├── Tüm kullanıcı bilgilerini görüntüle (PII sızıntısı)
  ├── Herhangi bir kullanıcıyı banla
  ├── Toplu sahte bildirim gönder
  ├── Kendine yeni admin hesabı ekle
  └── Aylık Hope değerini 0'a düşür (ekonomik sabotaj)
```

**🔴 RİSK DEĞERLENDİRMESİ:**

| Aksiyon | Geri Alınabilir? | Tespit Süresi |
|---------|------------------|---------------|
| PII görüntüleme | ❌ | Belirsiz |
| Toplu ban | ✅ | Dakikalar |
| Sahte bildirim | ❌ | Anında |
| Hope değeri değiştir | ✅ | Aylar |
| Yeni admin ekle | ✅ | Gün/Hafta |

### 📝 ÖNERİLER

#### AD-1: İki Faktörlü Doğrulama (2FA)

```dart
// Admin girişinde 2FA zorunluluğu
Future<bool> verifyAdminLogin(String uid) async {
  final adminDoc = await _firestore.collection('admins').doc(uid).get();
  if (!adminDoc.exists) return false;
  
  final requires2FA = adminDoc.data()?['requires_2fa'] ?? true;
  if (requires2FA) {
    // TOTP doğrulaması iste
    final totpVerified = await _verify2FACode(uid);
    if (!totpVerified) {
      await _logSuspiciousAdminAccess(uid, 'failed_2fa');
      return false;
    }
  }
  
  return true;
}
```

#### AD-2: Admin İşlem Denetim Logu

```typescript
// Her admin işlemi için detaylı log
async function auditAdminAction(
  adminId: string,
  action: string,
  target: { type: string; id: string },
  details: any,
  clientInfo: { ip: string; userAgent: string }
) {
  await db.collection('admin_audit_logs').add({
    admin_id: adminId,
    action,
    target_type: target.type,
    target_id: target.id,
    details,
    client_ip: clientInfo.ip,
    user_agent: clientInfo.userAgent,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    // Sonradan değiştirilemez (immutable)
  });
}

// Firestore Rules
match /admin_audit_logs/{logId} {
  allow read: if isAdmin();
  allow create: if isAdmin();
  allow update, delete: if false; // Kimse değiştiremez/silemez
}
```

#### AD-3: Kritik İşlemler İçin Çift Onay

```typescript
// Toplu işlemler için 2. admin onayı
export const executeBulkAction = functions.https.onCall(async (data, context) => {
  const { actionId } = data;
  
  const actionDoc = await db.collection('pending_bulk_actions').doc(actionId).get();
  const actionData = actionDoc.data();
  
  // Oluşturan admin ile onaylayan admin farklı olmalı
  if (actionData.created_by === context.auth?.uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Kendi oluşturduğunuz işlemi onaylayamazsınız'
    );
  }
  
  // 2. admin onayı
  await actionDoc.ref.update({
    approved_by: context.auth?.uid,
    approved_at: admin.firestore.FieldValue.serverTimestamp(),
    status: 'approved'
  });
  
  // İşlemi çalıştır
  // ...
});
```

#### AD-4: Anomali Tespiti

```typescript
// Anormal admin davranışı tespit
export const monitorAdminActivity = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async () => {
    const fiveMinutesAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 5 * 60 * 1000)
    );
    
    const recentActions = await db.collection('admin_audit_logs')
      .where('timestamp', '>=', fiveMinutesAgo)
      .get();
    
    // Admin başına işlem sayısı
    const actionCounts: Record<string, number> = {};
    recentActions.forEach(doc => {
      const adminId = doc.data().admin_id;
      actionCounts[adminId] = (actionCounts[adminId] || 0) + 1;
    });
    
    // 5 dakikada 50'den fazla işlem = şüpheli
    for (const [adminId, count] of Object.entries(actionCounts)) {
      if (count > 50) {
        await sendSecurityAlert({
          type: 'suspicious_admin_activity',
          admin_id: adminId,
          action_count: count,
          period: '5_minutes'
        });
        
        // Opsiyonel: Admin hesabını geçici olarak devre dışı bırak
        // await db.collection('admins').doc(adminId).update({ is_active: false });
      }
    }
  });
```

---

# 5. ÜRETİM DERLEME BAYRAKLARI

## 5.1 App Check DEBUG Modu

### 📍 Kaynak Lokasyon
- [main.dart](lib/main.dart):100-115

### 🔴 KRİTİK BULGU

```dart
// main.dart:100-115
// 🔒 App Check - API isteklerini doğrulama
// NOT: Production'da debug provider KAPALI olmalı!
try {
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug, // ⚠️ PRODUCTION İÇİN DEĞİŞTİR
    appleProvider: AppleProvider.debug,     // ⚠️ PRODUCTION İÇİN DEĞİŞTİR
  );
  debugPrint('✅ App Check aktif (Debug modda)');
} catch (e) {
  debugPrint('⚠️ App Check başlatılamadı: $e');
}
```

### 📊 Risk Değerlendirmesi

| Mod | Ne yapar? | Risk |
|-----|-----------|------|
| `AndroidProvider.debug` | Herkes token alabilir | 🔴 KRİTİK |
| `AndroidProvider.playIntegrity` | Sadece gerçek cihazlar | ✅ GÜVENLİ |
| `AppleProvider.debug` | Herkes token alabilir | 🔴 KRİTİK |
| `AppleProvider.deviceCheck` | Sadece gerçek Apple cihazları | ✅ GÜVENLİ |

### 📝 ÇÖZÜM: Ortam Bazlı Yapılandırma

```dart
// lib/config/app_config.dart
class AppConfig {
  static const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  
  static AndroidProvider get androidAppCheckProvider =>
      isProduction ? AndroidProvider.playIntegrity : AndroidProvider.debug;
  
  static AppleProvider get appleAppCheckProvider =>
      isProduction ? AppleProvider.deviceCheck : AppleProvider.debug;
}

// main.dart
await FirebaseAppCheck.instance.activate(
  androidProvider: AppConfig.androidAppCheckProvider,
  appleProvider: AppConfig.appleAppCheckProvider,
);
```

**Derleme Komutu:**
```bash
# Development
flutter run

# Production
flutter build apk --dart-define=PRODUCTION=true
flutter build ipa --dart-define=PRODUCTION=true
```

---

## 5.2 Debug Print Statement'ları

### 🔍 Tarama Sonuçları

```bash
grep -r "debugPrint\|print(" lib/ --include="*.dart" | wc -l
# Sonuç: 347 adet print/debugPrint
```

**Örnek Hassas Loglar:**

```dart
// step_conversion_service.dart:180
print('🔧 Bozuk veri düzeltildi: converted_steps $convertedSteps -> $dailySteps');

// device_service.dart:52
debugPrint('📱 Device ID: $_cachedDeviceId');

// rewarded_ad_service.dart:45
print('RewardedAd yüklendi');
```

### 📝 ÖNERİ: Logging Wrapper

```dart
// lib/utils/logger.dart
class AppLogger {
  static const bool _enableInProduction = false;
  
  static void debug(String message, {String? tag}) {
    if (kDebugMode || _enableInProduction) {
      debugPrint('[${tag ?? 'DEBUG'}] $message');
    }
  }
  
  static void info(String message, {String? tag}) {
    // Firebase Crashlytics'e log
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.log(message);
    }
    debugPrint('[${tag ?? 'INFO'}] $message');
  }
  
  static void sensitive(String message) {
    // Hassas bilgiler ASLA üretimde loglanmaz
    if (kDebugMode) {
      debugPrint('[SENSITIVE] $message');
    }
  }
}
```

---

# 6. SİMÜLE VERİ EXPLOİT ANALİZİ

## 6.1 Simüle Veri Akışı

### 📍 Kaynak Dosya
- [health_service.dart](lib/services/health_service.dart)

### 🔍 Simüle Veri Üretici

```dart
// health_service.dart:313-326
int _generateSimulatedSteps() {
  final now = DateTime.now();
  final hour = now.hour;
  
  // Günün saatine göre mantıklı bir değer
  if (hour < 8) {
    return 500 + (now.minute * 10);   // 500-1100
  } else if (hour < 12) {
    return 2000 + (hour * 200);       // 3600-4200
  } else if (hour < 18) {
    return 5000 + (hour * 300);       // 8600-10100
  } else {
    return 7000 + (hour * 200);       // 10600-11600
  }
}
```

### 📊 Ne Zaman Simüle Veri Kullanılır?

| Koşul | `_useSimulatedData` | Gerçek Veri |
|-------|---------------------|-------------|
| Web platformu | ✅ TRUE | ❌ |
| Android + Health Connect yok | ✅ TRUE | ❌ |
| Android + Health Connect var | ❌ FALSE | ✅ |
| iOS | ❌ FALSE | ✅ |
| Herhangi bir hata | ✅ TRUE (fallback) | ❌ |

### 🔴 SÖMÜRÜ SENARYOSU

```
SENARYO SD-1: Health Connect Kaldırma Saldırısı

1. Saldırgan Android cihazında Health Connect'i kaldırır
2. Uygulama: "Health Connect yüklü değil" → _useSimulatedData = true
3. Saldırgan uygulamayı saatlerce açık tutar
4. Her fetchTodaySteps() çağrısında ~10.000 simüle adım alır
5. Bu adımları Hope'a çevirir

Kazanç: Günde ~10.000 simüle adım = ~100 Hope (sınırsız)
```

### 📝 ÖNERİLER

#### SD-1: Simüle Veriden Hope Dönüşümü Engelleme

```dart
// step_conversion_service.dart - convertSteps() içinde
Future<Map<String, dynamic>> convertSteps({
  required String userId,
  required int steps,
  required double hopeEarned,
  required bool isFromSimulatedData, // ⚠️ YENİ PARAMETRE
}) async {
  // Simüle veriden dönüşüm engelle
  if (isFromSimulatedData) {
    return {
      'success': false,
      'error': 'simulated_data_not_allowed',
      'message': 'Gerçek adım verisi gerekli. Lütfen Health Connect yükleyin.',
    };
  }
  
  // ... mevcut mantık ...
}
```

#### SD-2: Simüle Veri Kullanımını Loglama

```dart
// health_service.dart
Future<int> fetchTodaySteps() async {
  // ... mevcut mantık ...
  
  if (_useSimulatedData) {
    // Firebase Analytics'e log
    await FirebaseAnalytics.instance.logEvent(
      name: 'simulated_data_used',
      parameters: {
        'platform': _getPlatformName(),
        'reason': _simulatedDataReason,
      },
    );
  }
  
  return _todaySteps;
}
```

#### SD-3: Üretimde Simüle Veri Tamamen Kapatma

```dart
// health_service.dart
Future<bool> initialize() async {
  if (kReleaseMode) {
    // PRODUCTION'DA SİMÜLE VERİ YASAK
    _canUseSimulatedData = false;
  }
  
  // ...
  
  if (_useSimulatedData && !_canUseSimulatedData) {
    _isAuthorized = false;
    _todaySteps = 0;
    return false; // Başarısız başlatma
  }
}
```

---

# 7. KRİTİK BULGU ÖZETİ

## 🔴 KRİTİK (Hemen Düzelt)

| ID | Bulgu | Konum | Öneri |
|----|-------|-------|-------|
| FA-1 | Race condition: Çift dönüşüm | step_conversion_service.dart:490 | Server-side cooldown + transaction |
| AC-1 | App Check DEBUG modu | main.dart:100 | Üretimde playIntegrity/deviceCheck |
| AD-1 | Admin 2FA yok | admin_service.dart | TOTP zorunluluğu |

## 🟠 YÜKSEK (1 Hafta İçinde)

| ID | Bulgu | Konum | Öneri |
|----|-------|-------|-------|
| CF-1 | carryOverDailySteps idempotent değil | index.ts:593 | Günlük kilit mekanizması |
| FA-3 | Rewarded Ad SSV yok | rewarded_ad_service.dart | Google SSV entegrasyonu |
| SD-1 | Simüle veriden Hope dönüşümü | health_service.dart | Engelleme + loglama |

## 🟡 ORTA (Sprint İçinde)

| ID | Bulgu | Konum | Öneri |
|----|-------|-------|-------|
| AD-2 | Admin audit log zayıf | index.ts:990 | Detaylı immutable log |
| CF-2 | Ödül dağıtımı increment kullanıyor | index.ts:1950 | Transaction + mutlak değer |
| FA-2 | Makul olmayan adım tespiti yok | step_conversion_service.dart | Spike detection |

---

# 8. ACİL EYLEM PLANI

## Hafta 1: Kritik Düzeltmeler

### Gün 1-2: App Check Production Modu
```dart
// 1. AppConfig oluştur
// 2. main.dart'ı güncelle
// 3. CI/CD pipeline'ı güncelle
// 4. Test et
```

### Gün 3-4: Server-Side Cooldown
```typescript
// 1. safeConvertSteps Cloud Function oluştur
// 2. Flutter'dan bu function'ı çağır
// 3. Eski client-side cooldown'ı kaldır
// 4. Test et
```

### Gün 5: Admin 2FA
```dart
// 1. firebase_auth 2FA ayarla
// 2. Admin girişinde zorunlu kıl
// 3. Mevcut adminlere bildiri gönder
```

## Hafta 2: Yüksek Öncelikli Düzeltmeler

### Gün 1-2: Cloud Functions İdempotency
- carryOverDailySteps kilit mekanizması
- distributeRewards transaction

### Gün 3-4: Simüle Veri Kontrolü
- Production'da simüle veri engelleme
- Loglama ekleme

### Gün 5: Rewarded Ad SSV
- Google SSV endpoint oluşturma
- Flutter entegrasyonu

---

# 📎 EKLER

## Ek A: Test Senaryoları

```gherkin
Feature: Finansal Suistimal Önleme

Scenario: Çift Dönüşüm Saldırısı
  Given Kullanıcının 2500 adımı var
  When İki eşzamanlı convertSteps isteği gönderilir
  Then Sadece biri başarılı olmalı
  And Diğeri "cooldown_active" hatası almalı

Scenario: Simüle Veri Dönüşümü
  Given Kullanıcı Health Connect'i kaldırmış
  And _useSimulatedData = true
  When convertSteps çağrılır
  Then "simulated_data_not_allowed" hatası dönmeli

Scenario: Admin Hesap Ele Geçirme
  Given Saldırgan admin şifresini biliyor
  When Admin paneline giriş dener
  Then 2FA kodu istenmeli
  And 3 yanlış denemede hesap kilitlenmeli
```

## Ek B: Güvenlik Kontrol Listesi (Release Öncesi)

- [ ] App Check production modda
- [ ] Debug print'ler temizlendi
- [ ] Simüle veri dönüşümü engellendi
- [ ] Admin 2FA aktif
- [ ] Cloud Functions idempotent
- [ ] Rewarded Ad SSV aktif
- [ ] Rate limiting uygulandı
- [ ] Audit logları çalışıyor
- [ ] Anomali tespiti aktif

---

**Rapor Sonu**

*Bu rapor Bir Adım Umut projesi için hazırlanmıştır.*
*Meta-denetim bulgularına göre genişletilmiştir.*
