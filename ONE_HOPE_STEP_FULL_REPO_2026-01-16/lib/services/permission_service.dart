import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Platform;

/// İzin yönetim servisi - Health, Bildirim ve diğer izinler
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  static const String _permissionsCompletedKey = 'permissions_setup_completed';
  static const String _healthPermissionKey = 'health_permission_granted';
  static const String _notificationPermissionKey = 'notification_permission_granted';

  /// İzin sayfasının gösterilip gösterilmeyeceğini kontrol et
  Future<bool> shouldShowPermissionsScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_permissionsCompletedKey) ?? false);
  }

  /// İzin kurulumunu tamamlandı olarak işaretle
  Future<void> markPermissionsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsCompletedKey, true);
  }

  /// Tüm izin durumlarını kontrol et
  Future<Map<String, bool>> checkAllPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'health': prefs.getBool(_healthPermissionKey) ?? false,
      'notification': prefs.getBool(_notificationPermissionKey) ?? false,
    };
  }

  /// Sağlık/Adım izni iste (Apple Health / Google Fit)
  Future<bool> requestHealthPermission() async {
    try {
      if (kIsWeb) {
        debugPrint('Health API web\'de desteklenmiyor');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();

      // iOS için Apple Health
      if (Platform.isIOS) {
        // TODO: health paketi aktif edildiğinde gerçek izin isteği yapılacak
        /*
        final health = Health();
        final types = [
          HealthDataType.STEPS,
          HealthDataType.DISTANCE_WALKING_RUNNING,
          HealthDataType.ACTIVE_ENERGY_BURNED,
        ];
        final permissions = types.map((e) => HealthDataAccess.READ).toList();
        
        bool authorized = await health.requestAuthorization(types, permissions: permissions);
        await prefs.setBool(_healthPermissionKey, authorized);
        return authorized;
        */
        
        // Şimdilik simüle et - paket aktif edilince gerçek izin isteyecek
        debugPrint('iOS: Health izni isteniyor (simüle)');
        await Future.delayed(const Duration(milliseconds: 500));
        await prefs.setBool(_healthPermissionKey, true);
        return true;
      }
      
      // Android için Google Fit
      if (Platform.isAndroid) {
        // TODO: health paketi aktif edildiğinde gerçek izin isteği yapılacak
        /*
        final health = Health();
        final types = [
          HealthDataType.STEPS,
          HealthDataType.DISTANCE_DELTA,
          HealthDataType.MOVE_MINUTES,
        ];
        final permissions = types.map((e) => HealthDataAccess.READ).toList();
        
        bool authorized = await health.requestAuthorization(types, permissions: permissions);
        await prefs.setBool(_healthPermissionKey, authorized);
        return authorized;
        */
        
        // Şimdilik simüle et
        debugPrint('Android: Google Fit izni isteniyor (simüle)');
        await Future.delayed(const Duration(milliseconds: 500));
        await prefs.setBool(_healthPermissionKey, true);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Health izni hatası: $e');
      return false;
    }
  }

  /// Bildirim izni iste
  Future<bool> requestNotificationPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      await prefs.setBool(_notificationPermissionKey, granted);
      
      debugPrint('Bildirim izni: ${granted ? "verildi" : "reddedildi"}');
      return granted;
    } catch (e) {
      debugPrint('Bildirim izni hatası: $e');
      return false;
    }
  }

  /// Health izni durumunu kontrol et
  Future<bool> isHealthPermissionGranted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_healthPermissionKey) ?? false;
  }

  /// Bildirim izni durumunu kontrol et
  Future<bool> isNotificationPermissionGranted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationPermissionKey) ?? false;
  }

  /// İzinleri sıfırla (test için)
  Future<void> resetPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_permissionsCompletedKey);
    await prefs.remove(_healthPermissionKey);
    await prefs.remove(_notificationPermissionKey);
  }
}
