import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Tema yönetimi için Provider
/// 
/// Firestore'dan tema tercihini yükler ve değişiklikleri senkronize eder.
/// Hata durumunda rollback yapılabilir.
class ThemeProvider extends ChangeNotifier {
  final ThemeService _themeService = ThemeService();
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// Provider başlatıcı - main.dart'ta çağrılmalı
  ThemeProvider() {
    _loadTheme();
  }

  /// Tema tercihini Firestore/Local'den yükle
  Future<void> _loadTheme() async {
    try {
      _themeMode = await _themeService.getTheme();
      _isInitialized = true;
      notifyListeners();
      debugPrint('🎨 Tema yüklendi: $_themeMode');
    } catch (e) {
      debugPrint('🎨 Tema yüklenirken hata (varsayılan system kullanılıyor): $e');
      _themeMode = ThemeMode.system;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Temayı değiştir - Hata durumunda rollback yapar
  /// 
  /// [newMode] - Yeni tema modu (system, light, dark)
  /// Returns true if successful, false if rollback occurred
  Future<bool> setThemeMode(ThemeMode newMode) async {
    final previousMode = _themeMode;
    
    // Önce UI'ı güncelle (hızlı yanıt için)
    _themeMode = newMode;
    notifyListeners();
    
    try {
      // Firestore + Local'e kaydet
      final success = await _themeService.setTheme(newMode);
      
      if (!success) {
        // Kaydetme başarısız - rollback
        _themeMode = previousMode;
        notifyListeners();
        debugPrint('🎨 Tema kaydedilemedi, rollback yapıldı');
        return false;
      }
      
      debugPrint('🎨 Tema değiştirildi: $previousMode → $newMode');
      return true;
    } catch (e) {
      // Hata durumunda rollback
      _themeMode = previousMode;
      notifyListeners();
      debugPrint('🎨 Tema değiştirme hatası, rollback yapıldı: $e');
      return false;
    }
  }

  /// Temayı toggle et (light <-> dark)
  /// System modundayken dark'a geçer
  Future<bool> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.dark 
        ? ThemeMode.light 
        : ThemeMode.dark;
    return await setThemeMode(newMode);
  }

  /// Kullanıcı çıkış yaptığında temayı yeniden yükle
  /// (Firestore'dan local'e fallback için)
  Future<void> onUserLogout() async {
    await _loadTheme();
  }

  /// Kullanıcı giriş yaptığında Firestore'dan temayı senkronize et
  Future<void> onUserLogin() async {
    await _loadTheme();
  }
}
