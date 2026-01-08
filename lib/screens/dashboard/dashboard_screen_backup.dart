import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/step_conversion_service.dart';
import '../../models/user_model.dart';
import '../charity/charity_screen.dart';
import '../teams/teams_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';

/// Ana Dashboard Ekranı - İç içe Progress Bar ile
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final StepConversionService _stepService = StepConversionService();
  
  UserModel? _currentUser;
  bool _isLoading = true;
  int _selectedIndex = 0;

  // Adım verileri
  int _dailySteps = 0;
  int _convertedSteps = 0;
  int _remainingSteps = 0;
  int _carryOverSteps = 0; // Taşınan adımlar
  static const int _dailyGoal = 15000;
  static const int _maxConvertPerTime = 2500;

  // Cooldown
  bool _canConvert = true;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  // Haftalık veri
  List<int> _weeklySteps = [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
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
      final stepData = await _stepService.getTodayStepData(uid);
      final weeklyData = await _stepService.getWeeklySteps(uid);
      final carryOver = await _stepService.getCarryOverSteps(uid);
      
      // Eski adımları temizle (7 günden eski)
      await _stepService.cleanupExpiredSteps(uid);
      
      if (mounted) {
        setState(() {
          _dailySteps = stepData['daily_steps'] ?? 0;
          _convertedSteps = stepData['converted_steps'] ?? 0;
          _remainingSteps = _dailySteps - _convertedSteps;
          if (_remainingSteps < 0) _remainingSteps = 0;
          _carryOverSteps = carryOver;
          _weeklySteps = weeklyData;
          
          // Cooldown kontrolü
          final lastConversion = stepData['last_conversion_time'] as Timestamp?;
          if (lastConversion != null) {
            final diff = DateTime.now().difference(lastConversion.toDate());
            if (diff.inMinutes < 10) {
              _startCooldown(600 - diff.inSeconds);
            }
          }
        });
      }
    } catch (e) {
      print('Step data yükleme hatası: $e');
      // Demo data
      setState(() {
        _dailySteps = 4500;
        _convertedSteps = 0;
        _remainingSteps = 4500;
        _carryOverSteps = 3200; // Demo taşınan adım
        _weeklySteps = [3200, 5100, 4800, 6200, 4500, 7800, 4500];
      });
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          const CharityScreen(),
          const TeamsScreen(),
          const LeaderboardScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Bağış - Özel ikon
                _buildNavItemWithImage(
                  index: 1,
                  imagePath: 'assets/icons/bagis.png',
                  label: 'Bağış',
                ),
                // Takım - Özel ikon
                _buildNavItemWithImage(
                  index: 2,
                  imagePath: 'assets/icons/takım.png',
                  label: 'Takım',
                ),
                // Ana Sayfa (Ortada ve büyük) - Özel ikon
                _buildCenterNavItemWithImage(),
                // Sıralama - Özel ikon
                _buildNavItemWithImage(
                  index: 3,
                  imagePath: 'assets/icons/siralama.png',
                  label: 'Sıralama',
                ),
                // Profil - Özel ikon
                _buildNavItemWithImage(
                  index: 4,
                  imagePath: 'assets/icons/Profil.png',
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Özel PNG ikonlu navigation item
  Widget _buildNavItemWithImage({
    required int index,
    required String imagePath,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6EC6B5).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                isSelected ? const Color(0xFF6EC6B5) : Colors.grey[500]!,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                imagePath,
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF6EC6B5) : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ortadaki ana sayfa butonu - Özel ikon
  Widget _buildCenterNavItemWithImage() {
    final isSelected = _selectedIndex == 0;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected 
                ? [const Color(0xFF6EC6B5), const Color(0xFFE07A5F)]
                : [Colors.grey[300]!, Colors.grey[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? const Color(0xFF6EC6B5).withOpacity(0.4)
                  : Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.white,
            BlendMode.srcIn,
          ),
          child: Image.asset(
            'assets/icons/anasayfa.png',
            width: 32,
            height: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? Colors.blue[600] : Colors.grey[500],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.blue[600] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    final isSelected = _selectedIndex == 0;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected 
                ? [Colors.blue[400]!, Colors.blue[600]!]
                : [Colors.grey[300]!, Colors.grey[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? Colors.blue.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isSelected ? Icons.home : Icons.home_outlined,
          color: Colors.white,
          size: 32,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 24),
              _buildHopeBalanceCard(),
              const SizedBox(height: 24),
              _buildNestedProgressBar(),
              const SizedBox(height: 24),
              _buildConversionCard(),
              const SizedBox(height: 24),
              _buildWeeklyChart(),
              const SizedBox(height: 20),
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
        Row(
          children: [
            // Profil Fotoğrafı
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue[100],
              backgroundImage: _currentUser?.profileImageUrl != null
                  ? NetworkImage(_currentUser!.profileImageUrl!)
                  : null,
              child: _currentUser?.profileImageUrl == null
                  ? Text(
                      _currentUser?.fullName.isNotEmpty == true
                          ? _currentUser!.fullName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoşgeldiniz 👋',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentUser?.fullName ?? 'Kullanıcı',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        // Bildirim ikonu
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('receiver_uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            int count = snapshot.data?.docs.length ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 28),
                  onPressed: _showNotifications,
                ),
                if (count > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHopeBalanceCard() {
    return GestureDetector(
      onTap: () {
        // Bağış sayfasına git (index 1)
        setState(() => _selectedIndex = 1);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[600]!, Colors.purple[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
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
                  const Text(
                    'Hope Bakiyen',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
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
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'H',
                            style: TextStyle(
                              color: Colors.purple[700],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _currentUser?.walletBalanceHope != null && _currentUser!.walletBalanceHope >= 5
                            ? Icons.check_circle
                            : Icons.info_outline,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentUser?.walletBalanceHope != null && _currentUser!.walletBalanceHope >= 5
                            ? 'Umut olabilirsiniz →'
                            : 'Min 5 H gerekli',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Ok ikonu - tıklanabilir olduğunu gösterir
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  /// İÇ İÇE PROGRESS BAR - Dış: Taşınan (Turuncu), Orta: Günlük Adım (Mavi), İç: Dönüştürülen (Yeşil)
  Widget _buildNestedProgressBar() {
    double dailyProgress = _dailySteps / _dailyGoal;
    double convertedProgress = _convertedSteps / _dailyGoal;
    double carryOverProgress = _carryOverSteps / _dailyGoal;
    if (dailyProgress > 1) dailyProgress = 1;
    if (convertedProgress > 1) convertedProgress = 1;
    if (carryOverProgress > 1) carryOverProgress = 1;

    return Container(
      padding: const EdgeInsets.all(20),
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
              const Text(
                'Günlük Adım Durumu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_dailySteps / $_dailyGoal',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // İÇ İÇE CIRCULAR PROGRESS (3 HALKA)
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // EN DIŞ - Taşınan Adımlar (Turuncu) - sadece varsa göster
                if (_carryOverSteps > 0)
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: carryOverProgress,
                      strokeWidth: 14,
                      backgroundColor: Colors.deepOrange[100],
                      valueColor: AlwaysStoppedAnimation(Colors.deepOrange[600]),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                // ORTA - Günlük Adım (Mavi)
                SizedBox(
                  width: _carryOverSteps > 0 ? 184 : 200,
                  height: _carryOverSteps > 0 ? 184 : 200,
                  child: CircularProgressIndicator(
                    value: dailyProgress,
                    strokeWidth: 16,
                    backgroundColor: Colors.blue[100],
                    valueColor: AlwaysStoppedAnimation(Colors.blue[600]),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // İÇ - Dönüştürülen Adım (Yeşil)
                SizedBox(
                  width: _carryOverSteps > 0 ? 144 : 156,
                  height: _carryOverSteps > 0 ? 144 : 156,
                  child: CircularProgressIndicator(
                    value: convertedProgress,
                    strokeWidth: 12,
                    backgroundColor: Colors.green[100],
                    valueColor: AlwaysStoppedAnimation(Colors.green[600]),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Ortadaki bilgi
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk, size: 28, color: Colors.blue[600]),
                    const SizedBox(height: 4),
                    Text(
                      '$_remainingSteps',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Bekleyen Adım',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                    if (_carryOverSteps > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '+$_carryOverSteps taşınan',
                        style: TextStyle(color: Colors.deepOrange[600], fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (_carryOverSteps > 0)
                _buildLegendItem('Taşınan', Colors.deepOrange[600]!),
              _buildLegendItem('Günlük Adım', Colors.blue[600]!),
              _buildLegendItem('Dönüştürülen', Colors.green[600]!),
            ],
          ),

          const SizedBox(height: 16),

          // Demo: Adım ekle butonu
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addDemoSteps,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('+1000 Adım'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addDemoHope,
                  icon: const Icon(Icons.favorite, size: 18, color: Colors.purple),
                  label: const Text('+50 Hope'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
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

  /// Dönüştürme Kartı - 2500 max, 10dk cooldown, reklam zorunlu
  Widget _buildConversionCard() {
    int canConvertAmount = _remainingSteps > _maxConvertPerTime 
        ? _maxConvertPerTime 
        : _remainingSteps;
    double hopeEarned = canConvertAmount / 2500 * 0.10;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[500]!, Colors.purple[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Adımları Dönüştür',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (!_canConvert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatCooldown(_cooldownSeconds),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Bilgi kutuları
          Row(
            children: [
              Expanded(
                child: _buildInfoBox('Dönüştürülecek', '$canConvertAmount', 'adım', Icons.sync),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoBox('Kazanılacak', hopeEarned.toStringAsFixed(2), 'Hope', Icons.favorite),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Kural bilgisi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Max 2500 adım/sefer • 10dk bekleme • Reklam zorunlu',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Dönüştür butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_canConvert && _remainingSteps > 0) ? _handleConversion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.purple[700],
                disabledBackgroundColor: Colors.white.withOpacity(0.4),
                disabledForegroundColor: Colors.purple[300],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_canConvert ? Icons.play_circle_fill : Icons.timer, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _canConvert
                        ? (_remainingSteps > 0 ? 'Adım Adım Umut' : 'Dönüştürülecek adım yok')
                        : 'Bekleme: ${_formatCooldown(_cooldownSeconds)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Taşınan adımları dönüştür butonu
          if (_carryOverSteps > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _canConvert ? _handleCarryOverConversion : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '🔥 Taşınan $_carryOverSteps adımı dönüştür',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBox(String title, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
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
    final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    int maxValue = _weeklySteps.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) maxValue = 1;

    return Container(
      padding: const EdgeInsets.all(20),
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
              const Text(
                'Haftalık Özet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Toplam: ${_weeklySteps.reduce((a, b) => a + b)} adım',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: CustomPaint(
              size: const Size(double.infinity, 150),
              painter: _LineChartPainter(
                data: _weeklySteps,
                maxValue: maxValue,
                days: days,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCooldown(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _addDemoSteps() {
    setState(() {
      _dailySteps += 1000;
      _remainingSteps = _dailySteps - _convertedSteps;
      _weeklySteps[6] = _dailySteps;
    });
    
    // Firestore'a kaydet
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _stepService.updateDailySteps(uid, _dailySteps);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('➕ 1000 adım eklendi!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _addDemoHope() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'wallet_balance_hope': FieldValue.increment(50),
      }, SetOptions(merge: true));

      // Kullanıcı verisini yenile
      await _loadUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💜 +50 Hope eklendi!'),
          backgroundColor: Colors.purple,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
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

  Future<void> _handleConversion() async {
    // Reklam göster
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AdSimulationDialog(),
    );

    if (result == true) {
      int convertAmount = _remainingSteps > _maxConvertPerTime 
          ? _maxConvertPerTime 
          : _remainingSteps;
      double hopeEarned = convertAmount / 2500 * 0.10;

      // Firestore'a kaydet
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _stepService.convertSteps(
          userId: uid,
          steps: convertAmount,
          hopeEarned: hopeEarned,
        );
      }

      setState(() {
        _convertedSteps += convertAmount;
        _remainingSteps = _dailySteps - _convertedSteps;
      });

      // 10 dakika cooldown başlat
      _startCooldown(600);

      // Kullanıcı bakiyesini güncelle
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.white),
                const SizedBox(width: 8),
                Text('${hopeEarned.toStringAsFixed(2)} Hope kazandınız!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Taşınan adımları dönüştür
  Future<void> _handleCarryOverConversion() async {
    if (_carryOverSteps <= 0) return;

    // Reklam göster
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AdSimulationDialog(),
    );

    if (result == true) {
      int convertAmount = _carryOverSteps > _maxConvertPerTime 
          ? _maxConvertPerTime 
          : _carryOverSteps;
      double hopeEarned = convertAmount / 2500 * 0.10;

      // Firestore'a kaydet
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _stepService.convertCarryOverSteps(
          userId: uid,
          steps: convertAmount,
          hopeEarned: hopeEarned,
        );
      }

      setState(() {
        _carryOverSteps -= convertAmount;
      });

      // 10 dakika cooldown başlat
      _startCooldown(600);

      // Kullanıcı bakiyesini güncelle
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.history, color: Colors.white),
                const SizedBox(width: 8),
                Text('🔥 Taşınan adımlardan ${hopeEarned.toStringAsFixed(2)} Hope kazandınız!'),
              ],
            ),
            backgroundColor: Colors.deepOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.group_add, color: Colors.blue[700], size: 20),
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Takıma katıldınız!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet reddedildi')),
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
                const Text(
                  'Reklam',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                      'Reklam Alanı',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(Google AdMob entegrasyonu)',
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
              valueColor: AlwaysStoppedAnimation(Colors.purple[600]),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text(
              'Reklam $_countdown saniye sonra kapanacak...',
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
  final int maxValue;
  final List<String> days;

  _LineChartPainter({
    required this.data,
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
    final paint = Paint()
      ..color = Colors.blue[600]!
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
          Colors.blue[400]!.withOpacity(0.3),
          Colors.blue[100]!.withOpacity(0.05),
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

    // Bezier curve ile yumuşak çizgi
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      linePath.cubicTo(controlX1, p0.dy, controlX2, p1.dy, p1.dx, p1.dy);
    }
    canvas.drawPath(linePath, paint);

    // Noktaları çiz
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final isToday = i == 6;
      
      // Beyaz border
      canvas.drawCircle(point, isToday ? 7 : 5, Paint()..color = Colors.white);
      // Renkli nokta
      canvas.drawCircle(point, isToday ? 5 : 3.5, 
        Paint()..color = isToday ? Colors.blue[700]! : Colors.blue[400]!);

      // Gün adı (altta)
      textPainter.text = TextSpan(
        text: days[i],
        style: TextStyle(
          color: isToday ? Colors.blue[700] : Colors.grey[600],
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
    return oldDelegate.data != data || oldDelegate.maxValue != maxValue;
  }
}
