import 'package:cloud_firestore/cloud_firestore.dart';

class TeamMemberModel {
  final String teamId;
  final String userId;
  final String memberStatus; // 'active' | 'pending' | 'left'
  final DateTime joinDate;
  final double memberTotalHope; // Üyenin bağışladığı toplam Hope (cache)
  final int memberDailySteps; // Günlük adım sayısı (cache)

  TeamMemberModel({
    required this.teamId,
    required this.userId,
    required this.memberStatus,
    required this.joinDate,
    required this.memberTotalHope,
    required this.memberDailySteps,
  });

  /// Firestore'dan TeamMemberModel'e dönüştür
  factory TeamMemberModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TeamMemberModel(
      teamId: data['team_id'] ?? '',
      userId: data['user_id'] ?? '',
      memberStatus: data['member_status'] ?? 'active',
      joinDate: (data['join_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberTotalHope: (data['member_total_hope'] ?? 0).toDouble(),
      memberDailySteps: data['member_daily_steps'] ?? 0,
    );
  }

  /// TeamMemberModel'den Firestore Map'e dönüştür
  Map<String, dynamic> toFirestore() {
    return {
      'team_id': teamId,
      'user_id': userId,
      'member_status': memberStatus,
      'join_date': Timestamp.fromDate(joinDate),
      'member_total_hope': memberTotalHope,
      'member_daily_steps': memberDailySteps,
    };
  }

  /// Kopya oluştur
  TeamMemberModel copyWith({
    String? teamId,
    String? userId,
    String? memberStatus,
    DateTime? joinDate,
    double? memberTotalHope,
    int? memberDailySteps,
  }) {
    return TeamMemberModel(
      teamId: teamId ?? this.teamId,
      userId: userId ?? this.userId,
      memberStatus: memberStatus ?? this.memberStatus,
      joinDate: joinDate ?? this.joinDate,
      memberTotalHope: memberTotalHope ?? this.memberTotalHope,
      memberDailySteps: memberDailySteps ?? this.memberDailySteps,
    );
  }
}
