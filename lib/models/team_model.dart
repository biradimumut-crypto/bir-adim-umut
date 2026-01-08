import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String teamId;
  final String name;
  final String? logoUrl;
  final String referralCode; // Benzersiz ve zorunlu
  final String leaderUid;
  final int membersCount;
  final double totalTeamHope; // Sıralamada kullanılan toplam bağış
  final DateTime createdAt;
  final List<String> memberIds; // Üye listesi (opsiyonel - performans için)
  
  // Takım Bonus Adımları (sıralama ödülü + referral)
  final int teamBonusSteps; // Takım bonus havuzu
  final int teamBonusConverted; // Dönüştürülen takım bonus adımlar

  TeamModel({
    required this.teamId,
    required this.name,
    this.logoUrl,
    required this.referralCode,
    required this.leaderUid,
    required this.membersCount,
    required this.totalTeamHope,
    required this.createdAt,
    this.memberIds = const [],
    this.teamBonusSteps = 0,
    this.teamBonusConverted = 0,
  });

  /// Firestore'dan TeamModel'e dönüştür
  factory TeamModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TeamModel(
      teamId: doc.id,
      name: data['name'] ?? '',
      logoUrl: data['logo_url'],
      referralCode: data['referral_code'] ?? '',
      leaderUid: data['leader_uid'] ?? '',
      membersCount: data['members_count'] ?? 0,
      totalTeamHope: (data['total_team_hope'] ?? 0).toDouble(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberIds: List<String>.from(data['member_ids'] ?? []),
      teamBonusSteps: data['team_bonus_steps'] ?? 0,
      teamBonusConverted: data['team_bonus_converted'] ?? 0,
    );
  }

  /// TeamModel'den Firestore Map'e dönüştür
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'logo_url': logoUrl,
      'referral_code': referralCode,
      'leader_uid': leaderUid,
      'members_count': membersCount,
      'total_team_hope': totalTeamHope,
      'created_at': Timestamp.fromDate(createdAt),
      'member_ids': memberIds,
      'team_bonus_steps': teamBonusSteps,
      'team_bonus_converted': teamBonusConverted,
    };
  }

  /// Kopya oluştur (güncelleme için)
  TeamModel copyWith({
    String? teamId,
    String? name,
    String? logoUrl,
    String? referralCode,
    String? leaderUid,
    int? membersCount,
    double? totalTeamHope,
    DateTime? createdAt,
    List<String>? memberIds,
    int? teamBonusSteps,
    int? teamBonusConverted,
  }) {
    return TeamModel(
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      referralCode: referralCode ?? this.referralCode,
      leaderUid: leaderUid ?? this.leaderUid,
      membersCount: membersCount ?? this.membersCount,
      totalTeamHope: totalTeamHope ?? this.totalTeamHope,
      createdAt: createdAt ?? this.createdAt,
      memberIds: memberIds ?? this.memberIds,
      teamBonusSteps: teamBonusSteps ?? this.teamBonusSteps,
      teamBonusConverted: teamBonusConverted ?? this.teamBonusConverted,
    );
  }
}
