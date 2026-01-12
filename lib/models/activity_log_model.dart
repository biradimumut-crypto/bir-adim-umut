import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String logId;
  final String userId;
  final String activityType; // 'donation' | 'step_conversion' | 'team_joined' etc.
  final String targetName; // Vakıf adı veya takım adı
  final double amount; // Hope miktarı
  final int? stepsConverted; // Dönüştürülen adım sayısı (step_conversion için)
  final DateTime timestamp;
  final String? charityLogoUrl; // Vakıf logosu (cache)

  ActivityLogModel({
    required this.logId,
    required this.userId,
    required this.activityType,
    required this.targetName,
    required this.amount,
    this.stepsConverted,
    required this.timestamp,
    this.charityLogoUrl,
  });

  /// Firestore'dan ActivityLogModel'e dönüştür
  factory ActivityLogModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ActivityLogModel(
      logId: doc.id,
      userId: data['user_id'] ?? '',
      // activity_type öncelikli, geriye uyumluluk için action_type de desteklenir
      activityType: data['activity_type'] ?? data['action_type'] ?? 'donation',
      targetName: data['target_name'] ?? data['charity_name'] ?? '',
      amount: (data['amount'] ?? data['hope_amount'] ?? data['hope_earned'] ?? 0).toDouble(),
      stepsConverted: data['steps_converted'],
      // timestamp öncelikli, created_at da desteklenir
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? 
                 (data['created_at'] as Timestamp?)?.toDate() ?? 
                 DateTime.now(),
      charityLogoUrl: data['charity_logo_url'],
    );
  }

  /// ActivityLogModel'den Firestore Map'e dönüştür
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'activity_type': activityType,
      'target_name': targetName,
      'amount': amount,
      'steps_converted': stepsConverted,
      'timestamp': Timestamp.fromDate(timestamp),
      'created_at': Timestamp.fromDate(timestamp),
      'charity_logo_url': charityLogoUrl,
    };
  }

  /// Kopya oluştur
  ActivityLogModel copyWith({
    String? logId,
    String? userId,
    String? activityType,
    String? targetName,
    double? amount,
    int? stepsConverted,
    DateTime? timestamp,
    String? charityLogoUrl,
  }) {
    return ActivityLogModel(
      logId: logId ?? this.logId,
      userId: userId ?? this.userId,
      activityType: activityType ?? this.activityType,
      targetName: targetName ?? this.targetName,
      amount: amount ?? this.amount,
      stepsConverted: stepsConverted ?? this.stepsConverted,
      timestamp: timestamp ?? this.timestamp,
      charityLogoUrl: charityLogoUrl ?? this.charityLogoUrl,
    );
  }
}
