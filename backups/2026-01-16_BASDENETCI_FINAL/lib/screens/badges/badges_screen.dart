import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../models/badge_model.dart';
import '../../services/badge_service.dart';
import '../../providers/language_provider.dart';
import '../../widgets/banner_ad_widget.dart';

/// Rozetlerim Sayfası - 3 Kategorili Rozet Görüntüleme
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({Key? key}) : super(key: key);

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> with SingleTickerProviderStateMixin {
  final BadgeService _badgeService = BadgeService();
  late TabController _tabController;
  
  Set<String> _earnedBadgeIds = {};
  Map<String, dynamic> _lifetimeStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final earnedIds = await _badgeService.getUserBadgeIds(uid);
      final stats = await _badgeService.getLifetimeStats(uid);
      
      if (mounted) {
        setState(() {
          _earnedBadgeIds = earnedIds;
          _lifetimeStats = stats;
          _isLoading = false;
        });
      }
      
      // Tüm "new" rozetleri gördü olarak işaretle
      await _badgeService.markAllBadgesAsSeen(uid);
    } catch (e) {
      print('Rozet verisi yükleme hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lang.isTurkish ? 'Rozetlerim' : 'My Badges',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF2C94C),
          indicatorWeight: 3,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              icon: Image.asset('assets/badges/adimm.png', width: 36, height: 36),
              text: lang.isTurkish ? 'Adım' : 'Steps',
            ),
            Tab(
              icon: Image.asset('assets/badges/bagiss.png', width: 36, height: 36),
              text: lang.isTurkish ? 'Bağış' : 'Donation',
            ),
            Tab(
              icon: Image.asset('assets/badges/aktivite.png', width: 36, height: 36),
              text: lang.isTurkish ? 'Aktivite' : 'Activity',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBadgeGrid(BadgeCategory.steps),
                      _buildBadgeGrid(BadgeCategory.donation),
                      _buildBadgeGrid(BadgeCategory.activity),
                    ],
                  ),
                ),
                const SafeArea(
                  top: false,
                  child: BannerAdWidget(),
                ),
              ],
            ),
    );
  }

  Widget _buildBadgeGrid(BadgeCategory category) {
    final badges = BadgeDefinitions.getBadgesByCategory(category);
    final lang = context.watch<LanguageProvider>();
    
    // Kategori için mevcut değer
    int currentValue = 0;
    String valueLabel = '';
    
    switch (category) {
      case BadgeCategory.steps:
        currentValue = _lifetimeStats['lifetime_total_steps'] ?? 0;
        valueLabel = lang.isTurkish 
            ? 'Toplam Dönüştürülen: ${BadgeService.formatNumber(currentValue)} adım'
            : 'Total Converted: ${BadgeService.formatNumber(currentValue)} steps';
        break;
      case BadgeCategory.donation:
        currentValue = ((_lifetimeStats['lifetime_total_donations'] ?? 0) as double).toInt();
        valueLabel = lang.isTurkish 
            ? 'Toplam Bağış: ${BadgeService.formatNumber(currentValue)} Hope'
            : 'Total Donated: ${BadgeService.formatNumber(currentValue)} Hope';
        break;
      case BadgeCategory.activity:
        final currentStreak = _lifetimeStats['current_streak'] ?? 0;
        final longestStreak = _lifetimeStats['longest_streak'] ?? 0;
        currentValue = longestStreak;
        valueLabel = lang.isTurkish 
            ? 'Mevcut Seri: $currentStreak gün | En Uzun: $longestStreak gün'
            : 'Current Streak: $currentStreak days | Longest: $longestStreak days';
        break;
    }
    
    // Kazanılan rozet sayısı
    final earnedCount = badges.where((b) => _earnedBadgeIds.contains(b.id)).length;
    
    return Column(
      children: [
        // Kategori İstatistik Kartı
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF2C94C).withOpacity(0.1),
                const Color(0xFFE07A5F).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF2C94C).withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    valueLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2C94C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$earnedCount/${badges.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // İlerleme çubuğu
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: earnedCount / badges.length,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF2C94C)),
                ),
              ),
            ],
          ),
        ),
        
        // Rozet Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final badge = badges[index];
              final isEarned = _earnedBadgeIds.contains(badge.id);
              
              return _buildBadgeItem(badge, isEarned, currentValue);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeItem(BadgeDefinition badge, bool isEarned, int currentValue) {
    final progress = isEarned ? 1.0 : (currentValue / badge.requirement).clamp(0.0, 1.0);
    final lang = context.watch<LanguageProvider>();
    
    // Rozet ismi ve açıklaması
    final badgeName = _getBadgeName(badge.id, isTurkish: lang.isTurkish);
    final badgeDescription = _getBadgeDescription(badge.id, isTurkish: lang.isTurkish);
    
    return GestureDetector(
      onTap: () => _showBadgeDetail(badge, isEarned, progress),
      child: Column(
        children: [
          // Rozet görseli (sıvı doluluk efekti ile)
          Expanded(
            flex: 3,
            child: _buildLiquidBadge(badge, progress, isEarned),
          ),
          const SizedBox(height: 4),
          // Rozet ismi ve hedefi
          Text(
            badgeName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isEarned ? Color(badge.gradientStart) : Colors.grey[700],
            ),
          ),
          Text(
            badgeDescription,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: isEarned ? Color(badge.gradientEnd) : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Sıvı doluluk efekti ile rozet görseli
  /// Alt katman: Orijinal renkli PNG
  /// Üst katman: Gri PNG (progress'e göre dalgalı şekilde üstten kırpılır)
  Widget _buildLiquidBadge(BadgeDefinition badge, double progress, bool isEarned) {
    // Eğer imagePath varsa PNG kullan, yoksa emoji
    if (badge.imagePath != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          // Alt katman: Orijinal renkli PNG (her zaman görünür)
          Image.asset(
            badge.imagePath!,
            fit: BoxFit.contain,
          ),
          // Üst katman: Gri PNG (progress'e göre dalgalı şekilde üstten kırpılır)
          // %100 ise gri katman yok, %0 ise tamamen gri
          if (progress < 1.0)
            _WavyGrayOverlay(
              imagePath: badge.imagePath!,
              progress: progress,
            ),
        ],
      );
    } else {
      // Legacy emoji rozeti
      return Container(
        decoration: BoxDecoration(
          color: isEarned ? null : Colors.grey[200],
          gradient: isEarned
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(badge.gradientStart),
                    Color(badge.gradientEnd),
                  ],
                )
              : null,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            badge.icon,
            style: TextStyle(
              fontSize: 32,
              color: isEarned ? null : Colors.grey,
            ),
          ),
        ),
      );
    }
  }
  
  /// Rozet ismi (kısa başlık)
  String _getBadgeName(String badgeId, {bool isTurkish = true}) {
    final namesTr = {
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
    final namesEn = {
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
    final names = isTurkish ? namesTr : namesEn;
    return names[badgeId] ?? badgeId;
  }
  
  /// Rozet açıklaması (gereksinim)
  String _getBadgeDescription(String badgeId, {bool isTurkish = true}) {
    final descriptionsTr = {
      // Adım Rozetleri
      'steps_10k': '10.000 Adım',
      'steps_100k': '100.000 Adım',
      'steps_1m': '1 Milyon Adım',
      'steps_10m': '10 Milyon Adım',
      'steps_100m': '100 Milyon Adım',
      'steps_1b': '1 Milyar Adım',
      // Bağış Rozetleri
      'donation_10': '10 Hope',
      'donation_100': '100 Hope',
      'donation_1k': '1.000 Hope',
      'donation_10k': '10.000 Hope',
      'donation_100k': '100.000 Hope',
      'donation_1m': '1 Milyon Hope',
      // Aktivite Rozetleri
      'streak_first': 'İlk Giriş',
      'streak_7': '7 Gün Seri',
      'streak_30': '30 Gün Seri',
      'streak_90': '90 Gün Seri',
      'streak_180': '180 Gün Seri',
      'streak_365': '365 Gün Seri',
    };
    final descriptionsEn = {
      // Step Badges
      'steps_10k': '10,000 Steps',
      'steps_100k': '100,000 Steps',
      'steps_1m': '1 Million Steps',
      'steps_10m': '10 Million Steps',
      'steps_100m': '100 Million Steps',
      'steps_1b': '1 Billion Steps',
      // Donation Badges
      'donation_10': '10 Hope',
      'donation_100': '100 Hope',
      'donation_1k': '1,000 Hope',
      'donation_10k': '10,000 Hope',
      'donation_100k': '100,000 Hope',
      'donation_1m': '1 Million Hope',
      // Activity Badges
      'streak_first': 'First Login',
      'streak_7': '7 Day Streak',
      'streak_30': '30 Day Streak',
      'streak_90': '90 Day Streak',
      'streak_180': '180 Day Streak',
      'streak_365': '365 Day Streak',
    };
    final descriptions = isTurkish ? descriptionsTr : descriptionsEn;
    return descriptions[badgeId] ?? badgeId;
  }

  void _showBadgeDetail(BadgeDefinition badge, bool isEarned, double progress) {
    final lang = context.read<LanguageProvider>();
    final badgeName = _getBadgeName(badge.id, isTurkish: lang.isTurkish);
    final badgeDescription = _getBadgeDescription(badge.id, isTurkish: lang.isTurkish);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Büyük rozet ikonu (sıvı doluluk efekti ile)
            SizedBox(
              width: 120,
              height: 120,
              child: _buildLiquidBadge(badge, progress, isEarned),
            ),
            const SizedBox(height: 16),
            
            // Rozet ismi (kısa başlık)
            Text(
              badgeName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            
            // Rozet açıklaması (gereksinim)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(badge.gradientStart).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeDescription,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(badge.gradientStart),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Detaylı açıklama
            Text(
              lang.isTurkish 
                  ? BadgeService.getBadgeDescriptionTr(badge.id)
                  : BadgeService.getBadgeDescriptionEn(badge.id),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            // Durum
            if (isEarned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6EC6B5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF6EC6B5), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      lang.isTurkish ? 'Kazanıldı! 🎉' : 'Earned! 🎉',
                      style: const TextStyle(
                        color: Color(0xFF6EC6B5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  // İlerleme çubuğu
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(badge.gradientStart),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}% ${lang.isTurkish ? 'tamamlandı' : 'completed'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.isTurkish 
                        ? 'Hedef: ${_formatRequirement(badge, isTurkish: true)}'
                        : 'Target: ${_formatRequirement(badge, isTurkish: false)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatRequirement(BadgeDefinition badge, {bool isTurkish = true}) {
    switch (badge.category) {
      case BadgeCategory.steps:
        return '${BadgeService.formatNumber(badge.requirement)} ${isTurkish ? 'adım' : 'steps'}';
      case BadgeCategory.donation:
        return '${BadgeService.formatNumber(badge.requirement)} Hope';
      case BadgeCategory.activity:
        if (badge.requirement == 1) return isTurkish ? 'İlk giriş' : 'First login';
        return '${badge.requirement} ${isTurkish ? 'gün seri' : 'day streak'}';
    }
  }
}

/// Dalgalı gri overlay widget
/// Animasyonlu dalga efekti ile gri katmanı gösterir
class _WavyGrayOverlay extends StatefulWidget {
  final String imagePath;
  final double progress;

  const _WavyGrayOverlay({
    required this.imagePath,
    required this.progress,
  });

  @override
  State<_WavyGrayOverlay> createState() => _WavyGrayOverlayState();
}

class _WavyGrayOverlayState extends State<_WavyGrayOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipPath(
          clipper: _WavyClipper(
            progress: widget.progress,
            animationValue: _controller.value,
          ),
          child: child,
        );
      },
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: Image.asset(
          widget.imagePath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Dalgalı clipper
/// Sıvı seviyesinin üst kısmında dalga efekti oluşturur
/// Gri katmanı ÜSTTEN gösterir - böylece progress arttıkça alttan renkli görünür
class _WavyClipper extends CustomClipper<Path> {
  final double progress;
  final double animationValue;

  _WavyClipper({
    required this.progress,
    required this.animationValue,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Gerçek progress değerini kullan - %0 ise hiç renkli görünmez
    final effectiveProgress = progress.clamp(0.0, 1.0);
    
    // Sıvı seviyesi - progress arttıkça gri alan azalır (üstten aşağı)
    final waveY = size.height * (1 - effectiveProgress);
    
    // Dalga parametreleri
    final waveHeight = 3.0;
    final waveCount = 1.5;
    
    // Başlangıç noktası (sol üst köşe)
    path.moveTo(0, 0);
    
    // Sol kenardan aşağı dalga seviyesine
    path.lineTo(0, waveY);
    
    // Dalgalı çizgi çiz (soldan sağa)
    for (double x = 0; x <= size.width; x++) {
      final normalizedX = x / size.width;
      final waveOffset = math.sin(
        (normalizedX * waveCount * 2 * math.pi) + (animationValue * 2 * math.pi)
      ) * waveHeight;
      path.lineTo(x, waveY + waveOffset);
    }
    
    // Sağ üst köşeye ve kapatma
    path.lineTo(size.width, 0);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(_WavyClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.animationValue != animationValue;
}
