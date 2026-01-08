import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/admin_stats_model.dart';
import '../models/admin_dashboard_stats.dart';
import '../models/charity_model.dart';
import '../models/admin_badge_model.dart';
import '../models/user_model.dart';
import '../models/team_model.dart';

/// Admin paneli için tüm servis işlemleri
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== ADMIN YETKİ KONTROLÜ ====================

  /// Mevcut kullanıcının admin olup olmadığını kontrol et
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final adminDoc = await _firestore.collection('admins').doc(user.uid).get();
    return adminDoc.exists && (adminDoc.data()?['is_active'] ?? false);
  }

  /// Admin listesine kullanıcı ekle
  Future<void> addAdmin(String uid, String role) async {
    await _firestore.collection('admins').doc(uid).set({
      'uid': uid,
      'role': role, // 'super_admin', 'admin', 'moderator'
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // ==================== İSTATİSTİKLER ====================

  /// Genel istatistikleri getir
  Future<AdminStatsModel> getAdminStats() async {
    // Toplam kullanıcı sayısı
    final usersSnapshot = await _firestore.collection('users').count().get();
    final totalUsers = usersSnapshot.count ?? 0;

    // ============================================================
    // GÜNLÜK AKTİF KULLANICILAR - TUTARLI HESAPLAMA
    // ============================================================
    // Bugün aktif = Bugün için daily_steps subcollection'ında kaydı olan kullanıcılar
    // Bu, Adım İstatistikleri sayfasındaki "Bugün Aktif" ile aynı hesaplama
    
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final Set<String> activeUserIds = {};
    
    // Tüm kullanıcıların daily_steps subcollection'larını kontrol et
    final allUsersForActive = await _firestore.collection('users').get();
    
    for (var userDoc in allUsersForActive.docs) {
      try {
        final todayStepDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('daily_steps')
            .doc(todayKey)
            .get();
        
        if (todayStepDoc.exists) {
          activeUserIds.add(userDoc.id);
        }
      } catch (e) {
        // Devam et
      }
    }
    
    int dailyActiveUsers = activeUserIds.length;
    print('📊 Bugün aktif kullanıcı (daily_steps kaydı olan): $dailyActiveUsers');

    // Toplam takım sayısı - getAllTeams ile tutarlı olması için aynı yöntemi kullan
    final teamsSnapshot = await _firestore.collection('teams').get();
    final totalTeams = teamsSnapshot.docs.length;

    // Vakıf sayısı
    final charitiesSnapshot = await _firestore
        .collection('charities')
        .where('type', isEqualTo: 'charity')
        .count()
        .get();
    final totalCharities = charitiesSnapshot.count ?? 0;

    // Topluluk sayısı
    final communitiesSnapshot = await _firestore
        .collection('charities')
        .where('type', isEqualTo: 'community')
        .count()
        .get();
    final totalCommunities = communitiesSnapshot.count ?? 0;

    // Birey sayısı
    final individualsSnapshot = await _firestore
        .collection('charities')
        .where('type', isEqualTo: 'individual')
        .count()
        .get();
    final totalIndividuals = individualsSnapshot.count ?? 0;

    // Aylık istatistikleri hesapla
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthlyStats = await _getMonthlyStats(monthStart);

    // Toplam bağışları activity_logs'tan hesapla (eski ve yeni formatları destekle)
    double totalDonationsAmount = 0;
    
    // Önce activity_type ile dene
    final donationsSnapshot1 = await _firestore
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation')
        .get();
    
    for (var doc in donationsSnapshot1.docs) {
      final data = doc.data();
      // Hem amount hem hope_amount alanlarını kontrol et
      final amount = data['amount'] ?? data['hope_amount'];
      if (amount != null) {
        totalDonationsAmount += (amount is int) ? amount.toDouble() : (amount as num).toDouble();
      }
    }
    
    // Sonra action_type ile de kontrol et (eski kayıtlar için)
    final donationsSnapshot2 = await _firestore
        .collection('activity_logs')
        .where('action_type', isEqualTo: 'donation')
        .get();
    
    // Duplicate'leri önlemek için ID'leri takip et
    final processedIds = donationsSnapshot1.docs.map((d) => d.id).toSet();
    
    for (var doc in donationsSnapshot2.docs) {
      if (processedIds.contains(doc.id)) continue; // Zaten işlendi
      final data = doc.data();
      final amount = data['amount'] ?? data['hope_amount'];
      if (amount != null) {
        totalDonationsAmount += (amount is int) ? amount.toDouble() : (amount as num).toDouble();
      }
    }

    // Toplam adımları users/{userId}/daily_steps subcollection'larından hesapla
    int totalStepsAll = 0;
    final allUsersForSteps = await _firestore.collection('users').get();
    
    for (var userDoc in allUsersForSteps.docs) {
      try {
        final dailyStepsSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('daily_steps')
            .get();
        
        for (var stepDoc in dailyStepsSnapshot.docs) {
          final data = stepDoc.data();
          final steps = data['daily_steps'] ?? data['total_steps'];
          if (steps != null) {
            totalStepsAll += (steps is int) ? steps : (steps as num).toInt();
          }
        }
      } catch (e) {
        // Subcollection yok veya erişim hatası, devam et
      }
    }
    
    // Eğer subcollection'lardan veri alınamazsa, global daily_steps'tan dene
    if (totalStepsAll == 0) {
      final allStepsSnapshot = await _firestore.collection('daily_steps').get();
      for (var doc in allStepsSnapshot.docs) {
        final data = doc.data();
        final steps = data['total_steps'];
        if (steps != null) {
          totalStepsAll += (steps is int) ? steps : (steps as num).toInt();
        }
      }
    }

    // ============================================================
    // TOPLAM HOPE HESAPLAMA - TEK DOĞRU KAYNAK
    // ============================================================
    // DOĞRU FORMÜL: Toplam Hope = Cüzdanlardaki + Bağışlanan
    // Çünkü sistem kapalı - Hope sadece bu iki yerde olabilir!
    
    double totalHopeInWallets = 0; // Cüzdanlardaki Hope
    double totalHopeDonated = totalDonationsAmount; // Bağışlanan Hope
    
    // Referral bonus adımlarını da hesapla
    int totalReferralBonusSteps = 0; // Verilen toplam bonus adım
    int totalReferralBonusConverted = 0; // Dönüştürülen bonus adım
    
    final allUsersSnapshot = await _firestore.collection('users').get();
    
    // Cüzdan bakiyelerini ve referral bonus adımlarını topla
    for (var doc in allUsersSnapshot.docs) {
      final data = doc.data();
      
      // Cüzdan bakiyesi
      final walletHope = data['wallet_balance_hope'];
      if (walletHope != null) {
        totalHopeInWallets += (walletHope is int) ? walletHope.toDouble() : (walletHope as num).toDouble();
      }
      
      // Referral bonus adımları (100.000 adım per referral)
      final bonusSteps = data['referral_bonus_steps'];
      if (bonusSteps != null) {
        totalReferralBonusSteps += (bonusSteps is int) ? bonusSteps : (bonusSteps as num).toInt();
      }
      
      // Dönüştürülen referral bonus adımları
      final bonusConverted = data['referral_bonus_converted'];
      if (bonusConverted != null) {
        totalReferralBonusConverted += (bonusConverted is int) ? bonusConverted : (bonusConverted as num).toInt();
      }
    }
    
    // TOPLAM HOPE = Cüzdanlardaki + Bağışlanan
    double totalHopeProduced = totalHopeInWallets + totalHopeDonated;
    
    // Referral bonus Hope = DÖNÜŞTÜRÜLEN referral adımı / 100
    // (Verilen bonus değil, kullanılan bonus!)
    double referralBonusHope = totalReferralBonusConverted / 100.0;
    
    print('📊 Hope Hesaplama:');
    print('   Cüzdanlardaki: $totalHopeInWallets H');
    print('   Bağışlanan: $totalHopeDonated H');
    print('   TOPLAM: $totalHopeProduced H');
    print('   Referral Bonus Adım (verilen): $totalReferralBonusSteps');
    print('   Referral Bonus Dönüştürülen: $totalReferralBonusConverted');
    print('   Referral Bonus Hope: $referralBonusHope H');
    
    // Normal adımlardan dönüştürülen (referral hariç)
    int allTimeConvertedSteps = 0;
    
    for (var userDoc in allUsersSnapshot.docs) {
      try {
        final dailyStepsSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('daily_steps')
            .get();
        
        for (var stepDoc in dailyStepsSnapshot.docs) {
          final data = stepDoc.data();
          final converted = data['converted_steps'];
          if (converted != null) {
            allTimeConvertedSteps += (converted is int) ? converted : (converted as num).toInt();
          }
        }
      } catch (e) {
        // Devam et
      }
    }
    
    // Global daily_steps'tan da kontrol et (eğer subcollection boşsa)
    if (allTimeConvertedSteps == 0) {
      final globalStepsSnapshot = await _firestore.collection('daily_steps').get();
      for (var doc in globalStepsSnapshot.docs) {
        final data = doc.data();
        final converted = data['converted_steps'];
        if (converted != null) {
          allTimeConvertedSteps += (converted is int) ? converted : (converted as num).toInt();
        }
      }
    }
    
    // ============================================================
    // BONUS HOPE HESAPLAMA - DOĞRU YÖNTEM
    // ============================================================
    // converted_steps içinde referral bonus adımları DAHİL DEĞİL!
    // Referral bonus ayrı bir havuzda tutulur (referral_bonus_steps)
    // 
    // Dolayısıyla:
    // - Normal adımlardan Hope = allTimeConvertedSteps / 100
    // - Referral'dan Hope = totalReferralBonusConverted / 100
    // - 2x Bonus Hope = Toplam Hope - Normal Hope - Referral Hope
    //
    // UYARI: Referral bonus kullanıldığında da 2x bonus aktif olabilir!
    // Bu durumda referral'dan gelen Hope da 2 kat olur.
    
    // Referral Hope (dönüştürülen referral adım / 100)
    // totalReferralBonusConverted yukarıda zaten hesaplandı
    double referralHopeFromBonus = totalReferralBonusConverted / 100.0;
    
    // Normal adımlardan gelen Hope (referral hariç)
    double normalHopeFromSteps = allTimeConvertedSteps / 100.0;
    
    // Toplam normal hesaplamayla olması gereken Hope
    double expectedNormalHope = normalHopeFromSteps + referralHopeFromBonus;
    
    // 2x Bonus Hope = Gerçek Toplam - Beklenen Normal Toplam
    // Bu fark, 2x bonus aktifken kazanılan ekstra Hope'u gösterir
    double bonusHopeAmount = totalHopeProduced - expectedNormalHope;
    if (bonusHopeAmount < 0) bonusHopeAmount = 0;
    
    print('   Dönüştürülen adım (daily_steps): $allTimeConvertedSteps');
    print('   Referral bonus dönüştürülen: $totalReferralBonusConverted');
    print('   Normal Hope (daily_steps/100): $normalHopeFromSteps H');
    print('   Referral Hope (bonus_converted/100): $referralHopeFromBonus H');
    print('   Beklenen normal toplam: $expectedNormalHope H');
    print('   Gerçek toplam: $totalHopeProduced H');
    print('   2x Bonus Hope (fark): $bonusHopeAmount H');
    
    // Toplam davet sayısını hesapla
    int totalReferralCount = 0;
    for (var doc in allUsersSnapshot.docs) {
      final data = doc.data();
      final referralCount = data['referral_count'];
      if (referralCount != null) {
        totalReferralCount += (referralCount is int) ? referralCount : (referralCount as num).toInt();
      }
    }

    // Admin stats dökümanından indirme ve reklam bilgilerini al
    final statsDoc = await _firestore.collection('admin_stats').doc('current').get();
    final statsData = statsDoc.data() ?? {};
    
    // ✅ Reklam istatistiklerini çek
    final adStats = await getAdStats();

    return AdminStatsModel(
      totalUsers: totalUsers,
      dailyActiveUsers: dailyActiveUsers,
      totalSteps: totalStepsAll,
      monthlySteps: monthlyStats['steps'] ?? 0,
      totalHopeConverted: totalHopeProduced,
      monthlyHopeConverted: totalHopeProduced, // Bu ay = Toplam (çünkü uygulama bu ay başladı!)
      totalDonations: totalDonationsAmount,
      monthlyDonations: (monthlyStats['donations'] ?? 0).toDouble(),
      bonusHope: bonusHopeAmount,
      hopeInWallets: totalHopeInWallets,
      referralHope: referralHopeFromBonus,
      totalReferralCount: totalReferralCount,
      totalReferralBonusSteps: totalReferralBonusSteps,
      totalReferralBonusConverted: totalReferralBonusConverted,
      totalTeams: totalTeams,
      totalCharities: totalCharities,
      totalCommunities: totalCommunities,
      totalIndividuals: totalIndividuals,
      iosDownloads: statsData['ios_downloads'] ?? 0,
      androidDownloads: statsData['android_downloads'] ?? 0,
      adRevenue: (statsData['ad_revenue'] ?? 0).toDouble(),
      totalInterstitialAds: adStats['totalInterstitialAds'] ?? 0,
      totalRewardedAds: adStats['totalRewardedAds'] ?? 0,
      totalRewardedCompleted: adStats['totalRewardedCompleted'] ?? 0,
      totalRewardedHope: (adStats['totalRewardedHope'] ?? 0).toDouble(),
      todayAdsWatched: adStats['todayAdsWatched'] ?? 0,
      lastUpdated: DateTime.now(),
    );
  }

  // ==================== REKLAM İSTATİSTİKLERİ ====================

  /// 📊 Reklam istatistiklerini hesapla
  /// ad_logs koleksiyonundan tüm reklam verilerini toplar
  Future<Map<String, dynamic>> getAdStats() async {
    try {
      int totalInterstitialAds = 0;
      int totalRewardedAds = 0;
      int totalRewardedCompleted = 0;
      double totalRewardedHope = 0;
      int todayAdsWatched = 0;
      
      // Bugünün tarihi
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      
      // Global ad_logs koleksiyonundan verileri çek
      final adLogsSnapshot = await _firestore.collection('ad_logs').get();
      
      for (var doc in adLogsSnapshot.docs) {
        final data = doc.data();
        final adType = data['ad_type'] ?? '';
        final wasCompleted = data['was_completed'] ?? false;
        final rewardAmount = (data['reward_amount'] ?? 0).toDouble();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        // Reklam türüne göre say
        if (adType == 'interstitial') {
          totalInterstitialAds++;
        } else if (adType == 'rewarded') {
          totalRewardedAds++;
          if (wasCompleted == true) {
            totalRewardedCompleted++;
            totalRewardedHope += rewardAmount;
          }
        }
        
        // Bugün izlenen reklamlar
        if (timestamp != null && timestamp.isAfter(todayStart)) {
          todayAdsWatched++;
        }
      }
      
      print('📊 Reklam stats:');
      print('   Toplam interstitial: $totalInterstitialAds');
      print('   Toplam rewarded: $totalRewardedAds');
      print('   Tamamlanan rewarded: $totalRewardedCompleted');
      print('   Rewarded Hope: $totalRewardedHope');
      print('   Bugün izlenen: $todayAdsWatched');
      
      return {
        'totalInterstitialAds': totalInterstitialAds,
        'totalRewardedAds': totalRewardedAds,
        'totalRewardedCompleted': totalRewardedCompleted,
        'totalRewardedHope': totalRewardedHope,
        'todayAdsWatched': todayAdsWatched,
      };
    } catch (e) {
      print('❌ Reklam stats hatası: $e');
      return {
        'totalInterstitialAds': 0,
        'totalRewardedAds': 0,
        'totalRewardedCompleted': 0,
        'totalRewardedHope': 0.0,
        'todayAdsWatched': 0,
      };
    }
  }

  /// Aylık istatistikleri hesapla
  Future<Map<String, dynamic>> _getMonthlyStats(DateTime monthStart) async {
    int totalSteps = 0;
    double totalHopeFromSteps = 0; // Adımlardan üretilen Hope
    double totalDonations = 0;
    
    // Bu ay adımları ve hope dönüşümlerini hesapla
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
    final usersSnapshot = await _firestore.collection('users').get();
    
    print('📊 Aylık stats - users toplam: ${usersSnapshot.docs.length}');
    
    // Her kullanıcının bu ayki adım ve hope verilerini topla
    for (var userDoc in usersSnapshot.docs) {
      try {
        final dailyStepsSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('daily_steps')
            .get();
        
        for (var stepDoc in dailyStepsSnapshot.docs) {
          final data = stepDoc.data();
          final docId = stepDoc.id; // Format: YYYY-MM-DD
          
          // Tarih kontrolü için doc ID'yi parse et
          DateTime? docDate;
          try {
            final parts = docId.split('-');
            if (parts.length == 3) {
              docDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            }
          } catch (e) {
            // Parse hatası, data içindeki date alanına bak
            final dateField = data['date'];
            if (dateField is Timestamp) {
              docDate = dateField.toDate();
            }
          }
          
          // Bu ayın içinde mi kontrol et
          if (docDate != null && 
              docDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
              docDate.isBefore(monthEnd.add(const Duration(days: 1)))) {
            // Adımları topla
            final steps = data['daily_steps'] ?? data['total_steps'];
            if (steps != null) {
              totalSteps += (steps is int) ? steps : (steps as num).toInt();
            }
            
            // Dönüştürülmüş adımları (Hope) topla - 100 adım = 1 Hope
            final converted = data['converted_steps'];
            if (converted != null) {
              final convertedValue = (converted is int) ? converted : (converted as num).toInt();
              totalHopeFromSteps += convertedValue / 100.0;
            }
          }
        }
      } catch (e) {
        // Subcollection yok veya erişim hatası, devam et
      }
    }
    
    // Eğer subcollection'lardan veri alınamazsa, global daily_steps'tan dene
    if (totalSteps == 0 || totalHopeFromSteps == 0) {
      final dailyStepsSnapshot = await _firestore.collection('daily_steps').get();
      
      int globalSteps = 0;
      double globalHope = 0;
      
      for (var doc in dailyStepsSnapshot.docs) {
        final data = doc.data();
        final docDate = (data['date'] as Timestamp?)?.toDate();
        
        if (docDate != null && 
            docDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            docDate.isBefore(monthEnd.add(const Duration(days: 1)))) {
          // Adımları topla
          final steps = data['total_steps'];
          if (steps != null) {
            globalSteps += (steps is int) ? steps : (steps as num).toInt();
          }
          
          // Dönüştürülmüş adımları topla
          final converted = data['converted_steps'];
          if (converted != null) {
            final convertedValue = (converted is int) ? converted : (converted as num).toInt();
            globalHope += convertedValue / 100.0;
          }
        }
      }
      
      // Eğer subcollection boşsa global değerleri kullan
      if (totalSteps == 0) totalSteps = globalSteps;
      if (totalHopeFromSteps == 0) totalHopeFromSteps = globalHope;
    }
    
    // Bu ay verilen BONUS Hope'u activity_logs'tan hesapla
    double bonusHopeThisMonth = 0;
    try {
      final bonusSnapshot = await _firestore
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'bonus')
          .get();
      
      for (var doc in bonusSnapshot.docs) {
        final data = doc.data();
        final bonusDate = (data['created_at'] as Timestamp?)?.toDate() ?? 
                          (data['timestamp'] as Timestamp?)?.toDate();
        
        if (bonusDate != null && 
            bonusDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            bonusDate.isBefore(monthEnd.add(const Duration(days: 1)))) {
          final amount = data['hope_amount'] ?? data['amount'];
          if (amount != null) {
            bonusHopeThisMonth += (amount is int) ? amount.toDouble() : (amount as num).toDouble();
          }
        }
      }
    } catch (e) {
      print('Bonus hesaplama hatası: $e');
    }
    
    // Bu ay toplam Hope = Adımlardan + Bonus
    double totalHopeThisMonth = totalHopeFromSteps + bonusHopeThisMonth;
    
    print('📊 Bu ay adım: $totalSteps');
    print('   Adımlardan Hope: $totalHopeFromSteps H');
    print('   Bonus Hope: $bonusHopeThisMonth H');
    print('   TOPLAM Bu Ay Hope: $totalHopeThisMonth H');

    // Aylık bağışları activity_logs'tan topla (eski ve yeni formatları destekle)
    // activity_type ile
    final donationsSnapshot1 = await _firestore
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation')
        .get();
    
    // action_type ile (eski kayıtlar)
    final donationsSnapshot2 = await _firestore
        .collection('activity_logs')
        .where('action_type', isEqualTo: 'donation')
        .get();
    
    // Birleştir
    final allDonationDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (var doc in donationsSnapshot1.docs) {
      allDonationDocs[doc.id] = doc;
    }
    for (var doc in donationsSnapshot2.docs) {
      allDonationDocs[doc.id] = doc;
    }
    
    for (var doc in allDonationDocs.values) {
      final data = doc.data();
      // Hem created_at hem timestamp kontrol et
      final donatedAt = (data['created_at'] as Timestamp?)?.toDate() ?? 
                        (data['timestamp'] as Timestamp?)?.toDate();
      if (donatedAt != null && donatedAt.isAfter(monthStart.subtract(const Duration(days: 1)))) {
        // Hem amount hem hope_amount kontrol et
        final amount = data['amount'] ?? data['hope_amount'] ?? 0;
        totalDonations += (amount is int) ? amount.toDouble() : (amount as num).toDouble();
      }
    }
    
    print('📊 Aylık bağış toplamı: $totalDonations');

    return {
      'steps': totalSteps,
      'hope_converted': totalHopeThisMonth, // Bonus dahil toplam Hope
      'donations': totalDonations,
    };
  }

  /// Son 30 günlük grafik verisi
  Future<List<DailyStatModel>> getDailyStats({int days = 30}) async {
    final List<DailyStatModel> stats = [];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('daily_stats')
          .doc(dateKey)
          .get();

      if (snapshot.exists) {
        stats.add(DailyStatModel.fromMap(snapshot.data()!));
      } else {
        stats.add(DailyStatModel(
          date: date,
          steps: 0,
          hopeConverted: 0,
          donations: 0,
          activeUsers: 0,
        ));
      }
    }

    return stats;
  }

  // ==================== KULLANICI YÖNETİMİ ====================

  /// Tüm kullanıcıları getir (sayfalama ile)
  Future<List<UserModel>> getAllUsers({
    int limit = 50,
    DocumentSnapshot? lastDoc,
    String? searchQuery,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('users');

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // İsim veya email ile ara
      query = query
          .where('full_name', isGreaterThanOrEqualTo: searchQuery)
          .where('full_name', isLessThanOrEqualTo: '$searchQuery\uf8ff');
    }

    query = query.orderBy('created_at', descending: true).limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();
  }

  /// Kullanıcı ara (isim veya email)
  Future<List<UserModel>> searchUsers(String query) async {
    final results = <UserModel>[];

    // İsme göre ara
    final nameSnapshot = await _firestore
        .collection('users')
        .where('full_name', isGreaterThanOrEqualTo: query)
        .where('full_name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    results.addAll(nameSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)));

    // Email'e göre ara
    final emailSnapshot = await _firestore
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    for (var doc in emailSnapshot.docs) {
      final user = UserModel.fromFirestore(doc);
      if (!results.any((u) => u.uid == user.uid)) {
        results.add(user);
      }
    }

    return results;
  }

  /// Kullanıcı detaylarını getir
  Future<UserModel?> getUserDetails(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Kullanıcıyı banla
  Future<void> banUser(String uid, String reason) async {
    await _firestore.collection('users').doc(uid).update({
      'is_banned': true,
      'ban_reason': reason,
      'banned_at': FieldValue.serverTimestamp(),
      'banned_by': _auth.currentUser?.uid,
    });

    // Ban logunu kaydet
    await _firestore.collection('admin_logs').add({
      'action': 'ban_user',
      'target_uid': uid,
      'reason': reason,
      'admin_uid': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Kullanıcının banını kaldır
  Future<void> unbanUser(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'is_banned': false,
      'ban_reason': null,
      'banned_at': null,
      'banned_by': null,
    });

    await _firestore.collection('admin_logs').add({
      'action': 'unban_user',
      'target_uid': uid,
      'admin_uid': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Kullanıcının Hope bakiyesini güncelle
  Future<void> updateUserBalance(String uid, double newBalance, String reason) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final oldBalance = (userDoc.data()?['wallet_balance_hope'] ?? 0).toDouble();

    await _firestore.collection('users').doc(uid).update({
      'wallet_balance_hope': newBalance,
    });

    await _firestore.collection('admin_logs').add({
      'action': 'update_balance',
      'target_uid': uid,
      'old_balance': oldBalance,
      'new_balance': newBalance,
      'reason': reason,
      'admin_uid': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ==================== TAKIM YÖNETİMİ ====================

  /// Tüm takımları getir
  Future<List<TeamModel>> getAllTeams({
    int limit = 50,
    DocumentSnapshot? lastDoc,
  }) async {
    // Basit sorgu - önce tüm takımları al, sonra client-side sırala
    // Bu sayede created_at alanı olmayan takımlar da dahil edilir
    final snapshot = await _firestore.collection('teams').get();
    
    List<TeamModel> teams = snapshot.docs
        .map((doc) => TeamModel.fromFirestore(doc))
        .toList();
    
    // Tarihe göre sırala (yeniden eskiye), null tarihler en sona
    teams.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    
    // Limit uygula
    if (teams.length > limit) {
      teams = teams.take(limit).toList();
    }
    
    return teams;
  }

  /// Takımı sil
  Future<void> deleteTeam(String teamId) async {
    // Takım üyelerinin current_team_id'sini temizle
    final membersSnapshot = await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('team_members')
        .get();

    final batch = _firestore.batch();

    for (var memberDoc in membersSnapshot.docs) {
      batch.update(
        _firestore.collection('users').doc(memberDoc.id),
        {'current_team_id': null},
      );
      batch.delete(memberDoc.reference);
    }

    // Takımı sil
    batch.delete(_firestore.collection('teams').doc(teamId));

    await batch.commit();

    await _firestore.collection('admin_logs').add({
      'action': 'delete_team',
      'target_team_id': teamId,
      'admin_uid': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ==================== VAKIF/TOPLULUK/BİREY YÖNETİMİ ====================

  /// Tüm bağış alıcılarını getir (tür filtresi ile) - istatistikler activity_logs'dan hesaplanır
  Future<List<CharityModel>> getAllCharities({
    RecipientType? type,
    bool? isActive,
    int limit = 100,
  }) async {
    try {
      // Basit sorgu - sadece koleksiyonu çek, filtrelemeyi client-side yap
      // Bu sayede composite index gereksinimi ortadan kalkar
      final snapshot = await _firestore.collection('charities').get();
      
      List<CharityModel> charities = snapshot.docs
          .map((doc) => CharityModel.fromFirestore(doc))
          .toList();
      
      // Activity_logs'dan gerçek istatistikleri hesapla
      final donationStats = await _getCharityDonationStats();
      
      // İstatistikleri charity'lere ekle
      charities = charities.map((charity) {
        final stats = donationStats[charity.id];
        if (stats != null) {
          return charity.copyWith(
            collectedAmount: stats['totalAmount'] ?? charity.collectedAmount,
            donorCount: stats['donorCount'] ?? charity.donorCount,
          );
        }
        return charity;
      }).toList();
      
      // Client-side filtreleme
      if (type != null) {
        charities = charities.where((c) => c.type == type).toList();
      }
      
      if (isActive != null) {
        charities = charities.where((c) => c.isActive == isActive).toList();
      }
      
      // Tarihe göre sırala (yeniden eskiye)
      charities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Limit uygula
      if (charities.length > limit) {
        charities = charities.take(limit).toList();
      }
      
      return charities;
    } catch (e) {
      print('❌ getAllCharities hatası: $e');
      rethrow;
    }
  }
  
  /// Activity_logs'dan her charity için bağış istatistiklerini hesapla
  Future<Map<String, Map<String, dynamic>>> _getCharityDonationStats() async {
    try {
      // activity_type ile bağış kayıtları
      final snapshot1 = await _firestore
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'donation')
          .get();
      
      // action_type ile bağış kayıtları (eski format)
      final snapshot2 = await _firestore
          .collection('activity_logs')
          .where('action_type', isEqualTo: 'donation')
          .get();
      
      // Birleştir
      final allDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (var doc in snapshot1.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in snapshot2.docs) {
        allDocs[doc.id] = doc;
      }
      
      // Charity bazında grupla
      final Map<String, Map<String, dynamic>> stats = {};
      final Map<String, Set<String>> uniqueDonors = {};
      
      for (var doc in allDocs.values) {
        final data = doc.data();
        
        // recipient_id veya charity_id alanını al
        final charityId = data['recipient_id'] ?? data['charity_id'];
        if (charityId == null || charityId.toString().isEmpty) continue;
        
        // Amount'u al (amount veya hope_amount)
        final amount = (data['amount'] ?? data['hope_amount'] ?? 0).toDouble();
        
        // Donor uid'yi al
        final donorUid = data['user_id'] ?? data['donor_uid'] ?? '';
        
        // İstatistikleri güncelle
        if (!stats.containsKey(charityId)) {
          stats[charityId] = {'totalAmount': 0.0, 'donorCount': 0};
          uniqueDonors[charityId] = {};
        }
        
        stats[charityId]!['totalAmount'] = (stats[charityId]!['totalAmount'] as double) + amount;
        
        if (donorUid.toString().isNotEmpty) {
          uniqueDonors[charityId]!.add(donorUid.toString());
        }
      }
      
      // Unique donor sayısını güncelle
      for (var charityId in stats.keys) {
        stats[charityId]!['donorCount'] = uniqueDonors[charityId]?.length ?? 0;
      }
      
      print('📊 Charity istatistikleri hesaplandı: ${stats.length} charity');
      return stats;
    } catch (e) {
      print('❌ _getCharityDonationStats hatası: $e');
      return {};
    }
  }

  /// Yeni vakıf/topluluk/birey ekle
  Future<String> createCharity(CharityModel charity) async {
    try {
      final docRef = await _firestore.collection('charities').add(
        charity.copyWith(
          createdAt: DateTime.now(),
          createdBy: _auth.currentUser?.uid,
        ).toFirestore(),
      );

      await _firestore.collection('admin_logs').add({
        'action': 'create_charity',
        'charity_id': docRef.id,
        'charity_type': charity.type.value,
        'admin_uid': _auth.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Charity oluşturuldu: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ createCharity hatası: $e');
      rethrow;
    }
  }

  /// Vakıf/topluluk/birey güncelle
  Future<void> updateCharity(CharityModel charity) async {
    await _firestore.collection('charities').doc(charity.id).update(
      charity.copyWith(updatedAt: DateTime.now()).toFirestore(),
    );

    await _firestore.collection('admin_logs').add({
      'action': 'update_charity',
      'charity_id': charity.id,
      'admin_uid': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Vakıf/topluluk/birey sil
  Future<void> deleteCharity(String charityId) async {
    await _firestore.collection('charities').doc(charityId).delete();

    await _firestore.collection('admin_logs').add({
      'action': 'delete_charity',
      'charity_id': charityId,
      'admin_uid': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Aktif/Pasif durumunu değiştir
  Future<void> toggleCharityStatus(String charityId, bool isActive) async {
    await _firestore.collection('charities').doc(charityId).update({
      'is_active': isActive,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Hedef miktarı güncelle
  Future<void> updateCharityTarget(String charityId, double targetAmount) async {
    await _firestore.collection('charities').doc(charityId).update({
      'target_amount': targetAmount,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ==================== BAĞIŞ RAPORLARI ====================

  /// Aylık bağış raporunu getir (activity_logs koleksiyonundan)
  Future<List<DonationRecordModel>> getMonthlyDonations({
    DateTime? startDate,
    DateTime? endDate,
    RecipientType? recipientType,
  }) async {
    final start = startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final end = endDate ?? DateTime.now();

    // activity_logs koleksiyonundan tüm donation kayıtlarını çek (eski ve yeni formatları destekle)
    // Önce activity_type ile
    final snapshot1 = await _firestore
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation')
        .get();
    
    // Sonra action_type ile (eski kayıtlar)
    final snapshot2 = await _firestore
        .collection('activity_logs')
        .where('action_type', isEqualTo: 'donation')
        .get();
    
    // Birleştir ve duplicate'leri kaldır
    final allDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (var doc in snapshot1.docs) {
      allDocs[doc.id] = doc;
    }
    for (var doc in snapshot2.docs) {
      allDocs[doc.id] = doc; // Zaten varsa üzerine yazar (aynı doc)
    }
    
    print('📊 Toplam bağış kaydı: ${allDocs.length} (activity_type: ${snapshot1.docs.length}, action_type: ${snapshot2.docs.length})');
    
    // Tarih alanını parse eden yardımcı fonksiyon
    DateTime? parseTimestamp(Map<String, dynamic> data) {
      final possibleFields = ['donated_at', 'created_at', 'timestamp', 'date'];
      for (var field in possibleFields) {
        final value = data[field];
        if (value is Timestamp) {
          return value.toDate();
        }
      }
      return null;
    }
    
    // Client-side tarih filtrelemesi yap
    final filteredDocs = allDocs.values.where((doc) {
      final data = doc.data();
      final createdAt = parseTimestamp(data);
      if (createdAt == null) return false;
      return createdAt.isAfter(start.subtract(const Duration(days: 1))) && 
             createdAt.isBefore(end.add(const Duration(days: 1)));
    }).toList();
    
    print('📊 Tarih filtrelemesi sonrası: ${filteredDocs.length} adet');
    
    // Tarihe göre sırala (en yeni önce)
    filteredDocs.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aDate = parseTimestamp(aData) ?? DateTime(1970);
      final bDate = parseTimestamp(bData) ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    
    return filteredDocs
        .map((doc) => DonationRecordModel.fromFirestore(doc))
        .toList();
  }

  /// Vakıf/topluluk/birey bazında bağış özeti
  Future<Map<String, double>> getDonationsByRecipient(DateTime startDate, DateTime endDate) async {
    final donations = await getMonthlyDonations(startDate: startDate, endDate: endDate);

    final Map<String, double> summary = {};
    for (var donation in donations) {
      summary[donation.recipientName] =
          (summary[donation.recipientName] ?? 0) + donation.amount;
    }

    return summary;
  }

  /// Bağış aktarım durumunu güncelle
  Future<void> markDonationAsTransferred(String donationId, bool isTransferred) async {
    // Önce bağış bilgisini al
    final donationDoc = await _firestore.collection('activity_logs').doc(donationId).get();
    final donationData = donationDoc.data();
    
    await _firestore.collection('activity_logs').doc(donationId).update({
      'is_transferred': isTransferred,
      'transferred_at': isTransferred ? FieldValue.serverTimestamp() : null,
      'transferred_by': isTransferred ? _auth.currentUser?.uid : null,
    });
    
    // Admin log kaydı - detaylı bilgilerle
    await _firestore.collection('admin_logs').add({
      'action': isTransferred ? 'mark_donation_transferred' : 'unmark_donation_transferred',
      'donation_id': donationId,
      'amount': donationData?['amount'] ?? donationData?['hope_amount'] ?? 0,
      'recipient_id': donationData?['recipient_id'] ?? donationData?['charity_id'] ?? '-',
      'recipient_name': donationData?['recipient_name'] ?? donationData?['charity_name'] ?? '-',
      'donor_uid': donationData?['uid'] ?? '-',
      'donor_name': donationData?['donor_name'] ?? '-',
      'admin_uid': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Belirli bir alıcıya yapılan bağışları getir
  Future<List<DonationRecordModel>> getDonationsByRecipientId(String recipientId) async {
    // activity_type ile sorgular
    final snapshot1 = await _firestore
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation')
        .where('charity_id', isEqualTo: recipientId)
        .get();
    
    final snapshot2 = await _firestore
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation')
        .where('recipient_id', isEqualTo: recipientId)
        .get();
    
    // action_type ile sorgular (eski kayıtlar)
    final snapshot3 = await _firestore
        .collection('activity_logs')
        .where('action_type', isEqualTo: 'donation')
        .where('charity_id', isEqualTo: recipientId)
        .get();
    
    final snapshot4 = await _firestore
        .collection('activity_logs')
        .where('action_type', isEqualTo: 'donation')
        .where('recipient_id', isEqualTo: recipientId)
        .get();
    
    // Tüm sonuçları birleştir (duplicate'leri kaldır)
    final allDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (var doc in [...snapshot1.docs, ...snapshot2.docs, ...snapshot3.docs, ...snapshot4.docs]) {
      allDocs[doc.id] = doc;
    }
    
    print('📊 getDonationsByRecipientId ($recipientId): ${allDocs.length} bağış bulundu');
    
    final donations = allDocs.values
        .map((doc) => DonationRecordModel.fromFirestore(doc))
        .toList();
    
    // Tarihe göre sırala (en yeni önce)
    donations.sort((a, b) => b.donatedAt.compareTo(a.donatedAt));
    
    return donations;
  }

  // ==================== BİLDİRİM YÖNETİMİ ====================

  /// Toplu bildirim gönder (Cloud Function ile push notification gönderir)
  Future<Map<String, dynamic>> sendBroadcastNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
    String targetAudience = 'all', // 'all', 'premium', 'team_leaders'
    DateTime? scheduledTime, // Zamanlanmış bildirim için
    String? repeatType, // 'daily', 'weekly', 'monthly', null = tekil
    List<int>? repeatDays, // Haftalık için gün listesi (1=Pzt, 7=Paz)
    int? repeatMonthDay, // Aylık için gün (1-28)
  }) async {
    try {
      // Zamanlanmış bildirim ise farklı işle
      if (scheduledTime != null) {
        // Zamanlanmış bildirimi Firestore'a kaydet
        await _firestore.collection('scheduled_notifications').add({
          'title': title,
          'body': body,
          'image_url': imageUrl,
          'data': data,
          'target_audience': targetAudience,
          'scheduled_time': Timestamp.fromDate(scheduledTime),
          'created_at': FieldValue.serverTimestamp(),
          'created_by': _auth.currentUser?.uid,
          'status': 'pending', // pending, sent, cancelled
          'repeat_type': repeatType ?? 'none',
          'repeat_days': repeatDays,
          'repeat_month_day': repeatMonthDay,
        });

        // Admin log kaydı
        await _firestore.collection('admin_logs').add({
          'action': 'schedule_broadcast',
          'title': title,
          'target_audience': targetAudience,
          'scheduled_time': Timestamp.fromDate(scheduledTime),
          'repeat_type': repeatType,
          'admin_uid': _auth.currentUser?.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });

        String repeatInfo = '';
        if (repeatType == 'daily') {
          repeatInfo = ' (Her gün yinelenecek)';
        } else if (repeatType == 'weekly' && repeatDays != null) {
          repeatInfo = ' (Haftalık yinelenecek)';
        } else if (repeatType == 'monthly') {
          repeatInfo = ' (Her ayın ${repeatMonthDay ?? 1}. günü yinelenecek)';
        }

        return {
          'success': true,
          'scheduled': true,
          'scheduledTime': scheduledTime.toIso8601String(),
          'message': 'Bildirim ${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year} ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')} için zamanlandı$repeatInfo',
        };
      }

      // Cloud Function'ı çağır - gerçek push notification için
      final callable = FirebaseFunctions.instance.httpsCallable('sendBroadcastNotification');
      final result = await callable.call<Map<String, dynamic>>({
        'title': title,
        'body': body,
        'targetAudience': targetAudience,
        'data': data ?? {},
      });
      
      // Admin log kaydı
      await _firestore.collection('admin_logs').add({
        'action': 'send_broadcast',
        'title': title,
        'target_audience': targetAudience,
        'admin_uid': _auth.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      return result.data ?? {'success': true, 'sentCount': 0};
    } catch (e) {
      debugPrint('Cloud Function hatası: $e');
      
      // Fallback: Sadece Firestore'a kaydet (in-app bildirimler için)
      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();

      for (var userDoc in usersSnapshot.docs) {
        final notificationRef = _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'title': title,
          'body': body,
          'image_url': imageUrl,
          'data': data,
          'type': 'broadcast',
          'is_read': false,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await _firestore.collection('broadcast_notifications').add({
        'title': title,
        'body': body,
        'image_url': imageUrl,
        'data': data,
        'sent_at': FieldValue.serverTimestamp(),
        'sent_by': _auth.currentUser?.uid,
        'status': 'fallback_only_inapp',
      });

      await _firestore.collection('admin_logs').add({
        'action': 'send_broadcast',
        'title': title,
        'admin_uid': _auth.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'note': 'Cloud Function failed, only in-app notifications sent',
      });
      
      return {
        'success': true,
        'sentCount': usersSnapshot.docs.length,
        'message': 'Sadece uygulama içi bildirimler gönderildi (push notification başarısız)',
      };
    }
  }

  /// Belirli kullanıcılara bildirim gönder
  Future<void> sendTargetedNotification({
    required List<String> userIds,
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
  }) async {
    final batch = _firestore.batch();

    for (var uid in userIds) {
      final notificationRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc();

      batch.set(notificationRef, {
        'title': title,
        'body': body,
        'image_url': imageUrl,
        'data': data,
        'type': 'targeted',
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ==================== ROZET YÖNETİMİ ====================

  /// Tüm rozetleri getir (Firestore'dan veya uygulama içi sabit tanımlardan)
  Future<List<AdminBadgeModel>> getAllBadges() async {
    try {
      final snapshot = await _firestore
          .collection('badge_definitions')
          .orderBy('level')
          .orderBy('criteria_type')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => AdminBadgeModel.fromFirestore(doc))
            .toList();
      }
    } catch (e) {
      print('Firestore rozet okuma hatası: $e');
    }
    
    // Firestore'da rozet yoksa, uygulama içi sabit tanımları döndür
    return await _getBuiltInBadgesWithCounts();
  }
  
  /// Her rozet için kaç kullanıcının kazandığını hesapla
  Future<Map<String, int>> _getBadgeEarnedCounts() async {
    final Map<String, int> counts = {};
    
    try {
      // Tüm kullanıcıların badges subcollection'larını kontrol et
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (var userDoc in usersSnapshot.docs) {
        try {
          final badgesSnapshot = await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('badges')
              .get();
          
          for (var badgeDoc in badgesSnapshot.docs) {
            final badgeId = badgeDoc.id;
            counts[badgeId] = (counts[badgeId] ?? 0) + 1;
          }
        } catch (e) {
          // Subcollection yok veya erişim hatası, devam et
        }
      }
    } catch (e) {
      print('Rozet sayısı hesaplama hatası: $e');
    }
    
    return counts;
  }
  
  /// Uygulama içi sabit rozet tanımlarını kazanan sayılarıyla birlikte döndür
  Future<List<AdminBadgeModel>> _getBuiltInBadgesWithCounts() async {
    final List<AdminBadgeModel> badges = [];
    
    // Önce kazanan sayılarını hesapla
    final earnedCounts = await _getBadgeEarnedCounts();
    print('📊 Rozet kazanan sayıları: $earnedCounts');
    
    // Adım rozetleri - ID'ler uygulamadakilerle aynı olmalı
    final stepIds = ['steps_10k', 'steps_100k', 'steps_1m', 'steps_10m', 'steps_100m', 'steps_1b'];
    final stepRequirements = [10000, 100000, 1000000, 10000000, 100000000, 1000000000];
    final stepNames = ['10K Adım', '100K Adım', '1M Adım', '10M Adım', '100M Adım', '1B Adım'];
    final levels = [BadgeLevel.bronze, BadgeLevel.silver, BadgeLevel.gold, BadgeLevel.platinum, BadgeLevel.diamond, BadgeLevel.diamond];
    
    for (int i = 0; i < stepRequirements.length; i++) {
      final badgeId = stepIds[i];
      badges.add(AdminBadgeModel(
        id: badgeId,
        name: stepNames[i],
        description: '${_formatNumber(stepRequirements[i])} adım dönüştürdüğünüzde kazanılır',
        criteriaType: BadgeCriteriaType.steps,
        criteriaValue: stepRequirements[i],
        level: levels[i],
        iconUrl: '',
        isActive: true,
        earnedCount: earnedCounts[badgeId] ?? 0,
        createdAt: DateTime.now(),
      ));
    }
    
    // Bağış rozetleri - ID'ler uygulamadakilerle aynı olmalı
    final donationIds = ['donation_10', 'donation_100', 'donation_1k', 'donation_10k', 'donation_100k', 'donation_1m'];
    final donationRequirements = [10, 100, 1000, 10000, 100000, 1000000];
    final donationNames = ['10 Hope', '100 Hope', '1K Hope', '10K Hope', '100K Hope', '1M Hope'];
    
    for (int i = 0; i < donationRequirements.length; i++) {
      final badgeId = donationIds[i];
      badges.add(AdminBadgeModel(
        id: badgeId,
        name: donationNames[i],
        description: '${_formatNumber(donationRequirements[i])} Hope bağışladığınızda kazanılır',
        criteriaType: BadgeCriteriaType.donations,
        criteriaValue: donationRequirements[i],
        level: levels[i],
        iconUrl: '',
        isActive: true,
        earnedCount: earnedCounts[badgeId] ?? 0,
        createdAt: DateTime.now(),
      ));
    }
    
    // Aktivite rozetleri - Uygulamadaki tüm streak rozetleri
    final streakRequirements = [1, 7, 30, 90, 180, 365];
    final streakNames = ['İlk Giriş', '7 Gün Streak', '30 Gün Streak', '90 Gün Streak', '180 Gün Streak', '365 Gün Streak'];
    final streakLevels = [BadgeLevel.bronze, BadgeLevel.silver, BadgeLevel.gold, BadgeLevel.platinum, BadgeLevel.diamond, BadgeLevel.diamond];
    final streakIds = ['streak_first', 'streak_7', 'streak_30', 'streak_90', 'streak_180', 'streak_365'];
    
    for (int i = 0; i < streakRequirements.length; i++) {
      final badgeId = streakIds[i];
      badges.add(AdminBadgeModel(
        id: badgeId,
        name: streakNames[i],
        description: '${streakRequirements[i]} gün üst üste giriş yaptığınızda kazanılır',
        criteriaType: BadgeCriteriaType.streak,
        criteriaValue: streakRequirements[i],
        level: streakLevels[i],
        iconUrl: '',
        isActive: true,
        earnedCount: earnedCounts[badgeId] ?? 0,
        createdAt: DateTime.now(),
      ));
    }
    
    return badges;
  }
  
  String _formatNumber(int number) {
    if (number >= 1000000000) return '${(number / 1000000000).toStringAsFixed(0)}B';
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(0)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(0)}K';
    return number.toString();
  }

  /// Yeni rozet ekle
  Future<String> createBadge(AdminBadgeModel badge) async {
    final docRef = await _firestore.collection('badge_definitions').add(
      badge.copyWith(createdAt: DateTime.now()).toFirestore(),
    );

    await _firestore.collection('admin_logs').add({
      'action': 'create_badge',
      'badge_id': docRef.id,
      'badge_name': badge.name,
      'admin_uid': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Rozeti güncelle
  Future<void> updateBadge(AdminBadgeModel badge) async {
    await _firestore.collection('badge_definitions').doc(badge.id).update(
      badge.copyWith(updatedAt: DateTime.now()).toFirestore(),
    );
  }

  /// Rozeti sil
  Future<void> deleteBadge(String badgeId) async {
    await _firestore.collection('badge_definitions').doc(badgeId).delete();

    await _firestore.collection('admin_logs').add({
      'action': 'delete_badge',
      'badge_id': badgeId,
      'admin_uid': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ==================== ADIM & HOPE İSTATİSTİKLERİ ====================

  /// Detaylı adım ve hope istatistikleri
  Future<Map<String, dynamic>> getDetailedStepStats() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final currentMonthStart = DateTime(today.year, today.month, 1);
    
    // ==================== GÜNLÜK ADIMLAR (00:00 - 23:59) ====================
    int todayTotalSteps = 0;           // Bugün atılan toplam adım
    int todayConvertedSteps = 0;       // Bugün dönüştürülen adım
    double todayHopeEarned = 0;        // Bugün kazanılan Hope (2x bonus dahil)
    double todayHopeNormal = 0;        // Bugün normal kazanılan Hope (1x)
    double todayHopeBonus = 0;         // Bugün bonus kazanılan Hope (2x'in ekstra kısmı)
    int todayConversionCount = 0;      // Bugün dönüşüm sayısı
    
    // ==================== AKTARILAN ADIMLAR (AYLIK SİSTEM) ====================
    int carryOverTotalSteps = 0;       // Bu ay aktarılan toplam adım (dönüştürülmemiş günlük adımlar)
    int carryOverConvertedSteps = 0;   // Bu ayın aktarılanlarından dönüştürülen
    int carryOverPendingSteps = 0;     // Bu ayın aktarılanlarından bekleyen
    double carryOverHopeEarned = 0;    // Aktarılanlardan kazanılan Hope
    int carryOverExpiredSteps = 0;     // Önceki ayın dönüştürülmemiş adımları (süresi dolan)
    
    // ==================== BONUS ADIMLAR (DAVET/REFERRAL) ====================
    int totalBonusSteps = 0;           // Toplam verilen bonus adım
    int totalBonusConverted = 0;       // Dönüştürülen bonus adım
    int totalBonusPending = 0;         // Bekleyen bonus adım
    double bonusHopeEarned = 0;        // Bonus adımlardan kazanılan Hope
    int totalReferralCount = 0;        // Toplam davet sayısı
    
    // ==================== GENEL ====================
    int totalDailySteps = 0;           // Tüm zamanlar toplam adım
    int totalConvertedSteps = 0;       // Tüm zamanlar dönüştürülen
    int totalPendingSteps = 0;         // Tüm zamanlar bekleyen
    double totalHopeConverted = 0;     // Toplam üretilen Hope
    double totalHopeDonated = 0;       // Bağışlanan Hope
    double totalHopeInWallets = 0;     // Cüzdanlardaki Hope
    int activeUsersToday = 0;          // Bugün aktif kullanıcı sayısı
    
    // 1. users/{userId}/daily_steps subcollection'dan verileri al
    final usersSnapshot = await _firestore.collection('users').get();
    print('📊 Toplam kullanıcı sayısı: ${usersSnapshot.docs.length}');
    
    for (var userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      final userData = userDoc.data();
      
      // Kullanıcının cüzdan bakiyesi
      final walletHope = userData['wallet_balance_hope'];
      if (walletHope != null) {
        totalHopeInWallets += (walletHope is int) ? walletHope.toDouble() : (walletHope as num).toDouble();
      }
      
      // Davet ve bonus bilgileri
      final referralCount = userData['referral_count'];
      if (referralCount != null && referralCount > 0) {
        totalReferralCount += (referralCount is int) ? referralCount : (referralCount as num).toInt();
      }
      
      final bonusSteps = userData['referral_bonus_steps'];
      final bonusConverted = userData['referral_bonus_converted'];
      
      if (bonusSteps != null && bonusSteps > 0) {
        totalBonusSteps += (bonusSteps is int) ? bonusSteps : (bonusSteps as num).toInt();
      }
      if (bonusConverted != null && bonusConverted > 0) {
        totalBonusConverted += (bonusConverted is int) ? bonusConverted : (bonusConverted as num).toInt();
      }
      
      // Carryover pending adımları (Cloud Function tarafından ayarlanan)
      final carryoverPending = userData['carryover_pending'];
      if (carryoverPending != null && carryoverPending > 0) {
        carryOverPendingSteps += (carryoverPending is int) ? carryoverPending : (carryoverPending as num).toInt();
      }
      
      // Kullanıcının daily_steps subcollection'ını kontrol et
      try {
        final dailyStepsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_steps')
            .get();
        
        for (var stepDoc in dailyStepsSnapshot.docs) {
          final data = stepDoc.data();
          final docId = stepDoc.id;
          final dailySteps = data['daily_steps'] ?? 0;
          final convertedSteps = data['converted_steps'] ?? 0;
          
          final steps = (dailySteps is int) ? dailySteps : (dailySteps as num).toInt();
          final converted = (convertedSteps is int) ? convertedSteps : (convertedSteps as num).toInt();
          
          totalDailySteps += steps;
          totalConvertedSteps += converted;
          
          // Bugünün verisi mi?
          if (docId == todayKey) {
            todayTotalSteps += steps;
            todayConvertedSteps += converted;
            activeUsersToday++;
          } else {
            // Bu ay içinde mi? (carry-over - aylık sistem)
            try {
              final parts = docId.split('-');
              if (parts.length == 3) {
                final docDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                
                // Bugün değilse VE bu ay içindeyse → toplam/dönüştürülen istatistik
                if (docDate.isAfter(currentMonthStart.subtract(const Duration(days: 1))) && 
                    docDate.isBefore(todayStart)) {
                  // Bu ay içinde ama bugünden önce - carry-over hesabı
                  carryOverTotalSteps += steps;
                  carryOverConvertedSteps += converted;
                  // Not: carryOverPendingSteps artık user document'ındaki carryover_pending alanından okunuyor
                }
                // Not: Geçmiş ayların verileri monthly_reset_logs'dan alınacak
              }
            } catch (e) {
              // Tarih parse hatası, atla
            }
          }
        }
      } catch (e) {
        // Subcollection yok veya erişim hatası
      }
    }
    
    // Global daily_steps koleksiyonunu da kontrol et (eski format)
    try {
      final globalDailyStepsSnapshot = await _firestore.collection('daily_steps').get();
      for (var doc in globalDailyStepsSnapshot.docs) {
        final data = doc.data();
        final steps = data['total_steps'];
        final converted = data['converted_steps'];
        final docDate = (data['date'] as Timestamp?)?.toDate();
        
        if (steps != null) {
          final stepsInt = (steps is int) ? steps : (steps as num).toInt();
          // Çift sayma olmasın diye sadece subcollection'da olmayan verileri ekle
          // Bu kontrolü basitleştirmek için şimdilik tümünü ekleyelim
          // (Gerçek production'da user_id ile kontrol edilmeli)
        }
        
        // Bugün aktif mi? (global koleksiyon için)
        if (docDate != null && docDate.isAfter(todayStart.subtract(const Duration(days: 1)))) {
          // activeUsersToday++ zaten subcollection'da sayıldı
        }
      }
    } catch (e) {
      print('Global daily_steps okuma hatası: $e');
    }
    
    // Önceki ayın süresi dolan adımlarını monthly_reset_summaries'den al
    try {
      // Bu ayın başındaki reset summary'yi bul (yani önceki ayın expired adımları)
      final resetLogId = '${today.year}-${today.month.toString().padLeft(2, '0')}';
      final resetLogDoc = await _firestore
          .collection('monthly_reset_summaries')
          .doc(resetLogId)
          .get();
      
      if (resetLogDoc.exists) {
        final resetData = resetLogDoc.data();
        if (resetData != null) {
          final expiredSteps = resetData['total_carryover_expired'];
          if (expiredSteps != null && expiredSteps > 0) {
            carryOverExpiredSteps = (expiredSteps is int) ? expiredSteps : (expiredSteps as num).toInt();
          }
        }
      }
    } catch (e) {
      print('Monthly reset summary okuma hatası: $e');
    }
    
    totalPendingSteps = totalDailySteps - totalConvertedSteps;
    totalBonusPending = totalBonusSteps - totalBonusConverted;
    
    // 2. activity_logs'tan Hope kazanımlarını hesapla
    // Yeni format: activity_type
    final stepConversionsSnapshot1 = await _firestore
        .collection('activity_logs')
        .where('activity_type', whereIn: ['step_conversion', 'carryover_conversion', 'bonus_conversion'])
        .get();
    
    // Eski format: action_type
    final stepConversionsSnapshot2 = await _firestore
        .collection('activity_logs')
        .where('action_type', whereIn: ['step_conversion', 'carryover_conversion', 'bonus_conversion'])
        .get();
    
    // Birleştir ve duplicate kaldır
    final allConversionDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (var doc in stepConversionsSnapshot1.docs) {
      allConversionDocs[doc.id] = doc;
    }
    for (var doc in stepConversionsSnapshot2.docs) {
      allConversionDocs[doc.id] = doc;
    }
    
    print('📊 activity_logs (step_conversion + carryover) toplam: ${allConversionDocs.length}');
    
    for (var doc in allConversionDocs.values) {
      final data = doc.data();
      final activityType = data['activity_type'] ?? data['action_type'];
      final hopeEarned = data['hope_earned'];
      final stepsConverted = data['steps_converted'];
      // Tarih için tüm olası alanları kontrol et
      DateTime? createdAt;
      final possibleDateFields = ['created_at', 'timestamp', 'date'];
      for (var field in possibleDateFields) {
        if (data[field] is Timestamp) {
          createdAt = (data[field] as Timestamp).toDate();
          break;
        }
      }
      
      if (hopeEarned != null) {
        final hope = (hopeEarned is int) ? hopeEarned.toDouble() : (hopeEarned as num).toDouble();
        totalHopeConverted += hope;
        
        // Bugünün dönüşümü mü?
        if (createdAt != null && createdAt.isAfter(todayStart)) {
          if (activityType == 'step_conversion') {
            todayHopeEarned += hope;
            todayConversionCount++;
            
            // 2x bonus kontrolü (2500 adım = 50 Hope ise bonus aktif)
            if (stepsConverted != null) {
              final steps = (stepsConverted is int) ? stepsConverted : (stepsConverted as num).toInt();
              final normalHope = steps / 100.0; // Normal: 100 adım = 1 Hope
              if (hope > normalHope) {
                // 2x bonus aktif
                todayHopeNormal += normalHope;
                todayHopeBonus += (hope - normalHope);
              } else {
                todayHopeNormal += hope;
              }
            }
          } else if (activityType == 'carryover_conversion') {
            carryOverHopeEarned += hope;
          } else if (activityType == 'bonus_conversion') {
            bonusHopeEarned += hope;
          }
        } else if (createdAt != null && activityType == 'carryover_conversion') {
          // Geçmiş günlerin carry-over dönüşümleri
          carryOverHopeEarned += hope;
        } else if (createdAt != null && activityType == 'bonus_conversion') {
          // Geçmiş günlerin bonus dönüşümleri
          bonusHopeEarned += hope;
        }
      }
    }
    
    // Not: Bonus Hope artık activity_logs'tan hesaplanıyor (bonusHopeEarned)
    
    // 3. Bağışları activity_logs'tan al (eski ve yeni formatları destekle)
    final donationsSnapshot1 = await _firestore
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation')
        .get();
    
    final donationsSnapshot2 = await _firestore
        .collection('activity_logs')
        .where('action_type', isEqualTo: 'donation')
        .get();
    
    // Birleştir ve duplicate kaldır
    final allDonationDocsForStats = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (var doc in donationsSnapshot1.docs) {
      allDonationDocsForStats[doc.id] = doc;
    }
    for (var doc in donationsSnapshot2.docs) {
      allDonationDocsForStats[doc.id] = doc;
    }
    
    print('📊 activity_logs (donation) toplam: ${allDonationDocsForStats.length}');
    
    for (var doc in allDonationDocsForStats.values) {
      final data = doc.data();
      // Hem amount hem hope_amount kontrol et
      final amount = data['amount'] ?? data['hope_amount'];
      if (amount != null) {
        totalHopeDonated += (amount is int) ? amount.toDouble() : (amount as num).toDouble();
      }
    }
    
    print('📊 Toplam bağışlanan Hope: $totalHopeDonated');
    
    // Aktarılan Hope'u doğrudan dönüştürülen adımdan hesapla (100 adım = 1 Hope)
    // 2x bonus dahil olabilir ama basit hesap için normal oran kullanıyoruz
    final double carryOverHopeCalculated = carryOverConvertedSteps / 100.0;

    return {
      // Bugünkü Günlük Adımlar
      'today_total_steps': todayTotalSteps,
      'today_converted_steps': todayConvertedSteps,
      'today_pending_steps': todayTotalSteps - todayConvertedSteps,
      'today_hope_earned': todayHopeEarned,
      'today_hope_normal': todayHopeNormal,
      'today_hope_bonus': todayHopeBonus,
      'today_conversion_count': todayConversionCount,
      
      // Carry-Over Adımlar (Aylık)
      'carryover_total_steps': carryOverTotalSteps,
      'carryover_converted_steps': carryOverConvertedSteps,
      'carryover_pending_steps': carryOverPendingSteps,
      'carryover_hope_earned': carryOverHopeCalculated, // Dönüştürülen adım / 100
      'carryover_expired_steps': carryOverExpiredSteps,
      
      // Bonus Adımlar (Davet)
      'total_bonus_steps': totalBonusSteps,
      'total_bonus_converted': totalBonusConverted,
      'total_bonus_pending': totalBonusPending,
      'bonus_hope_earned': bonusHopeEarned,
      'total_referral_count': totalReferralCount,
      
      // Genel Toplamlar
      'total_daily_steps': totalDailySteps,
      'total_converted_steps': totalConvertedSteps,
      'total_pending_steps': totalPendingSteps,
      // TUTARLI HESAP: Cüzdanlardaki + Bağışlanan = Toplam Hope (bonus dahil)
      'total_hope_converted': totalHopeInWallets + totalHopeDonated,
      'total_hope_donated': totalHopeDonated,
      'total_hope_in_wallets': totalHopeInWallets,
      'active_users_today': activeUsersToday,
      'total_users': usersSnapshot.docs.length,
      
      // Eski uyumluluk için
      'net_transferred_steps': totalConvertedSteps - totalBonusConverted,
    };
  }

  /// Aylık adım ve hope dönüşüm istatistikleri
  Future<Map<String, dynamic>> getMonthlyStepStats({int year = 0, int month = 0}) async {
    final now = DateTime.now();
    final targetYear = year > 0 ? year : now.year;
    final targetMonth = month > 0 ? month : now.month;

    final monthStart = DateTime(targetYear, targetMonth, 1);
    final monthEnd = DateTime(targetYear, targetMonth + 1, 0);

    int totalSteps = 0;
    int convertedSteps = 0;
    double totalHopeConverted = 0;

    // daily_steps koleksiyonundan TÜM verileri al ve kod tarafında filtrele
    final snapshot = await _firestore
        .collection('daily_steps')
        .get();
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final docDate = (data['date'] as Timestamp?)?.toDate();
      
      // Tarih filtresini kod tarafında uygula
      if (docDate != null && 
          docDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          docDate.isBefore(monthEnd.add(const Duration(days: 1)))) {
        final steps = data['total_steps'];
        final converted = data['converted_steps'];
        
        if (steps != null) {
          totalSteps += (steps is int) ? steps : (steps as num).toInt();
        }
        if (converted != null) {
          convertedSteps += (converted is int) ? converted : (converted as num).toInt();
          // 2500 adım = 25 Hope → 100 adım = 1 Hope
          totalHopeConverted += ((converted is int) ? converted : (converted as num).toInt()) / 100.0;
        }
      }
    }

    return {
      'year': targetYear,
      'month': targetMonth,
      'total_steps': totalSteps,
      'converted_steps': convertedSteps,
      'pending_steps': totalSteps - convertedSteps,
      'total_hope_converted': totalHopeConverted,
      'conversion_rate': totalSteps > 0 
          ? ((convertedSteps / totalSteps) * 100).toStringAsFixed(1)
          : '0',
    };
  }

  // ==================== ADMIN LOG ====================

  /// Admin işlem loglarını getir
  Future<List<Map<String, dynamic>>> getAdminLogs({int limit = 100}) async {
    final snapshot = await _firestore
        .collection('admin_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => {
      ...doc.data(),
      'id': doc.id,
    }).toList();
  }

  // ==================== TARİH BAZLI İSTATİSTİKLER ====================

  /// Belirli bir gün için detaylı istatistik getir
  Future<Map<String, dynamic>> getStatsForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    debugPrint('🔍 getStatsForDate: Aranan tarih: $dateStr');
    
    int totalSteps = 0;
    int convertedSteps = 0;
    double totalHopeConverted = 0;
    Set<String> activeUserIds = {};
    int donationCount = 0;
    double donationAmount = 0;
    int conversionCount = 0;
    
    // 1. ÖNCE: users/{userId}/daily_steps subcollection'dan verileri al
    final usersSnapshot = await _firestore.collection('users').get();
    debugPrint('🔍 Toplam kullanıcı: ${usersSnapshot.docs.length}');
    
    for (var userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      
      try {
        final dailyStepDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_steps')
            .doc(dateStr)
            .get();
        
        if (dailyStepDoc.exists) {
          final data = dailyStepDoc.data()!;
          activeUserIds.add(userId);
          
          final steps = data['daily_steps'] ?? data['total_steps'] ?? 0;
          final converted = data['converted_steps'] ?? 0;
          
          totalSteps += (steps is int) ? steps : (steps as num).toInt();
          convertedSteps += (converted is int) ? converted : (converted as num).toInt();
        }
      } catch (e) {
        // Subcollection erişim hatası
      }
    }
    
    debugPrint('🔍 Subcollection\'dan: Aktif=${{activeUserIds.length}}, Adım=$totalSteps');
    
    // 2. SONRA: Eğer subcollection'dan veri gelmediyse, global daily_steps'tan dene
    if (totalSteps == 0) {
      debugPrint('🔍 Subcollection boş, global daily_steps kontrol ediliyor...');
      
      final globalSnapshot = await _firestore.collection('daily_steps').get();
      
      for (var doc in globalSnapshot.docs) {
        final data = doc.data();
        final docDate = (data['date'] as Timestamp?)?.toDate();
        final docUserId = data['user_id'] as String?;
        
        // Tarih kontrolü
        if (docDate != null && 
            docDate.year == date.year && 
            docDate.month == date.month && 
            docDate.day == date.day) {
          
          if (docUserId != null) {
            activeUserIds.add(docUserId);
          }
          
          final steps = data['total_steps'] ?? 0;
          final converted = data['converted_steps'] ?? 0;
          
          totalSteps += (steps is int) ? steps : (steps as num).toInt();
          convertedSteps += (converted is int) ? converted : (converted as num).toInt();
          
          debugPrint('  ✅ Global: ${{doc.id}} -> steps=$steps, converted=$converted');
        }
      }
      
      debugPrint('🔍 Global\'dan: Aktif=${{activeUserIds.length}}, Adım=$totalSteps');
    }
    
    // Hope hesapla: 100 adım = 1 Hope
    totalHopeConverted = convertedSteps / 100.0;
    
    // 3. O güne ait bağış aktivitelerini al
    try {
      final donationsQuery1 = await _firestore
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'donation')
          .get();
      
      for (final doc in donationsQuery1.docs) {
        final data = doc.data();
        final timestamp = data['created_at'] ?? data['timestamp'] ?? data['date'];
        if (timestamp != null && timestamp is Timestamp) {
          final activityDate = timestamp.toDate();
          if (activityDate.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
              activityDate.isBefore(dayEnd)) {
            donationCount++;
            final amount = data['amount'] ?? data['hope_amount'] ?? 0;
            donationAmount += (amount is num) ? amount.toDouble() : 0;
          }
        }
      }
    } catch (e) {
      debugPrint('Donation query error: $e');
    }
    
    try {
      final donationsQuery2 = await _firestore
          .collection('activity_logs')
          .where('action_type', isEqualTo: 'donation')
          .get();
      
      for (final doc in donationsQuery2.docs) {
        final data = doc.data();
        final timestamp = data['created_at'] ?? data['timestamp'] ?? data['date'];
        if (timestamp != null && timestamp is Timestamp) {
          final activityDate = timestamp.toDate();
          if (activityDate.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
              activityDate.isBefore(dayEnd)) {
            donationCount++;
            final amount = data['amount'] ?? data['hope_amount'] ?? 0;
            donationAmount += (amount is num) ? amount.toDouble() : 0;
          }
        }
      }
    } catch (e) {
      debugPrint('Donation query error: $e');
    }
    
    // 4. O güne ait dönüştürme sayısını al
    try {
      final conversions1 = await _firestore
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'step_conversion')
          .get();
      
      for (final doc in conversions1.docs) {
        final data = doc.data();
        final timestamp = data['created_at'] ?? data['timestamp'] ?? data['date'];
        if (timestamp != null && timestamp is Timestamp) {
          final activityDate = timestamp.toDate();
          if (activityDate.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
              activityDate.isBefore(dayEnd)) {
            conversionCount++;
          }
        }
      }
    } catch (e) {
      debugPrint('Conversion query error: $e');
    }
    
    try {
      final conversions2 = await _firestore
          .collection('activity_logs')
          .where('action_type', isEqualTo: 'step_conversion')
          .get();
      
      for (final doc in conversions2.docs) {
        final data = doc.data();
        final timestamp = data['created_at'] ?? data['timestamp'] ?? data['date'];
        if (timestamp != null && timestamp is Timestamp) {
          final activityDate = timestamp.toDate();
          if (activityDate.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
              activityDate.isBefore(dayEnd)) {
            conversionCount++;
          }
        }
      }
    } catch (e) {
      debugPrint('Conversion query error: $e');
    }
    
    return {
      'date': dateStr,
      'total_steps': totalSteps,
      'converted_steps': convertedSteps,
      'pending_steps': totalSteps - convertedSteps,
      'total_hope_converted': totalHopeConverted,
      'active_users': activeUserIds.length,
      'donation_count': donationCount,
      'donation_amount': donationAmount,
      'conversion_count': conversionCount,
      'conversion_rate': totalSteps > 0 
          ? ((convertedSteps / totalSteps) * 100).toStringAsFixed(1)
          : '0',
    };
  }

  /// Belirli bir ay için detaylı istatistik getir
  Future<Map<String, dynamic>> getStatsForMonth(int year, int month) async {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);
    final daysInMonth = monthEnd.day;
    
    debugPrint('🔍 getStatsForMonth: $year-$month (1-$daysInMonth)');
    
    int totalSteps = 0;
    int convertedSteps = 0;
    double totalHopeConverted = 0;
    Set<String> activeUserIds = {};
    int donationCount = 0;
    double donationAmount = 0;
    int conversionCount = 0;
    
    // 1. ÖNCE: users/{userId}/daily_steps subcollection'dan verileri al
    final usersSnapshot = await _firestore.collection('users').get();
    debugPrint('🔍 Toplam kullanıcı: ${usersSnapshot.docs.length}');
    
    for (var userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      
      try {
        final dailyStepsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_steps')
            .get();
        
        for (var stepDoc in dailyStepsSnapshot.docs) {
          final docId = stepDoc.id;
          
          try {
            final parts = docId.split('-');
            if (parts.length == 3) {
              final docYear = int.parse(parts[0]);
              final docMonth = int.parse(parts[1]);
              
              if (docYear == year && docMonth == month) {
                final data = stepDoc.data();
                activeUserIds.add(userId);
                
                final steps = data['daily_steps'] ?? data['total_steps'] ?? 0;
                final converted = data['converted_steps'] ?? 0;
                
                totalSteps += (steps is int) ? steps : (steps as num).toInt();
                convertedSteps += (converted is int) ? converted : (converted as num).toInt();
              }
            }
          } catch (e) {
            // Tarih parse hatası
          }
        }
      } catch (e) {
        // Subcollection erişim hatası
      }
    }
    
    debugPrint('🔍 Subcollection\'dan: Aktif=${activeUserIds.length}, Adım=$totalSteps');
    
    // 2. SONRA: Eğer subcollection'dan veri gelmediyse, global daily_steps'tan dene
    if (totalSteps == 0) {
      debugPrint('🔍 Subcollection boş, global daily_steps kontrol ediliyor...');
      
      final globalSnapshot = await _firestore.collection('daily_steps').get();
      
      for (var doc in globalSnapshot.docs) {
        final data = doc.data();
        final docDate = (data['date'] as Timestamp?)?.toDate();
        final docUserId = data['user_id'] as String?;
        
        // Tarih kontrolü - bu ay içinde mi?
        if (docDate != null && 
            docDate.year == year && 
            docDate.month == month) {
          
          if (docUserId != null) {
            activeUserIds.add(docUserId);
          }
          
          final steps = data['total_steps'] ?? 0;
          final converted = data['converted_steps'] ?? 0;
          
          totalSteps += (steps is int) ? steps : (steps as num).toInt();
          convertedSteps += (converted is int) ? converted : (converted as num).toInt();
        }
      }
      
      debugPrint('🔍 Global\'dan: Aktif=${activeUserIds.length}, Adım=$totalSteps');
    }
    
    // Hope hesapla: 100 adım = 1 Hope
    totalHopeConverted = convertedSteps / 100.0;
    
    // 2. O aydaki bağış aktivitelerini al
    try {
      final donationsQuery1 = await _firestore
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'donation')
          .get();
      
      for (final doc in donationsQuery1.docs) {
        final data = doc.data();
        final timestamp = data['created_at'] ?? data['timestamp'] ?? data['date'];
        if (timestamp != null && timestamp is Timestamp) {
          final activityDate = timestamp.toDate();
          if (activityDate.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              activityDate.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            donationCount++;
            final amount = data['amount'] ?? data['hope_amount'] ?? 0;
            donationAmount += (amount is num) ? amount.toDouble() : 0;
          }
        }
      }
    } catch (e) {
      debugPrint('Donation query error: $e');
    }
    
    try {
      final donationsQuery2 = await _firestore
          .collection('activity_logs')
          .where('action_type', isEqualTo: 'donation')
          .get();
      
      for (final doc in donationsQuery2.docs) {
        final data = doc.data();
        final timestamp = data['created_at'] ?? data['timestamp'] ?? data['date'];
        if (timestamp != null && timestamp is Timestamp) {
          final activityDate = timestamp.toDate();
          if (activityDate.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              activityDate.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            donationCount++;
            final amount = data['amount'] ?? data['hope_amount'] ?? 0;
            donationAmount += (amount is num) ? amount.toDouble() : 0;
          }
        }
      }
    } catch (e) {
      debugPrint('Donation query error: $e');
    }
    
    // 3. O aydaki dönüştürme sayısını al
    try {
      final conversions1 = await _firestore
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'step_conversion')
          .get();
      
      for (final doc in conversions1.docs) {
        final data = doc.data();
        final timestamp = data['created_at'] ?? data['timestamp'] ?? data['date'];
        if (timestamp != null && timestamp is Timestamp) {
          final activityDate = timestamp.toDate();
          if (activityDate.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              activityDate.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            conversionCount++;
          }
        }
      }
    } catch (e) {
      debugPrint('Conversion query error: $e');
    }
    
    try {
      final conversions2 = await _firestore
          .collection('activity_logs')
          .where('action_type', isEqualTo: 'step_conversion')
          .get();
      
      for (final doc in conversions2.docs) {
        final data = doc.data();
        final timestamp = data['created_at'] ?? data['timestamp'] ?? data['date'];
        if (timestamp != null && timestamp is Timestamp) {
          final activityDate = timestamp.toDate();
          if (activityDate.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              activityDate.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            conversionCount++;
          }
        }
      }
    } catch (e) {
      debugPrint('Conversion query error: $e');
    }
    
    return {
      'year': year,
      'month': month,
      'total_steps': totalSteps,
      'converted_steps': convertedSteps,
      'pending_steps': totalSteps - convertedSteps,
      'total_hope_converted': totalHopeConverted,
      'active_users': activeUserIds.length,
      'donation_count': donationCount,
      'donation_amount': donationAmount,
      'conversion_count': conversionCount,
      'conversion_rate': totalSteps > 0 
          ? ((convertedSteps / totalSteps) * 100).toStringAsFixed(1)
          : '0',
    };
  }
  
  String _getMonthName(int month) {
    const monthNames = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return monthNames[month - 1];
  }

  // ==================== YENİ DASHBOARD ANALİTİKLERİ ====================

  /// Günlük Adım Analizlerini getir
  Future<DailyStepAnalytics> getDailyStepAnalytics({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateKey = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    
    int totalDailySteps = 0;
    int convertedSteps = 0;
    int bonusConversions = 0; // 2x bonus ile dönüştürülen ADIM sayısı
    double bonusHopeEarned = 0; // 2x bonus ile kazanılan HOPE
    
    // Tüm kullanıcıların bugünkü adım verilerini topla
    final usersSnapshot = await _firestore.collection('users').get();
    
    for (var userDoc in usersSnapshot.docs) {
      try {
        final stepDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('daily_steps')
            .doc(dateKey)
            .get();
        
        if (stepDoc.exists) {
          final data = stepDoc.data()!;
          totalDailySteps += (data['daily_steps'] ?? 0) as int;
          convertedSteps += (data['converted_steps'] ?? 0) as int;
          
          // Bonus adımları daily_steps'ten al (bonus_steps_converted alanı)
          final bonusStepsConverted = (data['bonus_steps_converted'] ?? 0) as int;
          bonusConversions += bonusStepsConverted;
        }
      } catch (e) {
        // Devam et
      }
    }
    
    // Activity logs'tan bonus Hope miktarını al (her zaman güncel kaynak)
    final activityLogs = await _firestore
        .collection('activity_logs')
        .where('activity_type', whereIn: ['step_conversion', 'step_conversion_2x'])
        .get();
    
    for (var doc in activityLogs.docs) {
      final data = doc.data();
      final timestamp = (data['created_at'] ?? data['timestamp']) as Timestamp?;
      if (timestamp != null) {
        final logDate = timestamp.toDate();
        if (logDate.year == targetDate.year && 
            logDate.month == targetDate.month && 
            logDate.day == targetDate.day) {
          final activityType = data['activity_type'] ?? '';
          final isBonus = data['is_bonus'] == true || activityType == 'step_conversion_2x';
          
          if (isBonus) {
            final steps = (data['steps_converted'] ?? 0) as int;
            final hope = (data['hope_earned'] ?? 0).toDouble();
            
            // Eğer daily_steps'ten bonus alınamadıysa, activity_logs'tan al
            if (bonusConversions == 0) {
              bonusConversions += steps;
            }
            bonusHopeEarned += hope; // Gerçek bonus Hope miktarı
          }
        }
      }
    }
    
    int normalConversions = convertedSteps - bonusConversions;
    if (normalConversions < 0) normalConversions = 0;
    
    // Hope hesaplama
    // Normal: 100 adım = 1 Hope
    // Bonus (2x): Activity logs'tan alınan gerçek hope_earned değeri
    final normalHope = normalConversions / 100.0;
    // Eğer activity logs'tan bonus hope alınamadıysa, manuel hesapla
    // 2x bonus: 2500 adım = 50 Hope (normal 25, bonus +25)
    final bonusHope = bonusHopeEarned > 0 ? bonusHopeEarned : (bonusConversions / 100.0) * 2;
    
    return DailyStepAnalytics(
      totalDailySteps: totalDailySteps,
      convertedSteps: convertedSteps,
      normalConvertedSteps: normalConversions,
      bonusConvertedSteps: bonusConversions,
      normalHopeEarned: normalHope,
      bonusHopeEarned: bonusHope,
      totalHopeEarned: normalHope + bonusHope,
      date: targetDate,
    );
  }

  /// Taşınan (Carryover) Adım Analizlerini getir
  Future<CarryoverAnalytics> getCarryoverAnalytics() async {
    int totalCarryover = 0;
    int convertedCarryover = 0;
    int pendingCarryover = 0;
    int expiredSteps = 0;
    int usersWithCarryover = 0; // Taşınan adımı olan kullanıcı sayısı
    
    final usersSnapshot = await _firestore.collection('users').get();
    
    for (var userDoc in usersSnapshot.docs) {
      final data = userDoc.data();
      
      // Toplam taşınan adım (tarihsel) - users'tan
      totalCarryover += (data['total_carryover_steps'] ?? 0) as int;
      
      // Bekleyen taşınan adım
      final pending = (data['carryover_pending'] ?? 0) as int;
      pendingCarryover += pending;
      
      // Taşınan adımı olan kullanıcıları say
      if (pending > 0) {
        usersWithCarryover++;
      }
      
      // Dönüştürülen taşınan adım - users'tan
      convertedCarryover += (data['carryover_converted'] ?? 0) as int;
      
      // Süresi dolup silinen adımlar (tarihsel toplam)
      expiredSteps += (data['expired_steps_total'] ?? 0) as int;
    }
    
    // Activity logs'tan carryover dönüşümlerini de kontrol et
    final carryoverLogs = await _firestore
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'carryover_conversion')
        .get();
    
    double hopeFromCarryover = 0;
    int stepsFromLogs = 0;
    
    for (var doc in carryoverLogs.docs) {
      final data = doc.data();
      hopeFromCarryover += (data['hope_earned'] ?? 0).toDouble();
      stepsFromLogs += (data['steps_converted'] ?? 0) as int;
    }
    
    // Eğer users'taki carryover_converted boşsa, activity_logs'tan al
    if (convertedCarryover == 0 && stepsFromLogs > 0) {
      convertedCarryover = stepsFromLogs;
    }
    
    // Toplam carryover = dönüştürülen + bekleyen + silinen (tarihsel)
    if (totalCarryover == 0) {
      totalCarryover = convertedCarryover + pendingCarryover + expiredSteps;
    }
    
    return CarryoverAnalytics(
      totalCarryoverSteps: totalCarryover,
      convertedCarryoverSteps: convertedCarryover,
      pendingCarryoverSteps: pendingCarryover,
      hopeFromCarryover: hopeFromCarryover,
      expiredSteps: expiredSteps,
      lastResetDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
      usersWithCarryover: usersWithCarryover,
    );
  }

  /// Referans ve Davet Analizlerini getir
  Future<ReferralAnalytics> getReferralAnalytics() async {
    int totalReferralUsers = 0;
    int totalBonusGiven = 0;
    int convertedBonus = 0;
    Map<String, int> topReferrers = {};
    
    final usersSnapshot = await _firestore.collection('users').get();
    
    for (var userDoc in usersSnapshot.docs) {
      final data = userDoc.data();
      
      // Referans ile gelen kullanıcı kontrolü
      final referredBy = data['referred_by'];
      if (referredBy != null && referredBy.toString().isNotEmpty) {
        totalReferralUsers++;
      }
      
      // Davet eden kullanıcının istatistikleri
      final referralCount = (data['referral_count'] ?? 0) as int;
      final bonusSteps = (data['referral_bonus_steps'] ?? 0) as int;
      final bonusConverted = (data['referral_bonus_converted'] ?? 0) as int;
      
      totalBonusGiven += bonusSteps;
      convertedBonus += bonusConverted;
      
      // En çok davet edenler
      if (referralCount > 0) {
        final userName = data['full_name'] ?? 'Kullanıcı';
        topReferrers[userName] = referralCount;
      }
    }
    
    // Hope hesaplama: 100 adım = 1 Hope
    final hopeFromBonus = convertedBonus / 100.0;
    
    // Top 5 referrer'ı al
    final sortedReferrers = Map.fromEntries(
      topReferrers.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
    );
    final top5 = Map.fromEntries(sortedReferrers.entries.take(5));
    
    return ReferralAnalytics(
      totalReferralUsers: totalReferralUsers,
      totalBonusStepsGiven: totalBonusGiven,
      convertedBonusSteps: convertedBonus,
      pendingBonusSteps: totalBonusGiven - convertedBonus,
      hopeFromBonusSteps: hopeFromBonus,
      topReferrers: top5,
    );
  }

  /// Bağış Analizlerini getir
  Future<DonationAnalytics> getDonationAnalytics({DateTime? startDate, DateTime? endDate}) async {
    int totalCount = 0;
    double totalAmount = 0;
    Map<String, double> charityBreakdown = {};
    List<DonationRecord> recentDonations = [];
    
    // Activity logs'tan bağışları çek
    Query<Map<String, dynamic>> query = _firestore
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation');
    
    final donations1 = await query.get();
    
    // Eski format desteği
    final donations2 = await _firestore
        .collection('activity_logs')
        .where('action_type', isEqualTo: 'donation')
        .get();
    
    // Birleştir ve duplicate kaldır
    final allDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (var doc in donations1.docs) {
      allDocs[doc.id] = doc;
    }
    for (var doc in donations2.docs) {
      allDocs[doc.id] = doc;
    }
    
    for (var doc in allDocs.values) {
      final data = doc.data();
      
      // Tarih filtresi
      final timestamp = (data['created_at'] ?? data['timestamp']) as Timestamp?;
      if (timestamp != null && startDate != null) {
        final donationDate = timestamp.toDate();
        if (donationDate.isBefore(startDate)) continue;
        if (endDate != null && donationDate.isAfter(endDate)) continue;
      }
      
      final amount = (data['amount'] ?? data['hope_amount'] ?? 0).toDouble();
      final charityName = data['charity_name'] ?? data['target_name'] ?? 'Bilinmeyen';
      final userName = data['user_name'] ?? 'Anonim';
      
      totalCount++;
      totalAmount += amount;
      
      // Vakıf bazında dağılım
      charityBreakdown[charityName] = (charityBreakdown[charityName] ?? 0) + amount;
      
      // Son bağışlar
      if (timestamp != null) {
        recentDonations.add(DonationRecord(
          id: doc.id,
          userId: data['user_id'] ?? '',
          username: userName,
          charityName: charityName,
          hopeAmount: amount,
          date: timestamp.toDate(),
        ));
      }
    }
    
    // Son 20 bağışı tarihe göre sırala
    recentDonations.sort((a, b) => b.date.compareTo(a.date));
    recentDonations = recentDonations.take(20).toList();
    
    return DonationAnalytics(
      totalDonationCount: totalCount,
      totalDonatedHope: totalAmount,
      averageDonation: totalCount > 0 ? totalAmount / totalCount : 0,
      charityBreakdown: charityBreakdown,
      recentDonations: recentDonations,
    );
  }

  /// Detaylı kullanıcı adım kayıtlarını getir (Filtreli)
  Future<List<UserStepRecord>> getDetailedStepRecords({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    List<UserStepRecord> records = [];
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();
    
    final usersSnapshot = await _firestore.collection('users').get();
    
    for (var userDoc in usersSnapshot.docs) {
      final userName = userDoc.data()['full_name'] ?? 'Kullanıcı';
      
      try {
        final stepsSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('daily_steps')
            .get();
        
        for (var stepDoc in stepsSnapshot.docs) {
          // Tarih parse et
          final parts = stepDoc.id.split('-');
          if (parts.length == 3) {
            final date = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            
            if (date.isAfter(start.subtract(const Duration(days: 1))) &&
                date.isBefore(end.add(const Duration(days: 1)))) {
              final data = stepDoc.data();
              final dailySteps = (data['daily_steps'] ?? 0) as int;
              final converted = (data['converted_steps'] ?? 0) as int;
              
              if (dailySteps > 0 || converted > 0) {
                records.add(UserStepRecord(
                  userId: userDoc.id,
                  username: userName,
                  steps: dailySteps,
                  convertedSteps: converted,
                  hopeEarned: converted / 100.0,
                  hasBonusMultiplier: (data['bonus_conversion_count'] ?? 0) > 0,
                  date: date,
                ));
              }
            }
          }
        }
      } catch (e) {
        // Devam et
      }
    }
    
    // Tarihe göre sırala (en yeniden)
    records.sort((a, b) => b.date.compareTo(a.date));
    return records.take(limit).toList();
  }

  /// Detaylı bağış kayıtlarını getir (Filtreli)
  Future<List<DonationRecord>> getDetailedDonationRecords({
    DateTime? startDate,
    DateTime? endDate,
    String? charityId,
    int limit = 100,
  }) async {
    List<DonationRecord> records = [];
    
    Query<Map<String, dynamic>> query = _firestore
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation');
    
    if (charityId != null) {
      query = query.where('charity_id', isEqualTo: charityId);
    }
    
    final snapshot = await query.get();
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = (data['created_at'] ?? data['timestamp']) as Timestamp?;
      
      if (timestamp != null) {
        final donationDate = timestamp.toDate();
        
        // Tarih filtresi
        if (startDate != null && donationDate.isBefore(startDate)) continue;
        if (endDate != null && donationDate.isAfter(endDate)) continue;
        
        records.add(DonationRecord(
          id: doc.id,
          userId: data['user_id'] ?? '',
          username: data['user_name'] ?? 'Anonim',
          charityName: data['charity_name'] ?? data['target_name'] ?? 'Bilinmeyen',
          hopeAmount: (data['amount'] ?? data['hope_amount'] ?? 0).toDouble(),
          date: donationDate,
        ));
      }
    }
    
    // Tarihe göre sırala
    records.sort((a, b) => b.date.compareTo(a.date));
    return records.take(limit).toList();
  }

  /// Detaylı referral kayıtlarını getir
  Future<List<ReferralRecord>> getDetailedReferralRecords({
    DateFilterType? filterType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    List<ReferralRecord> records = [];
    
    final usersSnapshot = await _firestore.collection('users').get();
    
    for (var userDoc in usersSnapshot.docs) {
      final data = userDoc.data();
      final referredBy = data['referred_by'];
      
      if (referredBy != null && referredBy.toString().isNotEmpty) {
        // Davet eden kullanıcıyı bul
        try {
          final referrerDoc = await _firestore.collection('users').doc(referredBy).get();
          final referrerName = referrerDoc.data()?['full_name'] ?? 'Kullanıcı';
          
          records.add(ReferralRecord(
            referrerId: referredBy,
            referrerUsername: referrerName,
            referredId: userDoc.id,
            referredUsername: data['full_name'] ?? 'Kullanıcı',
            bonusStepsGiven: 100000, // Her davet 100K bonus
            bonusStepsUsed: (data['referral_bonus_converted'] ?? 0) as int,
            referralDate: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ));
        } catch (e) {
          // Devam et
        }
      }
    }
    
    // Tarihe göre sırala
    records.sort((a, b) => b.referralDate.compareTo(a.referralDate));
    return records.take(limit).toList();
  }
}
