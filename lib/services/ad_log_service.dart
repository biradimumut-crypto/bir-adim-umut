import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Reklam İzleme Log Servisi
/// Tüm reklam gösterimlerini ve ödüllerini kaydeder
class AdLogService {
  static final AdLogService _instance = AdLogService._internal();
  factory AdLogService() => _instance;
  AdLogService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Reklam türleri
  static const String adTypeInterstitial = 'interstitial';
  static const String adTypeRewarded = 'rewarded';
  static const String adTypeBanner = 'banner';

  /// Platform bilgisini al
  String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  /// Interstitial (Geçiş) reklam izleme kaydı
  /// [context]: Reklamın gösterildiği bağlam (step_conversion, donation, vb.)
  Future<void> logInterstitialAd({
    required String context,
    bool wasShown = true,
    String? errorMessage,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final logData = {
        'user_id': userId,
        'ad_type': adTypeInterstitial,
        'context': context,
        'was_shown': wasShown,
        'platform': _platform,
        'timestamp': FieldValue.serverTimestamp(),
        'error_message': errorMessage,
      };

      // Global ad_logs koleksiyonuna kaydet
      await _firestore.collection('ad_logs').add(logData);

      // Kullanıcının ad_logs subcollection'ına da kaydet
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('ad_logs')
          .add(logData);

      debugPrint('📺 Interstitial ad log: $context (shown: $wasShown)');
    } catch (e) {
      debugPrint('❌ Ad log error: $e');
    }
  }

  /// Banner reklam izleme kaydı
  /// [context]: Reklamın gösterildiği sayfa/bağlam
  Future<void> logBannerAd({
    String context = 'general',
    bool wasShown = true,
    String? errorMessage,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final logData = {
        'user_id': userId,
        'ad_type': adTypeBanner,
        'context': context,
        'was_shown': wasShown,
        'platform': _platform,
        'timestamp': FieldValue.serverTimestamp(),
        'error_message': errorMessage,
      };

      // Global ad_logs koleksiyonuna kaydet
      await _firestore.collection('ad_logs').add(logData);

      // Kullanıcının ad_logs subcollection'ına da kaydet
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('ad_logs')
          .add(logData);

      debugPrint('🖼️ Banner ad log: $context (shown: $wasShown)');
    } catch (e) {
      debugPrint('❌ Banner ad log error: $e');
    }
  }

  /// Rewarded (Ödüllü) reklam izleme kaydı
  /// [rewardAmount]: Verilen ödül miktarı (Hope)
  /// [rewardType]: Ödül türü (bonus_hope, extra_steps, vb.)
  Future<void> logRewardedAd({
    required String context,
    required int rewardAmount,
    String rewardType = 'bonus_hope',
    bool wasCompleted = true,
    String? errorMessage,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final logData = {
        'user_id': userId,
        'ad_type': adTypeRewarded,
        'context': context,
        'was_completed': wasCompleted,
        'reward_amount': rewardAmount,
        'reward_type': rewardType,
        'platform': _platform,
        'timestamp': FieldValue.serverTimestamp(),
        'error_message': errorMessage,
      };

      // Global ad_logs koleksiyonuna kaydet
      await _firestore.collection('ad_logs').add(logData);

      // Kullanıcının ad_logs subcollection'ına da kaydet
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('ad_logs')
          .add(logData);

      // Eğer ödül verilmişse, activity_logs'a da kaydet
      if (wasCompleted && rewardAmount > 0) {
        await _firestore.collection('activity_logs').add({
          'user_id': userId,
          'activity_type': 'reward_ad_bonus',
          'amount': rewardAmount.toDouble(),
          'context': context,
          'platform': _platform,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('🎬 Rewarded ad log: $context (completed: $wasCompleted, reward: $rewardAmount)');
    } catch (e) {
      debugPrint('❌ Rewarded ad log error: $e');
    }
  }

  /// Reklam yüklenme hatası kaydı
  Future<void> logAdLoadError({
    required String adType,
    required String errorMessage,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      
      // Kullanıcı oturum açmadıysa log kaydetme
      if (userId == null) {
        debugPrint('⚠️ Ad load error (not logged - no user): $adType - $errorMessage');
        return;
      }

      await _firestore.collection('ad_errors').add({
        'user_id': userId,
        'ad_type': adType,
        'error_message': errorMessage,
        'platform': _platform,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('⚠️ Ad load error logged: $adType - $errorMessage');
    } catch (e) {
      debugPrint('❌ Ad error log failed: $e');
    }
  }

  /// Kullanıcının toplam reklam izleme istatistiklerini al
  Future<Map<String, dynamic>> getUserAdStats(String userId) async {
    try {
      final interstitialQuery = await _firestore
          .collection('ad_logs')
          .where('user_id', isEqualTo: userId)
          .where('ad_type', isEqualTo: adTypeInterstitial)
          .where('was_shown', isEqualTo: true)
          .count()
          .get();

      final rewardedQuery = await _firestore
          .collection('ad_logs')
          .where('user_id', isEqualTo: userId)
          .where('ad_type', isEqualTo: adTypeRewarded)
          .where('was_completed', isEqualTo: true)
          .count()
          .get();

      // Toplam ödül miktarını hesapla
      final rewardedDocs = await _firestore
          .collection('ad_logs')
          .where('user_id', isEqualTo: userId)
          .where('ad_type', isEqualTo: adTypeRewarded)
          .where('was_completed', isEqualTo: true)
          .get();

      int totalRewardAmount = 0;
      for (var doc in rewardedDocs.docs) {
        totalRewardAmount += (doc.data()['reward_amount'] ?? 0) as int;
      }

      return {
        'total_interstitial_watched': interstitialQuery.count ?? 0,
        'total_rewarded_watched': rewardedQuery.count ?? 0,
        'total_reward_earned': totalRewardAmount,
      };
    } catch (e) {
      debugPrint('❌ Get user ad stats error: $e');
      return {
        'total_interstitial_watched': 0,
        'total_rewarded_watched': 0,
        'total_reward_earned': 0,
      };
    }
  }
}
