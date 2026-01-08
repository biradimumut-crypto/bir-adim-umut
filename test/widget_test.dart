// Bir Adım Umut - Widget Testleri
//
// Bu testler uygulama bileşenlerinin doğru çalıştığını kontrol eder.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bir_adim_umut/main.dart';
import 'package:bir_adim_umut/providers/theme_provider.dart';
import 'package:bir_adim_umut/providers/language_provider.dart';

void main() {
  // SharedPreferences mock'u kurulumu
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUp(() {
    // SharedPreferences için mock değerler
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MyApp widget oluşturulabilir mi', (WidgetTester tester) async {
    // Provider'lar ile MyApp widget'ını oluştur
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // MaterialApp oluşturulmuş mu kontrol et
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('ThemeProvider light/dark tema değiştirebilir', (WidgetTester tester) async {
    final themeProvider = ThemeProvider();

    // Varsayılan tema kontrolü
    expect(themeProvider.themeMode, ThemeMode.system);

    // Light tema
    await themeProvider.setThemeMode(ThemeMode.light);
    expect(themeProvider.themeMode, ThemeMode.light);

    // Dark tema
    await themeProvider.setThemeMode(ThemeMode.dark);
    expect(themeProvider.themeMode, ThemeMode.dark);
  });

  testWidgets('LanguageProvider dil değiştirebilir', (WidgetTester tester) async {
    final languageProvider = LanguageProvider();
    
    // Pump yaparak async yüklenmeyi bekle
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Varsayılan dil kontrolü (Türkçe olmalı)
    expect(languageProvider.languageCode, 'tr');

    // Dil değiştir
    await languageProvider.setLanguage('en');
    expect(languageProvider.languageCode, 'en');

    // Tekrar Türkçe
    await languageProvider.setLanguage('tr');
    expect(languageProvider.languageCode, 'tr');
  });
}
