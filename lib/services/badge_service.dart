import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/badge_model.dart';
import '../providers/language_provider.dart';
import 'local_notification_service.dart';
import 'social_share_service.dart';

/// Rozet kazanıldığında çağrılacak callback
typedef BadgeEarnedCallback = void Function(BadgeDefinition badge);

/// Rozet Servisi - Rozet kazanma ve yönetim
class BadgeService {
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Rozet kazanıldığında çağrılacak callback
  BadgeEarnedCallback? onBadgeEarned;
  
  /// Global navigator key (dialog göstermek için)
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Kullanıcının lifetime istatistiklerini al
  /// Her zaman activity_logs'tan güncel hesaplama yapar
  Future<Map<String, dynamic>> getLifetimeStats(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      
      // Lifetime steps - her zaman activity_logs'tan hesapla
      final lifetimeSteps = await _calculateLifetimeSteps(uid);
      
      // Lifetime donations - her zaman activity_logs'tan hesapla
      final lifetimeDonations = await _calculateLifetimeDonations(uid);
      
      return {
        'lifetime_total_steps': lifetimeSteps,
        'lifetime_total_donations': lifetimeDonations,
        'current_streak': data['current_streak'] ?? 0,
        'longest_streak': data['longest_streak'] ?? 0,
        'last_login_date': data['last_login_date'],
      };
    } catch (e) {
      print('Lifetime stats alma hatası: $e');
      return {
        'lifetime_total_steps': 0,
        'lifetime_total_donations': 0.0,
        'current_streak': 0,
        'longest_streak': 0,
        'last_login_date': null,
      };
    }
  }

  /// Activity logs'tan toplam dönüştürülen adımları hesapla
  Future<int> _calculateLifetimeSteps(String uid) async {
    try {
      int totalSteps = 0;
      
      // 1. Global activity_logs koleksiyonundan oku (step_conversion ve carryover_conversion)
      final globalLogs = await _firestore
          .collection('activity_logs')
          .where('user_id', isEqualTo: uid)
          .get();
      
      for (final doc in globalLogs.docs) {
        final data = doc.data();
        final activityType = data['activity_type'] ?? data['action_type'] ?? '';
        // step_conversion, step_conversion_2x, carryover_conversion, bonus_conversion
        if (activityType == 'step_conversion' || 
            activityType == 'step_conversion_2x' || 
            activityType == 'carryover_conversion' ||
            activityType == 'bonus_conversion' ||
            activityType == 'leaderboard_bonus_conversion' ||
            activityType == 'team_bonus_conversion') {
          totalSteps += (data['steps_converted'] ?? data['steps'] ?? 0) as int;
        }
      }
      
      // 2. User subcollection'dan da oku (eski veriler için)
      final userLogs = await _firestore
          .collection('users')
          .doc(uid)
          .collection('activity_logs')
          .get();
      
      for (final doc in userLogs.docs) {
        final data = doc.data();
        final actionType = data['activity_type'] ?? data['action_type'] ?? '';
        // step_conversion, step_conversion_2x, carryover_conversion, bonus_conversion
        if (actionType == 'step_conversion' || 
            actionType == 'step_conversion_2x' || 
            actionType == 'carryover_conversion' ||
            actionType == 'bonus_conversion' ||
            actionType == 'leaderboard_bonus_conversion' ||
            actionType == 'team_bonus_conversion') {
          totalSteps += (data['steps_converted'] ?? data['steps'] ?? 0) as int;
        }
      }
      
      // Değeri kaydet (bir dahaki sefere hızlı olsun)
      if (totalSteps > 0) {
        await _firestore.collection('users').doc(uid).set({
          'lifetime_total_steps': totalSteps,
        }, SetOptions(merge: true));
      }
      
      return totalSteps;
    } catch (e) {
      print('Lifetime steps hesaplama hatası: $e');
      return 0;
    }
  }

  /// Activity logs'tan toplam bağışları hesapla
  Future<double> _calculateLifetimeDonations(String uid) async {
    try {
      // User subcollection'dan bağışları al (hem activity_type hem action_type destekle)
      final userLogs1 = await _firestore
          .collection('users')
          .doc(uid)
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'donation')
          .get();
      
      final userLogs2 = await _firestore
          .collection('users')
          .doc(uid)
          .collection('activity_logs')
          .where('action_type', isEqualTo: 'donation')
          .get();
      
      // Birleştir ve duplicate kaldır
      final allDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (var doc in userLogs1.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in userLogs2.docs) {
        allDocs[doc.id] = doc;
      }
      
      double totalDonations = 0;
      for (final doc in allDocs.values) {
        final data = doc.data();
        totalDonations += (data['amount'] ?? data['hope_amount'] ?? 0).toDouble();
      }
      
      // Değeri kaydet (bir dahaki sefere hızlı olsun)
      if (totalDonations > 0) {
        await _firestore.collection('users').doc(uid).set({
          'lifetime_total_donations': totalDonations,
        }, SetOptions(merge: true));
      }
      
      return totalDonations;
    } catch (e) {
      print('Lifetime donations hesaplama hatası: $e');
      return 0;
    }
  }

  /// Giriş streak'ini güncelle (her giriş yaparken çağrılmalı)
  Future<void> updateLoginStreak() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final lastLoginTimestamp = data['last_login_date'] as Timestamp?;
      final lastLoginDate = lastLoginTimestamp?.toDate();
      
      int currentStreak = data['current_streak'] ?? 0;
      int longestStreak = data['longest_streak'] ?? 0;
      
      if (lastLoginDate != null) {
        final lastLogin = DateTime(lastLoginDate.year, lastLoginDate.month, lastLoginDate.day);
        final difference = today.difference(lastLogin).inDays;
        
        if (difference == 0) {
          // Bugün zaten giriş yapmış, streak değişmez
          return;
        } else if (difference == 1) {
          // Dün giriş yapmış, streak devam
          currentStreak += 1;
        } else {
          // Streak kırıldı, sıfırdan başla
          currentStreak = 1;
        }
      } else {
        // İlk giriş
        currentStreak = 1;
      }
      
      // En uzun streak güncelle
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
      
      // Firestore güncelle (set with merge kullan - yeni alanlar için)
      await _firestore.collection('users').doc(uid).set({
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_login_date': Timestamp.fromDate(today),
      }, SetOptions(merge: true));
      
      // Yeni rozet kazanıldı mı kontrol et
      await checkAndAwardActivityBadges(uid, currentStreak);
      
      print('Login streak güncellendi: $currentStreak gün');
    } catch (e) {
      print('Login streak güncelleme hatası: $e');
    }
  }

  /// Toplam adım sayısını güncelle (her adım dönüştürmede çağrılmalı)
  Future<void> updateLifetimeSteps(int stepsToAdd) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Atomic increment kullan
      await _firestore.collection('users').doc(uid).update({
        'lifetime_total_steps': FieldValue.increment(stepsToAdd),
      });
      
      // Güncel değeri al ve rozet kontrol et
      final doc = await _firestore.collection('users').doc(uid).get();
      final totalSteps = doc.data()?['lifetime_total_steps'] ?? 0;
      
      await checkAndAwardStepBadges(uid, totalSteps);
      
      print('Lifetime adım güncellendi: $totalSteps');
    } catch (e) {
      print('Lifetime adım güncelleme hatası: $e');
    }
  }

  /// Toplam bağış miktarını güncelle (her bağışta çağrılmalı)
  Future<void> updateLifetimeDonations(double amountToAdd) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Önce mevcut değeri al
      final doc = await _firestore.collection('users').doc(uid).get();
      final currentDonations = (doc.data()?['lifetime_total_donations'] ?? 0).toDouble();
      final newTotal = currentDonations + amountToAdd;
      
      // Set ile güncelle (alan yoksa oluşturur)
      await _firestore.collection('users').doc(uid).set({
        'lifetime_total_donations': newTotal,
      }, SetOptions(merge: true));
      
      await checkAndAwardDonationBadges(uid, newTotal);
      
      print('Lifetime bağış güncellendi: $newTotal Hope');
    } catch (e) {
      print('Lifetime bağış güncelleme hatası: $e');
    }
  }

  /// Kullanıcının kazandığı rozetleri al
  Future<List<UserBadge>> getUserBadges(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('badges')
          .orderBy('earned_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => 
        UserBadge.fromFirestore(doc.data())
      ).toList();
    } catch (e) {
      print('Rozet alma hatası: $e');
      return [];
    }
  }

  /// Kullanıcının kazandığı rozet ID'lerini al
  Future<Set<String>> getUserBadgeIds(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('badges')
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      print('Rozet ID alma hatası: $e');
      return {};
    }
  }

  /// Rozet kazandır
  Future<bool> awardBadge(String uid, String badgeId) async {
    try {
      // Zaten kazanılmış mı kontrol et
      final existingBadge = await _firestore
          .collection('users')
          .doc(uid)
          .collection('badges')
          .doc(badgeId)
          .get();
      
      if (existingBadge.exists) {
        return false; // Zaten var
      }
      
      // Rozet kazandır
      final userBadge = UserBadge(
        badgeId: badgeId,
        earnedAt: DateTime.now(),
        isNew: true,
      );
      
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('badges')
          .doc(badgeId)
          .set(userBadge.toFirestore());
      
      // Bildirim gönder (dialog Dashboard'da gösterilecek)
      final badgeDef = BadgeDefinitions.getBadgeById(badgeId);
      if (badgeDef != null) {
        // Push notification
        final notificationService = LocalNotificationService();
        await notificationService.showAchievementNotification(
          'Yeni Rozet Kazandın! ${badgeDef.icon}',
          _getBadgeNameTr(badgeId),
        );
      }
      
      print('Rozet kazanıldı: $badgeId');
      return true;
    } catch (e) {
      print('Rozet kazandırma hatası: $e');
      return false;
    }
  }
  
  /// Rozet kazanıldığında dialog göster (public - Dashboard'dan çağrılacak)
  void showBadgeEarnedDialog(BadgeDefinition badge) {
    // navigatorKey üzerinden context al
    final navigatorState = navigatorKey?.currentState;
    if (navigatorState == null) {
      print('Navigator state null, dialog gösterilemiyor');
      return;
    }
    
    final context = navigatorState.overlay?.context;
    if (context == null) {
      print('Context null, dialog gösterilemiyor');
      return;
    }
    
    // Görsel paylaşımı için GlobalKey
    final GlobalKey shareImageKey = GlobalKey();
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Paylaşılacak görsel alanı
            RepaintBoundary(
              key: shareImageKey,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rozet ikonu
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(badge.gradientStart),
                            Color(badge.gradientEnd),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(badge.gradientStart).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          badge.icon,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Kullanıcı adı
                    Text(
                      _auth.currentUser?.displayName ?? 'Kullanıcı',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (ctx) {
                        final isTurkish = ctx.read<LanguageProvider>().isTurkish;
                        return Text(
                          isTurkish ? '🎉 Yeni Rozet Kazandı! 🎉' : '🎉 New Badge Earned! 🎉',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (ctx) {
                        final isTurkish = ctx.read<LanguageProvider>().isTurkish;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(badge.gradientStart).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isTurkish ? _getBadgeNameTr(badge.id) : _getBadgeNameEn(badge.id),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(badge.gradientStart),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (ctx) {
                        final isTurkish = ctx.read<LanguageProvider>().isTurkish;
                        return Text(
                          isTurkish ? 'Bir Adım Umut' : 'OneHopeStep',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          Column(
            children: [
              // Paylaş butonu
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildShareButton(
                    icon: FontAwesomeIcons.whatsapp,
                    color: const Color(0xFF25D366),
                    onTap: () async {
                      final imageData = await SocialShareService().captureWidget(shareImageKey);
                      await SocialShareService().shareToWhatsApp(imageData: imageData);
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildShareButton(
                    icon: FontAwesomeIcons.instagram,
                    color: const Color(0xFFE4405F),
                    onTap: () async {
                      final imageData = await SocialShareService().captureWidget(shareImageKey);
                      await SocialShareService().shareToInstagram(imageData: imageData);
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildShareButton(
                    icon: FontAwesomeIcons.facebookF,
                    color: const Color(0xFF1877F2),
                    onTap: () async {
                      final imageData = await SocialShareService().captureWidget(shareImageKey);
                      await SocialShareService().shareToFacebook(imageData: imageData);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Harika butonu
              Builder(
                builder: (ctx) {
                  final isTurkish = ctx.read<LanguageProvider>().isTurkish;
                  return ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(badge.gradientStart),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(isTurkish ? 'Harika!' : 'Awesome!', style: const TextStyle(fontSize: 16)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Paylaşım butonu oluştur
  Widget _buildShareButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: FaIcon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  /// Rozet "new" işaretini kaldır
  Future<void> markBadgeAsSeen(String uid, String badgeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('badges')
          .doc(badgeId)
          .update({'is_new': false});
    } catch (e) {
      print('Rozet işaretleme hatası: $e');
    }
  }
  
  /// Yeni kazanılmış rozetleri al (is_new: true olanlar)
  Future<List<BadgeDefinition>> getNewBadges(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('badges')
          .where('is_new', isEqualTo: true)
          .get();
      
      final newBadges = <BadgeDefinition>[];
      for (final doc in snapshot.docs) {
        final badgeId = doc.id;
        final badgeDef = BadgeDefinitions.getBadgeById(badgeId);
        if (badgeDef != null) {
          newBadges.add(badgeDef);
        }
      }
      return newBadges;
    } catch (e) {
      print('Yeni rozetleri alma hatası: $e');
      return [];
    }
  }

  /// Tüm "new" rozetleri işaretle
  Future<void> markAllBadgesAsSeen(String uid) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('badges')
          .where('is_new', isEqualTo: true)
          .get();
      
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'is_new': false});
      }
      
      await batch.commit();
    } catch (e) {
      print('Toplu rozet işaretleme hatası: $e');
    }
  }

  // ==================== ROZET KONTROL FONKSİYONLARI ====================

  /// Adım rozetlerini kontrol et ve kazandır
  Future<void> checkAndAwardStepBadges(String uid, int totalSteps) async {
    final earnedBadgeIds = await getUserBadgeIds(uid);
    
    for (final badge in BadgeDefinitions.stepBadges) {
      if (!earnedBadgeIds.contains(badge.id) && totalSteps >= badge.requirement) {
        await awardBadge(uid, badge.id);
      }
    }
  }

  /// Bağış rozetlerini kontrol et ve kazandır
  Future<void> checkAndAwardDonationBadges(String uid, double totalDonations) async {
    final earnedBadgeIds = await getUserBadgeIds(uid);
    
    for (final badge in BadgeDefinitions.donationBadges) {
      if (!earnedBadgeIds.contains(badge.id) && totalDonations >= badge.requirement) {
        await awardBadge(uid, badge.id);
      }
    }
  }

  /// Aktivite/Streak rozetlerini kontrol et ve kazandır
  Future<void> checkAndAwardActivityBadges(String uid, int currentStreak) async {
    final earnedBadgeIds = await getUserBadgeIds(uid);
    
    for (final badge in BadgeDefinitions.activityBadges) {
      if (!earnedBadgeIds.contains(badge.id) && currentStreak >= badge.requirement) {
        await awardBadge(uid, badge.id);
      }
    }
  }

  /// Tüm rozetleri kontrol et (uygulama açılışında)
  Future<void> checkAllBadges() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final stats = await getLifetimeStats(uid);
      
      await checkAndAwardStepBadges(uid, stats['lifetime_total_steps'] as int);
      await checkAndAwardDonationBadges(uid, stats['lifetime_total_donations'] as double);
      await checkAndAwardActivityBadges(uid, stats['current_streak'] as int);
      
      print('Tüm rozetler kontrol edildi');
    } catch (e) {
      print('Rozet kontrolü hatası: $e');
    }
  }

  /// Kategoriye göre ilerleme hesapla
  Future<Map<String, dynamic>> getCategoryProgress(String uid, BadgeCategory category) async {
    final stats = await getLifetimeStats(uid);
    final earnedBadgeIds = await getUserBadgeIds(uid);
    final badges = BadgeDefinitions.getBadgesByCategory(category);
    
    int currentValue;
    switch (category) {
      case BadgeCategory.steps:
        currentValue = stats['lifetime_total_steps'] as int;
        break;
      case BadgeCategory.donation:
        currentValue = (stats['lifetime_total_donations'] as double).toInt();
        break;
      case BadgeCategory.activity:
        currentValue = stats['longest_streak'] as int;
        break;
    }
    
    int earnedCount = 0;
    BadgeDefinition? nextBadge;
    
    for (final badge in badges) {
      if (earnedBadgeIds.contains(badge.id)) {
        earnedCount++;
      } else if (nextBadge == null) {
        nextBadge = badge;
      }
    }
    
    double progressToNext = 0;
    if (nextBadge != null) {
      progressToNext = (currentValue / nextBadge.requirement).clamp(0.0, 1.0);
    }
    
    return {
      'currentValue': currentValue,
      'earnedCount': earnedCount,
      'totalCount': badges.length,
      'nextBadge': nextBadge,
      'progressToNext': progressToNext,
    };
  }

  // ==================== YARDIMCI FONKSİYONLAR ====================

  /// Rozet adını Türkçe olarak al
  String _getBadgeNameTr(String badgeId) {
    final names = {
      // Adım rozetleri
      'steps_1k': 'İlk Adım',
      'steps_10k': 'Yürüyüşçü',
      'steps_100k': 'Gezgin',
      'steps_1m': 'Koşucu',
      'steps_10m': 'Maraton',
      'steps_100m': 'Usta',
      'steps_1b': 'Efsane',
      // Bağış rozetleri
      'donation_1': 'Umut Tohumu',
      'donation_10': 'Yardımsever',
      'donation_100': 'Cömert Kalp',
      'donation_1k': 'Umut Elçisi',
      'donation_10k': 'Umut Kahramanı',
      'donation_100k': 'Umut Savaşçısı',
      'donation_1m': 'Umut Tanrısı',
      // Aktivite rozetleri
      'streak_first': 'Hoş Geldin',
      'streak_3': 'Kararlı',
      'streak_7': 'Sadık',
      'streak_30': 'Alışkanlık Ustası',
      'streak_90': 'Vazgeçmeyen',
      'streak_180': 'Adanmış',
      'streak_365': 'Efsanevi Bağlılık',
    };
    return names[badgeId] ?? badgeId;
  }

  /// Rozet adını İngilizce olarak al
  String _getBadgeNameEn(String badgeId) {
    final names = {
      // Step badges
      'steps_1k': 'First Step',
      'steps_10k': 'Walker',
      'steps_100k': 'Explorer',
      'steps_1m': 'Runner',
      'steps_10m': 'Marathon',
      'steps_100m': 'Master',
      'steps_1b': 'Legend',
      // Donation badges
      'donation_1': 'Hope Seed',
      'donation_10': 'Philanthropist',
      'donation_100': 'Generous Heart',
      'donation_1k': 'Hope Ambassador',
      'donation_10k': 'Hope Hero',
      'donation_100k': 'Hope Warrior',
      'donation_1m': 'Hope Legend',
      // Activity badges
      'streak_first': 'Welcome',
      'streak_3': 'Determined',
      'streak_7': 'Loyal',
      'streak_30': 'Habit Master',
      'streak_90': 'Persistent',
      'streak_180': 'Devoted',
      'streak_365': 'Legendary Commitment',
    };
    return names[badgeId] ?? badgeId;
  }

  /// Rozet açıklamasını Türkçe olarak al
  static String getBadgeDescriptionTr(String badgeId) {
    final descriptions = {
      // Adım rozetleri
      'steps_1k': 'Toplamda 1.000 adım dönüştürdün!',
      'steps_10k': 'Toplamda 10.000 adım dönüştürdün!',
      'steps_100k': 'Toplamda 100.000 adım dönüştürdün!',
      'steps_1m': 'Toplamda 1 milyon adım dönüştürdün! Muhteşem!',
      'steps_10m': 'Toplamda 10 milyon adım dönüştürdün! Efsane!',
      'steps_100m': 'Toplamda 100 milyon adım! İnanılmaz!',
      'steps_1b': '1 milyar adım! Sen bir efsanesin!',
      // Bağış rozetleri
      'donation_1': 'İlk 1 Hope bağışını yaptın!',
      'donation_10': 'Toplamda 10 Hope bağışladın!',
      'donation_100': 'Toplamda 100 Hope bağışladın!',
      'donation_1k': 'Toplamda 1.000 Hope bağışladın!',
      'donation_10k': 'Toplamda 10.000 Hope bağışladın!',
      'donation_100k': 'Toplamda 100.000 Hope bağışladın!',
      'donation_1m': '1 milyon Hope bağışı! Kalbin çok güzel!',
      // Aktivite rozetleri
      'streak_first': 'İlk kez uygulamaya giriş yaptın!',
      'streak_3': '3 gün üst üste giriş yaptın!',
      'streak_7': '1 hafta boyunca her gün giriş yaptın!',
      'streak_30': '1 ay boyunca her gün giriş yaptın!',
      'streak_90': '3 ay boyunca her gün giriş yaptın!',
      'streak_180': '6 ay boyunca her gün giriş yaptın!',
      'streak_365': '1 yıl boyunca her gün giriş yaptın! Efsane!',
    };
    return descriptions[badgeId] ?? '';
  }

  /// Rozet açıklamasını İngilizce olarak al
  static String getBadgeDescriptionEn(String badgeId) {
    final descriptions = {
      // Step badges
      'steps_1k': 'You converted 1,000 steps in total!',
      'steps_10k': 'You converted 10,000 steps in total!',
      'steps_100k': 'You converted 100,000 steps in total!',
      'steps_1m': 'You converted 1 million steps! Amazing!',
      'steps_10m': 'You converted 10 million steps! Legendary!',
      'steps_100m': '100 million steps in total! Incredible!',
      'steps_1b': '1 billion steps! You are a legend!',
      // Donation badges
      'donation_1': 'You made your first 1 Hope donation!',
      'donation_10': 'You donated 10 Hope in total!',
      'donation_100': 'You donated 100 Hope in total!',
      'donation_1k': 'You donated 1,000 Hope in total!',
      'donation_10k': 'You donated 10,000 Hope in total!',
      'donation_100k': 'You donated 100,000 Hope in total!',
      'donation_1m': '1 million Hope donated! Your heart is beautiful!',
      // Activity badges
      'streak_first': 'You logged in to the app for the first time!',
      'streak_3': 'You logged in for 3 consecutive days!',
      'streak_7': 'You logged in every day for 1 week!',
      'streak_30': 'You logged in every day for 1 month!',
      'streak_90': 'You logged in every day for 3 months!',
      'streak_180': 'You logged in every day for 6 months!',
      'streak_365': 'You logged in every day for 1 year! Legend!',
    };
    return descriptions[badgeId] ?? '';
  }

  /// Rozet adını Türkçe olarak al (static)
  static String getBadgeNameTr(String badgeId) {
    final names = {
      // Adım rozetleri
      'steps_1k': '1.000 Adım',
      'steps_10k': '10.000 Adım',
      'steps_100k': '100.000 Adım',
      'steps_1m': '1 Milyon Adım',
      'steps_10m': '10 Milyon Adım',
      'steps_100m': '100 Milyon Adım',
      'steps_1b': '1 Milyar Adım',
      // Bağış rozetleri
      'donation_1': '1 Hope',
      'donation_10': '10 Hope',
      'donation_100': '100 Hope',
      'donation_1k': '1.000 Hope',
      'donation_10k': '10.000 Hope',
      'donation_100k': '100.000 Hope',
      'donation_1m': '1 Milyon Hope',
      // Aktivite rozetleri
      'streak_first': 'İlk Giriş',
      'streak_3': '3 Gün Seri',
      'streak_7': '7 Gün Seri',
      'streak_30': '30 Gün Seri',
      'streak_90': '90 Gün Seri',
      'streak_180': '180 Gün Seri',
      'streak_365': '365 Gün Seri',
    };
    return names[badgeId] ?? badgeId;
  }

  /// Sayıyı formatla (1000 -> 1K, 1000000 -> 1M)
  static String formatNumber(int number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(0)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(0)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toString();
  }
}
