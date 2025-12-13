import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';

/// Splash Screen - Video veya Logo gösterimi
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _showFallbackUI = false;
  bool _hasNavigated = false;
  double _opacity = 1.0;
  
  late AnimationController _animationController;
  late AnimationController _fadeOutController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initVideo();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  Future<void> _initVideo() async {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/splash_video.mp4');
      
      await _videoController!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        
        _videoController!.setLooping(false);
        _videoController!.setVolume(0); // Sessiz oynat
        _videoController!.play();
        
        // Video bittiğinde yönlendir
        _videoController!.addListener(_videoListener);
        
        // Maksimum 5 saniye bekle
        Future.delayed(const Duration(seconds: 5), () {
          _navigateToNextScreen();
        });
      }
    } catch (e) {
      print('Video yükleme hatası: $e');
      // Video yüklenemezse fallback UI göster
      if (mounted) {
        setState(() {
          _showFallbackUI = true;
        });
        _animationController.forward();
        
        // 3 saniye sonra yönlendir
        Future.delayed(const Duration(seconds: 3), () {
          _navigateToNextScreen();
        });
      }
    }
  }

  void _videoListener() {
    if (_videoController != null && 
        _videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.duration.inMilliseconds > 0) {
      _navigateToNextScreen();
    }
  }

  void _navigateToNextScreen() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    
    // Önce fade-out animasyonu başlat
    setState(() {
      _opacity = 0.0;
    });
    
    // Fade-out tamamlandıktan sonra sayfaya geç
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      
      final user = FirebaseAuth.instance.currentUser;
      
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              user != null ? const DashboardScreen() : const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _animationController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Video başarıyla yüklendiyse video göster
    if (_isVideoInitialized && !_showFallbackUI) {
      return AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
        ),
      );
    }

    // Video yüklenemezse veya yüklenirken fallback UI
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _showFallbackUI
              ? FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildLogoContent(),
                  ),
                )
              : const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLogoContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.volunteer_activism,
            size: 60,
            color: Colors.purple[600],
          ),
        ),

        const SizedBox(height: 24),

        // Uygulama Adı
        const Text(
          'Bir Adım Umut',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 8),

        // Slogan
        Text(
          'Adımlarınla Umut Ol',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 48),

        // Loading indicator
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }
}
