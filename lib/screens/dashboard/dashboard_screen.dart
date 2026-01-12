import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/step_conversion_service.dart';
import '../../services/step_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/badge_service.dart';
import '../../services/interstitial_ad_service.dart';
import '../../models/user_model.dart';
import '../../providers/language_provider.dart';
import '../../widgets/hope_liquid_progress.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/success_dialog.dart';
import '../charity/charity_screen.dart';
import '../teams/teams_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';

/// Ana Dashboard Ekranı - Hope Sıvı Dolum Progress ile
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final StepConversionService _stepService = StepConversionService();
  final StepService _healthStepService = StepService();
  
  UserModel? _currentUser;
  bool _isLoading = true;
  int _selectedIndex = 0;
  int _conversionTabIndex = 0; // 0: Günlük, 1: Taşınan
  // ignore: unused_field
  bool _isUsingSimulatedData = true; // Health API simüle mi?

  // Adım verileri
  int _dailySteps = 0;
  int _convertedSteps = 0;
  int _remainingSteps = 0;
  int _carryOverSteps = 0; // Taşınan adımlar (sadece carryover_pending)
  int _bonusSteps = 0; // Referral bonus adımları (ayrı)
  int _leaderboardBonusSteps = 0; // Sıralama ödülü bonus adımları
  static const int _maxConvertPerTime = 2500;

  // Cooldown
  // ignore: unused_field
  bool _canConvert = true;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  // Haftalık veri
  List<int> _weeklySteps = [0, 0, 0, 0, 0, 0, 0];
  List<int> _weeklyConvertedSteps = [0, 0, 0, 0, 0, 0, 0];

  // 🔄 Real-time Firestore Streams
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _dailyStepsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Lifecycle observer ekle
    _loadAllData();
    _setupRealtimeListeners(); // Real-time dinleyicileri başlat
    // Dashboard açıldığında yeni rozetleri kontrol et (delay ile)
    _checkNewBadges(withDelay: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Lifecycle observer kaldır
    _cooldownTimer?.cancel();
    _userSubscription?.cancel(); // User stream'i iptal et
    _dailyStepsSubscription?.cancel(); // DailySteps stream'i iptal et
    super.dispose();
  }

  /// 🔄 Firestore real-time dinleyicileri kur
  void _setupRealtimeListeners() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // User dokümanını dinle (Hope bakiyesi, carryover vs.)
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          // UserModel güncelle
          _currentUser = UserModel.fromMap(data, uid);
          // Carryover ve bonus değerlerini güncelle
          _carryOverSteps = (data['carryover_pending'] ?? 0) as int;
          _bonusSteps = (data['referral_bonus_pending'] ?? 0) as int;
          _leaderboardBonusSteps = (data['leaderboard_bonus_pending'] ?? 0) as int;
        });
      }
    }, onError: (e) {
      debugPrint('User stream error: $e');
    });

    // Bugünün adım verilerini dinle
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    _dailyStepsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_steps')
        .doc(todayKey)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final dailySteps = (data['daily_steps'] ?? 0) as int;
        final convertedSteps = (data['converted_steps'] ?? 0) as int;
        setState(() {
          _dailySteps = dailySteps;
          _convertedSteps = convertedSteps > dailySteps ? dailySteps : convertedSteps;
          _remainingSteps = _dailySteps - _convertedSteps;
          if (_remainingSteps < 0) _remainingSteps = 0;
        });
      }
    }, onError: (e) {
      debugPrint('DailySteps stream error: $e');
    });
  }

  /// Uygulama arka plandan döndüğünde otomatik yenile
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Uygulama ön plana geldiğinde verileri yenile
      debugPrint('📱 App resumed - refreshing data...');
      _loadAllData();
    }
  }

  /// Yeni kazanılmış rozetleri kontrol et ve dialog göster
  Future<void> _checkNewBadges({bool withDelay = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    // İlk açılışta UI hazır olana kadar bekle
    if (withDelay) {
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    
    final badgeService = BadgeService();
    final newBadges = await badgeService.getNewBadges(uid);
    
    if (newBadges.isEmpty) return;
    
    // Her yeni rozet için sırayla dialog göster
    for (int i = 0; i < newBadges.length; i++) {
      final badge = newBadges[i];
      if (!mounted) return;
      
      // Dialog'un kapanmasını bekle
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _buildBadgeDialog(dialogContext, badge),
      );
      
      await badgeService.markBadgeAsSeen(uid, badge.id);
      
      // Birden fazla rozet varsa aralarında kısa bekleme
      if (i < newBadges.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }
  
  /// Rozet kazanıldı dialog'u
  Widget _buildBadgeDialog(BuildContext dialogContext, dynamic badge) {
    final lang = context.read<LanguageProvider>();
    final badgeName = lang.isTurkish ? _getBadgeNameTr(badge.id) : _getBadgeNameEn(badge.id);
    final badgeDescription = lang.isTurkish ? _getBadgeDescriptionTr(badge.id) : _getBadgeDescriptionEn(badge.id);
    final congratsMessage = lang.isTurkish ? _getBadgeCongratulationMessage(badge.id) : _getBadgeCongratulationMessageEn(badge.id);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Rozet görseli (PNG)
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(badge.gradientStart).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: badge.imagePath != null
                ? Image.asset(
                    badge.imagePath!,
                    fit: BoxFit.contain,
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(badge.gradientStart), Color(badge.gradientEnd)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(badge.icon, style: const TextStyle(fontSize: 45)),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Color(badge.gradientStart), Color(badge.gradientEnd)],
            ).createShader(bounds),
            child: Text(
              lang.isTurkish ? 'Tebrikler!' : 'Congratulations!',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Rozet ismi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(badge.gradientStart).withOpacity(0.15),
                  Color(badge.gradientEnd).withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Color(badge.gradientStart).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  lang.isTurkish ? '$badgeName Rozetiniz Açıldı!' : '$badgeName Badge Unlocked!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(badge.gradientStart),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badgeDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tebrik mesajı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              congratsMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Center(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(badge.gradientStart), Color(badge.gradientEnd)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lang.isTurkish ? 'Harika! ' : 'Awesome! ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Image.asset('assets/icons/yonca.png', width: 20, height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// Rozet açıklaması (gereksinim)
  String _getBadgeDescriptionTr(String badgeId) {
    final descriptions = {
      // Adım Rozetleri
      'steps_10k': '10.000 Adım Dönüştürüldü',
      'steps_100k': '100.000 Adım Dönüştürüldü',
      'steps_1m': '1 Milyon Adım Dönüştürüldü',
      'steps_10m': '10 Milyon Adım Dönüştürüldü',
      'steps_100m': '100 Milyon Adım Dönüştürüldü',
      'steps_1b': '1 Milyar Adım Dönüştürüldü',
      // Bağış Rozetleri
      'donation_10': '10 Hope Bağışlandı',
      'donation_100': '100 Hope Bağışlandı',
      'donation_1k': '1.000 Hope Bağışlandı',
      'donation_10k': '10.000 Hope Bağışlandı',
      'donation_100k': '100.000 Hope Bağışlandı',
      'donation_1m': '1 Milyon Hope Bağışlandı',
      // Aktivite Rozetleri
      'streak_first': 'İlk Giriş Yapıldı',
      'streak_7': '7 Gün Seri',
      'streak_30': '30 Gün Seri',
      'streak_90': '90 Gün Seri',
      'streak_180': '180 Gün Seri',
      'streak_365': '365 Gün Seri',
    };
    return descriptions[badgeId] ?? badgeId;
  }
  
  /// Tebrik mesajı
  String _getBadgeCongratulationMessage(String badgeId) {
    final messages = {
      // Adım Rozetleri
      'steps_10k': 'İlk adımını attın! 10.000 adım harika bir başarı! 👟',
      'steps_100k': 'Yürüyüşçü unvanını hak ettin! Adımların umuda dönüşüyor! 🚶',
      'steps_1m': 'Gezgin oldun! 1 milyon adım inanılmaz bir başarı! 🗺️',
      'steps_10m': 'Koşucu seviyesine ulaştın! Azmin örnek olsun! 🏃',
      'steps_100m': 'Maraton unvanı senin! 100 milyon adım efsanevi! 🏅',
      'steps_1b': 'Efsane oldun! 1 milyar adım... Sen bir kahramansın! 🌟',
      // Bağış Rozetleri
      'donation_10': 'İlk umut tohumunu ektin! 10 Hope ile başladın! 🌱',
      'donation_100': 'Yardımsever kalbinle 100 Hope bağışladın! Teşekkürler! 💚',
      'donation_1k': 'Cömert kalbin parlıyor! 1.000 Hope ile umut oldun! 💜',
      'donation_10k': 'Umut Elçisi unvanını kazandın! 10.000 Hope muhteşem! 🕊️',
      'donation_100k': 'Umut Kahramanısın! 100.000 Hope ile hayatlar değiştirdin! 🦸',
      'donation_1m': 'Umut Tanrısı! 1 milyon Hope... Sen bir efsanesin! 👑',
      // Aktivite Rozetleri
      'streak_first': 'Hoş geldin! İlk adımını attın, yolculuk başlıyor! 🎉',
      'streak_7': 'Kararlılığın ortaya çıkıyor! 7 gün üst üste, devam et! 💪',
      'streak_30': 'Sadık bir umut taşıyıcısısın! 30 günlük seri muhteşem! 🌟',
      'streak_90': 'Alışkanlık ustası oldun! 90 gün harika! 🔥',
      'streak_180': 'Adanmışlığın takdire değer! Yarım yıl boyunca buradaydın! 💎',
      'streak_365': 'Bağlılık şampiyonu! Tam bir yıl! Sen gerçek bir kahramansın! 👑',
    };
    return messages[badgeId] ?? 'Harika bir rozet kazandın!';
  }
  
  /// Rozet adını Türkçe olarak al
  String _getBadgeNameTr(String badgeId) {
    final names = {
      // Adım Rozetleri
      'steps_10k': 'İlk Adım',
      'steps_100k': 'Yürüyüşçü',
      'steps_1m': 'Gezgin',
      'steps_10m': 'Koşucu',
      'steps_100m': 'Maraton',
      'steps_1b': 'Efsane',
      // Bağış Rozetleri
      'donation_10': 'Umut Tohumu',
      'donation_100': 'Yardımsever',
      'donation_1k': 'Cömert Kalp',
      'donation_10k': 'Umut Elçisi',
      'donation_100k': 'Umut Kahramanı',
      'donation_1m': 'Umut Tanrısı',
      // Aktivite Rozetleri
      'streak_first': 'Hoşgeldin',
      'streak_7': 'Kararlı',
      'streak_30': 'Sadık',
      'streak_90': 'Alışkanlık',
      'streak_180': 'Adanmış',
      'streak_365': 'Bağlılık',
    };
    return names[badgeId] ?? badgeId;
  }

  /// Rozet adını İngilizce olarak al
  String _getBadgeNameEn(String badgeId) {
    final names = {
      // Step Badges
      'steps_10k': 'First Step',
      'steps_100k': 'Walker',
      'steps_1m': 'Explorer',
      'steps_10m': 'Runner',
      'steps_100m': 'Marathon',
      'steps_1b': 'Legend',
      // Donation Badges
      'donation_10': 'Hope Seed',
      'donation_100': 'Philanthropist',
      'donation_1k': 'Generous Heart',
      'donation_10k': 'Hope Ambassador',
      'donation_100k': 'Hope Hero',
      'donation_1m': 'Hope Legend',
      // Activity Badges
      'streak_first': 'Welcome',
      'streak_7': 'Determined',
      'streak_30': 'Loyal',
      'streak_90': 'Habitual',
      'streak_180': 'Devoted',
      'streak_365': 'Committed',
    };
    return names[badgeId] ?? badgeId;
  }

  /// Rozet açıklaması İngilizce
  String _getBadgeDescriptionEn(String badgeId) {
    final descriptions = {
      // Step Badges
      'steps_10k': '10,000 Steps Converted',
      'steps_100k': '100,000 Steps Converted',
      'steps_1m': '1 Million Steps Converted',
      'steps_10m': '10 Million Steps Converted',
      'steps_100m': '100 Million Steps Converted',
      'steps_1b': '1 Billion Steps Converted',
      // Donation Badges
      'donation_10': '10 Hope Donated',
      'donation_100': '100 Hope Donated',
      'donation_1k': '1,000 Hope Donated',
      'donation_10k': '10,000 Hope Donated',
      'donation_100k': '100,000 Hope Donated',
      'donation_1m': '1 Million Hope Donated',
      // Activity Badges
      'streak_first': 'First Login',
      'streak_7': '7 Day Streak',
      'streak_30': '30 Day Streak',
      'streak_90': '90 Day Streak',
      'streak_180': '180 Day Streak',
      'streak_365': '365 Day Streak',
    };
    return descriptions[badgeId] ?? badgeId;
  }

  /// Tebrik mesajı İngilizce
  String _getBadgeCongratulationMessageEn(String badgeId) {
    final messages = {
      // Step Badges
      'steps_10k': 'You took your first step! 10,000 steps is a great achievement! 👟',
      'steps_100k': 'You earned the Walker title! Your steps are turning into hope! 🚶',
      'steps_1m': 'You became an Explorer! 1 million steps is incredible! 🗺️',
      'steps_10m': 'You reached Runner level! Your perseverance is inspiring! 🏃',
      'steps_100m': 'Marathon title is yours! 100 million steps is legendary! 🏅',
      'steps_1b': 'You became a Legend! 1 billion steps... You are a hero! 🌟',
      // Donation Badges
      'donation_10': 'You planted the first seed of hope! Started with 10 Hope! 🌱',
      'donation_100': 'With your generous heart, you donated 100 Hope! Thank you! 💚',
      'donation_1k': 'Your generous heart shines! You became hope with 1,000 Hope! 💜',
      'donation_10k': 'You earned the Hope Ambassador title! 10,000 Hope is amazing! 🕊️',
      'donation_100k': 'You are a Hope Hero! Changed lives with 100,000 Hope! 🦸',
      'donation_1m': 'Hope Legend! 1 million Hope... You are a legend! 👑',
      // Activity Badges
      'streak_first': 'Welcome! You took your first step, the journey begins! 🎉',
      'streak_7': 'Your determination shows! 7 days in a row, keep going! 💪',
      'streak_30': 'You are a loyal hope carrier! 30 day streak is awesome! 🌟',
      'streak_90': 'You became a habit master! 90 days is amazing! 🔥',
      'streak_180': 'Your dedication is admirable! You were here for half a year! 💎',
      'streak_365': 'Commitment champion! A full year! You are a true hero! 👑',
    };
    return messages[badgeId] ?? 'You earned an amazing badge!';
  }

  /// Bildirim tetikleyicilerini kontrol et
  Future<void> _checkAndSendNotifications({
    required int dailySteps,
    required int remaining,
    required int carryOver,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final notificationService = LocalNotificationService();
    
    // 1. 2500 Adım Bonus Bildirimi (günde bir kez)
    final bonusKey = 'bonus_notification_$today';
    final bonusSent = prefs.getBool(bonusKey) ?? false;
    
    if (!bonusSent && remaining >= 2500) {
      await notificationService.showBonusReadyNotification();
      await prefs.setBool(bonusKey, true);
    }
    
    // 2. Ay Sonu Uyarısı (ayın son 3 gününde taşınan adımlar varsa)
    // Zamanlanmış bildirimler LocalNotificationService'de scheduleMonthEndWarnings() ile yapılıyor
    // Burada sadece taşınan adım varsa hatırlatma yapıyoruz
    if (carryOver > 0) {
      final warningKey = 'carryover_warning_$today';
      final warningSent = prefs.getBool(warningKey) ?? false;
      
      if (!warningSent && carryOver >= 1000) {
        // Eğer önemli miktarda taşınan adım varsa uyar
        await notificationService.showCarryOverReminder();
        await prefs.setBool(warningKey, true);
      }
    }
    
    // 3. Akşam Hatırlatması için unconverted steps kaydet
    await prefs.setInt('unconverted_steps', remaining + carryOver);
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadUserData(),
      _loadStepData(),
    ]);
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStepData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // 🏃 Health API'den güncel adımları al ve Firestore'a senkronize et
      final syncResult = await _healthStepService.syncTodayStepsToFirestore();
      
      // Eski adımları temizle ve bozuk veriyi düzelt
      await _stepService.cleanupExpiredSteps(uid);
      await _stepService.fixCorruptedData(uid);

      // StepConversionService'den veri al (dönüştürülmüş adımlar vs.)
      final stepData = await _stepService.getTodayStepData(uid);
      final weeklyData = await _stepService.getWeeklySteps(uid);
      final weeklyConvertedData = await _stepService.getWeeklyConvertedSteps(uid);
      final carryOver = await _stepService.getCarryOverSteps(uid);
      final bonusSteps = await _stepService.getReferralBonusSteps(uid);
      final leaderboardBonus = await _stepService.getLeaderboardBonusSteps(uid);
      
      // Health API'den gelen adımları kullan (daha güncel)
      final healthSteps = syncResult['success'] == true 
          ? syncResult['totalSteps'] ?? 0 
          : stepData['daily_steps'] ?? 0;
      final convertedSteps = stepData['converted_steps'] ?? 0;
      final remaining = healthSteps - convertedSteps;
      
      // ====== BİLDİRİM TETİKLEYİCİLERİ ======
      await _checkAndSendNotifications(
        dailySteps: healthSteps,
        remaining: remaining,
        carryOver: carryOver,
      );
      
      if (mounted) {
        setState(() {
          _dailySteps = healthSteps;
          _convertedSteps = convertedSteps;
          _isUsingSimulatedData = syncResult['isSimulated'] ?? true;
          
          // Ekstra güvenlik: converted hiçbir zaman daily'den büyük olamaz
          if (_convertedSteps > _dailySteps) {
            _convertedSteps = _dailySteps;
          }
          
          _remainingSteps = _dailySteps - _convertedSteps;
          if (_remainingSteps < 0) _remainingSteps = 0;
          _carryOverSteps = carryOver;
          _bonusSteps = bonusSteps;
          _leaderboardBonusSteps = leaderboardBonus;
          _weeklySteps = weeklyData;
          _weeklyConvertedSteps = weeklyConvertedData;
          
          // Cooldown DEVRE DIŞI - her zaman dönüştürme yapılabilir
          _canConvert = true;
        });
      }
    } catch (e) {
      print('Step data yükleme hatası: $e');
      // Hata durumunda sıfır değerler
      if (mounted) {
        setState(() {
          _dailySteps = 0;
          _convertedSteps = 0;
          _remainingSteps = 0;
          _carryOverSteps = 0;
          _bonusSteps = 0;
          _leaderboardBonusSteps = 0;
          _weeklySteps = [0, 0, 0, 0, 0, 0, 0];
          _weeklyConvertedSteps = [0, 0, 0, 0, 0, 0, 0];
        });
      }
    }
  }

  String _getGreeting(LanguageProvider lang) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return lang.goodMorning;
    } else if (hour < 18) {
      return lang.goodAfternoon;
    } else {
      return lang.goodEvening;
    }
  }

  void _startCooldown(int seconds) {
    setState(() {
      _canConvert = false;
      _cooldownSeconds = seconds > 0 ? seconds : 0;
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 0) {
        timer.cancel();
        setState(() => _canConvert = true);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Offline Banner (internet yoksa göster)
          const OfflineBanner(),
          // Ana içerik
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildHomeTab(),
                const CharityScreen(),
                const TeamsScreen(),
                const LeaderboardScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      // Kıvrımlı bottom app bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 8,
        color: Colors.white,
        child: Container(
          height: 70,
          padding: const EdgeInsets.only(left: 6, right: 6, top: 0, bottom: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItemWithImage(
                index: 1,
                imagePath: 'assets/icons/bagis.png',
                label: 'Bağış',
              ),
              _buildNavItemWithImage(
                index: 2,
                imagePath: 'assets/icons/takım.png',
                label: 'Takım',
              ),
              const SizedBox(width: 50),
              _buildNavItemWithImage(
                index: 3,
                imagePath: 'assets/icons/siralama.png',
                label: 'Sıralama',
              ),
              _buildNavItemWithImage(
                index: 4,
                imagePath: 'assets/icons/Profil.png',
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
      // FAB'ı ortada ve docked konumda
      floatingActionButton: _buildCenterNavItem(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        // Home tab'a dönüldüğünde rozet kontrolü yap
        if (index == 0) {
          _checkNewBadges();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [const Color(0xFF6EC6B5).withOpacity(0.2), const Color(0xFFE07A5F).withOpacity(0.2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6EC6B5).withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ShaderMask(
          shaderCallback: (bounds) => isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds)
              : LinearGradient(
                  colors: [Colors.grey.shade500, Colors.grey.shade500],
                ).createShader(bounds),
          child: Icon(
            isSelected ? selectedIcon : icon,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  /// PNG görsel ile alt bar butonu - Gradient çerçeveli + Label
  Widget _buildNavItemWithImage({
    required int index,
    required String imagePath,
    String? label,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        // Home tab'a dönüldüğünde rozet kontrolü yap
        if (index == 0) {
          _checkNewBadges();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE07A5F), Color(0xFF6EC6B5), Color(0xFFF2C94C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Image.asset(
                      imagePath,
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.error_outline,
                        color: Color(0xFFE07A5F),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 1),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFE07A5F), Color(0xFF6EC6B5), Color(0xFFF2C94C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE07A5F).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: FloatingActionButton(
              heroTag: 'fab_home',
              onPressed: () {
                setState(() => _selectedIndex = 0);
                // Home tab'a dönüldüğünde rozet kontrolü yap
                _checkNewBadges();
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              highlightElevation: 0,
              shape: const CircleBorder(),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/yenilogo.png',
                  width: 62,
                  height: 62,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    _selectedIndex == 0 ? Icons.home : Icons.home_outlined,
                    color: const Color(0xFFE07A5F),
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 16),
              _buildNestedProgressBar(),
              const SizedBox(height: 16),
              _buildUnifiedConversionCard(), // Birleşik dönüştürme paneli
              const SizedBox(height: 8),
              const BannerAdWidget(), // Reklam Alanı
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Sol taraf - Profil
        Row(
          children: [
            // Profil Fotoğrafı
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE8F7F5),
              backgroundImage: _currentUser?.profileImageUrl != null
                  ? NetworkImage(_currentUser!.profileImageUrl!)
                  : null,
              child: _currentUser?.profileImageUrl == null
                  ? Text(
                      _currentUser?.fullName.isNotEmpty == true
                          ? _currentUser!.fullName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6EC6B5),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer<LanguageProvider>(
                  builder: (context, lang, _) => Text(
                    lang.isTurkish ? 'Hoşgeldiniz' : 'Welcome',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                Consumer<LanguageProvider>(
                  builder: (context, lang, _) {
                    final name = _currentUser?.fullName ?? lang.user;
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          name.isNotEmpty ? name : lang.user,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // Sağ taraf - Hope Bakiyesi Butonu
        GestureDetector(
          onTap: () => setState(() => _selectedIndex = 1),
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.only(left: 12, right: 0, top: 0, bottom: 0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE07A5F).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentUser?.walletBalanceHope.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  child: Image.asset(
                    'assets/hp.png',
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHopeBalanceCard() {
    final lang = context.read<LanguageProvider>();
    return GestureDetector(
      onTap: () {
        // Bağış sayfasına git (index 1)
        setState(() => _selectedIndex = 1);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE07A5F).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.hopeBalanceTitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  // Bakiye ve H harfi tek buton gibi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_currentUser?.walletBalanceHope.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Image.asset(
                          'assets/icons/logoyeni.png',
                          width: 56,
                          height: 56,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentUser?.walletBalanceHope != null && _currentUser!.walletBalanceHope >= 5
                        ? lang.canBeHope
                        : lang.minHopeRequired,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Baloncuklu Progress Bar
  Widget _buildNestedProgressBar() {
    final lang = context.read<LanguageProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.isTurkish ? 'Günlük İlerleme' : 'Daily Progress',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_dailySteps ${lang.steps.toLowerCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // YENİ: Hope Sıvı Dolum Progress - Tıklanabilir Buton
          // Kalan adımlar (dailySteps - convertedSteps) / 2500 oranında doluyor
          // dailySteps sabit kalır (grafikte gösterilir)
          // convertedSteps artar (dönüştürülen toplam)
          // remainingSteps = dailySteps - convertedSteps (progress bar için)
          Center(
            child: Column(
              children: [
                HopeLiquidProgress(
                  progress: (_remainingSteps / 2500).clamp(0.0, 1.0),
                  width: 320,
                  height: 175, // 8800:4800 oranına uygun (1.83:1)
                  isActive: _remainingSteps >= 2500, // 2500 kalan adımda aktif
                  onTap: () => _showConvertDialog(),
                ),
                // 2x Bonus Badge - Her zaman görünür (kalıcı)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.95, end: 1.05),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: _remainingSteps >= 2500 ? value : 1.0,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _remainingSteps >= 2500 
                                ? [const Color(0xFFF2C94C), const Color(0xFFE07A5F)]
                                : [Colors.grey[400]!, Colors.grey[500]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _remainingSteps >= 2500 ? [
                            BoxShadow(
                              color: const Color(0xFFF2C94C).withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ] : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '2x ${lang.isTurkish ? 'BONUS' : 'BONUS'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Legend - Günlük Adım ve Dönüştürülen Adım
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(lang.isTurkish ? 'Günlük Adım' : 'Daily Steps', Colors.grey[400]!),
              const SizedBox(width: 24),
              _buildGradientLegendItem(lang.isTurkish ? 'Dönüştürülen Adım' : 'Converted Steps', const [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)]),
            ],
          ),
          
          // Taşınan adımlar yazısı kaldırıldı - artık conversion kartında gösteriliyor

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
      ],
    );
  }

  Widget _buildGradientLegendItem(String label, List<Color> colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
      ],
    );
  }

  /// Birleşik Adım Dönüştürme Paneli - Tab ile geçiş
  Widget _buildUnifiedConversionCard() {
    final lang = context.read<LanguageProvider>();
    
    // Günlük adım verileri
    double dailyHope = _remainingSteps / 100.0;
    bool hasDailySteps = _remainingSteps > 0;
    
    // Taşınan adım verileri
    double carryOverHope = _carryOverSteps / 100.0;
    bool hasCarryOverSteps = _carryOverSteps > 0;
    
    // Bonus adım verileri (Referral + Leaderboard)
    int totalBonusSteps = _bonusSteps + _leaderboardBonusSteps;
    double bonusHope = totalBonusSteps / 100.0;
    bool hasBonusSteps = totalBonusSteps > 0;

    // Mini haftalık grafik için
    int maxValue = _weeklySteps.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) maxValue = 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6EC6B5), Color(0xFFF2C94C), Color(0xFFE07A5F)],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6EC6B5).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 4'lü Tab Seçici (Günlük, Taşınan, Bonus, Grafik)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Günlük Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _conversionTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _conversionTabIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.today,
                            size: 14,
                            color: _conversionTabIndex == 0 ? const Color(0xFFF2C94C) : Colors.white,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lang.isTurkish ? 'Günlük' : 'Daily',
                            style: TextStyle(
                              color: _conversionTabIndex == 0 ? const Color(0xFFF2C94C) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Taşınan Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _conversionTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _conversionTabIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history,
                            size: 14,
                            color: _conversionTabIndex == 1 ? const Color(0xFFE07A5F) : Colors.white,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lang.isTurkish ? 'Taşınan' : 'Carried',
                            style: TextStyle(
                              color: _conversionTabIndex == 1 ? const Color(0xFFE07A5F) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bonus Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _conversionTabIndex = 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _conversionTabIndex == 2 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            size: 14,
                            color: _conversionTabIndex == 2 ? const Color(0xFF9B59B6) : Colors.white,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bonus',
                            style: TextStyle(
                              color: _conversionTabIndex == 2 ? const Color(0xFF9B59B6) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Grafik Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _conversionTabIndex = 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _conversionTabIndex == 3 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 14,
                            color: _conversionTabIndex == 3 ? const Color(0xFF6EC6B5) : Colors.white,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lang.isTurkish ? 'Grafik' : 'Graph',
                            style: TextStyle(
                              color: _conversionTabIndex == 3 ? const Color(0xFF6EC6B5) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // İçerik
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _conversionTabIndex == 0
                ? _buildDailyContent(lang, dailyHope, hasDailySteps)
                : _conversionTabIndex == 1
                    ? _buildCarryOverContent(lang, carryOverHope, hasCarryOverSteps)
                    : _conversionTabIndex == 2
                        ? _buildBonusContent(lang, bonusHope, hasBonusSteps)
                        : _buildWeeklyContent(lang, maxValue),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyContent(LanguageProvider lang, int maxValue) {
    final days = lang.isTurkish 
        ? ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final totalSteps = _weeklySteps.reduce((a, b) => a + b);
    
    return Column(
      key: const ValueKey('weekly'),
      children: [
        // Toplam bilgisi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.isTurkish ? 'Toplam Haftalık' : 'Total Weekly',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '$totalSteps ${lang.isTurkish ? 'adım' : 'steps'}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Dalgalı Grafik with Y-axis labels
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Sol taraf - Y ekseni değerleri
            SizedBox(
              width: 35,
              height: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    maxValue > 999 ? '${(maxValue / 1000).toStringAsFixed(0)}k' : '$maxValue',
                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                  Text(
                    maxValue > 999 ? '${(maxValue / 2000).toStringAsFixed(0)}k' : '${(maxValue / 2).toInt()}',
                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                  const Text(
                    '0',
                    style: TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Grafik
            Expanded(
              child: SizedBox(
                height: 80,
                child: CustomPaint(
                  size: const Size(double.infinity, 80),
                  painter: _WaveChartPainter(
                    data: _weeklySteps.map((e) => e.toDouble()).toList(),
                    convertedData: _weeklyConvertedSteps.map((e) => e.toDouble()).toList(),
                    maxValue: maxValue.toDouble(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Gün isimleri
        Padding(
          padding: const EdgeInsets.only(left: 43),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isToday = index == 6;
              return Text(
                days[index],
                style: TextStyle(
                  color: isToday ? Colors.white : Colors.white70,
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyContent(LanguageProvider lang, double hope, bool hasSteps) {
    return Column(
      key: const ValueKey('daily'),
      children: [
        // Bilgi kutuları
        Row(
          children: [
            Expanded(
              child: _buildInfoBoxWithImage(
                lang.isTurkish ? 'Dönüştürülebilir' : 'Convertible', 
                '$_remainingSteps', 
                lang.isTurkish ? 'adım' : 'steps', 
                'assets/badges/adimm.png',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoBoxWithImage(
                lang.isTurkish ? 'Kazanılacak' : 'Will Earn', 
                hope.toStringAsFixed(0), 
                'Hope', 
                'assets/hp.png',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Geçerlilik bilgisi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                lang.isTurkish 
                    ? '23:59\'a kadar geçerli' 
                    : 'Valid until 23:59',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Dönüştür butonu
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: hasSteps ? _showDailyConvertDialog : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: hasSteps ? const Color(0xFF6EC6B5) : Colors.grey[400],
              disabledBackgroundColor: Colors.white.withOpacity(0.7),
              disabledForegroundColor: Colors.grey[400],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/icons/adim.png', width: 28, height: 28),
                const SizedBox(width: 10),
                Text(
                  hasSteps 
                      ? (lang.isTurkish ? 'Dönüştür' : 'Convert')
                      : (lang.isTurkish ? 'Günlük Adım Yok' : 'No Daily Steps'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarryOverContent(LanguageProvider lang, double hope, bool hasSteps) {
    return Column(
      key: const ValueKey('carryover'),
      children: [
        // Bilgi kutuları
        Row(
          children: [
            Expanded(
              child: _buildInfoBoxWithImage(
                lang.isTurkish ? 'Taşınan' : 'Carried', 
                '$_carryOverSteps', 
                lang.isTurkish ? 'adım' : 'steps', 
                'assets/badges/adimm.png',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoBoxWithImage(
                lang.isTurkish ? 'Kazanılacak' : 'Will Earn', 
                hope.toStringAsFixed(0), 
                'Hope', 
                'assets/hp.png',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Geçerlilik bilgisi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_month, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                lang.isTurkish 
                    ? 'Ay sonuna kadar geçerli' 
                    : 'Valid until end of month',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Dönüştür butonu
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: hasSteps ? _showCarryOverConvertDialog : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: hasSteps ? const Color(0xFFE07A5F) : Colors.grey[400],
              disabledBackgroundColor: Colors.white.withOpacity(0.7),
              disabledForegroundColor: Colors.grey[400],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/icons/adim.png', width: 28, height: 28),
                const SizedBox(width: 10),
                Text(
                  hasSteps 
                      ? (lang.isTurkish ? 'Dönüştür' : 'Convert')
                      : (lang.isTurkish ? 'Taşınan Adım Yok' : 'No Carried Steps'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// Bonus (Referral + Leaderboard) adımları içeriği
  Widget _buildBonusContent(LanguageProvider lang, double hope, bool hasSteps) {
    final totalBonusSteps = _bonusSteps + _leaderboardBonusSteps;
    
    return Column(
      key: const ValueKey('bonus'),
      children: [
        // Bilgi kutuları - Günlük ve Taşınan ile aynı formatta
        Row(
          children: [
            // Bonus Adım
            Expanded(
              child: _buildInfoBoxWithImage(
                lang.isTurkish ? 'Bonus Adım' : 'Bonus Steps', 
                '$totalBonusSteps', 
                'adım',
                'assets/badges/adimm.png',
              ),
            ),
            const SizedBox(width: 8),
            // Kazanılacak Hope
            Expanded(
              child: _buildInfoBoxWithImage(
                lang.isTurkish ? 'Kazanılacak' : 'Earnable', 
                hope.toStringAsFixed(0), 
                'Hope', 
                'assets/hp.png',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Açıklama
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.all_inclusive, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                lang.isTurkish 
                    ? 'Süresiz geçerli' 
                    : 'Never expires',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Dönüştür butonu
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: hasSteps ? _showBonusConvertDialog : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: hasSteps ? const Color(0xFF6EC6B5) : Colors.grey[400],
              disabledBackgroundColor: Colors.white.withOpacity(0.7),
              disabledForegroundColor: Colors.grey[400],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/icons/adim.png', width: 28, height: 28),
                const SizedBox(width: 10),
                Text(
                  hasSteps 
                      ? (lang.isTurkish ? 'Dönüştür' : 'Convert')
                      : (lang.isTurkish ? 'Bonus Adım Yok' : 'No Bonus Steps'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// Bonus info box (icon ile)
  Widget _buildBonusInfoBox(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBoxWithImage(String title, String value, String unit, String imagePath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Image.asset(imagePath, width: 24, height: 24),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final lang = context.read<LanguageProvider>();
    final days = lang.isTurkish 
        ? ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    int maxValue = _weeklySteps.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) maxValue = 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.weeklyProgress,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '${lang.isTurkish ? 'Toplam' : 'Total'}: ${_weeklySteps.reduce((a, b) => a + b)} ${lang.steps.toLowerCase()}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegend(lang.isTurkish ? 'Atılan' : 'Steps', const Color(0xFFE07A5F)),
              const SizedBox(width: 16),
              _buildChartLegend(lang.isTurkish ? 'Dönüştürülen' : 'Converted', const Color(0xFF6EC6B5)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter: _LineChartPainter(
                data: _weeklySteps,
                convertedData: _weeklyConvertedSteps,
                maxValue: maxValue,
                days: days,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
      ],
    );
  }

  String _formatCooldown(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => NotificationSheet(scrollController: scrollController),
      ),
    );
  }

  /// Progress bar tıklandığında dönüştürme dialog'u göster (2x BONUS!) - Turuncu-Sarı tema
  void _showConvertDialog() {
    final lang = context.read<LanguageProvider>();
    int convertAmount = 2500; // Sabit 2500 adım
    double hopeEarned = 50.0; // 2x BONUS: 2500 adım = 50 Hope (normalde 25)
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFE8F7F5), const Color(0xFFFFF0ED), const Color(0xFFFFF9E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar - turuncu-sarı gradient
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // 2x Bonus Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE07A5F).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    lang.isTurkish ? '2x BONUS AKTİF!' : '2x BONUS ACTIVE!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.bolt, color: Colors.white, size: 24),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Başlık - Turuncu gradient text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE07A5F).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                    ).createShader(bounds),
                    child: Text(
                      lang.isTurkish ? 'Bonus Dönüştür' : 'Bonus Convert',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Bilgi kartları
            Row(
              children: [
                Expanded(
                  child: _buildConvertInfoCardWithImage(
                    imagePath: 'assets/badges/adimm.png',
                    title: lang.isTurkish ? 'Adım' : 'Steps',
                    value: '$convertAmount',
                    color: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildConvertInfoCardWithImage(
                    imagePath: 'assets/hp.png',
                    title: 'Hope',
                    value: hopeEarned.toStringAsFixed(0),
                    color: const Color(0xFFF2C94C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Normal oran karşılaştırması - Yeni tema
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6EC6B5).withOpacity(0.15), const Color(0xFFE07A5F).withOpacity(0.15), const Color(0xFFF2C94C).withOpacity(0.15)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up, color: const Color(0xFFE07A5F), size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      lang.isTurkish 
                          ? 'Normal: 25 → Bonus: 50 Hope (+25!)'
                          : 'Normal: 25 → Bonus: 50 Hope (+25!)',
                      style: TextStyle(
                        color: const Color(0xFFE07A5F),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Reklam bilgisi - Yeni tema
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6EC6B5).withOpacity(0.2), const Color(0xFFE07A5F).withOpacity(0.15), const Color(0xFFF2C94C).withOpacity(0.2)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.isTurkish 
                          ? 'Dönüştürmek için kısa bir reklam izlemeniz gerekiyor'
                          : 'You need to watch a short ad to convert',
                      style: TextStyle(
                        color: const Color(0xFFE07A5F),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Butonlar - Yeni gradient
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE07A5F)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      lang.isTurkish ? 'İptal' : 'Cancel',
                      style: const TextStyle(color: Color(0xFFE07A5F)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE07A5F).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _handleProgressConversion();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              lang.isTurkish ? 'Reklam İzle & Dönüştür' : 'Watch Ad & Convert',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Günlük adımları dönüştür dialog'u (Normal rate) - Turkuaz-Turuncu-Sarı tema
  void _showDailyConvertDialog() {
    final lang = context.read<LanguageProvider>();
    // Normal rate: 100 adım = 1 Hope
    int convertAmount = _remainingSteps > _maxConvertPerTime ? _maxConvertPerTime : _remainingSteps;
    double hopeEarned = convertAmount / 100.0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFE8F7F5), const Color(0xFFFFF0ED), const Color(0xFFFFF9E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar - Turkuaz-Turuncu-Sarı gradient
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Başlık - Turkuaz-Turuncu-Sarı tema
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE07A5F).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/icons/adim.png', width: 28, height: 28),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                    ).createShader(bounds),
                    child: Text(
                      lang.isTurkish ? 'Günlük Adımları Dönüştür' : 'Convert Daily Steps',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Rate bilgisi - Turkuaz-Turuncu gradient
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6EC6B5).withOpacity(0.15), const Color(0xFFE07A5F).withOpacity(0.15)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFE07A5F), size: 18),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
                    ).createShader(bounds),
                    child: Text(
                      lang.isTurkish 
                          ? 'Oran: 100 adım = 1 Hope'
                          : 'Rate: 100 steps = 1 Hope',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Bilgi kartları
            Row(
              children: [
                Expanded(
                  child: _buildConvertInfoCardWithImage(
                    imagePath: 'assets/badges/adimm.png',
                    title: lang.isTurkish ? 'Adım' : 'Steps',
                    value: '$convertAmount',
                    color: const Color(0xFF6EC6B5),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildConvertInfoCardWithImage(
                    imagePath: 'assets/hp.png',
                    title: 'Hope',
                    value: hopeEarned.toStringAsFixed(0),
                    color: const Color(0xFFE07A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Reklam bilgisi - Turkuaz-Turuncu tema
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6EC6B5).withOpacity(0.15), const Color(0xFFE07A5F).withOpacity(0.15)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.isTurkish 
                          ? 'Dönüştürmek için kısa bir reklam izlemeniz gerekiyor'
                          : 'You need to watch a short ad to convert',
                      style: const TextStyle(
                        color: Color(0xFFE07A5F),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Butonlar - Turkuaz-Turuncu-Sarı gradient
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE07A5F)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      lang.isTurkish ? 'İptal' : 'Cancel',
                      style: const TextStyle(color: Color(0xFFE07A5F)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE07A5F).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _handleConversion();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              lang.isTurkish ? 'Reklam İzle & Dönüştür' : 'Watch Ad & Convert',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Taşınan adımları dönüştür dialog'u - Turkuaz-Turuncu-Sarı tema
  void _showCarryOverConvertDialog() {
    final lang = context.read<LanguageProvider>();
    // Normal rate: 100 adım = 1 Hope
    int convertAmount = _carryOverSteps > _maxConvertPerTime ? _maxConvertPerTime : _carryOverSteps;
    double hopeEarned = convertAmount / 100.0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFE8F7F5), const Color(0xFFFFF0ED), const Color(0xFFFFF9E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar - Turkuaz-Turuncu-Sarı gradient
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Başlık - Turkuaz-Turuncu-Sarı tema
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE07A5F).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/icons/adim.png', width: 28, height: 28),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                    ).createShader(bounds),
                    child: Text(
                      lang.isTurkish ? 'Taşınan Adımları Dönüştür' : 'Convert Carried Steps',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Rate bilgisi - Turkuaz-Turuncu tema
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6EC6B5).withOpacity(0.15), const Color(0xFFE07A5F).withOpacity(0.15)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE07A5F).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFE07A5F), size: 18),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
                    ).createShader(bounds),
                    child: Text(
                      lang.isTurkish 
                          ? 'Oran: 100 adım = 1 Hope'
                          : 'Rate: 100 steps = 1 Hope',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Bilgi kartları - Carryover
            Row(
              children: [
                Expanded(
                  child: _buildConvertInfoCardWithImage(
                    imagePath: 'assets/badges/adimm.png',
                    title: lang.isTurkish ? 'Adım' : 'Steps',
                    value: '$convertAmount',
                    color: const Color(0xFF6EC6B5),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildConvertInfoCardWithImage(
                    imagePath: 'assets/hp.png',
                    title: 'Hope',
                    value: hopeEarned.toStringAsFixed(0),
                    color: const Color(0xFFE07A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Reklam bilgisi - Turkuaz-Turuncu tema
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6EC6B5).withOpacity(0.15), const Color(0xFFE07A5F).withOpacity(0.15)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.isTurkish 
                          ? 'Dönüştürmek için kısa bir reklam izlemeniz gerekiyor'
                          : 'You need to watch a short ad to convert',
                      style: const TextStyle(
                        color: Color(0xFFE07A5F),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Butonlar - Turkuaz-Turuncu-Sarı gradient
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE07A5F)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      lang.isTurkish ? 'İptal' : 'Cancel',
                      style: const TextStyle(color: Color(0xFFE07A5F)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE07A5F).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _handleCarryOverConversion();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              lang.isTurkish ? 'Reklam İzle & Dönüştür' : 'Watch Ad & Convert',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConvertInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConvertInfoCardWithImage({
    required String imagePath,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Image.asset(imagePath, width: 28, height: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Progress bar'dan dönüştürme işlemi (2x BONUS!)
  Future<void> _handleProgressConversion() async {
    // Gerçek Interstitial reklam göster
    await InterstitialAdService.instance.showAd(
      context: 'step_conversion_2x',
      onAdComplete: () async {
        int convertAmount = 2500; // Sabit 2500 adım
        // 2x BONUS: 100 adım = 1 Hope, 2500 adım = 25 Hope → 2x = 50 Hope
        double hopeEarned = 50.0; // 2x bonus: 50 Hope

        // Firestore'a kaydet
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final result = await _stepService.convertSteps(
            userId: uid,
            steps: convertAmount,
            hopeEarned: hopeEarned,
            isBonus: true, // 2x BONUS dönüşümü
          );

          // Device fraud kontrolü
          if (result['success'] == false && result['error'] == 'device_already_used') {
            if (mounted) {
              _showDeviceFraudError();
            }
            return;
          }
        }

        setState(() {
          // dailySteps SABİT KALIR (grafikte gösterilir)
          // sadece convertedSteps artar
          _convertedSteps += convertAmount;
          _remainingSteps = _dailySteps - _convertedSteps;
          if (_remainingSteps < 0) _remainingSteps = 0;
        });

        // Kullanıcı bakiyesini güncelle
        await _loadUserData();

        // Önce kutlama dialog'u göster (kullanıcı kapatana kadar bekle)
        if (mounted) {
          await _showCelebrationDialog(hopeEarned, isBonus: true);
        }
        
        // Sonra rozet kontrolü yap
        if (mounted) {
          await _checkNewBadges();
        }
      },
    );
  }

  /// Günlük adımları dönüştür (Normal rate: 100 adım = 1 Hope)
  Future<void> _handleConversion() async {
    // Gerçek Interstitial reklam göster
    await InterstitialAdService.instance.showAd(
      context: 'step_conversion',
      onAdComplete: () async {
        int convertAmount = _remainingSteps > _maxConvertPerTime 
            ? _maxConvertPerTime 
            : _remainingSteps;
        // Normal rate: 100 adım = 1 Hope
        double hopeEarned = convertAmount / 100.0;

        // Firestore'a kaydet
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final result = await _stepService.convertSteps(
            userId: uid,
            steps: convertAmount,
            hopeEarned: hopeEarned,
          );

          // Device fraud kontrolü
          if (result['success'] == false && result['error'] == 'device_already_used') {
            if (mounted) {
              _showDeviceFraudError();
            }
            return;
          }
        }

        setState(() {
          _convertedSteps += convertAmount;
          _remainingSteps = _dailySteps - _convertedSteps;
        });

        // 10 dakika cooldown başlat
        _startCooldown(600);

        // Kullanıcı bakiyesini güncelle
        await _loadUserData();

        // Önce kutlama dialog'u göster (kullanıcı kapatana kadar bekle)
        if (mounted) {
          await _showCelebrationDialog(hopeEarned, isBonus: false);
        }
        
        // Sonra rozet kontrolü yap
        if (mounted) {
          await _checkNewBadges();
        }
      },
    );
  }

  /// Taşınan adımları dönüştür (Normal rate: 100 adım = 1 Hope)
  Future<void> _handleCarryOverConversion() async {
    if (_carryOverSteps <= 0) return;

    // Gerçek Interstitial reklam göster
    await InterstitialAdService.instance.showAd(
      context: 'carryover_conversion',
      onAdComplete: () async {
        int convertAmount = _carryOverSteps > _maxConvertPerTime 
            ? _maxConvertPerTime 
            : _carryOverSteps;
        // Normal rate: 100 adım = 1 Hope (2500 adım = 25 Hope)
        double hopeEarned = convertAmount / 100.0;

        // Firestore'a kaydet
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final result = await _stepService.convertCarryOverSteps(
            userId: uid,
            steps: convertAmount,
            hopeEarned: hopeEarned,
          );

          // Device fraud kontrolü
          if (result['success'] == false && result['error'] == 'device_already_used') {
            if (mounted) {
              _showDeviceFraudError();
            }
            return;
          }
        }

        setState(() {
          _carryOverSteps -= convertAmount;
        });

        // Kullanıcı bakiyesini güncelle
        await _loadUserData();

        // Önce kutlama dialog'u göster (kullanıcı kapatana kadar bekle)
        if (mounted) {
          await _showCelebrationDialog(hopeEarned, isBonus: false, isCarryOver: true);
        }
        
        // Sonra rozet kontrolü yap
        if (mounted) {
          await _checkNewBadges();
        }
      },
    );
  }
  
  /// Bonus adımları dönüştürme dialog'u (Referral + Leaderboard)
  void _showBonusConvertDialog() {
    final lang = context.read<LanguageProvider>();
    final totalBonusSteps = _bonusSteps + _leaderboardBonusSteps;
    int convertAmount = totalBonusSteps > _maxConvertPerTime ? _maxConvertPerTime : totalBonusSteps;
    double hopeEarned = convertAmount / 100.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6EC6B5).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Başlık - Turkuaz tema
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6EC6B5),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6EC6B5).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/badges/adimm.png', width: 28, height: 28),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    lang.isTurkish ? 'Bonus Adımları Dönüştür' : 'Convert Bonus Steps',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6EC6B5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Süresiz geçerli bilgisi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6EC6B5).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6EC6B5).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.all_inclusive, color: Color(0xFF6EC6B5), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    lang.isTurkish 
                        ? 'Süresiz geçerli!'
                        : 'Never expires!',
                    style: const TextStyle(
                      color: Color(0xFF6EC6B5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Bilgi kartları - Bonus
            Row(
              children: [
                Expanded(
                  child: _buildConvertInfoCardWithImage(
                    imagePath: 'assets/badges/adimm.png',
                    title: lang.isTurkish ? 'Bonus Adım' : 'Bonus Steps',
                    value: '$convertAmount',
                    color: const Color(0xFF6EC6B5),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildConvertInfoCardWithImage(
                    imagePath: 'assets/hp.png',
                    title: 'Hope',
                    value: hopeEarned.toStringAsFixed(0),
                    color: const Color(0xFF6EC6B5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Reklam bilgisi - Turkuaz tema
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6EC6B5).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6EC6B5).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6EC6B5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.isTurkish 
                          ? 'Dönüştürmek için kısa bir reklam izlemeniz gerekiyor'
                          : 'You need to watch a short ad to convert',
                      style: const TextStyle(
                        color: Color(0xFF6EC6B5),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Butonlar - Turkuaz
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF6EC6B5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      lang.isTurkish ? 'İptal' : 'Cancel',
                      style: const TextStyle(color: Color(0xFF6EC6B5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF6EC6B5),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6EC6B5).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _handleBonusConversion();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              lang.isTurkish ? 'İzle & Dönüştür' : 'Watch & Convert',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  /// Bonus adımları dönüştürme işlemi (Referral + Leaderboard)
  Future<void> _handleBonusConversion() async {
    final totalBonusSteps = _bonusSteps + _leaderboardBonusSteps;
    if (totalBonusSteps <= 0) return;
    
    await InterstitialAdService.instance.showAd(
      context: 'bonus_conversion',
      onAdComplete: () async {
        int convertAmount = totalBonusSteps > _maxConvertPerTime 
            ? _maxConvertPerTime 
            : totalBonusSteps;
        double hopeEarned = convertAmount / 100.0;

        // Firestore'a kaydet
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          int remainingToConvert = convertAmount;
          
          // Önce referral bonuslarından dönüştür
          if (_bonusSteps > 0 && remainingToConvert > 0) {
            int fromReferral = _bonusSteps >= remainingToConvert ? remainingToConvert : _bonusSteps;
            double referralHope = fromReferral / 100.0;
            
            final result = await _stepService.convertBonusSteps(
              userId: uid,
              steps: fromReferral,
              hopeEarned: referralHope,
            );

            // Device fraud kontrolü
            if (result['success'] == false && result['error'] == 'device_already_used') {
              if (mounted) {
                _showDeviceFraudError();
              }
              return;
            }
            
            if (result['success'] == true) {
              _bonusSteps -= fromReferral;
              remainingToConvert -= fromReferral;
            }
          }
          
          // Kalan varsa leaderboard bonusundan dönüştür
          if (_leaderboardBonusSteps > 0 && remainingToConvert > 0) {
            int fromLeaderboard = _leaderboardBonusSteps >= remainingToConvert ? remainingToConvert : _leaderboardBonusSteps;
            double leaderboardHope = fromLeaderboard / 100.0;
            
            final result = await _stepService.convertLeaderboardBonusSteps(
              userId: uid,
              steps: fromLeaderboard,
              hopeEarned: leaderboardHope,
            );

            // Device fraud kontrolü
            if (result['success'] == false && result['error'] == 'device_already_used') {
              if (mounted) {
                _showDeviceFraudError();
              }
              return;
            }
            
            if (result['success'] == true) {
              _leaderboardBonusSteps -= fromLeaderboard;
              remainingToConvert -= fromLeaderboard;
            }
          }
        }

        // Kullanıcı bakiyesini güncelle
        await _loadUserData();

        // Önce kutlama dialog'u göster
        if (mounted) {
          await _showCelebrationDialog(hopeEarned, isBonus: false, isCarryOver: false);
        }
        
        // Sonra rozet kontrolü yap
        if (mounted) {
          await _checkNewBadges();
        }
      },
    );
  }

  /// Device fraud hatası göster
  void _showDeviceFraudError() {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
        title: Text(
          lang.deviceFraudWarningTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          lang.deviceAlreadyUsedError,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.ok),
          ),
        ],
      ),
    );
  }

  /// Kutlama Dialog'u - Her kaynak için özel tema + Konfeti
  Future<void> _showCelebrationDialog(double hopeEarned, {bool isBonus = false, bool isCarryOver = false}) async {
    final lang = context.read<LanguageProvider>();
    
    // Renk temasını belirle
    List<Color> gradientColors;
    List<Color> bgGradientColors;
    Color shadowColor;
    
    if (isBonus) {
      // 2x Bonus: Turkuaz-Turuncu-Sarı tema
      gradientColors = [const Color(0xFFF2C94C), const Color(0xFFE07A5F), const Color(0xFF6EC6B5)];
      bgGradientColors = [const Color(0xFFFFF9E6), const Color(0xFFFFF0ED), const Color(0xFFE8F7F5)];
      shadowColor = const Color(0xFFE07A5F);
    } else if (isCarryOver) {
      // Taşınan Adım: Turkuaz-Turuncu tema
      gradientColors = [const Color(0xFF6EC6B5), const Color(0xFFE07A5F)];
      bgGradientColors = [const Color(0xFFE8F7F5), const Color(0xFFFFF0ED)];
      shadowColor = const Color(0xFFE07A5F);
    } else {
      // Günlük Adım: Turkuaz-Turuncu-Sarı tema
      gradientColors = [const Color(0xFF6EC6B5), const Color(0xFFE07A5F), const Color(0xFFF2C94C)];
      bgGradientColors = [const Color(0xFFE8F7F5), const Color(0xFFFFF0ED), const Color(0xFFFFF9E6)];
      shadowColor = const Color(0xFF6EC6B5);
    }
    
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Sol konfeti
            Positioned(
              left: -50,
              top: 0,
              bottom: 0,
              child: ConfettiAnimation(isLeft: true),
            ),
            // Sağ konfeti
            Positioned(
              right: -50,
              top: 0,
              bottom: 0,
              child: ConfettiAnimation(isLeft: false),
            ),
            // Dialog içeriği
            Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bgGradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profil Resmi
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white,
                    backgroundImage: _currentUser?.profileImageUrl != null
                        ? NetworkImage(_currentUser!.profileImageUrl!)
                        : null,
                    child: _currentUser?.profileImageUrl == null
                        ? Text(
                            _currentUser?.fullName.isNotEmpty == true
                                ? _currentUser!.fullName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: gradientColors.first,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Tebrikler yazısı - Tüm temalar için gradient text
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: isBonus 
                      ? [const Color(0xFFF2C94C), const Color(0xFFE07A5F), const Color(0xFF6EC6B5)]
                      : isCarryOver 
                          ? [const Color(0xFF6EC6B5), const Color(0xFFE07A5F), const Color(0xFFF2C94C)]
                          : [const Color(0xFF6EC6B5), const Color(0xFFE07A5F), const Color(0xFFF2C94C)],
                ).createShader(bounds),
                child: Text(
                  lang.isTurkish ? 'Tebrikler!' : 'Congratulations!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Kullanıcı Adı
              Text(
                _currentUser?.fullName ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              
              // Kazanılan Hope
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/hp.png', width: 32, height: 32),
                    const SizedBox(width: 12),
                    Text(
                      '+${hopeEarned.toStringAsFixed(0)} Hope',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Bonus veya normal bilgisi
              if (isBonus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF6EC6B5).withOpacity(0.2), const Color(0xFFE07A5F).withOpacity(0.2), const Color(0xFFF2C94C).withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: Color(0xFFE07A5F), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '2x BONUS!',
                        style: TextStyle(
                          color: const Color(0xFFE07A5F),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Devam butonu - Tüm temalar için gradient buton
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          lang.isTurkish ? 'Muhteşem!' : 'Awesome!',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('🎉', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}

/// Bildirim Sheet
class NotificationSheet extends StatelessWidget {
  final ScrollController scrollController;
  
  const NotificationSheet({Key? key, required this.scrollController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bildirimler',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('receiver_uid', isEqualTo: uid)
                  .where('status', isEqualTo: 'pending')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('Bildirim yok', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    return NotificationItem(
                      notificationId: doc.id,
                      teamId: data['sender_team_id'] ?? '',
                      teamName: data['team_name'] ?? 'Takım',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationItem extends StatelessWidget {
  final String notificationId;
  final String teamId;
  final String teamName;

  const NotificationItem({
    Key? key,
    required this.notificationId,
    required this.teamId,
    required this.teamName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6EC6B5).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.group_add, color: const Color(0xFF6EC6B5), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Takım Daveti',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '"$teamName" takımından davet aldınız!',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleReject(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reddet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleAccept(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Kabul Et'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccept(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      // 1. Bildirimi güncelle
      batch.update(
        firestore.collection('notifications').doc(notificationId),
        {'status': 'accepted'},
      );

      // 2. Kullanıcıyı takıma ekle
      batch.set(
        firestore.collection('teams').doc(teamId).collection('team_members').doc(uid),
        {
          'team_id': teamId,
          'user_id': uid,
          'join_date': Timestamp.now(),
          'member_status': 'active',
          'member_total_hope': 0.0,
          'member_daily_steps': 0,
        },
      );

      // 3. User'ı güncelle
      batch.update(
        firestore.collection('users').doc(uid),
        {'current_team_id': teamId},
      );

      // 4. Team members_count güncelle
      batch.update(
        firestore.collection('teams').doc(teamId),
        {
          'members_count': FieldValue.increment(1),
          'member_ids': FieldValue.arrayUnion([uid]),
        },
      );

      await batch.commit();

      if (context.mounted) {
        final lang = context.read<LanguageProvider>();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.teamJoinedMsg),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.errorMsg(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'status': 'rejected'});

    if (context.mounted) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.inviteRejected)),
      );
    }
  }
}

/// Reklam Simülasyonu Dialog
class AdSimulationDialog extends StatefulWidget {
  const AdSimulationDialog({Key? key}) : super(key: key);

  @override
  State<AdSimulationDialog> createState() => _AdSimulationDialogState();
}

class _AdSimulationDialogState extends State<AdSimulationDialog> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        Navigator.pop(context, true);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.adTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_countdown',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_outline, size: 64, color: Colors.grey[500]),
                    const SizedBox(height: 8),
                    Text(
                      lang.adArea,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang.adIntegration,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: (5 - _countdown) / 5,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(const Color(0xFFE07A5F)),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text(
              lang.adClosingIn(_countdown),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Çizgi grafik çizen CustomPainter
class _LineChartPainter extends CustomPainter {
  final List<int> data;
  final List<int> convertedData;
  final int maxValue;
  final List<String> days;

  _LineChartPainter({
    required this.data,
    required this.convertedData,
    required this.maxValue,
    required this.days,
  });

  // Dinamik Y ekseni değerlerini hesapla
  List<int> _calculateYAxisValues(int maxVal) {
    if (maxVal <= 1000) return [0, 250, 500, 750, 1000];
    if (maxVal <= 2500) return [0, 500, 1000, 1500, 2500];
    if (maxVal <= 5000) return [0, 1000, 2500, 3500, 5000];
    if (maxVal <= 10000) return [0, 2500, 5000, 7500, 10000];
    if (maxVal <= 15000) return [0, 5000, 10000, 12500, 15000];
    if (maxVal <= 20000) return [0, 5000, 10000, 15000, 20000];
    if (maxVal <= 30000) return [0, 10000, 15000, 20000, 30000];
    return [0, 10000, 20000, 30000, 40000];
  }

  String _formatNumber(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return value.toString();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Gradient için shader kullanacağız
    final gradientPaint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final gridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Y ekseni için sol boşluk
    const leftPadding = 40.0;
    final chartHeight = size.height - 50;
    final chartWidth = size.width - leftPadding - 10;
    final stepX = chartWidth / 6;
    final startX = leftPadding;

    // Y ekseni değerlerini hesapla
    final yAxisValues = _calculateYAxisValues(maxValue);
    final actualMax = yAxisValues.last;

    // Gradient dolgu
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6EC6B5).withOpacity(0.3),
          const Color(0xFFE07A5F).withOpacity(0.1),
          const Color(0xFFF2C94C).withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(leftPadding, 0, chartWidth, chartHeight));

    // Yatay grid çizgileri ve Y ekseni değerleri
    for (int i = 0; i < yAxisValues.length; i++) {
      final y = chartHeight * (1 - yAxisValues[i] / actualMax);
      
      // Grid çizgisi
      canvas.drawLine(
        Offset(startX, y),
        Offset(size.width - 10, y),
        gridPaint,
      );

      // Y ekseni değeri
      textPainter.text = TextSpan(
        text: _formatNumber(yAxisValues[i]),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 9,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding - textPainter.width - 6, y - 6));
    }

    // Veri noktalarını hesapla
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = startX + i * stepX;
      final y = chartHeight * (1 - data[i] / actualMax);
      points.add(Offset(x, y.clamp(0, chartHeight)));
    }

    // Bezier curve ile yumuşak dolgu alanı
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, chartHeight);
    fillPath.lineTo(points.first.dx, points.first.dy);
    
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      fillPath.cubicTo(controlX1, p0.dy, controlX2, p1.dy, p1.dx, p1.dy);
    }
    
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Bezier curve ile yumuşak çizgi - Gradient
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      linePath.cubicTo(controlX1, p0.dy, controlX2, p1.dy, p1.dx, p1.dy);
    }
    
    // Çizgi için gradient shader
    gradientPaint.shader = const LinearGradient(
      colors: [Color(0xFFE07A5F), Color(0xFFF2C94C), Color(0xFF6EC6B5)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(Rect.fromLTWH(startX, 0, chartWidth, chartHeight));
    canvas.drawPath(linePath, gradientPaint);

    // === DÖNÜŞTÜRÜLEN ADIM ÇİZGİSİ ===
    // Converted veri noktalarını hesapla
    final convertedPoints = <Offset>[];
    for (int i = 0; i < convertedData.length; i++) {
      final x = startX + i * stepX;
      final y = chartHeight * (1 - convertedData[i] / actualMax);
      convertedPoints.add(Offset(x, y.clamp(0, chartHeight)));
    }

    // Dönüştürülen için soft renk çizgi
    final convertedLinePath = Path();
    convertedLinePath.moveTo(convertedPoints.first.dx, convertedPoints.first.dy);
    
    for (int i = 0; i < convertedPoints.length - 1; i++) {
      final p0 = convertedPoints[i];
      final p1 = convertedPoints[i + 1];
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      convertedLinePath.cubicTo(controlX1, p0.dy, controlX2, p1.dy, p1.dx, p1.dy);
    }
    
    // Yeşil-turkuaz gradient çizgi
    final convertedLinePaint = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: const [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFE07A5F)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(convertedLinePath, convertedLinePaint);

    // Dönüştürülen noktaları çiz (küçük) - gradient renklerde
    for (int i = 0; i < convertedPoints.length; i++) {
      final point = convertedPoints[i];
      final t = i / (convertedPoints.length - 1);
      final pointColor = Color.lerp(
        const Color(0xFF6EC6B5), // Yeşil
        const Color(0xFFE07A5F), // Turkuaz
        t,
      )!;
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
      canvas.drawCircle(point, 2, Paint()..color = pointColor);
    }

    // Noktaları çiz - Gradient renklerde (günlük adım)
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final isToday = i == 6;
      
      // Nokta rengi - pozisyona göre gradient
      final t = i / (points.length - 1);
      final pointColor = Color.lerp(
        const Color(0xFFE07A5F), // Mor
        const Color(0xFFF2C94C), // Pembe
        t,
      )!;
      
      // Beyaz border
      canvas.drawCircle(point, isToday ? 7 : 5, Paint()..color = Colors.white);
      // Renkli nokta
      canvas.drawCircle(point, isToday ? 5 : 3.5, 
        Paint()..color = isToday ? const Color(0xFFE07A5F) : pointColor);

      // Gün adı (altta)
      textPainter.text = TextSpan(
        text: days[i],
        style: TextStyle(
          color: isToday ? const Color(0xFFE07A5F) : Colors.grey[600],
          fontSize: 11,
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(point.dx - textPainter.width / 2, chartHeight + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.data != data || 
           oldDelegate.convertedData != convertedData || 
           oldDelegate.maxValue != maxValue;
  }
}

/// Mini dalgalı grafik painter (card içi için)
class _WaveChartPainter extends CustomPainter {
  final List<double> data;
  final List<double> convertedData;
  final double maxValue;

  _WaveChartPainter({required this.data, required this.convertedData, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue == 0) return;

    final segmentWidth = size.width / (data.length - 1);
    final chartHeight = size.height - 10;

    // Toplam adımlar için beyaz çizgi
    final mainPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mainFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Dönüştürülen adımlar için gradient çizgi (turuncu-turkuaz-sarı)
    final convertedGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0xFFE07A5F), // Turuncu
        Color(0xFF6EC6B5), // Turkuaz
        Color(0xFFF2C94C), // Sarı
      ],
    );

    final convertedFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE07A5F).withOpacity(0.25),
          const Color(0xFF6EC6B5).withOpacity(0.15),
          const Color(0xFFF2C94C).withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Ana veri noktalarını hesapla
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * segmentWidth;
      final normalizedValue = data[i] / maxValue;
      final y = chartHeight - (normalizedValue * (chartHeight - 10));
      points.add(Offset(x, y));
    }

    // Dönüştürülen veri noktalarını hesapla
    final convertedPoints = <Offset>[];
    for (int i = 0; i < convertedData.length; i++) {
      final x = i * segmentWidth;
      final normalizedValue = convertedData[i] / maxValue;
      final y = chartHeight - (normalizedValue * (chartHeight - 10));
      convertedPoints.add(Offset(x, y));
    }

    // Önce dönüştürülen çizgiyi çiz (altta kalacak)
    if (convertedPoints.isNotEmpty) {
      final convertedPath = Path();
      final convertedFillPath = Path();
      
      convertedPath.moveTo(convertedPoints[0].dx, convertedPoints[0].dy);
      convertedFillPath.moveTo(convertedPoints[0].dx, chartHeight);
      convertedFillPath.lineTo(convertedPoints[0].dx, convertedPoints[0].dy);

      for (int i = 0; i < convertedPoints.length - 1; i++) {
        final p0 = convertedPoints[i];
        final p1 = convertedPoints[i + 1];
        final controlX = (p0.dx + p1.dx) / 2;
        convertedPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
        convertedFillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }

      convertedFillPath.lineTo(convertedPoints.last.dx, chartHeight);
      convertedFillPath.close();

      // Gradient stroke paint
      final convertedPaint = Paint()
        ..shader = convertedGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(convertedFillPath, convertedFillPaint);
      canvas.drawPath(convertedPath, convertedPaint);
    }

    // Ana çizgiyi çiz (üstte kalacak)
    final path = Path();
    final fillPath = Path();
    
    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, chartHeight);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, mainFillPaint);
    canvas.drawPath(path, mainPaint);

    // Ana noktaları çiz (beyaz)
    for (int i = 0; i < points.length; i++) {
      final isToday = i == points.length - 1;
      canvas.drawCircle(points[i], isToday ? 5 : 3, Paint()..color = Colors.white);
      if (isToday) {
        canvas.drawCircle(
          points[i], 
          7, 
          Paint()
            ..color = Colors.white.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // Dönüştürülen noktaları çiz (gradient renkleri)
    for (int i = 0; i < convertedPoints.length; i++) {
      final isToday = i == convertedPoints.length - 1;
      final t = i / (convertedPoints.length - 1);
      Color pointColor;
      if (t < 0.5) {
        pointColor = Color.lerp(const Color(0xFFE07A5F), const Color(0xFF6EC6B5), t * 2)!;
      } else {
        pointColor = Color.lerp(const Color(0xFF6EC6B5), const Color(0xFFF2C94C), (t - 0.5) * 2)!;
      }
      canvas.drawCircle(convertedPoints[i], isToday ? 4 : 2.5, Paint()..color = pointColor);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveChartPainter oldDelegate) {
    return oldDelegate.data != data || 
           oldDelegate.convertedData != convertedData || 
           oldDelegate.maxValue != maxValue;
  }
}
