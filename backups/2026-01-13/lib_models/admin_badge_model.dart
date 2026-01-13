import 'package:cloud_firestore/cloud_firestore.dart';

/// Rozet kazanma kriterleri türü
enum BadgeCriteriaType {
  steps,          // Adım sayısı
  donations,      // Bağış miktarı
  referrals,      // Davet sayısı
  streak,         // Ardışık gün
  teamJoin,       // Takıma katılma
  custom,         // Özel kriter
}

extension BadgeCriteriaTypeExtension on BadgeCriteriaType {
  String get displayName {
    switch (this) {
      case BadgeCriteriaType.steps:
        return 'Adım Sayısı';
      case BadgeCriteriaType.donations:
        return 'Bağış Miktarı';
      case BadgeCriteriaType.referrals:
        return 'Davet Sayısı';
      case BadgeCriteriaType.streak:
        return 'Ardışık Gün';
      case BadgeCriteriaType.teamJoin:
        return 'Takıma Katılma';
      case BadgeCriteriaType.custom:
        return 'Özel Kriter';
    }
  }

  String get value {
    switch (this) {
      case BadgeCriteriaType.steps:
        return 'steps';
      case BadgeCriteriaType.donations:
        return 'donations';
      case BadgeCriteriaType.referrals:
        return 'referrals';
      case BadgeCriteriaType.streak:
        return 'streak';
      case BadgeCriteriaType.teamJoin:
        return 'team_join';
      case BadgeCriteriaType.custom:
        return 'custom';
    }
  }

  static BadgeCriteriaType fromString(String value) {
    switch (value) {
      case 'steps':
        return BadgeCriteriaType.steps;
      case 'donations':
        return BadgeCriteriaType.donations;
      case 'referrals':
        return BadgeCriteriaType.referrals;
      case 'streak':
        return BadgeCriteriaType.streak;
      case 'team_join':
        return BadgeCriteriaType.teamJoin;
      case 'custom':
        return BadgeCriteriaType.custom;
      default:
        return BadgeCriteriaType.custom;
    }
  }
}

/// Rozet seviyesi
enum BadgeLevel {
  bronze,   // Bronz
  silver,   // Gümüş
  gold,     // Altın
  platinum, // Platin
  diamond,  // Elmas
}

extension BadgeLevelExtension on BadgeLevel {
  String get displayName {
    switch (this) {
      case BadgeLevel.bronze:
        return 'Bronz';
      case BadgeLevel.silver:
        return 'Gümüş';
      case BadgeLevel.gold:
        return 'Altın';
      case BadgeLevel.platinum:
        return 'Platin';
      case BadgeLevel.diamond:
        return 'Elmas';
    }
  }

  String get value {
    switch (this) {
      case BadgeLevel.bronze:
        return 'bronze';
      case BadgeLevel.silver:
        return 'silver';
      case BadgeLevel.gold:
        return 'gold';
      case BadgeLevel.platinum:
        return 'platinum';
      case BadgeLevel.diamond:
        return 'diamond';
    }
  }

  static BadgeLevel fromString(String value) {
    switch (value) {
      case 'bronze':
        return BadgeLevel.bronze;
      case 'silver':
        return BadgeLevel.silver;
      case 'gold':
        return BadgeLevel.gold;
      case 'platinum':
        return BadgeLevel.platinum;
      case 'diamond':
        return BadgeLevel.diamond;
      default:
        return BadgeLevel.bronze;
    }
  }
}

/// Admin tarafından yönetilen rozet tanımı
class AdminBadgeModel {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final BadgeCriteriaType criteriaType;
  final int criteriaValue;       // Hedef değer (ör: 10000 adım)
  final BadgeLevel level;
  final int rewardHope;          // Rozet kazanıldığında verilen Hope
  final bool isActive;
  final int earnedCount;         // Kaç kullanıcı kazandı
  final DateTime createdAt;
  final DateTime? updatedAt;

  AdminBadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.criteriaType,
    required this.criteriaValue,
    required this.level,
    this.rewardHope = 0,
    this.isActive = true,
    this.earnedCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory AdminBadgeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AdminBadgeModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      iconUrl: data['icon_url'] ?? '',
      criteriaType: BadgeCriteriaTypeExtension.fromString(data['criteria_type'] ?? 'custom'),
      criteriaValue: data['criteria_value'] ?? 0,
      level: BadgeLevelExtension.fromString(data['level'] ?? 'bronze'),
      rewardHope: data['reward_hope'] ?? 0,
      isActive: data['is_active'] ?? true,
      earnedCount: data['earned_count'] ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'criteria_type': criteriaType.value,
      'criteria_value': criteriaValue,
      'level': level.value,
      'reward_hope': rewardHope,
      'is_active': isActive,
      'earned_count': earnedCount,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  AdminBadgeModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    BadgeCriteriaType? criteriaType,
    int? criteriaValue,
    BadgeLevel? level,
    int? rewardHope,
    bool? isActive,
    int? earnedCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminBadgeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      criteriaType: criteriaType ?? this.criteriaType,
      criteriaValue: criteriaValue ?? this.criteriaValue,
      level: level ?? this.level,
      rewardHope: rewardHope ?? this.rewardHope,
      isActive: isActive ?? this.isActive,
      earnedCount: earnedCount ?? this.earnedCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
