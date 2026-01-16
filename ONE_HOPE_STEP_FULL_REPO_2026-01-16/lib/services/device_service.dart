import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Device Service - Cihaz bazlı fraud önleme
/// 
/// Aynı cihazda birden fazla hesapla adım suistimalini önler.
/// Her cihaz günde sadece 1 hesaba adım kaydedebilir.
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  String? _cachedDeviceId;

  /// Cihazın unique ID'sini al
  /// iOS: identifierForVendor
  /// Android: androidId veya fingerprint
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      if (kIsWeb) {
        // Web için user agent hash kullan
        _cachedDeviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
        return _cachedDeviceId!;
      }

      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _cachedDeviceId = iosInfo.identifierForVendor ?? 'ios_unknown';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Android ID tercih edilir, yoksa fingerprint kullan
        _cachedDeviceId = androidInfo.id.isNotEmpty 
            ? androidInfo.id 
            : androidInfo.fingerprint;
      } else {
        _cachedDeviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }

      debugPrint('📱 Device ID: $_cachedDeviceId');
      return _cachedDeviceId!;
    } catch (e) {
      debugPrint('❌ Device ID alma hatası: $e');
      _cachedDeviceId = 'error_${DateTime.now().millisecondsSinceEpoch}';
      return _cachedDeviceId!;
    }
  }

  /// Bu cihaz bugün başka bir hesaba adım kaydetti mi kontrol et
  /// 
  /// Returns: 
  /// - null: Bu cihaz bugün hiçbir hesaba adım kaydetmedi, devam edilebilir
  /// - userId: Bu cihaz bugün bu userId'ye adım kaydetti
  Future<String?> checkDeviceStepOwner(String currentUserId) async {
    try {
      final deviceId = await getDeviceId();
      final today = _getTodayKey();
      
      final doc = await _firestore
          .collection('device_daily_steps')
          .doc('${deviceId}_$today')
          .get();

      if (!doc.exists) {
        // Bu cihaz bugün hiç adım kaydetmedi
        return null;
      }

      final data = doc.data()!;
      final ownerId = data['user_id'] as String?;

      if (ownerId == currentUserId) {
        // Aynı kullanıcı, devam edilebilir
        return null;
      }

      // Farklı kullanıcı bu cihazı zaten kullandı!
      debugPrint('⚠️ Device fraud tespit: $deviceId bugün $ownerId tarafından kullanıldı');
      return ownerId;
    } catch (e) {
      debugPrint('❌ Device kontrol hatası: $e');
      // Hata durumunda güvenli tarafta kal, devam etmeye izin ver
      return null;
    }
  }

  /// Bu cihazı bugün için kullanıcıya kaydet
  Future<bool> registerDeviceForUser(String userId) async {
    try {
      final deviceId = await getDeviceId();
      final today = _getTodayKey();
      
      await _firestore
          .collection('device_daily_steps')
          .doc('${deviceId}_$today')
          .set({
            'device_id': deviceId,
            'user_id': userId,
            'date': today,
            'registered_at': Timestamp.now(),
            'platform': _getPlatformName(),
          });

      debugPrint('✅ Device kaydedildi: $deviceId -> $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Device kayıt hatası: $e');
      return false;
    }
  }

  /// Kullanıcının cihaz ile adım senkronize edebilir mi?
  /// 
  /// Returns Map:
  /// - canSync: true/false
  /// - reason: Neden senkronize edilemiyor (eğer canSync = false ise)
  /// - ownerId: Mevcut sahip userId (eğer başkası kullanıyorsa)
  Future<Map<String, dynamic>> canSyncSteps(String userId, {String? userEmail}) async {
    try {
      // Test hesapları ve admin hesapları için device kontrolünü atla
      const testEmails = [
        'deneme@deneme.com',
        'sertacckhmr@gmail.com', // Admin hesabı
      ];
      if (userEmail != null && testEmails.contains(userEmail.toLowerCase())) {
        debugPrint('🧪 Test/Admin hesabı, device kontrolü atlandı: $userEmail');
        return {
          'canSync': true,
          'reason': null,
          'ownerId': null,
        };
      }
      
      final existingOwner = await checkDeviceStepOwner(userId);
      
      if (existingOwner == null) {
        // Cihaz müsait veya zaten bu kullanıcıya ait
        await registerDeviceForUser(userId);
        return {
          'canSync': true,
          'reason': null,
          'ownerId': null,
        };
      }

      // Başka biri kullanıyor
      return {
        'canSync': false,
        'reason': 'device_already_used',
        'ownerId': existingOwner,
      };
    } catch (e) {
      debugPrint('❌ canSyncSteps hatası: $e');
      // Hata durumunda izin ver
      return {
        'canSync': true,
        'reason': null,
        'ownerId': null,
      };
    }
  }

  /// Eski device kayıtlarını temizle (7 günden eski)
  Future<void> cleanupOldDeviceRecords() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final cutoffDate = _getDateKey(sevenDaysAgo);
      
      final snapshot = await _firestore
          .collection('device_daily_steps')
          .where('date', isLessThan: cutoffDate)
          .limit(100) // Batch işlem için limit
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('🧹 ${snapshot.docs.length} eski device kaydı temizlendi');
    } catch (e) {
      debugPrint('❌ Device cleanup hatası: $e');
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }
}
