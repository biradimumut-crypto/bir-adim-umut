import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/admin_stats_model.dart';
import '../../models/admin_dashboard_stats.dart';
import '../../widgets/admin/admin_sidebar.dart';
import 'admin_users_screen.dart';
import 'admin_teams_screen.dart';
import 'admin_charities_screen.dart';
import 'admin_donations_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_badges_screen.dart';
import 'admin_comments_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_logs_screen.dart';
import 'admin_dashboard_detail_screen.dart';

/// Ana admin paneli ekranı - Yenilenmiş Dashboard
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AdminService _adminService = AdminService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isLoading = true;
  
  // Yeni dashboard verileri
  DailyStepAnalytics? _dailyStepAnalytics;
  CarryoverAnalytics? _carryoverAnalytics;
  ReferralAnalytics? _referralAnalytics;
  DonationAnalytics? _donationAnalytics;
  AdminStatsModel? _stats;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _loadAllData();
  }

  Future<void> _checkAdminAccess() async {
    final isAdmin = await _adminService.isCurrentUserAdmin();
    if (!isAdmin && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu sayfaya erişim yetkiniz yok!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _adminService.getAdminStats(),
        _adminService.getDailyStepAnalytics(),
        _adminService.getCarryoverAnalytics(),
        _adminService.getReferralAnalytics(),
        _adminService.getDonationAnalytics(),
      ]);
      
      if (mounted) {
        setState(() {
          _stats = results[0] as AdminStatsModel;
          _dailyStepAnalytics = results[1] as DailyStepAnalytics;
          _carryoverAnalytics = results[2] as CarryoverAnalytics;
          _referralAnalytics = results[3] as ReferralAnalytics;
          _donationAnalytics = results[4] as DonationAnalytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Dashboard veri yükleme hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(_getPageTitle()),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllData,
              tooltip: 'Yenile',
            ),
        ],
      ),
      drawer: Drawer(
        child: AdminSidebar(
          selectedIndex: _selectedIndex,
          onItemSelected: (index) {
            setState(() => _selectedIndex = index);
            Navigator.pop(context);
          },
        ),
      ),
      body: _buildContent(),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'Kullanıcılar';
      case 2: return 'Takımlar';
      case 3: return 'Vakıf/Topluluk/Birey';
      case 4: return 'Bağış Raporları';
      case 5: return 'Bildirimler';
      case 6: return 'Rozetler';
      case 7: return 'Yorumlar';
      case 8: return 'Analitik';
      case 9: return 'Admin Logları';
      default: return 'Admin Panel';
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildNewDashboard();
      case 1:
        return const AdminUsersScreen();
      case 2:
        return const AdminTeamsScreen();
      case 3:
        return const AdminCharitiesScreen();
      case 4:
        return const AdminDonationsScreen();
      case 5:
        return const AdminNotificationsScreen();
      case 6:
        return const AdminBadgesScreen();
      case 7:
        return const AdminCommentsScreen();
      case 8:
        return const AdminAnalyticsScreen();
      case 9:
        return const AdminLogsScreen();
      default:
        return _buildNewDashboard();
    }
  }

  /// YENİ DASHBOARD - 4 Ana Kart ile Responsive Tasarım
  Widget _buildNewDashboard() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6EC6B5)),
            SizedBox(height: 16),
            Text('Dashboard yükleniyor...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final stats = _stats ?? AdminStatsModel.empty();

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: const Color(0xFF6EC6B5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık ve Son Güncelleme
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bir Adım Umut',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6EC6B5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF6EC6B5)),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(DateTime.now()),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6EC6B5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Text(
              'Admin Kontrol Paneli',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            
            const SizedBox(height: 24),
            
            // Hızlı Özet - Küçük Kartlar
            _buildQuickSummary(stats),
            
            const SizedBox(height: 24),
            
            // 4 ANA KART - Responsive Grid
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive breakpoint'ler
                final isWide = constraints.maxWidth > 900;
                final isMedium = constraints.maxWidth > 600;
                
                if (isWide) {
                  // Desktop - 2x2 grid
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDailyStepsCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildCarryoverCard()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildReferralCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDonationCard()),
                        ],
                      ),
                    ],
                  );
                } else if (isMedium) {
                  // Tablet - 2 sütun
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDailyStepsCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildCarryoverCard()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildReferralCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDonationCard()),
                        ],
                      ),
                    ],
                  );
                } else {
                  // Mobile - tek sütun
                  return Column(
                    children: [
                      _buildDailyStepsCard(),
                      const SizedBox(height: 12),
                      _buildCarryoverCard(),
                      const SizedBox(height: 12),
                      _buildReferralCard(),
                      const SizedBox(height: 12),
                      _buildDonationCard(),
                    ],
                  );
                }
              },
            ),
            
            const SizedBox(height: 24),
            
            // Ek Bilgiler Bölümü
            _buildAdditionalInfo(stats),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Hızlı Özet Kartları
  Widget _buildQuickSummary(AdminStatsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D5A8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Toplam Kullanıcı',
                  _formatNumber(stats.totalUsers),
                  Icons.people_rounded,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildMiniStat(
                  'Bugün Aktif',
                  _formatNumber(stats.dailyActiveUsers),
                  Icons.person_rounded,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildMiniStat(
                  'Toplam Hope',
                  '${_formatNumber(stats.totalHopeConverted.toInt())} H',
                  Icons.favorite_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// KART 1: Günlük Adım Analizleri
  Widget _buildDailyStepsCard() {
    final data = _dailyStepAnalytics ?? DailyStepAnalytics.empty();
    
    return _buildAnalyticsCard(
      title: 'Günlük Adım Analizleri',
      icon: Icons.directions_walk_rounded,
      color: const Color(0xFF6EC6B5),
      items: [
        _CardItem('Toplam Adım', _formatNumber(data.totalDailySteps), Icons.straighten),
        _CardItem('Dönüştürülen', _formatNumber(data.convertedSteps), Icons.check_circle_outline),
        _CardItem('Normal Hope', '${data.normalHopeEarned.toStringAsFixed(1)} H', Icons.spa_outlined),
        _CardItem('2x Bonus Hope', '${data.bonusHopeEarned.toStringAsFixed(1)} H', Icons.stars_rounded),
        _CardItem('TOPLAM HOPE', '${data.totalHopeEarned.toStringAsFixed(1)} H', Icons.favorite, isHighlighted: true),
      ],
      onTap: () => _navigateToDetail(DashboardDetailType.dailySteps),
    );
  }

  /// KART 2: Taşınan Adım Analizleri
  Widget _buildCarryoverCard() {
    final data = _carryoverAnalytics ?? CarryoverAnalytics.empty();
    
    return _buildAnalyticsCard(
      title: 'Taşınan Adım Analizleri',
      icon: Icons.history_rounded,
      color: const Color(0xFFE07A5F),
      items: [
        _CardItem('Toplam Taşınan', _formatNumber(data.totalCarryoverSteps), Icons.inventory_2_outlined),
        _CardItem('Dönüştürülen', _formatNumber(data.convertedCarryoverSteps), Icons.check_circle_outline),
        _CardItem('Bekleyen', _formatNumber(data.pendingCarryoverSteps), Icons.pending_outlined),
        _CardItem('Kazanılan Hope', '${data.hopeFromCarryover.toStringAsFixed(1)} H', Icons.spa_outlined),
        _CardItem('Silinen (Tarihsel)', _formatNumber(data.expiredSteps), Icons.delete_outline, isWarning: true),
      ],
      onTap: () => _navigateToDetail(DashboardDetailType.carryover),
    );
  }

  /// KART 3: Referans ve Davet Analizleri
  Widget _buildReferralCard() {
    final data = _referralAnalytics ?? ReferralAnalytics.empty();
    
    return _buildAnalyticsCard(
      title: 'Referans & Davet Analizleri',
      icon: Icons.people_outline_rounded,
      color: const Color(0xFFF2C94C),
      items: [
        _CardItem('Referans Kullanıcı', _formatNumber(data.totalReferralUsers), Icons.person_add_outlined),
        _CardItem('Verilen Bonus Adım', _formatNumber(data.totalBonusStepsGiven), Icons.card_giftcard_rounded),
        _CardItem('Dönüştürülen', _formatNumber(data.convertedBonusSteps), Icons.check_circle_outline),
        _CardItem('Bekleyen Bonus', _formatNumber(data.pendingBonusSteps), Icons.pending_outlined),
        _CardItem('Bonus Hope', '${data.hopeFromBonusSteps.toStringAsFixed(1)} H', Icons.stars_rounded, isHighlighted: true),
      ],
      onTap: () => _navigateToDetail(DashboardDetailType.referral),
    );
  }

  /// KART 4: Bağış Detayları
  Widget _buildDonationCard() {
    final data = _donationAnalytics ?? DonationAnalytics.empty();
    
    return _buildAnalyticsCard(
      title: 'Bağış Detayları',
      icon: Icons.volunteer_activism_rounded,
      color: const Color(0xFF9B59B6),
      items: [
        _CardItem('Toplam Bağış Adedi', _formatNumber(data.totalDonationCount), Icons.receipt_long_outlined),
        _CardItem('Bağışlanan Hope', '${data.totalDonatedHope.toStringAsFixed(1)} H', Icons.favorite_rounded, isHighlighted: true),
        _CardItem('Ortalama Bağış', '${data.averageDonation.toStringAsFixed(1)} H', Icons.analytics_outlined),
        _CardItem('Vakıf Sayısı', '${data.charityBreakdown.length}', Icons.business_rounded),
      ],
      onTap: () => _navigateToDetail(DashboardDetailType.donation),
    );
  }

  /// Genel Analitik Kart Widget'ı
  Widget _buildAnalyticsCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<_CardItem> items,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // İstatistikler
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 16,
                    color: item.isWarning 
                        ? Colors.red[400] 
                        : (item.isHighlighted ? color : Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: item.isHighlighted ? FontWeight.bold : FontWeight.w600,
                      color: item.isWarning 
                          ? Colors.red[400] 
                          : (item.isHighlighted ? color : Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            )),
            
            // Detay butonu
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Detaylı Rapor',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 14, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ek Bilgiler Bölümü
  Widget _buildAdditionalInfo(AdminStatsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sistem Özeti',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip('Takım', '${stats.totalTeams}', Icons.groups),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip('Vakıf', '${stats.totalCharities}', Icons.business),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip('Topluluk', '${stats.totalCommunities}', Icons.diversity_3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip('Birey', '${stats.totalIndividuals}', Icons.person),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip('Cüzdanlarda', '${stats.hopeInWallets.toStringAsFixed(0)} H', Icons.account_balance_wallet),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip('2x Bonus', '${stats.bonusHope.toStringAsFixed(0)} H', Icons.double_arrow),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Detay sayfasına git
  void _navigateToDetail(DashboardDetailType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminDashboardDetailScreen(type: type),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      String result = '';
      String numStr = number.toString();
      int count = 0;
      for (int i = numStr.length - 1; i >= 0; i--) {
        count++;
        result = numStr[i] + result;
        if (count % 3 == 0 && i > 0) {
          result = '.$result';
        }
      }
      return result;
    }
    return number.toString();
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Kart item modeli
class _CardItem {
  final String label;
  final String value;
  final IconData icon;
  final bool isHighlighted;
  final bool isWarning;

  _CardItem(this.label, this.value, this.icon, {this.isHighlighted = false, this.isWarning = false});
}
