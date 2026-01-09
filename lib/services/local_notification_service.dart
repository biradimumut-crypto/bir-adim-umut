import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';

/// Yerel bildirim servisi - Zamanlanmış ve anlık bildirimler
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Bildirim ID'leri
  static const int morningMotivationId = 1001;
  static const int eveningReminderId = 1002;
  static const int bonusReadyId = 1003;
  static const int monthEndWarning3DaysId = 1004; // Son 3 gün
  static const int monthEndWarning2DaysId = 1005; // Son 2 gün
  static const int monthEndWarning1DayId = 1006;  // Son 1 gün
  static const int carryOverReminderId = 1007;

  /// Kullanıcının dil tercihini kontrol et
  Future<bool> _isTurkish() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('language') != 'en';
  }

  /// Sabah motivasyon mesajları - Türkçe
  final List<Map<String, String>> _morningMessagesTr = [
    {
      'title': 'Günaydın! ☀️',
      'body': 'Bugün kaç adım atacaksın? Her adım bir umut!',
    },
    {
      'title': 'Yeni Bir Gün! 🌟',
      'body': 'Adımların sadece seni değil, bir başkasının hayatını da ileri taşıyor. Hadi başla!',
    },
    {
      'title': 'Harekete Geç! 💪',
      'body': 'Adımlar sayılıyor, umut birikiyor. Gün seninle başlasın!',
    },
    {
      'title': 'Umut Dolu Bir Gün! 💚',
      'body': 'Attığın her adım biyerlere umut ekiyor. Bugün de fark yarat!',
    },
    {
      'title': 'Merhaba Şampiyon! 🏆',
      'body': 'Bugün de adımlarınla umut olmaya hazır mısın?',
    },
  ];

  /// Sabah motivasyon mesajları - İngilizce
  final List<Map<String, String>> _morningMessagesEn = [
    {
      'title': 'Good Morning! ☀️',
      'body': 'How many steps will you take today? Every step is hope, every hope is a smile 😊',
    },
    {
      'title': 'A New Day! 🌟',
      'body': 'Leave yesterday behind, today brings new opportunities. Let\'s go! 🚶',
    },
    {
      'title': 'Are You Ready? 💪',
      'body': 'A small step today, a big change tomorrow. You can do it!',
    },
    {
      'title': 'A Day Full of Hope! 💚',
      'body': 'Every step you take touches someone\'s life. Make a difference today!',
    },
    {
      'title': 'Hello Champion! 🏆',
      'body': 'Are you ready to change the world with your steps today?',
    },
  ];

  /// Akşam hatırlatma mesajları - Türkçe
  final List<Map<String, String>> _eveningMessagesTr = [
    {
      'title': 'Adımların Seni Bekliyor! 🌙',
      'body': 'Bugün {steps} adım attın ama henüz dönüştürmedin. Gece olmadan Hope\'a çevir! 💚',
    },
    {
      'title': '💫 Belki fark etmedin…',
      'body': 'Bugün attığın adımlar birinin yarını olabilir.',
    },
    {
      'title': '🕊️ Küçük bir dokunuş yeterli.',
      'body': 'Adımların bir iyiliğe dönüşsün.',
    },
  ];

  /// Akşam hatırlatma mesajları - İngilizce
  final List<Map<String, String>> _eveningMessagesEn = [
    {
      'title': 'Your Steps Are Waiting! 🌙',
      'body': 'You took {steps} steps today but haven\'t converted them yet. Convert to Hope before midnight! 💚',
    },
    {
      'title': '💫 Maybe you didn\'t notice…',
      'body': 'The steps you took today could be someone\'s tomorrow.',
    },
    {
      'title': '🕊️ A small touch is enough.',
      'body': 'Let your steps turn into kindness.',
    },
  ];

  /// Servisi başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Timezone başlat
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Android ayarları
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS ayarları
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    print('Local Notification Service initialized!');
  }

  /// Bildirime tıklandığında
  void _onNotificationTapped(NotificationResponse response) {
    print('Bildirime tıklandı: ${response.payload}');
    // Burada navigasyon yapılabilir
  }

  /// Android bildirim kanalı oluştur
  AndroidNotificationDetails _getAndroidDetails({
    required String channelId,
    required String channelName,
    String? channelDescription,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );
  }

  /// iOS bildirim detayları
  DarwinNotificationDetails _getIOSDetails() {
    return const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
  }

  // ==================== ANLIK BİLDİRİMLER ====================

  /// 🎯 2500 Adım Bonus Bildirimi
  Future<void> showBonusReadyNotification() async {
    final isTr = await _isTurkish();
    await _notifications.show(
      bonusReadyId,
      isTr ? '2x Bonus Zamanı! 🎉' : '2x Bonus Time! 🎉',
      isTr 
          ? '2500 adıma ulaştın! Şu an dönüştürürsen 2 kat Hope kazanırsın. Fırsatı kaçırma!'
          : 'You reached 2500 steps! Convert now to earn 2x Hope. Don\'t miss it!',
      NotificationDetails(
        android: _getAndroidDetails(
          channelId: 'bonus_channel',
          channelName: isTr ? 'Bonus Bildirimleri' : 'Bonus Notifications',
          channelDescription: isTr ? 'Bonus fırsatları hakkında bildirimler' : 'Notifications about bonus opportunities',
        ),
        iOS: _getIOSDetails(),
      ),
      payload: 'bonus_ready',
    );
  }

  /// 🏆 Takım Sıralamaya Girdi
  Future<void> showTeamRankingNotification(String teamName, int rank) async {
    final isTr = await _isTurkish();
    String rankText = rank == 1 ? '1st' : rank == 2 ? '2nd' : '3rd';
    String rankTextTr = rank == 1 ? '1.' : rank == 2 ? '2.' : '3.';
    await _notifications.show(
      2000 + rank,
      isTr ? 'Takımın Zirveye Çıktı! 🏆' : 'Your Team Reached the Top! 🏆',
      isTr 
          ? '$teamName bu ay en çok Hope toplayan $rankTextTr takım oldu! Devam edin 💪'
          : '$teamName became the $rankText team with most Hope this month! Keep going 💪',
      NotificationDetails(
        android: _getAndroidDetails(
          channelId: 'ranking_channel',
          channelName: isTr ? 'Sıralama Bildirimleri' : 'Ranking Notifications',
        ),
        iOS: _getIOSDetails(),
      ),
      payload: 'team_ranking',
    );
  }

  /// 🚶 Kişi Adım Sıralamasına Girdi
  Future<void> showStepRankingNotification(int rank) async {
    final isTr = await _isTurkish();
    String rankText = rank == 1 ? '1st' : rank == 2 ? '2nd' : '3rd';
    String rankTextTr = rank == 1 ? '1.' : rank == 2 ? '2.' : '3.';
    String emoji = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    await _notifications.show(
      3000 + rank,
      isTr ? 'Adım Şampiyonu! $emoji' : 'Step Champion! $emoji',
      isTr 
          ? 'Tebrikler! Bu ay en çok adım dönüştüren $rankTextTr kişi oldun. Muhteşemsin! ⭐'
          : 'Congratulations! You\'re the $rankText person with most converted steps this month. Amazing! ⭐',
      NotificationDetails(
        android: _getAndroidDetails(
          channelId: 'ranking_channel',
          channelName: isTr ? 'Sıralama Bildirimleri' : 'Ranking Notifications',
        ),
        iOS: _getIOSDetails(),
      ),
      payload: 'step_ranking',
    );
  }

  /// 💜 Kişi Bağış Sıralamasına Girdi
  Future<void> showDonationRankingNotification(int rank) async {
    final isTr = await _isTurkish();
    String rankText = rank == 1 ? '1st' : rank == 2 ? '2nd' : '3rd';
    String rankTextTr = rank == 1 ? '1.' : rank == 2 ? '2.' : '3.';
    String emoji = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    await _notifications.show(
      4000 + rank,
      isTr ? 'Umut Kahramanı! $emoji' : 'Hope Hero! $emoji',
      isTr 
          ? 'Bu ay en çok bağış yapan $rankTextTr kişi oldun! Kalbin çok güzel, teşekkürler 🙏'
          : 'You\'re the $rankText person with most donations this month! Your heart is beautiful, thank you 🙏',
      NotificationDetails(
        android: _getAndroidDetails(
          channelId: 'ranking_channel',
          channelName: isTr ? 'Sıralama Bildirimleri' : 'Ranking Notifications',
        ),
        iOS: _getIOSDetails(),
      ),
      payload: 'donation_ranking',
    );
  }

  /// 📦 Taşınan Adım Hatırlatması
  Future<void> showCarryOverReminder() async {
    final isTr = await _isTurkish();
    await _notifications.show(
      carryOverReminderId,
      isTr ? 'Adımların Seni Bekliyor! 👟' : 'Your Steps Are Waiting! 👟',
      isTr 
          ? 'Dünkü adımların kaybolmadı, bugüne taşıdık! Hemen Hope\'a dönüştür, umut ol 💚'
          : 'Yesterday\'s steps didn\'t disappear, we carried them over! Convert to Hope now, be hope 💚',
      NotificationDetails(
        android: _getAndroidDetails(
          channelId: 'reminder_channel',
          channelName: isTr ? 'Hatırlatma Bildirimleri' : 'Reminder Notifications',
        ),
        iOS: _getIOSDetails(),
      ),
      payload: 'carry_over',
    );
  }

  /// ⚠️ Ay Sonu Uyarı Bildirimi (Son 3, 2, 1 gün)
  /// [daysRemaining]: Ayın sonuna kalan gün sayısı (1, 2 veya 3)
  Future<void> showMonthEndWarning(int daysRemaining) async {
    final isTr = await _isTurkish();
    
    int notificationId;
    String titleTr, titleEn, bodyTr, bodyEn;
    
    switch (daysRemaining) {
      case 3:
        notificationId = monthEndWarning3DaysId;
        titleTr = 'Ay Sonu Yaklaşıyor! ⏰';
        titleEn = 'Month End Approaching! ⏰';
        bodyTr = 'Taşınan adımlarının sıfırlanmaması için son 3 gün! Şimdi Hope\'a dönüştür 💚';
        bodyEn = 'Only 3 days left before your carry-over steps reset! Convert to Hope now 💚';
        break;
      case 2:
        notificationId = monthEndWarning2DaysId;
        titleTr = 'Son 2 Gün! ⚠️';
        titleEn = 'Only 2 Days Left! ⚠️';
        bodyTr = 'Taşınan adımlarının sıfırlanmaması için son 2 gün! Acele et, Hope\'a dönüştür 🙏';
        bodyEn = 'Only 2 days left before your carry-over steps reset! Hurry up, convert to Hope 🙏';
        break;
      case 1:
      default:
        notificationId = monthEndWarning1DayId;
        titleTr = 'Son Gün! 🚨';
        titleEn = 'Last Day! 🚨';
        bodyTr = 'Taşınan adımlarının sıfırlanmaması için son gün! Yarın her şey sıfırlanacak, hemen dönüştür! 🔥';
        bodyEn = 'Last day before your carry-over steps reset! Everything resets tomorrow, convert now! 🔥';
        break;
    }
    
    await _notifications.show(
      notificationId,
      isTr ? titleTr : titleEn,
      isTr ? bodyTr : bodyEn,
      NotificationDetails(
        android: _getAndroidDetails(
          channelId: 'warning_channel',
          channelName: isTr ? 'Uyarı Bildirimleri' : 'Warning Notifications',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: _getIOSDetails(),
      ),
      payload: 'month_end_warning_$daysRemaining',
    );
  }

  /// 📅 Ay Sonu Uyarı Bildirimi Zamanla (Her ayın son 3 günü saat 15:00)
  Future<void> scheduleMonthEndWarnings() async {
    final isTr = await _isTurkish();
    final now = tz.TZDateTime.now(tz.local);
    
    // Bu ayın son gününü bul
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    
    // Son 3 gün için bildirimler zamanla
    for (int i = 3; i >= 1; i--) {
      final warningDay = lastDayOfMonth - i + 1; // Son 3, 2, 1. günler
      final scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, warningDay, 15, 0);
      
      // Eğer tarih geçmişse, bir sonraki ayın aynı günü için zamanla
      if (scheduledDate.isBefore(now)) {
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        final nextMonthLastDay = DateTime(nextYear, nextMonth + 1, 0).day;
        final nextWarningDay = nextMonthLastDay - i + 1;
        
        final nextScheduledDate = tz.TZDateTime(tz.local, nextYear, nextMonth, nextWarningDay, 15, 0);
        await _scheduleMonthEndWarningNotification(i, nextScheduledDate, isTr);
      } else {
        await _scheduleMonthEndWarningNotification(i, scheduledDate, isTr);
      }
    }
    print('Month-end warning notifications scheduled for last 3 days at 15:00');
  }

  /// Ay sonu uyarı bildirimini zamanla (internal helper)
  Future<void> _scheduleMonthEndWarningNotification(int daysRemaining, tz.TZDateTime scheduledDate, bool isTr) async {
    int notificationId;
    String titleTr, titleEn, bodyTr, bodyEn;
    
    switch (daysRemaining) {
      case 3:
        notificationId = monthEndWarning3DaysId;
        titleTr = 'Ay Sonu Yaklaşıyor! ⏰';
        titleEn = 'Month End Approaching! ⏰';
        bodyTr = 'Taşınan adımlarının sıfırlanmaması için son 3 gün! Şimdi Hope\'a dönüştür 💚';
        bodyEn = 'Only 3 days left before your carry-over steps reset! Convert to Hope now 💚';
        break;
      case 2:
        notificationId = monthEndWarning2DaysId;
        titleTr = 'Son 2 Gün! ⚠️';
        titleEn = 'Only 2 Days Left! ⚠️';
        bodyTr = 'Taşınan adımlarının sıfırlanmaması için son 2 gün! Acele et, Hope\'a dönüştür 🙏';
        bodyEn = 'Only 2 days left before your carry-over steps reset! Hurry up, convert to Hope 🙏';
        break;
      case 1:
      default:
        notificationId = monthEndWarning1DayId;
        titleTr = 'Son Gün! 🚨';
        titleEn = 'Last Day! 🚨';
        bodyTr = 'Taşınan adımlarının sıfırlanmaması için son gün! Yarın her şey sıfırlanacak, hemen dönüştür! 🔥';
        bodyEn = 'Last day before your carry-over steps reset! Everything resets tomorrow, convert now! 🔥';
        break;
    }
    
    await _notifications.zonedSchedule(
      notificationId,
      isTr ? titleTr : titleEn,
      isTr ? bodyTr : bodyEn,
      scheduledDate,
      NotificationDetails(
        android: _getAndroidDetails(
          channelId: 'warning_channel',
          channelName: isTr ? 'Uyarı Bildirimleri' : 'Warning Notifications',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: _getIOSDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'month_end_warning_$daysRemaining',
    );
    print('Month-end warning ($daysRemaining days) scheduled for: $scheduledDate');
  }

  /// 🎖️ Başarı Bildirimi
  Future<void> showAchievementNotification(String title, String message) async {
    final isTurkish = await _isTurkish();
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      message,
      NotificationDetails(
        android: _getAndroidDetails(
          channelId: 'achievement_channel',
          channelName: isTurkish ? 'Başarı Bildirimleri' : 'Achievement Notifications',
        ),
        iOS: _getIOSDetails(),
      ),
      payload: 'achievement',
    );
  }

  // ==================== ZAMANLANMIŞ BİLDİRİMLER ====================

  /// ☀️ Sabah 11:00 Motivasyon Bildirimi Zamanla
  Future<void> scheduleMorningMotivation() async {
    // Dil kontrolü yap
    final isTurkish = await _isTurkish();
    
    // Rastgele mesaj seç (dile göre)
    final random = Random();
    final messages = isTurkish ? _morningMessagesTr : _morningMessagesEn;
    final message = messages[random.nextInt(messages.length)];

    await _notifications.zonedSchedule(
      morningMotivationId,
      message['title']!,
      message['body']!,
      _nextInstanceOfTime(11, 0), // Sabah 11:00
      NotificationDetails(
        android: _getAndroidDetails(
          channelId: 'motivation_channel',
          channelName: isTurkish ? 'Motivasyon Bildirimleri' : 'Motivation Notifications',
        ),
        iOS: _getIOSDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Her gün tekrarla
      payload: 'morning_motivation',
    );
    print('Morning motivation notification scheduled: 11:00');
  }

  /// 🌙 Akşam 20:00 Hatırlatma Bildirimi Zamanla
  Future<void> scheduleEveningReminder(int unconvertedSteps) async {
    if (unconvertedSteps <= 0) return;

    // Dil kontrolü yap
    final isTurkish = await _isTurkish();
    
    // Rastgele mesaj seç
    final random = Random();
    final messages = isTurkish ? _eveningMessagesTr : _eveningMessagesEn;
    final message = messages[random.nextInt(messages.length)];
    
    // {steps} placeholder'ını değiştir
    final title = message['title']!;
    final body = message['body']!.replaceAll('{steps}', unconvertedSteps.toString());

    await _notifications.zonedSchedule(
      eveningReminderId,
      title,
      body,
      _nextInstanceOfTime(20, 0), // Akşam 20:00
      NotificationDetails(
        android: _getAndroidDetails(
          channelId: 'reminder_channel',
          channelName: isTurkish ? 'Hatırlatma Bildirimleri' : 'Reminder Notifications',
        ),
        iOS: _getIOSDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'evening_reminder',
    );
    print('Evening reminder notification scheduled: 20:00');
  }

  /// Belirli saatte sonraki instance'ı hesapla
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Tüm günlük bildirimleri zamanla
  Future<void> scheduleAllDailyNotifications() async {
    await scheduleMorningMotivation();
    await scheduleMonthEndWarnings(); // Ay sonu uyarılarını zamanla
    print('All daily notifications scheduled!');
  }

  /// Belirli bir bildirimi iptal et
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Tüm bildirimleri iptal et
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Bildirim ayarlarını kaydet
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    
    if (!enabled) {
      await cancelAllNotifications();
    } else {
      await scheduleAllDailyNotifications();
    }
  }

  /// Bildirim ayarlarını al
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }
}
