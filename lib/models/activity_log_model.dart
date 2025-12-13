import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String logId;
  final String userId;
  final String actionType; // 'donation' | 'step_conversion' | 'team_join'
  final String targetName; // Vakıf adı veya takım adı
  final double amount; // Hope miktarı
  final int? stepsConverted; // Dönüştürülen adım sayısı (step_conversion için)
  final DateTime timestamp;
  final String? charityLogoUrl; // Vakıf logosu (cache)

  ActivityLogModel({
    required this.logId,
    required this.userId,
    required this.actionType,
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
      actionType: data['action_type'] ?? 'donation',
      targetName: data['target_name'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      stepsConverted: data['steps_converted'],
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      charityLogoUrl: data['charity_logo_url'],
    );
  }

  /// ActivityLogModel'den Firestore Map'e dönüştür
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'action_type': actionType,
      'target_name': targetName,
      'amount': amount,
      'steps_converted': stepsConverted,
      'timestamp': Timestamp.fromDate(timestamp),
      'charity_logo_url': charityLogoUrl,
    };
  }

  /// Kopya oluştur
  ActivityLogModel copyWith({
    String? logId,
    String? userId,
    String? actionType,
    String? targetName,
    double? amount,
    int? stepsConverted,
    DateTime? timestamp,
    String? charityLogoUrl,
  }) {
    return ActivityLogModel(
      logId: logId ?? this.logId,
      userId: userId ?? this.userId,
      actionType: actionType ?? this.actionType,
      targetName: targetName ?? this.targetName,
      amount: amount ?? this.amount,
      stepsConverted: stepsConverted ?? this.stepsConverted,
      timestamp: timestamp ?? this.timestamp,
      charityLogoUrl: charityLogoUrl ?? this.charityLogoUrl,
    );
  }
}
