import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Health ve Pedometer geçici olarak devre dışı
// import 'package:health/health.dart';
// import 'package:pedometer/pedometer.dart';
import '../models/daily_step_model.dart';

class StepService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Health plugin geçici olarak devre dışı
  // final Health _health = Health();
  // final List<String> permissions = [
  //   HealthDataType.STEPS.toString(),
  // ];

  /// Cihaz adımlarını (Pedometer/Health) gerçek zamanda oku
  /// MOCK: Geçici olarak boş stream döner
  Stream<int> getStepsStream() {
    // return Pedometer.stepCountStream;
    return Stream.periodic(const Duration(seconds: 5), (count) => count * 100);
  }

  /// Bugünün adımlarını al
  /// MOCK: Geçici olarak rastgele değer döner
  Future<int> getTodaySteps() async {
    try {
      // Mock değer - gerçek implementasyon için health paketi gerekli
      return DateTime.now().millisecond * 10; // Test için rastgele değer
    } catch (e) {
      print('Günlük adım al hatası: $e');
      return 0;
    }
  }

  /// Günlük adım verisini Firestore'a senkronize et
  /// 
  /// İş Mantığı:
  /// 1. Bugünün adımlarını cihazdan oku
  /// 2. Firestore'daki günlük kayıtla karşılaştır
  /// 3. Yeni veya güncellenmiş veriyi kaydet
  /// 4. Senkronizasyon zamanını kaydet (cooldown için)
  Future<Map<String, dynamic>> syncTodayStepsToFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {'success': false, 'error': 'Kullanıcı oturum açmamış'};
      }

      // Cihazdan bugünün adımlarını al
      final todaySteps = await getTodaySteps();

      // Günlük adım belgesini Firestore'dan al veya oluştur
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final stepDocId = '$userId-$dateStr';

      final stepDocRef = _firestore.collection('daily_steps').doc(stepDocId);
      final stepDoc = await stepDocRef.get();

      late int previousSteps;
      late int convertedSteps;

      if (stepDoc.exists) {
        final data = stepDoc.data()!;
        previousSteps = data['total_steps'] ?? 0;
        convertedSteps = data['converted_steps'] ?? 0;
      } else {
        previousSteps = 0;
        convertedSteps = 0;
      }

      // Günlük adım verisi güncelle
      await stepDocRef.set({
        'user_id': userId,
        'total_steps': todaySteps,
        'converted_steps': convertedSteps,
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'is_reset': false,
        'last_conversion_time': stepDoc.exists
            ? (stepDoc.data()?['last_conversion_time'] ?? Timestamp.now())
            : Timestamp.now(),
      }, SetOptions(merge: true));

      // Kullanıcı'nın last_step_sync_time'ını güncelle
      await _firestore.collection('users').doc(userId).update({
        'last_step_sync_time': Timestamp.now(),
      });

      return {
        'success': true,
        'totalSteps': todaySteps,
        'convertedSteps': convertedSteps,
        'availableSteps': todaySteps - convertedSteps,
        'stepChange': todaySteps - previousSteps,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Bugünün Daily Step modelini al
  Future<DailyStepModel?> getTodayDailyStepModel() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final stepDocId = '$userId-$dateStr';

      final doc = await _firestore.collection('daily_steps').doc(stepDocId).get();
      if (!doc.exists) return null;

      return DailyStepModel.fromFirestore(doc);
    } catch (e) {
      print('Daily step model al hatası: $e');
      return null;
    }
  }

  /// Haftalık adım geçmişini al (7 gün)
  Future<List<Map<String, dynamic>>> getWeeklyStepsHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('daily_steps')
          .where('user_id', isEqualTo: userId)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('date', descending: false)
          .get();

      final historyList = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        historyList.add({
          'date': (data['date'] as Timestamp).toDate(),
          'totalSteps': data['total_steps'] ?? 0,
          'convertedSteps': data['converted_steps'] ?? 0,
          'availableSteps': (data['total_steps'] ?? 0) - (data['converted_steps'] ?? 0),
        });
      }

      return historyList;
    } catch (e) {
      print('Haftalık adım geçmişi al hatası: $e');
      return [];
    }
  }

  /// Aylık adım istatistiklerini al
  Future<Map<String, dynamic>> getMonthlyStatstics({
    required int year,
    required int month,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {};

      final firstDay = DateTime(year, month, 1);
      final lastDay = month == 12
          ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('daily_steps')
          .where('user_id', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
          .get();

      int totalSteps = 0;
      int totalConverted = 0;
      int daysWithSteps = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalSteps += data['total_steps'] ?? 0;
        totalConverted += data['converted_steps'] ?? 0;
        if ((data['total_steps'] ?? 0) > 0) {
          daysWithSteps++;
        }
      }

      final averageSteps = daysWithSteps > 0 ? totalSteps ~/ daysWithSteps : 0;

      return {
        'totalSteps': totalSteps,
        'totalConverted': totalConverted,
        'daysWithSteps': daysWithSteps,
        'averageStepsPerDay': averageSteps,
        'monthDays': lastDay.day,
      };
    } catch (e) {
      print('Aylık istatistik al hatası: $e');
      return {};
    }
  }

  /// Gece 00:00'de adımları sıfırla (Scheduled Cloud Function)
  /// Bu fonksiyon Cloud Functions'ta günlük çalıştırılmalı
  Future<void> resetDailySteps() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final stepDocId = '$userId-$dateStr';

      // Dünün adım belgesini al
      final yesterdayDoc =
          await _firestore.collection('daily_steps').doc(stepDocId).get();

      if (yesterdayDoc.exists) {
        // Bugün için yeni belge oluştur (sıfırlanmış)
        final today = DateTime.now();
        final todayStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final todayDocId = '$userId-$todayStr';

        await _firestore.collection('daily_steps').doc(todayDocId).set({
          'user_id': userId,
          'total_steps': 0,
          'converted_steps': 0,
          'date': Timestamp.fromDate(DateTime(today.year, today.month, today.day)),
          'is_reset': true,
          'last_conversion_time': Timestamp.now(),
        });
      }
    } catch (e) {
      print('Günlük sıfırlama hatası: $e');
    }
  }

  /// Cooldown kontrolü (10 dakika)
  Future<bool> canConvertSteps() async {
    try {
      final todayModel = await getTodayDailyStepModel();
      if (todayModel == null) return true;
      return todayModel.canConvertSteps();
    } catch (e) {
      print('Cooldown kontrol hatası: $e');
      return false;
    }
  }

  /// Son dönüştürmeden kalan zamanı al (dakika cinsinden)
  Future<int> getTimeUntilNextConversion() async {
    try {
      final todayModel = await getTodayDailyStepModel();
      if (todayModel == null) return 0;

      final now = DateTime.now();
      final difference = now.difference(todayModel.lastConversionTime);
      final remainingMinutes = 10 - difference.inMinutes;

      return remainingMinutes > 0 ? remainingMinutes : 0;
    } catch (e) {
      print('Kalan zaman al hatası: $e');
      return 0;
    }
  }
}
