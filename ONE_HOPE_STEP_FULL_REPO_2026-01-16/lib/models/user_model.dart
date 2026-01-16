import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String? maskedName; // İsim maskesi için
  final String? nickname;
  final String email;
  final String? profileImageUrl;
  final double walletBalanceHope;
  final String? currentTeamId; // Kullanıcının katıldığı takım
  final String themePreference; // dark/light
  final DateTime createdAt;
  final DateTime? lastStepSyncTime;
  final DateTime? lastLoginAt;
  final DateTime? updatedAt;
  
  // Kişisel Referral Sistemi
  final String? personalReferralCode; // Kullanıcının kendi referral kodu (6 karakter)
  final String? referredBy; // Davet eden kullanıcının UID'si
  final int referralCount; // Kaç kişi davet ettiği
  
  // Süresiz Bonus Adımlar
  final int referralBonusSteps; // Toplam kazanılan bonus adımlar
  final int referralBonusConverted; // Dönüştürülen bonus adımlar
  
  // Sıralama Ödül Bonus Adımları (süresiz)
  final int leaderboardBonusSteps; // Sıralama ödülü bonus adımlar
  final int leaderboardBonusConverted; // Dönüştürülen sıralama bonus adımlar
  
  // Lifetime İstatistikler
  final int? lifetimeSteps; // Toplam adım sayısı
  final double? lifetimeEarnedHope; // Toplam kazanılan Hope
  final double? lifetimeDonatedHope; // Toplam bağışlanan Hope
  final int? totalDonationCount; // Toplam bağış sayısı
  
  // Ban Sistemi
  final bool isBanned;
  final String? banReason;
  final DateTime? bannedAt;
  final String? bannedBy;
  
  // Auth Provider (google, apple, email)
  final String? authProvider;

  UserModel({
    required this.uid,
    required this.fullName,
    this.maskedName,
    this.nickname,
    required this.email,
    this.profileImageUrl,
    required this.walletBalanceHope,
    this.currentTeamId,
    required this.themePreference,
    required this.createdAt,
    this.lastStepSyncTime,
    this.lastLoginAt,
    this.updatedAt,
    this.personalReferralCode,
    this.referredBy,
    this.referralCount = 0,
    this.referralBonusSteps = 0,
    this.referralBonusConverted = 0,
    this.leaderboardBonusSteps = 0,
    this.leaderboardBonusConverted = 0,
    this.lifetimeSteps,
    this.lifetimeEarnedHope,
    this.lifetimeDonatedHope,
    this.totalDonationCount,
    this.isBanned = false,
    this.banReason,
    this.bannedAt,
    this.bannedBy,
    this.authProvider,
  });

  /// Firestore'dan UserModel'e dönüştür
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  /// Map'ten UserModel'e dönüştür (stream için)
  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      fullName: data['full_name'] ?? '',
      maskedName: data['masked_name'],
      nickname: data['nickname'],
      email: data['email'] ?? '',
      profileImageUrl: data['profile_image_url'],
      walletBalanceHope: (data['wallet_balance_hope'] ?? 0).toDouble(),
      currentTeamId: data['current_team_id'],
      themePreference: data['theme_preference'] ?? 'light',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastStepSyncTime: (data['last_step_sync_time'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['last_login_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      personalReferralCode: data['personal_referral_code'],
      referredBy: data['referred_by'],
      referralCount: data['referral_count'] ?? 0,
      referralBonusSteps: data['referral_bonus_steps'] ?? 0,
      referralBonusConverted: data['referral_bonus_converted'] ?? 0,
      leaderboardBonusSteps: data['leaderboard_bonus_steps'] ?? 0,
      leaderboardBonusConverted: data['leaderboard_bonus_converted'] ?? 0,
      lifetimeSteps: data['lifetime_steps'],
      lifetimeEarnedHope: (data['lifetime_earned_hope'] as num?)?.toDouble(),
      lifetimeDonatedHope: (data['lifetime_donated_hope'] as num?)?.toDouble(),
      totalDonationCount: data['total_donation_count'],
      isBanned: data['is_banned'] ?? false,
      banReason: data['ban_reason'],
      bannedAt: (data['banned_at'] as Timestamp?)?.toDate(),
      bannedBy: data['banned_by'],
      authProvider: data['auth_provider'],
    );
  }

  /// UserModel'den Firestore Map'e dönüştür
  Map<String, dynamic> toFirestore() {
    return {
      'full_name': fullName,
      'masked_name': maskedName,
      'nickname': nickname,
      'email': email,
      'profile_image_url': profileImageUrl,
      'wallet_balance_hope': walletBalanceHope,
      'current_team_id': currentTeamId,
      'theme_preference': themePreference,
      'created_at': Timestamp.fromDate(createdAt),
      'last_step_sync_time': lastStepSyncTime != null 
          ? Timestamp.fromDate(lastStepSyncTime!) 
          : null,
      'last_login_at': lastLoginAt != null 
          ? Timestamp.fromDate(lastLoginAt!) 
          : null,
      'updated_at': updatedAt != null 
          ? Timestamp.fromDate(updatedAt!) 
          : null,
      'personal_referral_code': personalReferralCode,
      'referred_by': referredBy,
      'referral_count': referralCount,
      'referral_bonus_steps': referralBonusSteps,
      'referral_bonus_converted': referralBonusConverted,
      'leaderboard_bonus_steps': leaderboardBonusSteps,
      'leaderboard_bonus_converted': leaderboardBonusConverted,
      'lifetime_steps': lifetimeSteps,
      'lifetime_earned_hope': lifetimeEarnedHope,
      'lifetime_donated_hope': lifetimeDonatedHope,
      'total_donation_count': totalDonationCount,
      'is_banned': isBanned,
      'ban_reason': banReason,
      'banned_at': bannedAt != null ? Timestamp.fromDate(bannedAt!) : null,
      'banned_by': bannedBy,
      'auth_provider': authProvider,
    };
  }

  /// Kopya oluştur (güncelleme için)
  UserModel copyWith({
    String? uid,
    String? fullName,
    String? maskedName,
    String? nickname,
    String? email,
    String? profileImageUrl,
    double? walletBalanceHope,
    String? currentTeamId,
    String? themePreference,
    DateTime? createdAt,
    DateTime? lastStepSyncTime,
    DateTime? lastLoginAt,
    DateTime? updatedAt,
    String? personalReferralCode,
    String? referredBy,
    int? referralCount,
    int? referralBonusSteps,
    int? referralBonusConverted,
    int? leaderboardBonusSteps,
    int? leaderboardBonusConverted,
    int? lifetimeSteps,
    double? lifetimeEarnedHope,
    double? lifetimeDonatedHope,
    int? totalDonationCount,
    bool? isBanned,
    String? banReason,
    DateTime? bannedAt,
    String? bannedBy,
    String? authProvider,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      maskedName: maskedName ?? this.maskedName,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      walletBalanceHope: walletBalanceHope ?? this.walletBalanceHope,
      currentTeamId: currentTeamId ?? this.currentTeamId,
      themePreference: themePreference ?? this.themePreference,
      createdAt: createdAt ?? this.createdAt,
      lastStepSyncTime: lastStepSyncTime ?? this.lastStepSyncTime,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      updatedAt: updatedAt ?? this.updatedAt,
      personalReferralCode: personalReferralCode ?? this.personalReferralCode,
      referredBy: referredBy ?? this.referredBy,
      referralCount: referralCount ?? this.referralCount,
      referralBonusSteps: referralBonusSteps ?? this.referralBonusSteps,
      referralBonusConverted: referralBonusConverted ?? this.referralBonusConverted,
      leaderboardBonusSteps: leaderboardBonusSteps ?? this.leaderboardBonusSteps,
      leaderboardBonusConverted: leaderboardBonusConverted ?? this.leaderboardBonusConverted,
      lifetimeSteps: lifetimeSteps ?? this.lifetimeSteps,
      lifetimeEarnedHope: lifetimeEarnedHope ?? this.lifetimeEarnedHope,
      lifetimeDonatedHope: lifetimeDonatedHope ?? this.lifetimeDonatedHope,
      totalDonationCount: totalDonationCount ?? this.totalDonationCount,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      bannedAt: bannedAt ?? this.bannedAt,
      bannedBy: bannedBy ?? this.bannedBy,
      authProvider: authProvider ?? this.authProvider,
    );
  }

  /// İsim maskeleme (sıralamada gizlilik için)
  /// Kural: Her isim parçası için ilk 2 harf + **
  /// Örnek: "Sefa Sercan Karslı" -> "Se** Se** Ka**"
  static String maskName(String fullName) {
    if (fullName.isEmpty) return fullName;
    final parts = fullName.trim().split(' ');
    
    final maskedParts = parts.map((part) {
      if (part.length <= 2) {
        return '$part**';
      }
      return '${part.substring(0, 2)}**';
    }).toList();
    
    return maskedParts.join(' ');
  }
}
