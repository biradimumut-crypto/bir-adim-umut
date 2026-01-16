/// Admin istatistik modeli
class AdminStatsModel {
  final int totalUsers;
  final int dailyActiveUsers;
  final int totalSteps;
  final int monthlySteps;
  final double totalHopeConverted;
  final double monthlyHopeConverted;
  final double totalDonations;
  final double monthlyDonations;
  final double bonusHope; // 2x bonus'tan gelen ekstra Hope
  final double hopeInWallets; // Cüzdanlardaki Hope
  final double referralHope; // Referral bonus'tan gelen Hope
  final int totalReferralCount; // Toplam davet sayısı
  final int totalReferralBonusSteps; // Verilen toplam bonus adım
  final int totalReferralBonusConverted; // Dönüştürülen bonus adım
  final int totalTeams;
  final int totalCharities;
  final int totalCommunities;
  final int totalIndividuals;
  final int iosDownloads;
  final int androidDownloads;
  final double adRevenue;
  // 📊 Reklam istatistikleri
  final int totalInterstitialAds; // Toplam interstitial reklam gösterimi
  final int totalRewardedAds; // Toplam rewarded reklam gösterimi
  final int totalRewardedCompleted; // Tamamlanan rewarded reklamlar
  final double totalRewardedHope; // Rewarded reklamlardan kazanılan Hope
  final int todayAdsWatched; // Bugün izlenen reklam sayısı
  final DateTime lastUpdated;

  AdminStatsModel({
    required this.totalUsers,
    required this.dailyActiveUsers,
    required this.totalSteps,
    required this.monthlySteps,
    required this.totalHopeConverted,
    required this.monthlyHopeConverted,
    required this.totalDonations,
    required this.monthlyDonations,
    this.bonusHope = 0,
    this.hopeInWallets = 0,
    this.referralHope = 0,
    this.totalReferralCount = 0,
    this.totalReferralBonusSteps = 0,
    this.totalReferralBonusConverted = 0,
    required this.totalTeams,
    required this.totalCharities,
    required this.totalCommunities,
    required this.totalIndividuals,
    required this.iosDownloads,
    required this.androidDownloads,
    required this.adRevenue,
    this.totalInterstitialAds = 0,
    this.totalRewardedAds = 0,
    this.totalRewardedCompleted = 0,
    this.totalRewardedHope = 0,
    this.todayAdsWatched = 0,
    required this.lastUpdated,
  });

  factory AdminStatsModel.empty() {
    return AdminStatsModel(
      totalUsers: 0,
      dailyActiveUsers: 0,
      totalSteps: 0,
      monthlySteps: 0,
      totalHopeConverted: 0,
      monthlyHopeConverted: 0,
      totalDonations: 0,
      monthlyDonations: 0,
      bonusHope: 0,
      hopeInWallets: 0,
      referralHope: 0,
      totalReferralCount: 0,
      totalReferralBonusSteps: 0,
      totalReferralBonusConverted: 0,
      totalTeams: 0,
      totalCharities: 0,
      totalCommunities: 0,
      totalIndividuals: 0,
      iosDownloads: 0,
      androidDownloads: 0,
      adRevenue: 0,
      totalInterstitialAds: 0,
      totalRewardedAds: 0,
      totalRewardedCompleted: 0,
      totalRewardedHope: 0,
      todayAdsWatched: 0,
      lastUpdated: DateTime.now(),
    );
  }

  factory AdminStatsModel.fromMap(Map<String, dynamic> map) {
    return AdminStatsModel(
      totalUsers: map['total_users'] ?? 0,
      dailyActiveUsers: map['daily_active_users'] ?? 0,
      totalSteps: map['total_steps'] ?? 0,
      monthlySteps: map['monthly_steps'] ?? 0,
      totalHopeConverted: (map['total_hope_converted'] ?? 0).toDouble(),
      monthlyHopeConverted: (map['monthly_hope_converted'] ?? 0).toDouble(),
      totalDonations: (map['total_donations'] ?? 0).toDouble(),
      monthlyDonations: (map['monthly_donations'] ?? 0).toDouble(),
      bonusHope: (map['bonus_hope'] ?? 0).toDouble(),
      hopeInWallets: (map['hope_in_wallets'] ?? 0).toDouble(),
      referralHope: (map['referral_hope'] ?? 0).toDouble(),
      totalReferralCount: map['total_referral_count'] ?? 0,
      totalReferralBonusSteps: map['total_referral_bonus_steps'] ?? 0,
      totalReferralBonusConverted: map['total_referral_bonus_converted'] ?? 0,
      totalTeams: map['total_teams'] ?? 0,
      totalCharities: map['total_charities'] ?? 0,
      totalCommunities: map['total_communities'] ?? 0,
      totalIndividuals: map['total_individuals'] ?? 0,
      iosDownloads: map['ios_downloads'] ?? 0,
      androidDownloads: map['android_downloads'] ?? 0,
      adRevenue: (map['ad_revenue'] ?? 0).toDouble(),
      totalInterstitialAds: map['total_interstitial_ads'] ?? 0,
      totalRewardedAds: map['total_rewarded_ads'] ?? 0,
      totalRewardedCompleted: map['total_rewarded_completed'] ?? 0,
      totalRewardedHope: (map['total_rewarded_hope'] ?? 0).toDouble(),
      todayAdsWatched: map['today_ads_watched'] ?? 0,
      lastUpdated: map['last_updated']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_users': totalUsers,
      'daily_active_users': dailyActiveUsers,
      'total_steps': totalSteps,
      'monthly_steps': monthlySteps,
      'total_hope_converted': totalHopeConverted,
      'monthly_hope_converted': monthlyHopeConverted,
      'total_donations': totalDonations,
      'monthly_donations': monthlyDonations,
      'bonus_hope': bonusHope,
      'hope_in_wallets': hopeInWallets,
      'referral_hope': referralHope,
      'total_referral_count': totalReferralCount,
      'total_referral_bonus_steps': totalReferralBonusSteps,
      'total_referral_bonus_converted': totalReferralBonusConverted,
      'total_teams': totalTeams,
      'total_charities': totalCharities,
      'total_communities': totalCommunities,
      'total_individuals': totalIndividuals,
      'ios_downloads': iosDownloads,
      'android_downloads': androidDownloads,
      'ad_revenue': adRevenue,
      'total_interstitial_ads': totalInterstitialAds,
      'total_rewarded_ads': totalRewardedAds,
      'total_rewarded_completed': totalRewardedCompleted,
      'total_rewarded_hope': totalRewardedHope,
      'today_ads_watched': todayAdsWatched,
      'last_updated': lastUpdated,
    };
  }
}

/// Günlük istatistik modeli (grafik için)
class DailyStatModel {
  final DateTime date;
  final int steps;
  final double hopeConverted;
  final double donations;
  final int activeUsers;

  DailyStatModel({
    required this.date,
    required this.steps,
    required this.hopeConverted,
    required this.donations,
    required this.activeUsers,
  });

  factory DailyStatModel.fromMap(Map<String, dynamic> map) {
    return DailyStatModel(
      date: map['date']?.toDate() ?? DateTime.now(),
      steps: map['steps'] ?? 0,
      hopeConverted: (map['hope_converted'] ?? 0).toDouble(),
      donations: (map['donations'] ?? 0).toDouble(),
      activeUsers: map['active_users'] ?? 0,
    );
  }
}
