import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/notifications/notifications_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase başlat
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase başarıyla başlatıldı!');
  } catch (e) {
    print('Firebase başlatma hatası: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sans-serif (Roboto) Typography Teması - KALINCA VERSION
    final textTheme = GoogleFonts.robotoTextTheme(
      Theme.of(context).textTheme,
    ).copyWith(
      // Başlık 1 - 32dp - ÇOOOK KALINCA
      headlineLarge: GoogleFonts.roboto(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.0,
      ),
      // Başlık 2 - 28dp - ÇOK KALINCA
      headlineMedium: GoogleFonts.roboto(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.0,
      ),
      // Başlık 3 - 24dp - KALINCA
      headlineSmall: GoogleFonts.roboto(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
      ),
      // Başlık 4 - 20dp (Body çok büyük) - KALINCA
      titleLarge: GoogleFonts.roboto(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      ),
      // Başlık 5 - 16dp - KALINCA
      titleMedium: GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      // Başlık 6 - 14dp - KALINCA
      titleSmall: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      // Body Büyük - 18dp - KALINCA
      bodyLarge: GoogleFonts.roboto(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.5,
      ),
      // Body Orta - 16dp - KALINCA
      bodyMedium: GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25,
        height: 1.5,
      ),
      // Body Küçük - 14dp - KALINCA
      bodySmall: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        height: 1.4,
      ),
      // Label Büyük - 16dp (Buton) - KALINCA
      labelLarge: GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      // Label Orta - 14dp - KALINCA
      labelMedium: GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      // Label Küçük - 12dp - KALINCA
      labelSmall: GoogleFonts.roboto(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      // Display Büyük - 57dp (Splash, Banner) - ÇOOOOK KALINCA
      displayLarge: GoogleFonts.roboto(
        fontSize: 57,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.0,
      ),
      // Display Orta - 45dp - ÇOK KALINCA
      displayMedium: GoogleFonts.roboto(
        fontSize: 45,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.0,
      ),
      // Display Küçük - 36dp - KALINCA
      displaySmall: GoogleFonts.roboto(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
      ),
    );

    return MaterialApp(
      title: 'Bir Adım Umut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          titleTextStyle: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        // Buton temaları
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        textTheme: GoogleFonts.robotoTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/sign-up': (context) => const SignUpScreen(),
        '/notifications': (context) => const NotificationsPage(),
      },
    );
  }
}

/// Auth wrapper - Kullanıcı giriş yapıp yapmadığını kontrol et
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Şimdilik Login ekranını göster
    // Production'da Firebase Auth state'ini kontrol et
    return const LoginScreen();
  }
}
