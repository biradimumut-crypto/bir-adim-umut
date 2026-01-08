import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../services/auth_service.dart';
import '../../services/step_conversion_service.dart';
import '../../models/user_model.dart';
import '../../widgets/hope_liquid_progress.dart';
import '../charity/charity_screen.dart';
import '../teams/teams_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';

/// Ana Dashboard Ekranı - HOPE Liquid Progress ile
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final StepConversionService _stepService = StepConversionService();
  
  UserModel? _currentUser;
  bool _isLoading = true;
  int _selectedIndex = 0;
  int _selectedTab = 0; // 0: Günlük, 1: Taşınan, 2: Bonus, 3: Grafik

  // Adım verileri
  int _dailySteps = 0;
  int _convertedSteps = 0;
  int _carryOverSteps = 0;
  int _bonusSteps = 0;
  static const int _dailyGoal = 15000;

  // Haftalık veri
  List<int> _weeklySteps = [0, 0, 0, 0, 0, 0, 0];

  // Cooldown
  bool _canConvert = true;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

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
      
      if (mounted) {
        setState(() {
          _dailySteps = stepData['daily_steps'] ?? 0;
          _convertedSteps = stepData['converted_steps'] ?? 0;
          _carryOverSteps = carryOver;
          _weeklySteps = weeklyData;
        });
      }
    } catch (e) {
      print('Step data alma hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
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
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 8,
        color: Colors.white,
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
      floatingActionButton: _buildCenterNavItem(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItemWithImage({
    required int index,
    required String imagePath,
    String? label,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
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
                    child: ColorFiltered(
                      colorFilter: isSelected
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                          : ColorFilter.mode(Colors.grey.shade400, BlendMode.modulate),
                      child: Image.asset(
                        imagePath,
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.error_outline,
                          color: isSelected ? const Color(0xFFE07A5F) : Colors.grey,
                          size: 28,
                        ),
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
                ),
              ),
            ],
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
              color: const Color(0xFF6EC6B5).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/yenilogo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.home,
                  color: Color(0xFFE07A5F),
                  size: 32,
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
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 16),
              _buildProgressSection(),
              const SizedBox(height: 16),
              _buildTabSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Avatar ve isim
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF6EC6B5),
            child: Text(
              _currentUser?.fullName?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoşgeldiniz',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                _currentUser?.fullName ?? 'Kullanıcı',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          // HOPE bakiye
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6EC6B5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Text(
                  (_currentUser?.walletBalanceHope ?? 0).toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.eco, size: 14, color: Color(0xFF6EC6B5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    double progress = _dailySteps / _dailyGoal;
    if (progress > 1) progress = 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Günlük İlerleme',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6EC6B5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_dailySteps adım',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // HOPE Liquid Progress
          HopeLiquidProgress(
            progress: progress,
            width: 200,
            height: 120,
            isActive: _dailySteps > 0,
          ),
          
          const SizedBox(height: 16),
          
          // 2x BONUS butonu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, color: Color(0xFFF2C94C), size: 18),
                SizedBox(width: 4),
                Text(
                  '2x BONUS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.grey[400]!, 'Günlük Adım'),
              const SizedBox(width: 24),
              _buildLegendItem(const Color(0xFF6EC6B5), 'Dönüştürülen Adım'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTabSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF2C94C), // Sarı
            Color(0xFFE07A5F), // Turuncu
            Color(0xFF6EC6B5), // Turkuaz
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Tab bar
          _buildTabBar(),
          const SizedBox(height: 16),
          // Tab content
          _buildTabContent(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Günlük', 'Taşınan', 'Bonus', 'Grafik'];
    final icons = [Icons.calendar_today, Icons.history, Icons.card_giftcard, Icons.bar_chart];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(4, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      icons[index],
                      size: 18,
                      color: isSelected ? const Color(0xFFE07A5F) : Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tabs[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? const Color(0xFFE07A5F) : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildDailyTab();
      case 1:
        return _buildCarryOverTab();
      case 2:
        return _buildBonusTab();
      case 3:
        return _buildGraphTab();
      default:
        return _buildDailyTab();
    }
  }

  Widget _buildDailyTab() {
    final convertable = _dailySteps - _convertedSteps;
    final earnableHope = (convertable / 2500).floor() * 0.01;
    
    return _buildTabContentCard(
      leftTitle: 'Dönüştürülebilir',
      leftValue: '${convertable > 0 ? convertable : 0}',
      leftUnit: 'adım',
      rightTitle: 'Kazanılacak',
      rightValue: earnableHope.toStringAsFixed(2),
      rightUnit: 'Hope',
      validityText: '23:59\'a kadar geçerli',
      buttonText: convertable > 0 ? 'Dönüştür' : 'Günlük Adım Yok',
      buttonEnabled: convertable > 0 && _canConvert,
      onButtonPressed: _handleDailyConversion,
    );
  }

  Widget _buildCarryOverTab() {
    final earnableHope = (_carryOverSteps / 2500).floor() * 0.01;
    
    return _buildTabContentCard(
      leftTitle: 'Taşınan',
      leftValue: '$_carryOverSteps',
      leftUnit: 'adım',
      rightTitle: 'Kazanılacak',
      rightValue: earnableHope.toStringAsFixed(2),
      rightUnit: 'Hope',
      validityText: 'Ay sonuna kadar geçerli',
      buttonText: _carryOverSteps > 0 ? 'Dönüştür' : 'Taşınan Adım Yok',
      buttonEnabled: _carryOverSteps > 0 && _canConvert,
      onButtonPressed: _handleCarryOverConversion,
    );
  }

  Widget _buildBonusTab() {
    final earnableHope = (_bonusSteps / 2500).floor() * 0.01;
    
    return _buildTabContentCard(
      leftTitle: 'Bonus',
      leftValue: '$_bonusSteps',
      leftUnit: 'adım',
      rightTitle: 'Kazanılacak',
      rightValue: earnableHope.toStringAsFixed(2),
      rightUnit: 'Hope',
      validityText: '30 gün sonra geçerli',
      buttonText: _bonusSteps > 0 ? 'Dönüştür' : 'Bonus Adım Yok',
      buttonEnabled: _bonusSteps > 0 && _canConvert,
      onButtonPressed: _handleBonusConversion,
    );
  }

  Widget _buildGraphTab() {
    final totalWeekly = _weeklySteps.reduce((a, b) => a + b);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Toplam Haftalık:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                '$totalWeekly adım',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: _buildWeeklyChart(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
                .map((day) => Text(
                      day,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final maxSteps = _weeklySteps.reduce((a, b) => a > b ? a : b);
    final normalizedMax = maxSteps > 0 ? maxSteps : 15000;
    
    return CustomPaint(
      size: const Size(double.infinity, 100),
      painter: _WeeklyChartPainter(
        data: _weeklySteps,
        maxValue: normalizedMax.toDouble(),
      ),
    );
  }

  Widget _buildTabContentCard({
    required String leftTitle,
    required String leftValue,
    required String leftUnit,
    required String rightTitle,
    required String rightValue,
    required String rightUnit,
    required String validityText,
    required String buttonText,
    required bool buttonEnabled,
    required VoidCallback onButtonPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Icon(Icons.directions_walk, color: Colors.red[400], size: 24),
                    const SizedBox(height: 4),
                    Text(leftTitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(
                      leftValue,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(leftUnit, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: Colors.grey[300]),
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.eco, color: Color(0xFF6EC6B5), size: 24),
                    const SizedBox(height: 4),
                    Text(rightTitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(
                      rightValue,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(rightUnit, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                validityText,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: buttonEnabled ? onButtonPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonEnabled ? const Color(0xFFF2C94C) : Colors.grey[300],
                foregroundColor: buttonEnabled ? Colors.white : Colors.grey[500],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!buttonEnabled) ...[
                    Icon(Icons.close, size: 18, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    buttonText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: buttonEnabled ? Colors.white : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDailyConversion() {
    // TODO: Implement daily conversion
    print('Günlük dönüşüm');
  }

  void _handleCarryOverConversion() {
    // TODO: Implement carry over conversion
    print('Taşınan dönüşüm');
  }

  void _handleBonusConversion() {
    // TODO: Implement bonus conversion
    print('Bonus dönüşüm');
  }
}

class _WeeklyChartPainter extends CustomPainter {
  final List<int> data;
  final double maxValue;

  _WeeklyChartPainter({required this.data, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE07A5F)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE07A5F).withOpacity(0.3),
          const Color(0xFFE07A5F).withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Noktaları çiz
    final dotPaint = Paint()
      ..color = const Color(0xFFE07A5F)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue * size.height);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
