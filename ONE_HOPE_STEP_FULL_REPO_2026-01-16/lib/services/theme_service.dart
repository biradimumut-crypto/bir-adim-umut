import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Theme Service - Firestore + SharedPreferences ile tema yönetimi
/// 
/// Öncelik sırası:
/// 1. Login ise → Firestore'dan theme_preference oku
/// 2. Login değilse → SharedPreferences'tan oku
/// 3. Hiçbiri yoksa → ThemeMode.system
class ThemeService {
  static const String _localThemeKey = 'theme_mode';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Tema modunu string'e çevir (Firestore için)
  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  /// String'i ThemeMode'a çevir
  ThemeMode _stringToThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Tema oku - Firestore (login ise) veya SharedPreferences'tan
  Future<ThemeMode> getTheme() async {
    final user = _auth.currentUser;
    
    // 1. Kullanıcı login ise Firestore'dan oku
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final themePreference = doc.data()?['theme_preference'];
          if (themePreference != null) {
            final themeMode = _stringToThemeMode(themePreference);
            // Local cache'e de kaydet (hızlı erişim için)
            await _saveToLocal(themeMode);
            return themeMode;
          }
        }
      } catch (e) {
        debugPrint('Firestore theme okuma hatası: $e');
      }
    }
    
    // 2. Firestore'dan okunamazsa local'dan oku
    return _getFromLocal();
  }

  /// Tema kaydet - Firestore (login ise) + SharedPreferences
  Future<bool> setTheme(ThemeMode mode) async {
    final user = _auth.currentUser;
    
    // Local'a her zaman kaydet
    await _saveToLocal(mode);
    
    // Kullanıcı login ise Firestore'a da kaydet
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'theme_preference': _themeModeToString(mode),
        });
        return true;
      } catch (e) {
        debugPrint('Firestore theme yazma hatası: $e');
        return false;
      }
    }
    
    return true;
  }

  /// Local'dan tema oku (SharedPreferences)
  Future<ThemeMode> _getFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_localThemeKey);
      return _stringToThemeMode(themeString);
    } catch (e) {
      debugPrint('Local theme okuma hatası: $e');
      return ThemeMode.system;
    }
  }

  /// Local'a tema kaydet (SharedPreferences)
  Future<void> _saveToLocal(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localThemeKey, _themeModeToString(mode));
    } catch (e) {
      debugPrint('Local theme yazma hatası: $e');
    }
  }

  /// Tema toggle (light <-> dark)
  Future<bool> toggleTheme(bool isDark) async {
    return await setTheme(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
