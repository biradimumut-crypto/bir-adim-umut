import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

/// Health API Servisi - Apple Health / Google Fit entegrasyonu
/// 
/// iOS: Apple HealthKit
/// Android: Health Connect (Google Fit yerini aldı)
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _isAuthorized = false;
  int _todaySteps = 0;
  bool _useSimulatedData = false;

  bool get isAuthorized => _isAuthorized;
  int get todaySteps => _todaySteps;
  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isUsingSimulatedData => _useSimulatedData;

  /// Okunacak sağlık veri tipleri
  static final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// Health API'yi başlat ve izin iste
  Future<bool> initialize() async {
    try {
      if (kIsWeb) {
        debugPrint('Health API web\'de desteklenmiyor');
        _useSimulatedData = true;
        _isAuthorized = true;
        _todaySteps = _generateSimulatedSteps();
        return true;
      }

      // Android için Activity Recognition izni
      if (isAndroid) {
        final activityStatus = await Permission.activityRecognition.request();
        if (!activityStatus.isGranted) {
          debugPrint('Activity Recognition izni reddedildi');
        }

        // Health Connect durumunu kontrol et
        try {
          final sdkStatus = await _health.getHealthConnectSdkStatus();
          debugPrint('Health Connect SDK durumu: $sdkStatus');

          if (sdkStatus == HealthConnectSdkStatus.sdkUnavailable) {
            debugPrint('Health Connect yüklü değil, simüle veri kullanılacak');
            _useSimulatedData = true;
            _isAuthorized = true;
            _todaySteps = _generateSimulatedSteps();
            return true;
          }
        } catch (e) {
          debugPrint('Health Connect kontrolü başarısız: $e');
        }
      }

      // İzin türlerini ayarla (sadece okuma)
      final permissions = _types.map((e) => HealthDataAccess.READ).toList();

      // İzin iste
      bool authorized = await _health.requestAuthorization(
        _types,
        permissions: permissions,
      );

      debugPrint('Health API requestAuthorization sonucu: $authorized');

      // iOS'ta requestAuthorization her zaman true döner
      // Gerçek veri okumayı deneyerek test edelim
      if (isIOS || authorized) {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        
        try {
          int? testSteps = await _health.getTotalStepsInInterval(midnight, now);
          debugPrint('HealthKit test okuması: $testSteps');
          
          // iOS'ta her zaman gerçek veri kullan (null ise 0)
          _isAuthorized = true;
          _useSimulatedData = false;
          _todaySteps = testSteps ?? 0;
          debugPrint('✅ HealthKit başlatıldı: $_todaySteps adım');
        } catch (e) {
          debugPrint('❌ HealthKit okuma hatası: $e');
          // iOS'ta hata olsa bile simüle veriye geçme
          if (isIOS) {
            _isAuthorized = true;
            _useSimulatedData = false;
            _todaySteps = 0;
          } else {
            _isAuthorized = false;
            _useSimulatedData = true;
            _todaySteps = _generateSimulatedSteps();
          }
        }
      } else {
        debugPrint('Health API izni reddedildi, simüle veri kullanılacak');
        _useSimulatedData = true;
        _todaySteps = _generateSimulatedSteps();
      }

      return true;
    } catch (e) {
      debugPrint('Health API başlatma hatası: $e');
      // Hata durumunda simüle veri kullan
      _useSimulatedData = true;
      _isAuthorized = true;
      _todaySteps = _generateSimulatedSteps();
      return true;
    }
  }

  /// Bugünkü adım sayısını al
  Future<int> fetchTodaySteps() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // iOS'ta her zaman gerçek veri almayı dene
      if (isIOS) {
        int? steps = await _health.getTotalStepsInInterval(midnight, now);
        debugPrint('📊 HealthKit ham değer: $steps');
        
        // null ise 0 kabul et (izin yok veya bugün adım yok)
        _todaySteps = steps ?? 0;
        _useSimulatedData = false;
        debugPrint('✅ iOS HealthKit adım: $_todaySteps');
        return _todaySteps;
      }

      // Android için simüle veri modundaysa
      if (_useSimulatedData) {
        _todaySteps = _generateSimulatedSteps();
        debugPrint('📊 Android simüle adım sayısı: $_todaySteps');
        return _todaySteps;
      }

      // Android gerçek veri almayı dene
      if (_isAuthorized) {
        int? steps = await _health.getTotalStepsInInterval(midnight, now);
        debugPrint('📊 Health Connect ham değer: $steps');
        
        if (steps != null) {
          _todaySteps = steps;
          debugPrint('✅ Gerçek adım sayısı: $_todaySteps');
          return _todaySteps;
        }
      }

      // Android'de gerçek veri alınamadıysa simüle et
      _todaySteps = _generateSimulatedSteps();
      debugPrint('⚠️ Fallback simüle adım sayısı: $_todaySteps');
      return _todaySteps;
    } catch (e) {
      debugPrint('Adım sayısı alma hatası: $e');
      // iOS'ta hata olsa bile 0 döndür, Android'de simüle et
      if (isIOS) {
        _todaySteps = 0;
        return 0;
      }
      _todaySteps = _generateSimulatedSteps();
      return _todaySteps;
    }
  }

  /// Belirli tarih aralığında adım sayısını al
  Future<int> fetchStepsInRange(DateTime start, DateTime end) async {
    try {
      if (!_useSimulatedData && _isAuthorized) {
        int? steps = await _health.getTotalStepsInInterval(start, end);
        if (steps != null && steps > 0) {
          return steps;
        }
      }

      // Simüle edilmiş veri
      final days = end.difference(start).inDays;
      return _generateSimulatedSteps() * (days > 0 ? days : 1);
    } catch (e) {
      debugPrint('Tarih aralığı adım hatası: $e');
      final days = end.difference(start).inDays;
      return _generateSimulatedSteps() * (days > 0 ? days : 1);
    }
  }

  /// Haftalık adım verilerini al
  Future<List<DailySteps>> fetchWeeklySteps() async {
    try {
      final List<DailySteps> weeklyData = [];
      final now = DateTime.now();

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        int steps = await fetchStepsInRange(dayStart, dayEnd);
        weeklyData.add(DailySteps(date: dayStart, steps: steps));
      }

      return weeklyData;
    } catch (e) {
      debugPrint('Haftalık veri alma hatası: $e');
      return [];
    }
  }

  /// Yürüme mesafesini al (metre cinsinden)
  Future<double> fetchTodayDistance() async {
    try {
      if (_useSimulatedData || !_isAuthorized) {
        return _todaySteps * 0.7;
      }

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      List<HealthDataPoint> data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_WALKING_RUNNING],
        startTime: midnight,
        endTime: now,
      );

      double totalDistance = 0;
      for (var point in data) {
        if (point.value is NumericHealthValue) {
          totalDistance += (point.value as NumericHealthValue).numericValue;
        }
      }

      if (totalDistance > 0) {
        return totalDistance;
      }

      // Simüle edilmiş veri (adım * 0.7 metre)
      return _todaySteps * 0.7;
    } catch (e) {
      debugPrint('Mesafe alma hatası: $e');
      return _todaySteps * 0.7;
    }
  }

  /// Yakılan kalori miktarını al
  Future<double> fetchTodayCalories() async {
    try {
      if (_useSimulatedData || !_isAuthorized) {
        return _todaySteps * 0.04;
      }

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      List<HealthDataPoint> data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: now,
      );

      double totalCalories = 0;
      for (var point in data) {
        if (point.value is NumericHealthValue) {
          totalCalories += (point.value as NumericHealthValue).numericValue;
        }
      }

      if (totalCalories > 0) {
        return totalCalories;
      }

      // Simüle edilmiş veri (adım * 0.04 kalori)
      return _todaySteps * 0.04;
    } catch (e) {
      debugPrint('Kalori alma hatası: $e');
      return _todaySteps * 0.04;
    }
  }

  /// Health API ayarlarını aç
  Future<void> openHealthSettings() async {
    try {
      if (isAndroid) {
        // Health Connect ayarlarını aç
        await _health.installHealthConnect();
      }
      // iOS için kullanıcı ayarlara manuel yönlendirilmeli
      await openAppSettings();
    } catch (e) {
      debugPrint('Ayarlar açılamadı: $e');
    }
  }

  /// Simüle edilmiş adım sayısı üret (Health Connect olmadığında fallback)
  int _generateSimulatedSteps() {
    final now = DateTime.now();
    final hour = now.hour;
    
    // Günün saatine göre mantıklı bir değer
    // Sabah az, öğlen orta, akşam çok
    if (hour < 8) {
      return 500 + (now.minute * 10);
    } else if (hour < 12) {
      return 2000 + (hour * 200);
    } else if (hour < 18) {
      return 5000 + (hour * 300);
    } else {
      return 7000 + (hour * 200);
    }
  }

  /// Health API'nin cihazda mevcut olup olmadığını kontrol et
  Future<bool> isHealthAvailable() async {
    if (kIsWeb) return false;
    
    try {
      if (isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        return status == HealthConnectSdkStatus.sdkAvailable;
      }
      // iOS her zaman HealthKit var
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Health Connect kurulu mu kontrol et (Android)
  Future<bool> isHealthConnectInstalled() async {
    if (!isAndroid) return true; // iOS her zaman HealthKit var
    
    try {
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      return false;
    }
  }

  /// Health Connect'i kur (Android)
  Future<void> installHealthConnect() async {
    if (isAndroid) {
      await _health.installHealthConnect();
    }
  }
}

/// Günlük adım verisi modeli
class DailySteps {
  final DateTime date;
  final int steps;

  DailySteps({required this.date, required this.steps});

  String get dayName {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[date.weekday - 1];
  }
}
