import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'badge_service.dart';
import 'device_service.dart';

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
class StepConversionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BadgeService _badgeService = BadgeService();
  final DeviceService _deviceService = DeviceService();

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
        }
      }
    } catch (e) {
      print('Carryover okuma hatası: $e');
    }

    return totalCarryOver;
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
        'message': 'Bu cihaz bugün başka bir hesapla kullanıldı. Her cihaz günde sadece bir hesapla adım dönüştürebilir.',
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
        'carryover_converted': FieldValue.increment(steps), // Dönüştürülen carryover takibi
        'wallet_balance_hope': FieldValue.increment(hopeEarned),
        'lifetime_converted_steps': FieldValue.increment(steps),
        'lifetime_earned_hope': FieldValue.increment(hopeEarned),
      });

      // Activity log ekle
      final logRef = _firestore.collection('activity_logs').doc();
      batch.set(logRef, {
        'user_id': userId,
        'activity_type': 'carryover_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': false, // Carryover normal oran ile dönüştürülür
        'created_at': Timestamp.now(),
      });

      await batch.commit();

      // Takım üyesi günlük adımını güncelle (eğer takımda ise)
      final teamId = userData?['current_team_id'];
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

      return {'success': true, 'hopeEarned': hopeEarned};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Referral bonus adımlarını dönüştür (süresiz geçerli)
  Future<Map<String, dynamic>> convertBonusSteps({
    required String userId,
    required int steps,
    required double hopeEarned,
  }) async {
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
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final userData = userDoc.data();
      
      // Bonus adımları güncelle
      final currentConverted = userData?['referral_bonus_converted'] ?? 0;
      final batch = _firestore.batch();
      
      batch.update(userRef, {
        'referral_bonus_converted': (currentConverted is int ? currentConverted : (currentConverted as num).toInt()) + steps,
        'wallet_balance_hope': FieldValue.increment(hopeEarned),
        'lifetime_converted_steps': FieldValue.increment(steps),
        'lifetime_earned_hope': FieldValue.increment(hopeEarned),
      });

      // Activity log ekle
      final logRef = _firestore.collection('activity_logs').doc();
      batch.set(logRef, {
        'user_id': userId,
        'activity_type': 'bonus_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': false, // Referral bonus adımlar normal oran ile dönüştürülür (2x değil)
        'is_referral_bonus': true, // Referral bonus olduğunu belirt
        'created_at': Timestamp.now(),
      });

      await batch.commit();

      // Takım üyesi günlük adımını güncelle (eğer takımda ise)
      final teamId = userData?['current_team_id'];
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

      return {'success': true, 'hopeEarned': hopeEarned};
    } catch (e) {
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
      final logRef = _firestore.collection('activity_logs').doc();
      batch.set(logRef, {
        'user_id': userId,
        'activity_type': isBonus ? 'step_conversion_2x' : 'step_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': isBonus,
        'created_at': Timestamp.now(),
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
      final logRef = _firestore.collection('activity_logs').doc();
      batch.set(logRef, {
        'user_id': userId,
        'activity_type': 'leaderboard_bonus_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': false, // Normal oran ile dönüştürülür
        'is_leaderboard_bonus': true,
        'created_at': Timestamp.now(),
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
      final logRef = _firestore.collection('activity_logs').doc();
      batch.set(logRef, {
        'user_id': userId,
        'team_id': teamId,
        'activity_type': 'team_bonus_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'is_bonus': false,
        'is_team_bonus': true,
        'created_at': Timestamp.now(),
      });

      await batch.commit();

      return {'success': true, 'hopeEarned': hopeEarned};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
