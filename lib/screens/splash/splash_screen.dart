import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';

/// Splash Screen - beyaz arka plan, yeni.gif, 200x200
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 2 saniye sonra otomatik geçiş
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _navigateToNextScreen();
      }
    });
  }

  void _navigateToNextScreen() {
    final user = FirebaseAuth.instance.currentUser;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            user != null ? const DashboardScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ekran genişliğinin %55'i kadar (native splash ile uyumlu)
    final size = MediaQuery.of(context).size.width * 0.55;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/videos/yeni.gif',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
