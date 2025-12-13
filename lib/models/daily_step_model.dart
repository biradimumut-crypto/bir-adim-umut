import 'package:cloud_firestore/cloud_firestore.dart';

class DailyStepModel {
  final String stepId; // userId + '-' + date
  final String userId;
  final int totalSteps;
  final int convertedSteps; // Dönüştürülen adım sayısı
  final DateTime date;
  final bool isReset; // 00:00'de sıfırlandı mı?
  final DateTime lastConversionTime; // Son dönüştürme saati (cooldown için)

  DailyStepModel({
    required this.stepId,
    required this.userId,
    required this.totalSteps,
    required this.convertedSteps,
    required this.date,
    required this.isReset,
    required this.lastConversionTime,
  });

  /// Firestore'dan DailyStepModel'e dönüştür
  factory DailyStepModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DailyStepModel(
      stepId: doc.id,
      userId: data['user_id'] ?? '',
      totalSteps: data['total_steps'] ?? 0,
      convertedSteps: data['converted_steps'] ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isReset: data['is_reset'] ?? false,
      lastConversionTime: (data['last_conversion_time'] as Timestamp?)?.toDate() ??
          DateTime.now().subtract(Duration(minutes: 11)),
    );
  }

  /// DailyStepModel'den Firestore Map'e dönüştür
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'total_steps': totalSteps,
      'converted_steps': convertedSteps,
      'date': Timestamp.fromDate(date),
      'is_reset': isReset,
      'last_conversion_time': Timestamp.fromDate(lastConversionTime),
    };
  }

  /// Kopya oluştur
  DailyStepModel copyWith({
    String? stepId,
    String? userId,
    int? totalSteps,
    int? convertedSteps,
    DateTime? date,
    bool? isReset,
    DateTime? lastConversionTime,
  }) {
    return DailyStepModel(
      stepId: stepId ?? this.stepId,
      userId: userId ?? this.userId,
      totalSteps: totalSteps ?? this.totalSteps,
      convertedSteps: convertedSteps ?? this.convertedSteps,
      date: date ?? this.date,
      isReset: isReset ?? this.isReset,
      lastConversionTime: lastConversionTime ?? this.lastConversionTime,
    );
  }

  /// Cooldown kontrol et (10 dakika)
  bool canConvertSteps() {
    final now = DateTime.now();
    final difference = now.difference(lastConversionTime);
    return difference.inMinutes >= 10;
  }

  /// Dönüştürebilecek adım sayısını hesapla
  int getAvailableStepsForConversion() {
    final available = totalSteps - convertedSteps;
    return available > 2500 ? 2500 : available;
  }
}
