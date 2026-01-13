import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_log_service.dart';

/// Interstitial (Geçiş) Reklam Servisi - Zorunlu Reklamlar
/// Hope dönüşümü ve bağış işlemlerinde gösterilir
class InterstitialAdService {
  static InterstitialAdService? _instance;
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  final AdLogService _adLogService = AdLogService();
  String _currentContext = 'unknown'; // Reklam bağlamını takip et

  // Singleton pattern
  static InterstitialAdService get instance {
    _instance ??= InterstitialAdService._();
    return _instance!;
  }

  InterstitialAdService._();

  // AdMob Interstitial Ad Unit ID'leri
  static String get _adUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8054071059959102/8479854657'; // Android Interstitial ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-8054071059959102/1567973702'; // iOS Interstitial ID
    } else {
      throw UnsupportedError('Desteklenmeyen platform');
    }
  }

  bool get isAdLoaded => _isAdLoaded;

  /// Reklamı önceden yükle
  Future<void> loadAd() async {
    print('🎬 InterstitialAd yükleniyor... (kDebugMode: $kDebugMode, adUnitId: $_adUnitId)');
    await InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          print('✅ InterstitialAd yüklendi başarıyla');

          // Reklam kapatıldığında yeni reklam yükle
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              print('InterstitialAd kapatıldı');
              // ✅ Reklam izleme logu
              _adLogService.logInterstitialAd(
                context: _currentContext,
                wasShown: true,
              );
              ad.dispose();
              _isAdLoaded = false;
              _interstitialAd = null;
              // Yeni reklam yükle
              loadAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ InterstitialAd gösterilemedi: ${error.message}');
              // ✅ Hata logu
              _adLogService.logInterstitialAd(
                context: _currentContext,
                wasShown: false,
                errorMessage: error.message,
              );
              ad.dispose();
              _isAdLoaded = false;
              _interstitialAd = null;
              loadAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('❌ InterstitialAd yüklenemedi: ${error.message} (code: ${error.code})');
          // ✅ Yükleme hatası logu
          _adLogService.logAdLoadError(
            adType: 'interstitial',
            errorMessage: error.message,
          );
          _isAdLoaded = false;
        },
      ),
    );
  }

  /// Reklamı göster ve tamamlandığında callback çalıştır
  /// [onAdComplete] - Reklam gösterildikten veya başarısız olduktan sonra çalışır
  /// [context] - Reklamın gösterildiği bağlam (step_conversion, donation, vb.)
  Future<void> showAd({required Function onAdComplete, String context = 'unknown'}) async {
    _currentContext = context; // Bağlamı kaydet
    
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          print('InterstitialAd kapatıldı');
          // ✅ Reklam izleme logu
          _adLogService.logInterstitialAd(
            context: _currentContext,
            wasShown: true,
          );
          ad.dispose();
          _isAdLoaded = false;
          _interstitialAd = null;
          onAdComplete();
          // Yeni reklam yükle
          loadAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('InterstitialAd gösterilemedi: ${error.message}');
          // ✅ Hata logu
          _adLogService.logInterstitialAd(
            context: _currentContext,
            wasShown: false,
            errorMessage: error.message,
          );
          ad.dispose();
          _isAdLoaded = false;
          _interstitialAd = null;
          onAdComplete();
          loadAd();
        },
      );
      await _interstitialAd!.show();
    } else {
      // Reklam yüklü değilse direkt işlemi yap
      print('InterstitialAd hazır değil, işlem devam ediyor');
      // ✅ Reklam gösterilmedi logu
      _adLogService.logInterstitialAd(
        context: _currentContext,
        wasShown: false,
        errorMessage: 'Ad not loaded',
      );
      onAdComplete();
      // Reklam yüklemeyi dene
      loadAd();
    }
  }

  /// Kaynakları temizle
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
  }
}
