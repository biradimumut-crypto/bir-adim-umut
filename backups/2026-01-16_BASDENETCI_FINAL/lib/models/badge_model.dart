import 'package:cloud_firestore/cloud_firestore.dart';

/// Rozet Kategorileri
enum BadgeCategory {
  steps,     // Adım rozetleri
  donation,  // Bağış rozetleri
  activity,  // Giriş/Streak rozetleri
}

/// Rozet Tier'ları (seviye)
enum BadgeTier {
  bronze,    // 🥉
  silver,    // 🥈
  gold,      // 🥇
  platinum,  // 💎
  diamond,   // 💠
  legendary, // 🏆
  mythic,    // ⭐
}

/// Rozet Tanımı (hangi rozetler var)
class BadgeDefinition {
  final String id;
  final String nameKey;       // Çeviri anahtarı
  final String descriptionKey;
  final BadgeCategory category;
  final BadgeTier tier;
  final int requirement;      // Hedef (adım sayısı, bağış miktarı, streak günü)
  final String icon;          // Emoji (legacy)
  final String? imagePath;    // PNG asset path
  final int gradientStart;    // Gradient renk başlangıç (hex int)
  final int gradientEnd;      // Gradient renk bitiş

  const BadgeDefinition({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.category,
    required this.tier,
    required this.requirement,
    required this.icon,
    this.imagePath,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

/// Kullanıcının Kazandığı Rozet
class UserBadge {
  final String badgeId;
  final DateTime earnedAt;
  final bool isNew;  // Yeni rozet animasyonu için

  UserBadge({
    required this.badgeId,
    required this.earnedAt,
    this.isNew = false,
  });

  factory UserBadge.fromFirestore(Map<String, dynamic> data) {
    return UserBadge(
      badgeId: data['badge_id'] ?? '',
      earnedAt: (data['earned_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isNew: data['is_new'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'badge_id': badgeId,
      'earned_at': Timestamp.fromDate(earnedAt),
      'is_new': isNew,
    };
  }
}

/// Tüm Rozet Tanımları
class BadgeDefinitions {
  // ==================== ADIM ROZETLERİ ====================
  static const List<BadgeDefinition> stepBadges = [
    BadgeDefinition(
      id: 'steps_10k',
      nameKey: 'badge_steps_10k',
      descriptionKey: 'badge_steps_10k_desc',
      category: BadgeCategory.steps,
      tier: BadgeTier.bronze,
      requirement: 10000,
      icon: '👟',
      imagePath: 'assets/badges/steps_10k.png',
      gradientStart: 0xFFCD7F32, // Bronze
      gradientEnd: 0xFFB87333,
    ),
    BadgeDefinition(
      id: 'steps_100k',
      nameKey: 'badge_steps_100k',
      descriptionKey: 'badge_steps_100k_desc',
      category: BadgeCategory.steps,
      tier: BadgeTier.silver,
      requirement: 100000,
      icon: '🦶',
      imagePath: 'assets/badges/steps_100k.png',
      gradientStart: 0xFF64748B, // Slate Blue
      gradientEnd: 0xFF94A3B8,   // Light Slate
    ),
    BadgeDefinition(
      id: 'steps_1m',
      nameKey: 'badge_steps_1m',
      descriptionKey: 'badge_steps_1m_desc',
      category: BadgeCategory.steps,
      tier: BadgeTier.gold,
      requirement: 1000000,
      icon: '🏃',
      imagePath: 'assets/badges/steps_1m.png',
      gradientStart: 0xFFFFD700, // Gold
      gradientEnd: 0xFFFFA500,
    ),
    BadgeDefinition(
      id: 'steps_10m',
      nameKey: 'badge_steps_10m',
      descriptionKey: 'badge_steps_10m_desc',
      category: BadgeCategory.steps,
      tier: BadgeTier.platinum,
      requirement: 10000000,
      icon: '🏅',
      imagePath: 'assets/badges/steps_10m.png',
      gradientStart: 0xFF8B5CF6, // Purple (App theme)
      gradientEnd: 0xFFEC4899,
    ),
    BadgeDefinition(
      id: 'steps_100m',
      nameKey: 'badge_steps_100m',
      descriptionKey: 'badge_steps_100m_desc',
      category: BadgeCategory.steps,
      tier: BadgeTier.diamond,
      requirement: 100000000,
      icon: '💎',
      imagePath: 'assets/badges/steps_100m.png',
      gradientStart: 0xFF6EC6B5, // Cyan (App theme)
      gradientEnd: 0xFF3B82F6,
    ),
    BadgeDefinition(
      id: 'steps_1b',
      nameKey: 'badge_steps_1b',
      descriptionKey: 'badge_steps_1b_desc',
      category: BadgeCategory.steps,
      tier: BadgeTier.mythic,
      requirement: 1000000000,
      icon: '🌟',
      imagePath: 'assets/badges/steps_1b.png',
      gradientStart: 0xFFFF6B6B,
      gradientEnd: 0xFFFFE66D,
    ),
  ];

  // ==================== BAĞIŞ ROZETLERİ ====================
  static const List<BadgeDefinition> donationBadges = [
    BadgeDefinition(
      id: 'donation_10',
      nameKey: 'badge_donation_10',
      descriptionKey: 'badge_donation_10_desc',
      category: BadgeCategory.donation,
      tier: BadgeTier.bronze,
      requirement: 10,
      icon: '💜',
      imagePath: 'assets/badges/donation_10.png',
      gradientStart: 0xFFCD7F32,
      gradientEnd: 0xFFD4A84B,
    ),
    BadgeDefinition(
      id: 'donation_100',
      nameKey: 'badge_donation_100',
      descriptionKey: 'badge_donation_100_desc',
      category: BadgeCategory.donation,
      tier: BadgeTier.silver,
      requirement: 100,
      icon: '💝',
      imagePath: 'assets/badges/donation_100.png',
      gradientStart: 0xFF64748B, // Slate Blue
      gradientEnd: 0xFF94A3B8,   // Light Slate
    ),
    BadgeDefinition(
      id: 'donation_1k',
      nameKey: 'badge_donation_1k',
      descriptionKey: 'badge_donation_1k_desc',
      category: BadgeCategory.donation,
      tier: BadgeTier.gold,
      requirement: 1000,
      icon: '🏆',
      imagePath: 'assets/badges/donation_1000.png',
      gradientStart: 0xFFFFD700,
      gradientEnd: 0xFFFFA500,
    ),
    BadgeDefinition(
      id: 'donation_10k',
      nameKey: 'badge_donation_10k',
      descriptionKey: 'badge_donation_10k_desc',
      category: BadgeCategory.donation,
      tier: BadgeTier.platinum,
      requirement: 10000,
      icon: '💎',
      imagePath: 'assets/badges/donation_10000.png',
      gradientStart: 0xFF8B5CF6,
      gradientEnd: 0xFFEC4899,
    ),
    BadgeDefinition(
      id: 'donation_100k',
      nameKey: 'badge_donation_100k',
      descriptionKey: 'badge_donation_100k_desc',
      category: BadgeCategory.donation,
      tier: BadgeTier.diamond,
      requirement: 100000,
      icon: '👑',
      imagePath: 'assets/badges/donation_100000.png',
      gradientStart: 0xFF6EC6B5,
      gradientEnd: 0xFF3B82F6,
    ),
    BadgeDefinition(
      id: 'donation_1m',
      nameKey: 'badge_donation_1m',
      descriptionKey: 'badge_donation_1m_desc',
      category: BadgeCategory.donation,
      tier: BadgeTier.mythic,
      requirement: 1000000,
      icon: '🌟',
      imagePath: 'assets/badges/donation_1000000.png',
      gradientStart: 0xFFFF6B6B,
      gradientEnd: 0xFFFFE66D,
    ),
  ];

  // ==================== AKTİVİTE/GİRİŞ ROZETLERİ ====================
  static const List<BadgeDefinition> activityBadges = [
    BadgeDefinition(
      id: 'streak_first',
      nameKey: 'badge_streak_first',
      descriptionKey: 'badge_streak_first_desc',
      category: BadgeCategory.activity,
      tier: BadgeTier.bronze,
      requirement: 1,
      icon: '🎉',
      imagePath: 'assets/badges/streak_7.png',
      gradientStart: 0xFFCD7F32,
      gradientEnd: 0xFFB87333,
    ),
    BadgeDefinition(
      id: 'streak_7',
      nameKey: 'badge_streak_7',
      descriptionKey: 'badge_streak_7_desc',
      category: BadgeCategory.activity,
      tier: BadgeTier.silver,
      requirement: 7,
      icon: '⚡',
      imagePath: 'assets/badges/streak_1.png',
      gradientStart: 0xFF64748B, // Slate Blue
      gradientEnd: 0xFF94A3B8,   // Light Slate
    ),
    BadgeDefinition(
      id: 'streak_30',
      nameKey: 'badge_streak_30',
      descriptionKey: 'badge_streak_30_desc',
      category: BadgeCategory.activity,
      tier: BadgeTier.gold,
      requirement: 30,
      icon: '🌙',
      imagePath: 'assets/badges/streak_30.png',
      gradientStart: 0xFFFFD700,
      gradientEnd: 0xFFFFA500,
    ),
    BadgeDefinition(
      id: 'streak_90',
      nameKey: 'badge_streak_90',
      descriptionKey: 'badge_streak_90_desc',
      category: BadgeCategory.activity,
      tier: BadgeTier.platinum,
      requirement: 90,
      icon: '🌟',
      imagePath: 'assets/badges/streak_90.png',
      gradientStart: 0xFF8B5CF6,
      gradientEnd: 0xFFEC4899,
    ),
    BadgeDefinition(
      id: 'streak_180',
      nameKey: 'badge_streak_180',
      descriptionKey: 'badge_streak_180_desc',
      category: BadgeCategory.activity,
      tier: BadgeTier.diamond,
      requirement: 180,
      icon: '💫',
      imagePath: 'assets/badges/streak_180.png',
      gradientStart: 0xFF6EC6B5,
      gradientEnd: 0xFF3B82F6,
    ),
    BadgeDefinition(
      id: 'streak_365',
      nameKey: 'badge_streak_365',
      descriptionKey: 'badge_streak_365_desc',
      category: BadgeCategory.activity,
      tier: BadgeTier.mythic,
      requirement: 365,
      icon: '🏆',
      imagePath: 'assets/badges/streak_365.png',
      gradientStart: 0xFFFF6B6B,
      gradientEnd: 0xFFFFE66D,
    ),
  ];

  /// Tüm rozetleri al
  static List<BadgeDefinition> get allBadges => [
    ...stepBadges,
    ...donationBadges,
    ...activityBadges,
  ];

  /// Kategoriye göre rozetleri al
  static List<BadgeDefinition> getBadgesByCategory(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.steps:
        return stepBadges;
      case BadgeCategory.donation:
        return donationBadges;
      case BadgeCategory.activity:
        return activityBadges;
    }
  }

  /// ID ile rozet bul
  static BadgeDefinition? getBadgeById(String id) {
    try {
      return allBadges.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
