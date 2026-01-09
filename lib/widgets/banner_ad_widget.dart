import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import '../services/ad_log_service.dart';

/// Banner Reklam Widget'ı - Google AdMob
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({Key? key}) : super(key: key);

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  final AdLogService _adLogService = AdLogService();
  bool _hasLoggedImpression = false; // Tekrar log atmasın

  // AdMob Banner Ad Unit ID'leri
  static String get _adUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8054071059959102/6703738555'; // Android Banner ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-8054071059959102/3520824404'; // iOS Banner ID
    } else {
      throw UnsupportedError('Desteklenmeyen platform');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
            // ✅ Banner gösterildi logu (sadece bir kez)
            if (!_hasLoggedImpression) {
              _hasLoggedImpression = true;
              _adLogService.logBannerAd(context: 'dashboard', wasShown: true);
            }
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('BannerAd yüklenemedi: ${error.message}');
          _adLogService.logAdLoadError(adType: 'banner', errorMessage: error.message);
          ad.dispose();
        },
        onAdOpened: (ad) {
          print('BannerAd açıldı');
        },
        onAdClosed: (ad) {
          print('BannerAd kapatıldı');
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      // Reklam yüklenene kadar placeholder
      return Container(
        width: double.infinity,
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey[400],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
