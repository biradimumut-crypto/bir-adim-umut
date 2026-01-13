import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/notifications/notifications_page.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'providers/language_provider.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_notification_service.dart';
import 'services/badge_service.dart';
import 'services/interstitial_ad_service.dart';
import 'services/rewarded_ad_service.dart';
import 'services/session_service.dart';
import 'services/health_service.dart';

/// Light Theme
ThemeData lightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF6EC6B5),
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF6EC6B5),
      secondary: const Color(0xFFE07A5F),
      tertiary: const Color(0xFFF2C94C),
    ),
    scaffoldBackgroundColor: Colors.grey[50],
    textTheme: GoogleFonts.poppinsTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
    ),
  );
}

/// Dark Theme
ThemeData darkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF6EC6B5),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF6EC6B5),
      secondary: const Color(0xFFE07A5F),
      tertiary: const Color(0xFFF2C94C),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: const CardTheme(
      color: Color(0xFF1E1E1E),
      elevation: 2,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase başlat
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase başarıyla başlatıldı!');
    
    // Firestore Offline Persistence (varsayılan olarak açık, ama ayarları optimize edelim)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    print('Firestore offline cache aktif!');
    
    // App Check başlat (güvenlik için) - Web'de devre dışı bırak
    if (!kIsWeb) {
      try {
        await FirebaseAppCheck.instance.activate(
          appleProvider: AppleProvider.debug, // Debug modda - production'da deviceCheck kullan
          androidProvider: AndroidProvider.debug, // Debug modda - production'da playIntegrity kullan
        );
        print('App Check başarıyla başlatıldı!');
      } catch (e) {
        print('App Check başlatılamadı (devam ediliyor): $e');
      }
    } else {
      print('Web modda App Check devre dışı');
    }
    
    // Push Notification background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Push Notification'ları başlat
    final notificationService = NotificationService();
    await notificationService.initializePushNotifications();
    
    // Local Notification'ları başlat
    final localNotifications = LocalNotificationService();
    await localNotifications.initialize();
    await localNotifications.scheduleAllDailyNotifications();
    print('Local bildirimler başlatıldı!');
    
    // AdMob başlat
    await MobileAds.instance.initialize();
    print('AdMob başarıyla başlatıldı!');
    
    // Interstitial ve Rewarded reklamları önceden yükle
    InterstitialAdService.instance.loadAd();
    RewardedAdService.instance.loadAd();
    print('Reklam servisleri başlatıldı!');
    
    // Connectivity monitoring başlat
    ConnectivityService().startMonitoring();
    print('Bağlantı izleme başlatıldı!');
    
    // 🎖️ Login streak ve rozet kontrolü (kullanıcı giriş yapmışsa)
    try {
      final badgeService = BadgeService();
      await badgeService.updateLoginStreak();
      await badgeService.checkAllBadges();
      print('Rozet sistemi kontrol edildi!');
    } catch (e) {
      print('Rozet sistemi başlatılamadı (kullanıcı giriş yapmamış olabilir): $e');
    }
    
    // 📊 Session takibi başlat (kullanıcı giriş yapmışsa)
    try {
      final sessionService = SessionService();
      await sessionService.startSession();
      print('Session takibi başlatıldı!');
    } catch (e) {
      print('Session takibi başlatılamadı: $e');
    }
    
    // 🏃 Health API başlat (Apple Health / Health Connect)
    if (!kIsWeb) {
      try {
        final healthService = HealthService();
        await healthService.initialize();
        print('Health API başlatıldı! (Simüle: ${healthService.isUsingSimulatedData})');
      } catch (e) {
        print('Health API başlatılamadı: $e');
      }
    }
    
  } catch (e) {
    print('Başlatma hatası: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final SessionService _sessionService = SessionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // Uygulama ön plana geldi - session heartbeat
        _sessionService.heartbeat();
        debugPrint('📱 App resumed - heartbeat sent');
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // Uygulama arka plana alındı veya kapatıldı - session sonlandır
        _sessionService.endSession();
        debugPrint('📱 App paused/inactive - session ended');
        break;
      case AppLifecycleState.hidden:
        // iOS'ta uygulama gizlendi
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Navigator key'i BadgeService'e bağla
    BadgeService.navigatorKey = navigatorKey;
    
    return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'OneHopeStep',
          debugShowCheckedModeBanner: false,
          theme: lightTheme(),
          // Türkçe dil desteği
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [
            Locale('tr', 'TR'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/sign-up': (context) => const SignUpScreen(),
            '/notifications': (context) => const NotificationsPage(),
            '/admin': (context) => const AdminPanelScreen(),
          },
        );
  }
}

/// Auth wrapper - Kullanıcı giriş yapıp yapmadığını kontrol et
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Bağlantı beklerken loading göster
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Kullanıcı giriş yapmışsa Dashboard'a git
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }
        
        // Giriş yapmamışsa Login ekranına git
        return const LoginScreen();
      },
    );
  }
}
