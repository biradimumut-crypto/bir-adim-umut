import 'package:cloud_firestore/cloud_firestore.dart';

/// Adım dönüştürme servisi
/// Kurallar:
/// - Max 2500 adım tek seferde dönüştürülebilir
/// - 10 dakika bekleme süresi (cooldown)
/// - Gece 00:00'da sıfırlanır
/// - 2500 Adım = 0.10 Hope
/// - Dönüştürülmemiş adımlar 7 gün taşınır, sonra silinir
class StepConversionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Taşınan (carry-over) adımları hesapla - son 7 günden
  Future<int> getCarryOverSteps(String userId) async {
    int totalCarryOver = 0;
    final now = DateTime.now();
    final today = _getTodayKey();

    // Son 7 günü kontrol et (bugün hariç)
    for (int i = 1; i <= 7; i++) {
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
          final data = doc.data()!;
          final dailySteps = data['daily_steps'] ?? 0;
          final convertedSteps = data['converted_steps'] ?? 0;
          final remaining = dailySteps - convertedSteps;
          
          if (remaining > 0) {
            totalCarryOver += remaining as int;
          }
        }
      } catch (e) {
        print('Carry-over hesaplama hatası: $e');
      }
    }

    return totalCarryOver;
  }

  /// Taşınan adımları dönüştür (en eski günden başlayarak)
  Future<Map<String, dynamic>> convertCarryOverSteps({
    required String userId,
    required int steps,
    required double hopeEarned,
  }) async {
    final now = DateTime.now();
    int remainingToConvert = steps;
    final batch = _firestore.batch();

    try {
      // En eski günden başlayarak dönüştür (7. günden 1. güne)
      for (int i = 7; i >= 1 && remainingToConvert > 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = _getDateKey(date);
        
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_steps')
            .doc(key)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final dailySteps = data['daily_steps'] ?? 0;
          final convertedSteps = data['converted_steps'] ?? 0;
          final available = dailySteps - convertedSteps;
          
          if (available > 0) {
            final toConvert = available < remainingToConvert ? available : remainingToConvert;
            
            batch.update(doc.reference, {
              'converted_steps': FieldValue.increment(toConvert),
            });
            
            remainingToConvert -= toConvert as int;
          }
        }
      }

      // User wallet güncelle
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'wallet_balance_hope': FieldValue.increment(hopeEarned),
      });

      // Activity log ekle
      final logRef = _firestore.collection('activity_logs').doc();
      batch.set(logRef, {
        'user_id': userId,
        'activity_type': 'carryover_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'created_at': Timestamp.now(),
      });

      await batch.commit();

      return {'success': true, 'hopeEarned': hopeEarned};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 7 günden eski dönüştürülmemiş adımları temizle
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
  }) async {
    final today = _getTodayKey();
    final batch = _firestore.batch();

    try {
      // 1. Daily steps güncelle
      final stepRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(today);

      batch.update(stepRef, {
        'converted_steps': FieldValue.increment(steps),
        'last_conversion_time': Timestamp.now(),
      });

      // 2. User wallet güncelle
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'wallet_balance_hope': FieldValue.increment(hopeEarned),
      });

      // 3. Activity log ekle
      final logRef = _firestore.collection('activity_logs').doc();
      batch.set(logRef, {
        'user_id': userId,
        'activity_type': 'step_conversion',
        'steps_converted': steps,
        'hope_earned': hopeEarned,
        'created_at': Timestamp.now(),
      });

      await batch.commit();

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
}
