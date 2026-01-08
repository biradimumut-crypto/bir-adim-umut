/// Yeni Admin Dashboard için detaylı istatistik modelleri

/// Filtre seçenekleri
enum DateFilterType {
  daily,
  monthly,
  custom,
}

/// 1. Günlük Adım Analizleri
class DailyStepAnalytics {
  final int totalDailySteps;          // Günlük toplam adım
  final int convertedSteps;           // Dönüştürülen adım
  final int normalConvertedSteps;     // Normal dönüştürülen (bonussuz)
  final int bonusConvertedSteps;      // 2x bonuslu dönüştürülen (progress bar'dan)
  final double normalHopeEarned;      // Normal Hope (100 adım = 1 Hope)
  final double bonusHopeEarned;       // Bonus Hope (2x: 2500 adım = 50 Hope, ZATEN KAYDEDILMIŞ)
  final double totalHopeEarned;       // Toplam Hope = normalHopeEarned + bonusHopeEarned
  final DateTime date;

  DailyStepAnalytics({
    required this.totalDailySteps,
    required this.convertedSteps,
    required this.normalConvertedSteps,
    required this.bonusConvertedSteps,
    required this.normalHopeEarned,
    required this.bonusHopeEarned,
    required this.totalHopeEarned,
    required this.date,
  });

  factory DailyStepAnalytics.empty() {
    return DailyStepAnalytics(
      totalDailySteps: 0,
      convertedSteps: 0,
      normalConvertedSteps: 0,
      bonusConvertedSteps: 0,
      normalHopeEarned: 0,
      bonusHopeEarned: 0,
      totalHopeEarned: 0,
      date: DateTime.now(),
    );
  }
}

/// 2. Taşınan (Carryover) Adım Analizleri
class CarryoverAnalytics {
  final int totalCarryoverSteps;      // Toplam taşınan adım (kümülatif)
  final int convertedCarryoverSteps;  // Dönüştürülen taşınan adım
  final int pendingCarryoverSteps;    // Bekleyen taşınan adım
  final double hopeFromCarryover;     // Taşınandan kazanılan Hope
  final int expiredSteps;             // Ay sonunda silinen adımlar (tarihsel toplam)
  final DateTime lastResetDate;       // Son sıfırlama tarihi
  final int usersWithCarryover;       // Taşınan adımı olan kullanıcı sayısı

  CarryoverAnalytics({
    required this.totalCarryoverSteps,
    required this.convertedCarryoverSteps,
    required this.pendingCarryoverSteps,
    required this.hopeFromCarryover,
    required this.expiredSteps,
    required this.lastResetDate,
    this.usersWithCarryover = 0,
  });

  factory CarryoverAnalytics.empty() {
    return CarryoverAnalytics(
      totalCarryoverSteps: 0,
      convertedCarryoverSteps: 0,
      pendingCarryoverSteps: 0,
      hopeFromCarryover: 0,
      expiredSteps: 0,
      lastResetDate: DateTime.now(),
      usersWithCarryover: 0,
    );
  }
}

/// 3. Referans ve Davet Analizleri
class ReferralAnalytics {
  final int totalReferralUsers;        // Referans ile gelen toplam kullanıcı
  final int totalBonusStepsGiven;      // Dağıtılan bonus adım toplamı
  final int convertedBonusSteps;       // Dönüştürülen bonus adım
  final int pendingBonusSteps;         // Bekleyen bonus adım
  final double hopeFromBonusSteps;     // Bonus adımlardan Hope
  final Map<String, int> topReferrers; // En çok davet eden kullanıcılar
  final double averageReferralsPerUser; // Kullanıcı başına ortalama davet

  ReferralAnalytics({
    required this.totalReferralUsers,
    required this.totalBonusStepsGiven,
    required this.convertedBonusSteps,
    required this.pendingBonusSteps,
    required this.hopeFromBonusSteps,
    required this.topReferrers,
    this.averageReferralsPerUser = 0,
  });

  factory ReferralAnalytics.empty() {
    return ReferralAnalytics(
      totalReferralUsers: 0,
      totalBonusStepsGiven: 0,
      convertedBonusSteps: 0,
      pendingBonusSteps: 0,
      hopeFromBonusSteps: 0,
      topReferrers: {},
      averageReferralsPerUser: 0,
    );
  }
}

/// 4. Bağış Analizleri
class DonationAnalytics {
  final int totalDonationCount;        // Toplam bağış adedi
  final double totalDonatedHope;       // Toplam bağışlanan Hope
  final double averageDonation;        // Ortalama bağış miktarı
  final Map<String, double> charityBreakdown; // Vakıf bazında dağılım
  final List<DonationRecord> recentDonations; // Son bağışlar

  DonationAnalytics({
    required this.totalDonationCount,
    required this.totalDonatedHope,
    required this.averageDonation,
    required this.charityBreakdown,
    required this.recentDonations,
  });

  factory DonationAnalytics.empty() {
    return DonationAnalytics(
      totalDonationCount: 0,
      totalDonatedHope: 0,
      averageDonation: 0,
      charityBreakdown: {},
      recentDonations: [],
    );
  }
}

/// Bağış kaydı
class DonationRecord {
  final String id;
  final String userId;
  final String username;
  final String charityName;
  final double hopeAmount;
  final DateTime date;

  DonationRecord({
    required this.id,
    required this.userId,
    required this.username,
    required this.charityName,
    required this.hopeAmount,
    required this.date,
  });
}

/// Detay listesi için kullanıcı adım kaydı
class UserStepRecord {
  final String userId;
  final String username;
  final int steps;
  final int convertedSteps;
  final double hopeEarned;
  final bool hasBonusMultiplier;
  final DateTime date;

  UserStepRecord({
    required this.userId,
    required this.username,
    required this.steps,
    required this.convertedSteps,
    required this.hopeEarned,
    required this.hasBonusMultiplier,
    required this.date,
  });
}

/// Detay listesi için referral kaydı
class ReferralRecord {
  final String referrerId;
  final String referrerUsername;
  final String referredId;
  final String referredUsername;
  final int bonusStepsGiven;
  final int bonusStepsUsed;
  final DateTime referralDate;

  ReferralRecord({
    required this.referrerId,
    required this.referrerUsername,
    required this.referredId,
    required this.referredUsername,
    required this.bonusStepsGiven,
    required this.bonusStepsUsed,
    required this.referralDate,
  });
}
