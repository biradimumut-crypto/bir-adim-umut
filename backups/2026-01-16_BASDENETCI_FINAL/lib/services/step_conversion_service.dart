import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;  // P1-2 REV.2
import 'badge_service.dart';
import 'device_service.dart';
import 'health_service.dart';
import 'app_security_service.dart';  // P1-2 REV.2: App Check state

/// Adım dönüştürme servisi
/// Kurallar:
/// - Max 2500 adım tek seferde dönüştürülebilir
/// - 10 dakika bekleme süresi (cooldown)
/// - Gece 00:00'da sıfırlanır
/// - 2500 Adım = 25 Hope (100 adım = 1 Hope)
/// - Progress bar 2x bonus: 2500 adım = 50 Hope
/// - Dönüştürülmemiş adımlar ay sonuna kadar taşınır, ayın 1'inde silinir
/// - Referral bonus adımları SÜRESİZ geçerlidir
/// - Aynı cihaz günde sadece 1 hesaba adım kaydedebilir (fraud önleme)
/// - 🚨 P2-1: Her dönüşüm conversion_ledger'a immutable olarak kaydedilir
class StepConversionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BadgeService _badgeService = BadgeService();
  final DeviceService _deviceService = DeviceService();
  final HealthService _healthService = HealthService();
  final AppSecurityService _appSecurity = AppSecurityService();  // P1-2 REV.2

  /// 🚨 P2-1 REV.1: Deterministik idempotency key
  /// Format: {uid}_{dateKey}_{type}_{convertedBefore}_{steps}
  /// Aynı conversion aynı key üretir → duplicate engeli
  String _generateIdempotencyKey(String userId, String dateKey, String type, int convertedBefore, int steps) {
    return '${userId}_${dateKey}_${type}_${convertedBefore}_$steps';
  }

  /// Bugünün adım verilerini al
  Future<Map<String, dynamic>> getTodayStepData(String userId) async {
    final today = _getTodayKey();
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(today)
          .get();

      if (doc.exists) {
        return doc.data() ?? _getDefaultStepData();
      }
      
      // Bugün için kayıt yok, oluştur
      final defaultData = _getDefaultStepData();
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(today)
          .set(defaultData);
      
      return defaultData;
    } catch (e) {
      print('Step data alma hatası: $e');
      return _getDefaultStepData();
    }
  }

  Map<String, dynamic> _getDefaultStepData() {
    return {
      'daily_steps': 0,
      'converted_steps': 0,
      'last_conversion_time': null,
      'date': _getTodayKey(),
    };
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Taşınan (carry-over) adımları hesapla
  /// 
  /// Yeni sistem (Aylık):
  /// 1. users koleksiyonundaki carryover_pending alanını kullan
  /// 2. Süresiz referral bonus adımları (referral_bonus_pending)
  /// 
  /// Bu değerler Cloud Function (resetMonthlyCarryoverSteps) tarafından
  /// her ayın 1'inde sıfırlanır (referral bonus hariç)
  Future<int> getCarryOverSteps(String userId) async {
    int totalCarryOver = 0;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        
        // Sadece aylık carryover adımları (ay sonuna kadar geçerli)
        // Referral bonus artık ayrı tutulacak
        final carryoverPending = userData['carryover_pending'] ?? 0;
        if (carryoverPending > 0) {
          totalCarryOver += (carryoverPending is int) ? carryoverPending : (carryoverPending as num).toInt();
          
          // Eğer bugün için step_carryover logu yoksa otomatik ekle
          await _ensureCarryoverLogExists(userId, totalCarryOver);
        }
      }
    } catch (e) {
      print('Carryover okuma hatası: $e');
    }

    return totalCarryOver;
  }
  
  /// Bugün için step_carryover logu yoksa ekle (Cloud Function bazen log ekleyemeyebilir)
  Future<void> _ensureCarryoverLogExists(String userId, int carryoverAmount) async {
    try {
      print('🔍 Carryover log kontrolü: userId=$userId, amount=$carryoverAmount');
      
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      
      // Bugün için step_carryover logu var mı kontrol et (basit sorgu - index gerektirmez)
      final allCarryoverLogs = await _firestore
          .collection('activity_logs')
          .where('user_id', isEqualTo: userId)
          .where('activity_type', isEqualTo: 'step_carryover')
          .get();
      
      // Client-side filtreleme - bugün mü?
      final todayLogs = allCarryoverLogs.docs.where((doc) {
        final data = doc.data();
        final createdAt = data['created_at'] as Timestamp?;
        if (createdAt == null) return false;
        return createdAt.toDate().isAfter(todayStart);
      }).toList();
      
      print('🔍 Bugünkü log sayısı: ${todayLogs.length}');
      
      if (todayLogs.isEmpty) {
        // Log yok, ekle
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
        final timestamp = Timestamp.now();
        
        // Global activity_logs
        await _firestore.collection('activity_logs').add({
          'user_id': userId,
          'activity_type': 'step_carryover',
          'steps': carryoverAmount,
          'from_date': yesterdayKey,
          'created_at': timestamp,
          'timestamp': timestamp,
        });
        
        // User subcollection activity_logs
        await _firestore.collection('users').doc(userId).collection('activity_logs').add({
          'user_id': userId,
          'activity_type': 'step_carryover',
          'steps': carryoverAmount,
          'from_date': yesterdayKey,
          'created_at': timestamp,
          'timestamp': timestamp,
        });
        
        print('✅ step_carryover logu eklendi: $carryoverAmount adım');
      } else {
        print('ℹ️ step_carryover logu zaten var');
      }
    } catch (e) {
      print('❌ Carryover log kontrolü hatası: $e');
    }
  }
  
  /// Referral bonus adımlarını al (süresiz geçerli, ayrı tutulur)
  Future<int> getReferralBonusSteps(String userId) async {
    int bonusSteps = 0;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        
        final referralBonusSteps = userData['referral_bonus_steps'] ?? 0;
        final referralBonusConverted = userData['referral_bonus_converted'] ?? 0;
        final remaining = (referralBonusSteps is int ? referralBonusSteps : (referralBonusSteps as num).toInt()) 
                         - (referralBonusConverted is int ? referralBonusConverted : (referralBonusConverted as num).toInt());
        
        if (remaining > 0) {
          bonusSteps = remaining;
        }
      }
    } catch (e) {
      print('Referral bonus okuma hatası: $e');
    }

    return bonusSteps;
  }

  /// Taşınan adımları dönüştür (sadece carryover_pending'den)
  /// 🚨 SECURITY: Transaction ile atomik yazma + _isAuthorized entry check
  /// 🚨 P1-2 REV.2: App Check kontrolü (fail-closed)
  Future<Map<String, dynamic>> convertCarryOverSteps({
    required String userId,
    required int steps,
    required double hopeEarned,
  }) async {
    // 🚨 P1-2 REV.2: App Check kontrolü (Release'de zorunlu)
    if (!_appSecurity.canPerformCriticalAction(isReleaseMode: kReleaseMode)) {
      print('⛔ convertCarryOverSteps ENGELLENDI: App Check başlatılamadı');
      return {
        'success': false,
        'error': 'app_check_failed',
        'message': _appSecurity.securityErrorMessage,
      };
    }
    
    // 🚨 ENTRY CHECK: Health API authorization kontrolü (UI-bağımsız)
    if (!_healthService.isAuthorized) {
      print('⛔ convertCarryOverSteps ENGELLENDI: HealthService.isAuthorized=false');
      return {
        'success': false,
        'error': 'health_not_authorized',
        'message': 'Adım verisi doğrulanamadı. Health API yetkisi yok.',
      };
    }
    
    // Device kontrolü - Fraud önleme
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    final deviceCheck = await _deviceService.canSyncSteps(userId, userEmail: userEmail);
    if (deviceCheck['canSync'] != true) {
      print('⚠️ Device fraud engellendi (carryover): ${deviceCheck['reason']}');
      return {
        'success': false,
        'error': 'device_already_used',
        'message': 'Bu cihaz bugün başka bir hesapla kullanıldı. Her cihaz günde sadece bir hesapla adım dönüştürebilir.',
        'ownerId': deviceCheck['ownerId'],
      };
    }

    try {
      // 🚨 P2-1: Idempotency key oluştur - carryover için dateKey: bugünün tarihi
      // 🚨 TRANSACTION: Atomik yazma - race condition önleme
      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);
        final userData = userDoc.data();
        
        // carryover_pending'den düş - double-spend kontrolü
        final currentPending = userData?['carryover_pending'] ?? 0;
        final pendingInt = (currentPending is int) ? currentPending : (currentPending as num).toInt();
        
        if (pendingInt < steps) {
          throw Exception('Yetersiz carryover adımı: mevcut=$pendingInt, istenen=$steps');
        }
        
        final currentCarryoverConverted = userData?['carryover_converted'] ?? 0;
        final carryoverConvertedInt = (currentCarryoverConverted is int) 
            ? currentCarryoverConverted 
            : (currentCarryoverConverted as num).toInt();
        
        // 🚨 P2-1 REV.1: Deterministik idempotency key
        final now = DateTime.now();
        final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final idempotencyKey = _generateIdempotencyKey(userId, dateKey, 'carryover', carryoverConvertedInt, steps);
        final ledgerRef = _firestore.collection('conversion_ledger').doc(idempotencyKey);
        
        // 🚨 P2-1 REV.1: Duplicate check
        final ledgerDoc = await transaction.get(ledgerRef);
        if (ledgerDoc.exists) {
          throw Exception('DUPLICATE_CONVERSION: Bu dönüşüm zaten kaydedilmiş (ledger_id: $idempotencyKey)');
        }
        
        // 🚨 P2-1: Conversion ledger kaydı - WALLET'TAN ÖNCE
        final tsNow = Timestamp.now();
        transaction.set(ledgerRef, {
          'idempotency_key': idempotencyKey,
          'user_id': userId,
          'conversion_type': 'carryover',
          'amount_steps': steps,
          'amount_hope': hopeEarned,
          'date_key': dateKey,
          'carryover_pending_before': pendingInt,
          'carryover_pending_after': pendingInt - steps,
          'carryover_converted_before': carryoverConvertedInt,
          'carryover_converted_after': carryoverConvertedInt + steps,
          'created_at': tsNow,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // User güncelle
        transaction.update(userRef, {
          'carryover_pending': pendingInt - steps,
          'carryover_converted': FieldValue.increment(steps),
          'wallet_balance_hope': FieldValue.increment(hopeEarned),
          'lifetime_converted_steps': FieldValue.increment(steps),
          'lifetime_earned_hope': FieldValue.increment(hopeEarned),
        });

        // Activity log ekle
        
        // Global
        final logRef = _firestore.collection('activity_logs').doc();
        transaction.set(logRef, {
          'user_id': userId,
          'activity_type': 'carryover_conversion',
          'steps_converted': steps,
          'hope_earned': hopeEarned,
          'is_bonus': false,
          'ledger_id': idempotencyKey,
          'created_at': tsNow,
          'timestamp': tsNow,
        });
        
        // User subcollection
        final userLogRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
        transaction.set(userLogRef, {
          'user_id': userId,
          'activity_type': 'carryover_conversion',
          'steps_converted': steps,
          'hope_earned': hopeEarned,
          'is_bonus': false,
          'ledger_id': idempotencyKey,
          'created_at': tsNow,
          'timestamp': tsNow,
        });

        return {'teamId': userData?['current_team_id'], 'ledgerId': idempotencyKey};
      });

      // Takım üyesi günlük adımını güncelle (transaction dışında, kritik değil)
      final teamId = result['teamId'];
      if (teamId != null) {
        try {
          await _firestore
              .collection('teams')
              .doc(teamId)
              .collection('team_members')
              .doc(userId)
              .update({
            'member_daily_steps': FieldValue.increment(steps),
          });
        } catch (e) {
          print('⚠️ Takım güncellemesi başarısız (kritik değil): $e');
        }
      }

      return {'success': true, 'hopeEarned': hopeEarned, 'ledgerId': result['ledgerId']};
    } catch (e) {
      print('❌ convertCarryOverSteps hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Referral bonus adımlarını dönüştür (süresiz geçerli)
  /// 🚨 SECURITY: Transaction ile atomik yazma + _isAuthorized entry check
  /// 🚨 P1-2 REV.2: App Check kontrolü (fail-closed)
  Future<Map<String, dynamic>> convertBonusSteps({
    required String userId,
    required int steps,
    required double hopeEarned,
  }) async {
    // 🚨 P1-2 REV.2: App Check kontrolü (Release'de zorunlu)
    if (!_appSecurity.canPerformCriticalAction(isReleaseMode: kReleaseMode)) {
      print('⛔ convertBonusSteps ENGELLENDI: App Check başlatılamadı');
      return {
        'success': false,
        'error': 'app_check_failed',
        'message': _appSecurity.securityErrorMessage,
      };
    }
    
    // 🚨 ENTRY CHECK: Health API authorization kontrolü (UI-bağımsız)
    if (!_healthService.isAuthorized) {
      print('⛔ convertBonusSteps ENGELLENDI: HealthService.isAuthorized=false');
      return {
        'success': false,
        'error': 'health_not_authorized',
        'message': 'Adım verisi doğrulanamadı. Health API yetkisi yok.',
      };
    }
    
    // Device kontrolü - Fraud önleme
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    final deviceCheck = await _deviceService.canSyncSteps(userId, userEmail: userEmail);
    if (deviceCheck['canSync'] != true) {
      print('⚠️ Device fraud engellendi (bonus): ${deviceCheck['reason']}');
      return {
        'success': false,
        'error': 'device_already_used',
        'message': 'Bu cihaz bugün başka bir hesapla kullanıldı. Her cihaz günde sadece bir hesapla adım dönüştürebilir.',
        'ownerId': deviceCheck['ownerId'],
      };
    }

    try {
      // 🚨 TRANSACTION: Atomik yazma - race condition önleme
      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);
        final userData = userDoc.data();
        
        // Double-spend kontrolü
        final bonusSteps = userData?['referral_bonus_steps'] ?? 0;
        final currentConverted = userData?['referral_bonus_converted'] ?? 0;
        final bonusInt = (bonusSteps is int) ? bonusSteps : (bonusSteps as num).toInt();
        final convertedInt = (currentConverted is int) ? currentConverted : (currentConverted as num).toInt();
        final available = bonusInt - convertedInt;
        
        if (available < steps) {
          throw Exception('Yetersiz bonus adımı: mevcut=$available, istenen=$steps');
        }
        
        // 🚨 P2-1 REV.1: Deterministik idempotency key
        final now = DateTime.now();
        final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final idempotencyKey = _generateIdempotencyKey(userId, dateKey, 'bonus', convertedInt, steps);
        final ledgerRef = _firestore.collection('conversion_ledger').doc(idempotencyKey);
        
        // 🚨 P2-1 REV.1: Duplicate check
        final ledgerDoc = await transaction.get(ledgerRef);
        if (ledgerDoc.exists) {
          throw Exception('DUPLICATE_CONVERSION: Bu dönüşüm zaten kaydedilmiş (ledger_id: $idempotencyKey)');
        }
        
        // 🚨 P2-1: Conversion ledger kaydı - WALLET'TAN ÖNCE
        final tsNow = Timestamp.now();
        transaction.set(ledgerRef, {
          'idempotency_key': idempotencyKey,
          'user_id': userId,
          'conversion_type': 'bonus',
          'amount_steps': steps,
          'amount_hope': hopeEarned,
          'date_key': dateKey,
          'bonus_total': bonusInt,
          'bonus_converted_before': convertedInt,
          'bonus_converted_after': convertedInt + steps,
          'created_at': tsNow,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // User güncelle
        transaction.update(userRef, {
          'referral_bonus_converted': convertedInt + steps,
          'wallet_balance_hope': FieldValue.increment(hopeEarned),
          'lifetime_converted_steps': FieldValue.increment(steps),
          'lifetime_earned_hope': FieldValue.increment(hopeEarned),
        });

        // Activity log ekle
        
        // Global
        final logRef = _firestore.collection('activity_logs').doc();
        transaction.set(logRef, {
          'user_id': userId,
          'activity_type': 'bonus_conversion',
          'steps_converted': steps,
          'hope_earned': hopeEarned,
          'is_bonus': false,
          'is_referral_bonus': true,
          'ledger_id': idempotencyKey,
          'created_at': tsNow,
          'timestamp': tsNow,
        });
        
        // User subcollection
        final userLogRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
        transaction.set(userLogRef, {
          'user_id': userId,
          'activity_type': 'bonus_conversion',
          'steps_converted': steps,
          'hope_earned': hopeEarned,
          'is_bonus': false,
          'is_referral_bonus': true,
          'ledger_id': idempotencyKey,
          'created_at': tsNow,
          'timestamp': tsNow,
        });

        return {'teamId': userData?['current_team_id'], 'ledgerId': idempotencyKey};
      });

      // Takım üyesi günlük adımını güncelle (transaction dışında, kritik değil)
      final teamId = result['teamId'];
      if (teamId != null) {
        try {
          await _firestore
              .collection('teams')
              .doc(teamId)
              .collection('team_members')
              .doc(userId)
              .update({
            'member_daily_steps': FieldValue.increment(steps),
          });
        } catch (e) {
          print('⚠️ Takım güncellemesi başarısız (kritik değil): $e');
        }
      }

      return {'success': true, 'hopeEarned': hopeEarned, 'ledgerId': result['ledgerId']};
    } catch (e) {
      print('❌ convertBonusSteps hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Aylık döngüde süresi dolan adımları temizle
  /// NOT: Bu işlem artık Cloud Function (resetMonthlyCarryoverSteps) tarafından
  /// her ayın 1'inde otomatik yapılır. Bu metod geriye uyumluluk için korunuyor.
  Future<void> cleanupExpiredSteps(String userId) async {
    final now = DateTime.now();
    
    // 8+ gün önceki kayıtları kontrol et ve sil
    for (int i = 8; i <= 30; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _getDateKey(date);
      
      try {
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_steps')
            .doc(key)
            .get();

        if (doc.exists) {
          // Eski kaydı sil veya arşivle
          // Şimdilik silmiyoruz, sadece converted_steps'i daily_steps'e eşitliyoruz
          final data = doc.data()!;
          final dailySteps = data['daily_steps'] ?? 0;
          
          await doc.reference.update({
            'converted_steps': dailySteps,
            'expired': true,
          });
        }
      } catch (e) {
        // Kayıt yok, devam et
      }
    }
  }

  /// Adım güncelle (health plugin'den veya manuel)
  Future<void> updateDailySteps(String userId, int steps) async {
    final today = _getTodayKey();
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_steps')
        .doc(today)
        .set({
          'daily_steps': steps,
          'date': today,
        }, SetOptions(merge: true));
  }

  /// Adımları Hope'a dönüştür
  /// 🚨 SECURITY: Transaction ile atomik yazma + _isAuthorized entry check
  /// 🚨 P1-2 REV.2: App Check kontrolü (fail-closed)
  Future<Map<String, dynamic>> convertSteps({
    required String userId,
    required int steps,
    required double hopeEarned,
    bool isBonus = false, // 2x bonus dönüşümü mü?
  }) async {
    // 🚨 P1-2 REV.2: App Check kontrolü (Release'de zorunlu)
    if (!_appSecurity.canPerformCriticalAction(isReleaseMode: kReleaseMode)) {
      print('⛔ convertSteps ENGELLENDI: App Check başlatılamadı');
      return {
        'success': false,
        'error': 'app_check_failed',
        'message': _appSecurity.securityErrorMessage,
      };
    }
    
    // 🚨 ENTRY CHECK: Health API authorization kontrolü (UI-bağımsız)
    if (!_healthService.isAuthorized) {
      print('⛔ convertSteps ENGELLENDI: HealthService.isAuthorized=false');
      return {
        'success': false,
        'error': 'health_not_authorized',
        'message': 'Adım verisi doğrulanamadı. Health API yetkisi yok.',
      };
    }
    
    final today = _getTodayKey();

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

      // 🚨 TRANSACTION: Atomik yazma - race condition önleme
      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        // 1. Daily steps doc'unu oku (transaction içinde)
        final stepRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_steps')
            .doc(today);
        final stepDoc = await transaction.get(stepRef);
        
        // 🚨 UPSERT: Doc yoksa veya daily_steps=0 ise sync gerekli
        int currentConverted = 0;
        int dailySteps = 0;
        
        if (stepDoc.exists) {
          final stepData = stepDoc.data()!;
          currentConverted = (stepData['converted_steps'] ?? 0) as int;
          // 📌 CANONICAL SOURCE: daily_steps alanı = Health API'den sync edilen değer
          dailySteps = (stepData['daily_steps'] ?? 0) as int;
        }
        
        // 🚨 SYNC KONTROLÜ: Doc yoksa veya daily_steps=0 ise kullanıcıyı bilgilendir
        if (!stepDoc.exists || dailySteps == 0) {
          throw Exception('SYNC_REQUIRED: Adım verisi henüz senkronize edilmedi. Lütfen önce adımlarınızı senkronize edin.');
        }
        
        // Double-spend kontrolü: Yeterli dönüştürülmemiş adım var mı?
        // 📌 availableSteps = Firestore'daki daily_steps - converted_steps
        // 📌 Client'tan gelen "steps" parametresi ile kıyaslanır
        final availableSteps = dailySteps - currentConverted;
        if (availableSteps < steps) {
          throw Exception('Yetersiz adım: mevcut=$availableSteps, istenen=$steps');
        }
        
        // 2. User doc'unu oku
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);
        
        // 🚨 P2-1 REV.1: Deterministik idempotency key
        final conversionType = isBonus ? 'daily_2x' : 'daily';
        final idempotencyKey = _generateIdempotencyKey(userId, today, conversionType, currentConverted, steps);
        final ledgerRef = _firestore.collection('conversion_ledger').doc(idempotencyKey);
        
        // 🚨 P2-1 REV.1: Duplicate check - varsa işlem zaten yapılmış
        final ledgerDoc = await transaction.get(ledgerRef);
        if (ledgerDoc.exists) {
          throw Exception('DUPLICATE_CONVERSION: Bu dönüşüm zaten kaydedilmiş (ledger_id: $idempotencyKey)');
        }
        
        // 3. Daily steps güncelle - SET with merge (upsert)
        final now = Timestamp.now();
        final stepUpdateData = <String, dynamic>{
          'converted_steps': currentConverted + steps,
          'last_conversion_time': now,
          'date': today,  // Doc yoksa tarih de ekle
        };
        if (isBonus) {
          stepUpdateData['bonus_conversion_count'] = FieldValue.increment(1);
          stepUpdateData['bonus_steps_converted'] = FieldValue.increment(steps);
        }
        // 🚨 SET with merge: Doc yoksa oluşturur, varsa günceller
        transaction.set(stepRef, stepUpdateData, SetOptions(merge: true));
        
        // 🚨 P2-1: LEDGER YAZIMI (wallet'tan ÖNCE - atomik garanti)
        // Ledger kaydı olmadan wallet artmaz
        transaction.set(ledgerRef, {
          'idempotency_key': idempotencyKey,
          'user_id': userId,
          'conversion_type': conversionType,
          'amount_steps': steps,
          'amount_hope': hopeEarned,
          'date_key': today,
          'daily_steps_at_conversion': dailySteps,
          'converted_steps_before': currentConverted,
          'converted_steps_after': currentConverted + steps,
          'created_at': now,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // 4. User wallet güncelle (ledger'dan SONRA)
        transaction.update(userRef, {
          'wallet_balance_hope': FieldValue.increment(hopeEarned),
          'lifetime_converted_steps': FieldValue.increment(steps),
          'lifetime_earned_hope': FieldValue.increment(hopeEarned),
        });
        
        // 5. Activity log ekle (transaction içinde)
        final logRef = _firestore.collection('activity_logs').doc();
        transaction.set(logRef, {
          'user_id': userId,
          'activity_type': isBonus ? 'step_conversion_2x' : 'step_conversion',
          'steps_converted': steps,
          'hope_earned': hopeEarned,
          'is_bonus': isBonus,
          'ledger_id': idempotencyKey,  // P2-1: Ledger referansı
          'created_at': now,
          'timestamp': now,
        });
        
        // User subcollection activity_logs
        final userLogRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
        transaction.set(userLogRef, {
          'user_id': userId,
          'activity_type': isBonus ? 'step_conversion_2x' : 'step_conversion',
          'steps_converted': steps,
          'hope_earned': hopeEarned,
          'is_bonus': isBonus,
          'ledger_id': idempotencyKey,  // P2-1: Ledger referansı
          'created_at': now,
          'timestamp': now,
        });
        
        // teamId'yi döndür (transaction dışında kullanmak için)
        return {
          'success': true,
          'teamId': userDoc.data()?['current_team_id'],
          'ledgerId': idempotencyKey,  // P2-1: Ledger ID döndür
        };
      });
      
      // Transaction başarılı - takım güncellemesi (transaction dışında, kritik değil)
      final teamId = result['teamId'];
      if (teamId != null) {
        try {
          await _firestore
              .collection('teams')
              .doc(teamId)
              .collection('team_members')
              .doc(userId)
              .update({
            'member_daily_steps': FieldValue.increment(steps),
          });
        } catch (e) {
          // Takım güncellemesi başarısız olsa bile conversion başarılı
          print('⚠️ Takım güncellemesi başarısız (kritik değil): $e');
        }
      }

      // 🎖️ Lifetime adımları güncelle ve rozet kontrol et
      await _badgeService.updateLifetimeSteps(steps);

      return {'success': true, 'hopeEarned': hopeEarned};
    } catch (e) {
      print('❌ convertSteps hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cooldown kontrolü
  Future<bool> canConvert(String userId) async {
    final data = await getTodayStepData(userId);
    final lastConversion = data['last_conversion_time'] as Timestamp?;
    
    if (lastConversion == null) return true;
    
    final diff = DateTime.now().difference(lastConversion.toDate());
    return diff.inMinutes >= 10;
  }

  /// Kalan cooldown süresi (saniye)
  Future<int> getRemainingCooldown(String userId) async {
    final data = await getTodayStepData(userId);
    final lastConversion = data['last_conversion_time'] as Timestamp?;
    
    if (lastConversion == null) return 0;
    
    final diff = DateTime.now().difference(lastConversion.toDate());
    final remaining = 600 - diff.inSeconds; // 10 dakika = 600 saniye
    
    return remaining > 0 ? remaining : 0;
  }

  /// Haftalık adım özeti
  Future<List<int>> getWeeklySteps(String userId) async {
    final List<int> weeklySteps = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      try {
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_steps')
            .doc(key)
            .get();

        weeklySteps.add(doc.data()?['daily_steps'] ?? 0);
      } catch (e) {
        weeklySteps.add(0);
      }
    }

    return weeklySteps;
  }

  /// Haftalık dönüştürülen adım özeti
  Future<List<int>> getWeeklyConvertedSteps(String userId) async {
    final List<int> weeklyConverted = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      try {
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_steps')
            .doc(key)
            .get();

        weeklyConverted.add(doc.data()?['converted_steps'] ?? 0);
      } catch (e) {
        weeklyConverted.add(0);
      }
    }

    return weeklyConverted;
  }

  /// Bugünün adım verisini sıfırla (test için)
  Future<void> resetTodaySteps(String userId) async {
    final today = _getTodayKey();
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_steps')
        .doc(today)
        .set({
          'daily_steps': 0,
          'converted_steps': 0,
          'date': today,
          'last_conversion_time': null,
        });
    print('✅ Bugünün adım verisi sıfırlandı: $today');
  }

  /// Bozuk veriyi düzelt (converted > daily durumu)
  Future<void> fixCorruptedData(String userId) async {
    final today = _getTodayKey();
    
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_steps')
        .doc(today)
        .get();
    
    if (doc.exists) {
      final data = doc.data()!;
      final dailySteps = data['daily_steps'] ?? 0;
      final convertedSteps = data['converted_steps'] ?? 0;
      
      // Converted, daily'den büyükse düzelt
      if (convertedSteps > dailySteps) {
        await doc.reference.update({
          'converted_steps': dailySteps, // daily_steps'e eşitle
        });
        print('🔧 Bozuk veri düzeltildi: converted_steps $convertedSteps -> $dailySteps');
      }
    }
  }
  
  // ==================== SIRALAMA ÖDÜLÜ BONUS DÖNÜŞTÜRME ====================
  
  /// Sıralama ödülü bonus adımlarını al
  Future<int> getLeaderboardBonusSteps(String userId) async {
    int bonusSteps = 0;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        
        final leaderboardBonusSteps = userData['leaderboard_bonus_steps'] ?? 0;
        final leaderboardBonusConverted = userData['leaderboard_bonus_converted'] ?? 0;
        final remaining = (leaderboardBonusSteps is int ? leaderboardBonusSteps : (leaderboardBonusSteps as num).toInt()) 
                         - (leaderboardBonusConverted is int ? leaderboardBonusConverted : (leaderboardBonusConverted as num).toInt());
        
        if (remaining > 0) {
          bonusSteps = remaining;
        }
      }
    } catch (e) {
      print('Leaderboard bonus okuma hatası: $e');
    }

    return bonusSteps;
  }
  
  /// Sıralama ödülü bonus adımlarını dönüştür (reklam izledikten sonra)
  Future<Map<String, dynamic>> convertLeaderboardBonusSteps({
    required String userId,
    required int steps,
    required double hopeEarned,
  }) async {
    // Device kontrolü - Fraud önleme
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    final deviceCheck = await _deviceService.canSyncSteps(userId, userEmail: userEmail);
    if (deviceCheck['canSync'] != true) {
      print('⚠️ Device fraud engellendi (leaderboard bonus): ${deviceCheck['reason']}');
      return {
        'success': false,
        'error': 'device_already_used',
        'message': 'Bu cihaz bugün başka bir hesapla kullanıldı. Her cihaz günde sadece bir hesapla adım dönüştürebilir.',
        'ownerId': deviceCheck['ownerId'],
      };
    }

    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final userData = userDoc.data();
      
      // Mevcut bonus kontrolü
      final currentBonus = userData?['leaderboard_bonus_steps'] ?? 0;
      final currentConverted = userData?['leaderboard_bonus_converted'] ?? 0;
      final remaining = (currentBonus is int ? currentBonus : (currentBonus as num).toInt()) 
                       - (currentConverted is int ? currentConverted : (currentConverted as num).toInt());
      
      if (remaining < steps) {
        return {'success': false, 'error': 'Yetersiz sıralama bonus adımı'};
      }
      
      final batch = _firestore.batch();
      
      batch.update(userRef, {
        'leaderboard_bonus_converted': FieldValue.increment(steps),
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
        'activity_type': 'leaderboard_bonus_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': false,
        'is_leaderboard_bonus': true,
        'created_at': now,
        'timestamp': now,
      });
      
      // User subcollection
      final userLogRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
      batch.set(userLogRef, {
        'user_id': userId,
        'activity_type': 'leaderboard_bonus_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': false,
        'is_leaderboard_bonus': true,
        'created_at': now,
        'timestamp': now,
      });

      await batch.commit();

      return {'success': true, 'hopeEarned': hopeEarned};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // ==================== TAKIM BONUS DÖNÜŞTÜRME ====================
  
  /// Takım bonus adımlarını al
  Future<int> getTeamBonusSteps(String teamId) async {
    int bonusSteps = 0;

    try {
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      if (teamDoc.exists) {
        final teamData = teamDoc.data()!;
        
        final teamBonusSteps = teamData['team_bonus_steps'] ?? 0;
        final teamBonusConverted = teamData['team_bonus_converted'] ?? 0;
        final remaining = (teamBonusSteps is int ? teamBonusSteps : (teamBonusSteps as num).toInt()) 
                         - (teamBonusConverted is int ? teamBonusConverted : (teamBonusConverted as num).toInt());
        
        if (remaining > 0) {
          bonusSteps = remaining;
        }
      }
    } catch (e) {
      print('Takım bonus okuma hatası: $e');
    }

    return bonusSteps;
  }
  
  /// Takım bonus adımlarını dönüştür
  /// Kim dönüştürürse Hope onun cüzdanına eklenir
  /// Reklam izledikten sonra çağrılmalı
  Future<Map<String, dynamic>> convertTeamBonusSteps({
    required String userId,
    required String teamId,
    required int steps,
    required double hopeEarned,
  }) async {
    // Önce kullanıcının bu takımda olup olmadığını kontrol et
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userTeamId = userDoc.data()?['current_team_id'];
      
      if (userTeamId != teamId) {
        return {'success': false, 'error': 'Bu takımın üyesi değilsiniz'};
      }
      
      // Takım bonus kontrolü
      final teamRef = _firestore.collection('teams').doc(teamId);
      final teamDoc = await teamRef.get();
      final teamData = teamDoc.data();
      
      final currentBonus = teamData?['team_bonus_steps'] ?? 0;
      final currentConverted = teamData?['team_bonus_converted'] ?? 0;
      final remaining = (currentBonus is int ? currentBonus : (currentBonus as num).toInt()) 
                       - (currentConverted is int ? currentConverted : (currentConverted as num).toInt());
      
      if (remaining < steps) {
        return {'success': false, 'error': 'Yetersiz takım bonus adımı'};
      }
      
      final batch = _firestore.batch();
      
      // Takım bonus'unu düş
      batch.update(teamRef, {
        'team_bonus_converted': FieldValue.increment(steps),
      });
      
      // Kullanıcının cüzdanına Hope ekle
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
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
        'team_id': teamId,
        'activity_type': 'team_bonus_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': false,
        'is_team_bonus': true,
        'created_at': now,
        'timestamp': now,
      });
      
      // User subcollection
      final userLogRef = _firestore.collection('users').doc(userId).collection('activity_logs').doc();
      batch.set(userLogRef, {
        'user_id': userId,
        'team_id': teamId,
        'activity_type': 'team_bonus_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': false,
        'is_team_bonus': true,
        'created_at': now,
        'timestamp': now,
      });

      await batch.commit();

      return {'success': true, 'hopeEarned': hopeEarned};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
