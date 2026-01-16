import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Session Tracking Servisi
/// Kullanıcı oturumları, platform bilgileri ve uygulama kullanımını takip eder
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  DateTime? _sessionStartTime;
  String? _currentSessionId;

  /// Platform bilgisini al
  String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  /// Uygulama versiyonunu al
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Device model bilgisini al
  Future<String> _getDeviceModel() async {
    try {
      if (kIsWeb) return 'web_browser';
      
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return '${iosInfo.model} (${iosInfo.systemVersion})';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model} (${androidInfo.version.release})';
      }
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Oturum başlat (Login sonrası çağrılmalı)
  Future<void> startSession() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      _sessionStartTime = DateTime.now();
      final appVersion = await _getAppVersion();
      final deviceModel = await _getDeviceModel();

      // Yeni session belgesi oluştur
      final sessionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc();
      
      _currentSessionId = sessionRef.id;

      await sessionRef.set({
        'session_id': _currentSessionId,
        'user_id': userId,
        'start_time': FieldValue.serverTimestamp(),
        'end_time': null,
        'duration_seconds': null,
        'platform': _platform,
        'app_version': appVersion,
        'device_model': deviceModel,
        'is_active': true,
      });

      // Kullanıcı belgesini güncelle
      await _firestore.collection('users').doc(userId).update({
        'last_login_at': FieldValue.serverTimestamp(),
        'last_platform': _platform,
        'last_app_version': appVersion,
        'last_device_model': deviceModel,
        'current_session_id': _currentSessionId,
      });

      debugPrint('📱 Session started: $_currentSessionId');
    } catch (e) {
      debugPrint('❌ Start session error: $e');
    }
  }

  /// Oturumu sonlandır (Logout veya app background'a geçtiğinde)
  Future<void> endSession() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null || _currentSessionId == null || _sessionStartTime == null) return;

      final endTime = DateTime.now();
      final duration = endTime.difference(_sessionStartTime!).inSeconds;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc(_currentSessionId)
          .update({
        'end_time': FieldValue.serverTimestamp(),
        'duration_seconds': duration,
        'is_active': false,
      });

      // Günlük session özetini güncelle
      final today = _getTodayKey();
      final dailySummaryRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_sessions')
          .doc(today);

      final dailySummary = await dailySummaryRef.get();
      if (dailySummary.exists) {
        await dailySummaryRef.update({
          'total_duration_seconds': FieldValue.increment(duration),
          'session_count': FieldValue.increment(1),
          'last_session_end': FieldValue.serverTimestamp(),
        });
      } else {
        await dailySummaryRef.set({
          'date': today,
          'user_id': userId,
          'total_duration_seconds': duration,
          'session_count': 1,
          'platform': _platform,
          'first_session_start': Timestamp.fromDate(_sessionStartTime!),
          'last_session_end': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('📱 Session ended: $_currentSessionId (duration: ${duration}s)');
      
      _currentSessionId = null;
      _sessionStartTime = null;
    } catch (e) {
      debugPrint('❌ End session error: $e');
    }
  }

  /// Heartbeat - Session'ın hala aktif olduğunu belirt (her 5 dakikada bir çağrılabilir)
  Future<void> heartbeat() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null || _currentSessionId == null) return;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc(_currentSessionId)
          .update({
        'last_heartbeat': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Heartbeat error: $e');
    }
  }

  /// Kullanıcının oturum istatistiklerini al
  Future<Map<String, dynamic>> getUserSessionStats(String userId) async {
    try {
      // Son 7 günün session verilerini al
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      final sessionsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();

      int totalSessions = sessionsQuery.docs.length;
      int totalDurationSeconds = 0;

      for (var doc in sessionsQuery.docs) {
        totalDurationSeconds += (doc.data()['duration_seconds'] ?? 0) as int;
      }

      // Platform dağılımı
      final platformCounts = <String, int>{};
      for (var doc in sessionsQuery.docs) {
        final platform = doc.data()['platform'] ?? 'unknown';
        platformCounts[platform] = (platformCounts[platform] ?? 0) + 1;
      }

      return {
        'total_sessions_7d': totalSessions,
        'total_duration_seconds_7d': totalDurationSeconds,
        'avg_session_duration_seconds': totalSessions > 0 ? totalDurationSeconds ~/ totalSessions : 0,
        'platform_distribution': platformCounts,
      };
    } catch (e) {
      debugPrint('❌ Get session stats error: $e');
      return {};
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
