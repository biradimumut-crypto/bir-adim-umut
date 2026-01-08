import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/permission_service.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../permissions/permissions_screen.dart';

/// Splash Screen - 111.png HOPE dolum animasyonu (opacity ile)
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _canNavigate = false;
  bool _hasNavigated = false;
  bool _imagesLoaded = false;

  // HOPE dolum animasyonu
  late AnimationController _hopeFillController;
  late Animation<double> _hopeFillAnimation;

  // HOPE pulse animasyonu (tıklanabilir olduğunu göstermek için)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesLoaded) {
      _preloadImages();
    }
  }

  void _initAnimations() {
    // HOPE dolum animasyonu - 3 saniye
    _hopeFillController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _hopeFillAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _hopeFillController,
        curve: Curves.easeInOut,
      ),
    );

    _hopeFillController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _canNavigate = true;
        });
        // Pulse animasyonunu başlat - tıklanabilir olduğunu göster
        _pulseController.repeat(reverse: true);
      }
    });

    // HOPE pulse animasyonu
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _preloadImages() async {
    try {
      // Görselleri önceden yükle
      await Future.wait([
        precacheImage(const AssetImage('assets/images/111_empty.png'), context),
        precacheImage(const AssetImage('assets/images/111.png'), context),
      ]);
      
      if (mounted) {
        setState(() {
          _imagesLoaded = true;
        });
        // Görseller yüklenince animasyonu başlat
        _hopeFillController.forward();
      }
    } catch (e) {
      print('Görsel yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _imagesLoaded = true;
        });
        _hopeFillController.forward();
      }
    }
  }

  void _navigateToNextScreen() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    final user = FirebaseAuth.instance.currentUser;

    // Kullanıcı giriş yapmışsa izin kontrolü yap
    if (user != null) {
      final permissionService = PermissionService();
      final shouldShowPermissions =
          await permissionService.shouldShowPermissionsScreen();

      if (shouldShowPermissions && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const PermissionsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            user != null ? const DashboardScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _hopeFillController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildLanguageButton(
      String label, bool isSelected, VoidCallback onTap, {bool isEnglish = false}) {
    final Color activeColor = isEnglish ? const Color(0xFFE07A5F) : const Color(0xFFE07A5F);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Alt katman: HOPE yazısız görsel (boş)
              if (_imagesLoaded)
                Image.asset(
                  'assets/images/111_empty.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              else
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),

              // Üst katman: HOPE yazılı görsel - opacity ile yavaşça belirme + tıklanabilir
              if (_imagesLoaded)
                AnimatedBuilder(
                  animation: Listenable.merge([_hopeFillAnimation, _pulseAnimation]),
                  builder: (context, child) {
                    return GestureDetector(
                      onTap: _canNavigate ? _navigateToNextScreen : null,
                      child: Transform.scale(
                        scale: _canNavigate ? _pulseAnimation.value : 1.0,
                        child: Opacity(
                          opacity: _hopeFillAnimation.value,
                          child: Image.asset(
                            'assets/images/111.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Dil seçici - Sağ üstte (mor-mavi gradient çerçeve)
              Positioned(
                top: 30,
                right: 20,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(2), // Gradient border için
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFF2C94C), // Mor
                          Color(0xFFE07A5F), // Mavi/Turkuaz
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(27),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLanguageButton(
                            'TR',
                            lang.isTurkish,
                            () => lang.setLanguage('tr'),
                          ),
                          _buildLanguageButton(
                            'EN',
                            lang.isEnglish,
                            () => lang.setLanguage('en'),
                            isEnglish: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
