import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_log_service.dart';

/// Rewarded (Ödüllü) Reklam Servisi - İsteğe Bağlı Reklamlar
/// Kullanıcı izlerse bonus Hope kazanır
class RewardedAdService {
  static RewardedAdService? _instance;
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  final AdLogService _adLogService = AdLogService();
  String _currentContext = 'bonus_hope'; // Reklam bağlamını takip et

  // Singleton pattern
  static RewardedAdService get instance {
    _instance ??= RewardedAdService._();
    return _instance!;
  }

  RewardedAdService._();

  // AdMob Rewarded Ad Unit ID'leri
  static String get _adUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8054071059959102/5399407506'; // Android Rewarded ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-8054071059959102/2964815850'; // iOS Rewarded ID (Ödüllü)
    } else {
      throw UnsupportedError('Desteklenmeyen platform');
    }
  }

  bool get isAdLoaded => _isAdLoaded;

  /// Reklamı önceden yükle
  Future<void> loadAd() async {
    await RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          print('RewardedAd yüklendi');
        },
        onAdFailedToLoad: (error) {
          print('RewardedAd yüklenemedi: ${error.message}');
          // ✅ Yükleme hatası logu
          _adLogService.logAdLoadError(
            adType: 'rewarded',
            errorMessage: error.message,
          );
          _isAdLoaded = false;
        },
      ),
    );
  }

  /// Reklamı göster ve ödül ver
  /// [onRewarded] - Kullanıcı reklamı izledikten sonra çalışır (ödül verilir)
  /// [onAdClosed] - Reklam kapatıldığında çalışır (ödül almadan kapatırsa)
  /// [context] - Reklamın gösterildiği bağlam
  Future<void> showAd({
    required Function(int rewardAmount) onRewarded,
    Function? onAdClosed,
    String context = 'bonus_hope',
  }) async {
    _currentContext = context;
    bool wasRewarded = false;
    
    if (_isAdLoaded && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          print('RewardedAd kapatıldı');
          // ✅ Reklam logu (ödül almadan kapatma dahil)
          if (!wasRewarded) {
            _adLogService.logRewardedAd(
              context: _currentContext,
              rewardAmount: 0,
              wasCompleted: false,
              errorMessage: 'User closed without reward',
            );
          }
          ad.dispose();
          _isAdLoaded = false;
          _rewardedAd = null;
          onAdClosed?.call();
          // Yeni reklam yükle
          loadAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('RewardedAd gösterilemedi: ${error.message}');
          // ✅ Hata logu
          _adLogService.logRewardedAd(
            context: _currentContext,
            rewardAmount: 0,
            wasCompleted: false,
            errorMessage: error.message,
          );
          ad.dispose();
          _isAdLoaded = false;
          _rewardedAd = null;
          loadAd();
        },
      );

      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          print('Kullanıcı ödül kazandı: ${reward.amount} ${reward.type}');
          wasRewarded = true;
          // ✅ Ödül logu
          _adLogService.logRewardedAd(
            context: _currentContext,
            rewardAmount: 50,
            wasCompleted: true,
          );
          // Bonus Hope miktarı (50 Hope)
          onRewarded(50);
        },
      );
    } else {
      print('RewardedAd hazır değil');
      // ✅ Reklam gösterilmedi logu
      _adLogService.logRewardedAd(
        context: _currentContext,
        rewardAmount: 0,
        wasCompleted: false,
        errorMessage: 'Ad not loaded',
      );
    }
  }

  /// Kaynakları temizle
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
  }
}
