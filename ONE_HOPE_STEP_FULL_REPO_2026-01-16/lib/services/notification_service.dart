import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

/// Arka plan mesaj handler (top-level fonksiyon olmalı)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Arka planda mesaj alındı: ${message.messageId}');
}

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  
  String? get fcmToken => _fcmToken;

  /// Push Notification'ları başlat
  Future<void> initializePushNotifications() async {
    try {
      // İzin iste
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Bildirim izni durumu: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _setupFcmToken();
        _setupForegroundHandler();
        _setupBackgroundHandler();
      }
    } catch (e) {
      debugPrint('Push notification başlatma hatası: $e');
    }
  }

  /// FCM Token al ve Firestore'a kaydet
  Future<void> _setupFcmToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');
      
      // Token'ı Firestore'a kaydet
      await _saveFcmTokenToFirestore(_fcmToken);

      // Token yenilendiğinde
      _messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        debugPrint('FCM Token yenilendi: $newToken');
        await _saveFcmTokenToFirestore(newToken);
      });
    } catch (e) {
      debugPrint('FCM Token alma hatası: $e');
    }
  }
  
  /// FCM Token'ı Firestore'a kaydet
  Future<void> _saveFcmTokenToFirestore(String? token) async {
    if (token == null) return;
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('FCM Token kaydedilemedi: Kullanıcı giriş yapmamış');
      return;
    }
    
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcm_token': token,
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM Token Firestore\'a kaydedildi');
    } catch (e) {
      debugPrint('FCM Token kaydetme hatası: $e');
    }
  }
  
  /// Kullanıcı giriş yaptıktan sonra FCM token'ı güncelle
  Future<void> updateFcmTokenAfterLogin() async {
    await _saveFcmTokenToFirestore(_fcmToken);
  }

  /// Ön planda bildirim handler
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Ön planda bildirim alındı: ${message.notification?.title}');
    });
  }

  /// Arka planda bildirim handler
  void _setupBackgroundHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Bildirime tıklandı: ${message.data}');
    });
  }

  /// Konuya abone ol
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Konu aboneliğinden çık
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  /// Beklemede olan bildirimleri al (Real-time)
  Stream<List<NotificationModel>> getPendingNotificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('notification_status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Tüm bildirimleri al (Real-time)
  Stream<List<NotificationModel>> getAllNotificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Belirli bir bildirimi al
  Future<NotificationModel?> getNotification(
    String userId,
    String notificationId,
  ) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .get();

      if (!doc.exists) return null;
      return NotificationModel.fromFirestore(doc);
    } catch (e) {
      print('Bildirim al hatası: $e');
      return null;
    }
  }

  /// Bildirimi sil
  Future<void> deleteNotification(
    String userId,
    String notificationId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Bildirim sil hatası: $e');
    }
  }

  /// Beklemede olan bildirimlerin sayısını al
  Future<int> getPendingNotificationCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('notification_status', isEqualTo: 'pending')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('Bildirim sayısı al hatası: $e');
      return 0;
    }
  }
}
