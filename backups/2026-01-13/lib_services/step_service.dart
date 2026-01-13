import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/daily_step_model.dart';
import 'health_service.dart';

/// Adım Servisi - Health API entegrasyonu ile
/// 
/// Tek koleksiyon yapısı: /users/{uid}/daily_steps/{date}
/// HealthService ile entegre çalışır
class StepService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HealthService _healthService = HealthService();

  /// Singleton pattern
  static final StepService _instance = StepService._internal();
  factory StepService() => _instance;
  StepService._internal();

  /// Bugünün tarih anahtarını al
  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Cihaz adımlarını gerçek zamanda oku (stream)
  Stream<int> getStepsStream() {
    return Stream.periodic(const Duration(seconds: 10), (count) async {
      final steps = await getTodaySteps();
      return steps;
    }).asyncMap((event) => event);
  }

  /// Bugünün adımlarını al (HealthService'den)
  Future<int> getTodaySteps() async {
    try {
      // HealthService'i başlat (henüz başlatılmadıysa)
      if (!_healthService.isAuthorized) {
        await _healthService.initialize();
      }
      
      // HealthService'den güncel adım sayısını al
      final steps = await _healthService.fetchTodaySteps();
      return steps;
    } catch (e) {
      print('Günlük adım al hatası: $e');
      return 0;
    }
  }

  /// Günlük adım verisini Firestore'a senkronize et
  Future<Map<String, dynamic>> syncTodayStepsToFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {'success': false, 'error': 'Kullanıcı oturum açmamış'};
      }

      // Health API'den bugünün adımlarını al
      final todaySteps = await getTodaySteps();
      final today = _getTodayKey();

      // Kullanıcının daily_steps subcollection'ına yaz
      final stepDocRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(today);
      
      final stepDoc = await stepDocRef.get();

      int previousSteps = 0;
      int convertedSteps = 0;

      if (stepDoc.exists) {
        final data = stepDoc.data()!;
        previousSteps = data['daily_steps'] ?? 0;
        convertedSteps = data['converted_steps'] ?? 0;
      }

      // Günlük adım verisi güncelle
      await stepDocRef.set({
        'daily_steps': todaySteps,
        'converted_steps': convertedSteps,
        'date': today,
        'last_sync_time': Timestamp.now(),
      }, SetOptions(merge: true));

      // Kullanıcının last_step_sync_time'ını güncelle
      await _firestore.collection('users').doc(userId).update({
        'last_step_sync_time': Timestamp.now(),
      });

      return {
        'success': true,
        'totalSteps': todaySteps,
        'convertedSteps': convertedSteps,
        'availableSteps': todaySteps - convertedSteps,
        'stepChange': todaySteps - previousSteps,
        'isSimulated': _healthService.isUsingSimulatedData,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Health API kullanılabilir mi?
  bool get isUsingRealData => !_healthService.isUsingSimulatedData;

  /// Health Connect / HealthKit kurulu mu?
  Future<bool> isHealthAvailable() => _healthService.isHealthAvailable();

  /// Health Connect'i kur (Android)
  Future<void> installHealthConnect() => _healthService.installHealthConnect();

  /// Bugünün Daily Step modelini al
  Future<DailyStepModel?> getTodayDailyStepModel() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final today = _getTodayKey();
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(today)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return DailyStepModel(
        stepId: doc.id,
        userId: userId,
        totalSteps: data['daily_steps'] ?? 0,
        convertedSteps: data['converted_steps'] ?? 0,
        date: DateTime.now(),
        isReset: false,
        lastConversionTime: (data['last_conversion_time'] as Timestamp?)?.toDate() ?? 
            DateTime.now().subtract(const Duration(minutes: 11)),
      );
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

      final List<Map<String, dynamic>> historyList = [];
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

          final data = doc.data();
          historyList.add({
            'date': date,
            'totalSteps': data?['daily_steps'] ?? 0,
            'convertedSteps': data?['converted_steps'] ?? 0,
            'availableSteps': (data?['daily_steps'] ?? 0) - (data?['converted_steps'] ?? 0),
          });
        } catch (e) {
          historyList.add({
            'date': date,
            'totalSteps': 0,
            'convertedSteps': 0,
            'availableSteps': 0,
          });
        }
      }

      return historyList;
    } catch (e) {
      print('Haftalık adım geçmişi al hatası: $e');
      return [];
    }
  }

  /// Aylık adım istatistiklerini al
  Future<Map<String, dynamic>> getMonthlyStatistics({
    required int year,
    required int month,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {};

      int totalSteps = 0;
      int totalConverted = 0;
      int daysWithSteps = 0;

      final lastDay = DateTime(year, month + 1, 0);

      for (int day = 1; day <= lastDay.day; day++) {
        final date = DateTime(year, month, day);
        if (date.isAfter(DateTime.now())) break;
        
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        try {
          final doc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('daily_steps')
              .doc(key)
              .get();

          if (doc.exists) {
            final data = doc.data()!;
            final steps = data['daily_steps'] ?? 0;
            final converted = data['converted_steps'] ?? 0;
            
            totalSteps += (steps as num).toInt();
            totalConverted += (converted as num).toInt();
            if (steps > 0) daysWithSteps++;
          }
        } catch (e) {
          // Veri yok, devam et
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

  /// Cooldown kontrolü (10 dakika)
  Future<bool> canConvertSteps() async {
    try {
      final todayModel = await getTodayDailyStepModel();
      if (todayModel == null) return true;
      return todayModel.canConvertSteps();
    } catch (e) {
      print('Cooldown kontrol hatası: $e');
      return true;
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
