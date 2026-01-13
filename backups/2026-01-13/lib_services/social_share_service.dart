import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sosyal medya paylaşım servisi
class SocialShareService {
  static final SocialShareService _instance = SocialShareService._internal();
  factory SocialShareService() => _instance;
  SocialShareService._internal();

  /// Dil kontrolü
  Future<String> _getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_language') ?? 'tr';
  }

  /// WhatsApp'ta görsel ile paylaş (sadece görsel)
  Future<void> shareToWhatsApp({Uint8List? imageData}) async {
    if (imageData != null) {
      await _shareImageOnly(imageData);
    }
  }

  /// Instagram'da görsel ile paylaş (sadece görsel)
  Future<void> shareToInstagram({Uint8List? imageData}) async {
    if (imageData != null) {
      await _shareImageOnly(imageData);
    }
  }

  /// Facebook'ta görsel ile paylaş (sadece görsel)
  Future<void> shareToFacebook({Uint8List? imageData}) async {
    if (imageData != null) {
      await _shareImageOnly(imageData);
    }
  }

  /// Sadece görsel paylaşım (iOS share sheet açar)
  Future<void> _shareImageOnly(Uint8List imageData) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/hopesteps_share.png');
      await file.writeAsBytes(imageData);
      
      // iOS için sharePositionOrigin gerekli
      await Share.shareXFiles(
        [XFile(file.path)],
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
      );
    } catch (e) {
      print('Image share error: $e');
    }
  }

  /// Genel paylaşım (sadece görsel)
  Future<void> shareGeneral({Uint8List? imageData}) async {
    if (imageData != null) {
      await _shareImageOnly(imageData);
    }
  }

  /// Widget'ı görsel olarak capture et
  Future<Uint8List?> captureWidget(GlobalKey key) async {
    try {
      RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Widget capture error: $e');
      return null;
    }
  }

  /// Rozet kazanıldığında paylaşım metni oluştur
  Future<String> getBadgeShareText(String badgeName, String badgeDescription) async {
    final langCode = await _getLanguageCode();
    
    switch (langCode) {
      case 'en':
        return '''🎉 I Earned a New Badge!

🏆 $badgeName

$badgeDescription

Every step turns into hope with OneHopeStep app! 
Join now: #OneHopeStep #DoGood 🌟''';
      case 'de':
        return '''🎉 Ich habe ein neues Abzeichen verdient!

🏆 $badgeName

$badgeDescription

Mit der OneHopeStep App wird jeder Schritt zur Hoffnung! 
Mach mit: #OneHopeStep #TuGutes 🌟''';
      case 'ja':
        return '''🎉 新しいバッジを獲得しました！

🏆 $badgeName

$badgeDescription

OneHopeStepアプリで一歩一歩が希望に変わる！ 
参加しよう: #OneHopeStep #善行 🌟''';
      case 'es':
        return '''🎉 ¡Gané una Nueva Insignia!

🏆 $badgeName

$badgeDescription

¡Cada paso se convierte en esperanza con OneHopeStep! 
Únete: #OneHopeStep #HazElBien 🌟''';
      case 'ro':
        return '''🎉 Am Câștigat o Insignă Nouă!

🏆 $badgeName

$badgeDescription

Cu aplicația OneHopeStep, fiecare pas devine speranță! 
Alătură-te: #OneHopeStep #FăBine 🌟''';
      default:
        return '''🎉 Yeni Rozet Kazandım!

🏆 $badgeName

$badgeDescription

OneHopeStep uygulamasıyla her adım umuda dönüşüyor! 
Sende katıl: #OneHopeStep #İyilikYap 🌟''';
    }
  }

  /// Bağış yapıldığında paylaşım metni oluştur
  Future<String> getDonationShareText(String charityName, double amount) async {
    final langCode = await _getLanguageCode();
    
    switch (langCode) {
      case 'en':
        return '''💝 I Made a Donation!

I donated ${amount.toStringAsFixed(0)} Hope to $charityName!

I'm turning my steps into hope with OneHopeStep app! 
Join now: #OneHopeStep #DoGood #BeHope 🌟''';
      case 'de':
        return '''💝 Ich habe gespendet!

Ich habe ${amount.toStringAsFixed(0)} Hope an $charityName gespendet!

Mit der OneHopeStep App verwandle ich meine Schritte in Hoffnung! 
Mach mit: #OneHopeStep #TuGutes #SeiHoffnung 🌟''';
      case 'ja':
        return '''💝 寄付しました！

$charityName に ${amount.toStringAsFixed(0)} Hope を寄付しました！

OneHopeStepアプリで歩数を希望に変えています！ 
参加しよう: #OneHopeStep #善行 #希望になろう 🌟''';
      case 'es':
        return '''💝 ¡Hice una Donación!

¡Doné ${amount.toStringAsFixed(0)} Hope a $charityName!

¡Estoy convirtiendo mis pasos en esperanza con OneHopeStep! 
Únete: #OneHopeStep #HazElBien #SéEsperanza 🌟''';
      case 'ro':
        return '''💝 Am Făcut o Donație!

Am donat ${amount.toStringAsFixed(0)} Hope către $charityName!

Cu aplicația OneHopeStep îmi transform pașii în speranță! 
Alătură-te: #OneHopeStep #FăBine #FiiSperanță 🌟''';
      default:
        return '''💝 Bağış Yaptım!

$charityName için ${amount.toStringAsFixed(0)} Hope bağışladım!

OneHopeStep uygulamasıyla adımlarımı umuda dönüştürüyorum! 
Sende katıl: #OneHopeStep #İyilikYap #UmutOl 🌟''';
    }
  }
}
