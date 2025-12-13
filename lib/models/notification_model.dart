import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String receiverUid;
  final String senderTeamId; // Daveti gönderen takımın ID'si
  final String notificationType; // 'team_invite' | 'donation' | 'achievement'
  final String notificationStatus; // 'pending' | 'accepted' | 'rejected'
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? senderName; // Daveti gönderenin adı (cache)
  final String? teamName; // Takım adı (cache)

  NotificationModel({
    required this.id,
    required this.receiverUid,
    required this.senderTeamId,
    required this.notificationType,
    required this.notificationStatus,
    required this.createdAt,
    this.respondedAt,
    this.senderName,
    this.teamName,
  });

  /// Firestore'dan NotificationModel'e dönüştür
  factory NotificationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return NotificationModel(
      id: doc.id,
      receiverUid: data['receiver_uid'] ?? '',
      senderTeamId: data['sender_team_id'] ?? '',
      notificationType: data['notification_type'] ?? 'team_invite',
      notificationStatus: data['notification_status'] ?? 'pending',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['responded_at'] as Timestamp?)?.toDate(),
      senderName: data['sender_name'],
      teamName: data['team_name'],
    );
  }

  /// NotificationModel'den Firestore Map'e dönüştür
  Map<String, dynamic> toFirestore() {
    return {
      'receiver_uid': receiverUid,
      'sender_team_id': senderTeamId,
      'notification_type': notificationType,
      'notification_status': notificationStatus,
      'created_at': Timestamp.fromDate(createdAt),
      'responded_at': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'sender_name': senderName,
      'team_name': teamName,
    };
  }

  /// Kopya oluştur
  NotificationModel copyWith({
    String? id,
    String? receiverUid,
    String? senderTeamId,
    String? notificationType,
    String? notificationStatus,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? senderName,
    String? teamName,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      receiverUid: receiverUid ?? this.receiverUid,
      senderTeamId: senderTeamId ?? this.senderTeamId,
      notificationType: notificationType ?? this.notificationType,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      senderName: senderName ?? this.senderName,
      teamName: teamName ?? this.teamName,
    );
  }
}
