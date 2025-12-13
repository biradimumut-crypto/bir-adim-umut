import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
