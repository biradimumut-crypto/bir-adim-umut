import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dil Provider - Uygulama dilini yönetir
class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  
  Locale _currentLocale = const Locale('tr', 'TR');
  bool _isLoaded = false;

  Locale get currentLocale => _currentLocale;
  bool get isLoaded => _isLoaded;
  String get languageCode => _currentLocale.languageCode;
  bool get isTurkish => _currentLocale.languageCode == 'tr';
  bool get isEnglish => _currentLocale.languageCode == 'en';
  bool get isGerman => _currentLocale.languageCode == 'de';
  bool get isJapanese => _currentLocale.languageCode == 'ja';
  bool get isSpanish => _currentLocale.languageCode == 'es';
  bool get isRomanian => _currentLocale.languageCode == 'ro';

  LanguageProvider() {
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey) ?? 'tr';
    
    switch (savedLanguage) {
      case 'en':
        _currentLocale = const Locale('en', 'US');
        break;
      case 'de':
        _currentLocale = const Locale('de', 'DE');
        break;
      case 'ja':
        _currentLocale = const Locale('ja', 'JP');
        break;
      case 'es':
        _currentLocale = const Locale('es', 'ES');
        break;
      case 'ro':
        _currentLocale = const Locale('ro', 'RO');
        break;
      default:
        _currentLocale = const Locale('tr', 'TR');
    }
    
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    switch (languageCode) {
      case 'en':
        _currentLocale = const Locale('en', 'US');
        break;
      case 'de':
        _currentLocale = const Locale('de', 'DE');
        break;
      case 'ja':
        _currentLocale = const Locale('ja', 'JP');
        break;
      case 'es':
        _currentLocale = const Locale('es', 'ES');
        break;
      case 'ro':
        _currentLocale = const Locale('ro', 'RO');
        break;
      default:
        _currentLocale = const Locale('tr', 'TR');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    // Cycle through languages: tr -> en -> de -> ja -> es -> ro -> tr
    switch (_currentLocale.languageCode) {
      case 'tr':
        await setLanguage('en');
        break;
      case 'en':
        await setLanguage('de');
        break;
      case 'de':
        await setLanguage('ja');
        break;
      case 'ja':
        await setLanguage('es');
        break;
      case 'es':
        await setLanguage('ro');
        break;
      case 'ro':
        await setLanguage('tr');
        break;
      default:
        await setLanguage('en');
    }
  }

  /// Helper method for 6-language translation
  String _t(String tr, String en, String de, String ja, String es, String ro) {
    switch (_currentLocale.languageCode) {
      case 'de': return de;
      case 'ja': return ja;
      case 'es': return es;
      case 'ro': return ro;
      case 'en': return en;
      default: return tr;
    }
  }

  // Çeviri metinleri
  String get appName => 'OneHopeStep';
  String get welcomeMessage => _t(
    'Bir Adımla Başlayan Hikayen, Binlerce Umuda Dönüşüyor.',
    'Your Story Starting with One Step, Turns into Thousands of Hopes.',
    'Deine Geschichte, die mit einem Schritt beginnt, verwandelt sich in Tausende Hoffnungen.',
    '一歩から始まるあなたの物語が、何千もの希望に変わります。',
    'Tu historia que comienza con un paso, se convierte en miles de esperanzas.',
    'Povestea ta care începe cu un pas, se transformă în mii de speranțe.',
  );
  String get email => _t('E-posta', 'Email', 'E-Mail', 'メール', 'Correo', 'Email');
  String get password => _t('Şifre', 'Password', 'Passwort', 'パスワード', 'Contraseña', 'Parolă');
  String get login => _t('Giriş Yap', 'Sign In', 'Anmelden', 'ログイン', 'Iniciar Sesión', 'Conectare');
  String get signUp => _t('Kayıt Ol', 'Sign Up', 'Registrieren', '登録', 'Registrarse', 'Înregistrare');
  String get forgotPassword => _t('Şifremi Unuttum', 'Forgot Password', 'Passwort vergessen', 'パスワードを忘れた', 'Olvidé mi contraseña', 'Am uitat parola');
  String get noAccount => _t('Hesabın yok mu?', "Don't have an account?", 'Kein Konto?', 'アカウントがない？', '¿No tienes cuenta?', 'Nu ai cont?');
  String get or => _t('veya', 'or', 'oder', 'または', 'o', 'sau');
  String get emailHint => _t('ornek@email.com', 'example@email.com', 'beispiel@email.com', 'example@email.com', 'ejemplo@email.com', 'exemplu@email.com');
  String get passwordHint => '••••••••';
  
  // Dashboard
  String get home => _t('Ana Sayfa', 'Home', 'Startseite', 'ホーム', 'Inicio', 'Acasă');
  String get donate => _t('Bağışla', 'Donate', 'Spenden', '寄付', 'Donar', 'Donează');
  String get teams => _t('Takımlar', 'Teams', 'Teams', 'チーム', 'Equipos', 'Echipe');
  String get profile => _t('Profil', 'Profile', 'Profil', 'プロフィール', 'Perfil', 'Profil');
  
  // Profile
  String get editProfile => _t('Profili Düzenle', 'Edit Profile', 'Profil bearbeiten', 'プロフィール編集', 'Editar Perfil', 'Editare Profil');
  String get activityHistory => _t('Aktivite Geçmişi', 'Activity History', 'Aktivitätsverlauf', 'アクティビティ履歴', 'Historial de Actividad', 'Istoric Activitate');
  String get notifications => _t('Bildirimler', 'Notifications', 'Benachrichtigungen', '通知', 'Notificaciones', 'Notificări');
  String get settings => _t('Ayarlar', 'Settings', 'Einstellungen', '設定', 'Configuración', 'Setări');
  String get darkTheme => _t('Koyu Tema', 'Dark Theme', 'Dunkles Thema', 'ダークテーマ', 'Tema Oscuro', 'Temă Întunecată');
  String get lightTheme => _t('Açık Tema', 'Light Theme', 'Helles Thema', 'ライトテーマ', 'Tema Claro', 'Temă Deschisă');
  String get language => _t('Dil', 'Language', 'Sprache', '言語', 'Idioma', 'Limbă');
  String get helpSupport => _t('Yardım & Destek', 'Help & Support', 'Hilfe & Support', 'ヘルプ＆サポート', 'Ayuda y Soporte', 'Ajutor & Suport');
  String get privacyPolicy => _t('Gizlilik Politikası', 'Privacy Policy', 'Datenschutzrichtlinie', 'プライバシーポリシー', 'Política de Privacidad', 'Politica de Confidențialitate');
  String get termsOfService => _t('Kullanım Koşulları', 'Terms of Service', 'Nutzungsbedingungen', '利用規約', 'Términos de Servicio', 'Termeni și Condiții');
  String get logout => _t('Çıkış Yap', 'Sign Out', 'Abmelden', 'ログアウト', 'Cerrar Sesión', 'Deconectare');
  String get comingSoon => _t('Yakında!', 'Coming Soon!', 'Demnächst!', '近日公開！', '¡Próximamente!', 'În curând!');
  
  // Steps & Hope
  String get steps => _t('Adım', 'Steps', 'Schritte', '歩数', 'Pasos', 'Pași');
  String get todaySteps => _t('Bugünkü Adımlar', 'Today\'s Steps', 'Heutige Schritte', '今日の歩数', 'Pasos de Hoy', 'Pașii de Azi');
  String get convertSteps => _t('Adımları Dönüştür', 'Convert Steps', 'Schritte umwandeln', '歩数を変換', 'Convertir Pasos', 'Convertește Pași');
  String get hopeBalance => _t('Hope Bakiyesi', 'Hope Balance', 'Hope-Guthaben', 'Hopeバランス', 'Balance de Hope', 'Sold Hope');
  String get hope => 'Hope';
  String get team => _t('Takım', 'Team', 'Team', 'チーム', 'Equipo', 'Echipă');
  String get membership => _t('Üyelik', 'Membership', 'Mitgliedschaft', 'メンバーシップ', 'Membresía', 'Membru');
  String get hasTeam => _t('Var', 'Yes', 'Ja', 'はい', 'Sí', 'Da');
  String get noTeam => _t('Yok', 'No', 'Nein', 'いいえ', 'No', 'Nu');
  String get user => _t('Kullanıcı', 'User', 'Benutzer', 'ユーザー', 'Usuario', 'Utilizator');
  String get version => 'OneHopeStep v1.0.0';
  
  // Home Screen
  String get goodMorning => _t('Günaydın', 'Good Morning', 'Guten Morgen', 'おはよう', 'Buenos Días', 'Bună Dimineața');
  String get goodAfternoon => _t('İyi Günler', 'Good Afternoon', 'Guten Tag', 'こんにちは', 'Buenas Tardes', 'Bună Ziua');
  String get goodEvening => _t('İyi Akşamlar', 'Good Evening', 'Guten Abend', 'こんばんは', 'Buenas Noches', 'Bună Seara');
  String get dailyGoal => _t('Günlük Hedef', 'Daily Goal', 'Tagesziel', '毎日の目標', 'Meta Diaria', 'Obiectiv Zilnic');
  String get weeklyStats => _t('Haftalık İstatistikler', 'Weekly Stats', 'Wöchentliche Statistiken', '週間統計', 'Estadísticas Semanales', 'Statistici Săptămânale');
  String get totalSteps => _t('Toplam Adım', 'Total Steps', 'Gesamte Schritte', '合計歩数', 'Pasos Totales', 'Total Pași');
  String get totalHope => _t('Toplam Hope', 'Total Hope', 'Gesamt Hope', '合計Hope', 'Hope Total', 'Total Hope');
  String get totalDonations => _t('Toplam Bağış', 'Total Donations', 'Gesamte Spenden', '合計寄付', 'Donaciones Totales', 'Total Donații');
  String get quickActions => _t('Hızlı İşlemler', 'Quick Actions', 'Schnellaktionen', 'クイックアクション', 'Acciones Rápidas', 'Acțiuni Rapide');
  String get convertNow => _t('Şimdi Dönüştür', 'Convert Now', 'Jetzt umwandeln', '今すぐ変換', 'Convertir Ahora', 'Convertește Acum');
  String get donateNow => _t('Bağış Yap', 'Donate Now', 'Jetzt spenden', '今すぐ寄付', 'Donar Ahora', 'Donează Acum');
  String get joinTeam => _t('Takıma Katıl', 'Join Team', 'Team beitreten', 'チームに参加', 'Unirse al Equipo', 'Alătură-te Echipei');
  String get leaderboard => _t('Liderlik Tablosu', 'Leaderboard', 'Rangliste', 'リーダーボード', 'Tabla de Líderes', 'Clasament');
  String get recentActivity => _t('Son Aktiviteler', 'Recent Activity', 'Letzte Aktivitäten', '最近のアクティビティ', 'Actividad Reciente', 'Activitate Recentă');
  String get seeAll => _t('Tümünü Gör', 'See All', 'Alle anzeigen', 'すべて見る', 'Ver Todo', 'Vezi Tot');
  String get noActivityYet => _t('Henüz aktivite yok', 'No activity yet', 'Noch keine Aktivität', 'まだアクティビティがありません', 'Sin actividad aún', 'Nicio activitate încă');
  String get startWalking => _t('Yürümeye başla!', 'Start walking!', 'Fang an zu laufen!', '歩き始めよう！', '¡Empieza a caminar!', 'Începe să mergi!');
  
  // Donate Screen
  String get selectCharity => _t('Vakıf Seç', 'Select Charity', 'Organisation auswählen', '慈善団体を選択', 'Seleccionar Organización', 'Selectează Organizația');
  String get donationAmount => _t('Bağış Miktarı', 'Donation Amount', 'Spendenbetrag', '寄付金額', 'Cantidad de Donación', 'Sumă Donație');
  String get yourBalance => _t('Bakiyeniz', 'Your Balance', 'Ihr Guthaben', 'あなたの残高', 'Su Balance', 'Soldul Tău');
  String get donateButton => _t('Bağışla', 'Donate', 'Spenden', '寄付する', 'Donar', 'Donează');
  String get donationSuccess => _t('Bağış başarılı!', 'Donation successful!', 'Spende erfolgreich!', '寄付成功！', '¡Donación exitosa!', 'Donație reușită!');
  String get donationFailed => _t('Bağış başarısız', 'Donation failed', 'Spende fehlgeschlagen', '寄付失敗', 'Donación fallida', 'Donație eșuată');
  String get insufficientBalance => _t('Yetersiz bakiye', 'Insufficient balance', 'Unzureichendes Guthaben', '残高不足', 'Saldo insuficiente', 'Sold insuficient');
  String get enterAmount => _t('Miktar girin', 'Enter amount', 'Betrag eingeben', '金額を入力', 'Ingrese cantidad', 'Introduceți suma');
  String get minDonation => _t('Minimum bağış: 1 Hope', 'Minimum donation: 1 Hope', 'Mindestspende: 1 Hope', '最低寄付: 1 Hope', 'Donación mínima: 1 Hope', 'Donație minimă: 1 Hope');
  String get charities => _t('Vakıflar', 'Charities', 'Organisationen', '慈善団体', 'Organizaciones', 'Organizații');
  String get allCharities => _t('Tüm Vakıflar', 'All Charities', 'Alle Organisationen', 'すべての慈善団体', 'Todas las Organizaciones', 'Toate Organizațiile');
  String get featuredCharities => _t('Öne Çıkan Vakıflar', 'Featured Charities', 'Empfohlene Organisationen', 'おすすめの慈善団体', 'Organizaciones Destacadas', 'Organizații Recomandate');
  
  // Teams Screen
  String get myTeam => _t('Takımım', 'My Team', 'Mein Team', 'マイチーム', 'Mi Equipo', 'Echipa Mea');
  String get createTeam => _t('Takım Oluştur', 'Create Team', 'Team erstellen', 'チームを作成', 'Crear Equipo', 'Creează Echipă');
  String get teamName => _t('Takım Adı', 'Team Name', 'Teamname', 'チーム名', 'Nombre del Equipo', 'Nume Echipă');
  String get teamMembers => _t('Takım Üyeleri', 'Team Members', 'Teammitglieder', 'チームメンバー', 'Miembros del Equipo', 'Membri Echipă');
  String get teamStats => _t('Takım İstatistikleri', 'Team Stats', 'Teamstatistiken', 'チーム統計', 'Estadísticas del Equipo', 'Statistici Echipă');
  String get leaveTeam => _t('Takımdan Ayrıl', 'Leave Team', 'Team verlassen', 'チームを離れる', 'Abandonar Equipo', 'Părăsește Echipa');
  String get inviteMembers => _t('Üye Davet Et', 'Invite Members', 'Mitglieder einladen', 'メンバーを招待', 'Invitar Miembros', 'Invită Membri');
  String get noTeamYet => _t('Henüz bir takımın yok', 'You don\'t have a team yet', 'Du hast noch kein Team', 'まだチームがありません', 'Aún no tienes equipo', 'Nu ai încă o echipă');
  String get joinOrCreate => _t('Katıl veya oluştur!', 'Join or create one!', 'Tritt bei oder erstelle eins!', '参加または作成！', '¡Únete o crea uno!', 'Alătură-te sau creează!');
  String get searchTeams => _t('Takım Ara', 'Search Teams', 'Teams suchen', 'チームを検索', 'Buscar Equipos', 'Caută Echipe');
  String get popularTeams => _t('Popüler Takımlar', 'Popular Teams', 'Beliebte Teams', '人気のチーム', 'Equipos Populares', 'Echipe Populare');
  String get members => _t('Üye', 'Members', 'Mitglieder', 'メンバー', 'Miembros', 'Membri');
  String get joined => _t('Katıldı', 'Joined', 'Beigetreten', '参加した', 'Se unió', 'S-a alăturat');
  String get teamCreated => _t('Takım oluşturuldu!', 'Team created!', 'Team erstellt!', 'チーム作成！', '¡Equipo creado!', 'Echipă creată!');
  String get teamJoined => _t('Takıma katıldın!', 'You joined the team!', 'Du bist dem Team beigetreten!', 'チームに参加しました！', '¡Te uniste al equipo!', 'Te-ai alăturat echipei!');
  String get teamLeft => _t('Takımdan ayrıldın', 'You left the team', 'Du hast das Team verlassen', 'チームを離れました', 'Abandonaste el equipo', 'Ai părăsit echipa');
  
  // Profile extras
  String get fullName => _t('Ad Soyad', 'Full Name', 'Vollständiger Name', '氏名', 'Nombre Completo', 'Nume Complet');
  String get save => _t('Kaydet', 'Save', 'Speichern', '保存', 'Guardar', 'Salvează');
  String get cancel => _t('İptal', 'Cancel', 'Abbrechen', 'キャンセル', 'Cancelar', 'Anulează');
  String get camera => _t('Kamera', 'Camera', 'Kamera', 'カメラ', 'Cámara', 'Cameră');
  String get gallery => _t('Galeri', 'Gallery', 'Galerie', 'ギャラリー', 'Galería', 'Galerie');
  String get takePhoto => _t('Fotoğraf çek', 'Take photo', 'Foto aufnehmen', '写真を撮る', 'Tomar foto', 'Fă o poză');
  String get chooseFromGallery => _t('Galeriden seç', 'Choose from gallery', 'Aus Galerie auswählen', 'ギャラリーから選択', 'Elegir de galería', 'Alege din galerie');
  String get selectPhoto => _t('Fotoğraf Seç', 'Select Photo', 'Foto auswählen', '写真を選択', 'Seleccionar Foto', 'Selectează Poza');
  String get days => _t('gün', 'days', 'Tage', '日', 'días', 'zile');
  
  // Activity types
  String get donation => _t('Bağış', 'Donation', 'Spende', '寄付', 'Donación', 'Donație');
  String get stepConversion => _t('Adım Dönüştürüldü', 'Steps Converted', 'Schritte umgewandelt', '歩数変換', 'Pasos Convertidos', 'Pași Convertiți');
  String get teamJoinedActivity => _t('Takıma Katıldı', 'Joined Team', 'Team beigetreten', 'チームに参加', 'Unido al Equipo', 'S-a Alăturat Echipei');
  String get teamCreatedActivity => _t('Takım Kuruldu', 'Team Created', 'Team erstellt', 'チーム作成', 'Equipo Creado', 'Echipă Creată');
  String get activity => _t('Aktivite', 'Activity', 'Aktivität', 'アクティビティ', 'Actividad', 'Activitate');
  String get carryoverConversion => _t('Taşınan Adım Dönüştürüldü', 'Carryover Steps Converted', 'Übertragene Schritte umgewandelt', '繰り越し歩数変換', 'Pasos Transferidos Convertidos', 'Pași Reportați Convertiți');
  
  // Confirmation
  String get areYouSure => _t('Emin misiniz?', 'Are you sure?', 'Sind Sie sicher?', '本当ですか？', '¿Estás seguro?', 'Ești sigur?');
  String get yes => _t('Evet', 'Yes', 'Ja', 'はい', 'Sí', 'Da');
  String get no => _t('Hayır', 'No', 'Nein', 'いいえ', 'No', 'Nu');
  String get confirm => _t('Onayla', 'Confirm', 'Bestätigen', '確認', 'Confirmar', 'Confirmă');
  String get delete => _t('Sil', 'Delete', 'Löschen', '削除', 'Eliminar', 'Șterge');
  String get edit => _t('Düzenle', 'Edit', 'Bearbeiten', '編集', 'Editar', 'Editează');
  
  // Loading & Status
  String get loading => _t('Yükleniyor...', 'Loading...', 'Laden...', '読み込み中...', 'Cargando...', 'Se încarcă...');
  String get error => _t('Hata', 'Error', 'Fehler', 'エラー', 'Error', 'Eroare');
  String get success => _t('Başarılı', 'Success', 'Erfolg', '成功', 'Éxito', 'Succes');
  String get retry => _t('Tekrar Dene', 'Retry', 'Wiederholen', '再試行', 'Reintentar', 'Reîncearcă');
  String get noData => _t('Veri yok', 'No data', 'Keine Daten', 'データなし', 'Sin datos', 'Fără date');
  String get dataLoadError => _t('Veriler yüklenemedi', 'Failed to load data', 'Daten konnten nicht geladen werden', 'データの読み込みに失敗', 'Error al cargar datos', 'Eroare la încărcare');
  
  // Errors
  String get loginFailed => _t('Giriş başarısız', 'Login failed', 'Anmeldung fehlgeschlagen', 'ログイン失敗', 'Error de inicio de sesión', 'Autentificare eșuată');
  String get googleLoginFailed => _t('Google girişi başarısız', 'Google sign in failed', 'Google-Anmeldung fehlgeschlagen', 'Googleログイン失敗', 'Error de inicio con Google', 'Autentificare Google eșuată');
  String get googleSignInCancelled => _t('Google girişi iptal edildi', 'Google sign in cancelled', 'Google-Anmeldung abgebrochen', 'Googleログインがキャンセルされました', 'Inicio con Google cancelado', 'Autentificare Google anulată');
  String get appleLoginFailed => _t('Apple girişi başarısız', 'Apple sign in failed', 'Apple-Anmeldung fehlgeschlagen', 'Appleログイン失敗', 'Error de inicio con Apple', 'Autentificare Apple eșuată');
  String get appleSignInTitle => _t('Apple ile Giriş', 'Sign in with Apple', 'Mit Apple anmelden', 'Appleでサインイン', 'Iniciar con Apple', 'Conectare cu Apple');
  String get appleSignInComingSoon => _t(
    'Apple ile giriş yapılıyor...',
    'Signing in with Apple...',
    'Mit Apple anmelden...',
    'Appleでサインイン中...',
    'Iniciando con Apple...',
    'Conectare cu Apple...',
  );
  String get invalidEmail => _t('Geçersiz e-posta adresi', 'Invalid email address', 'Ungültige E-Mail-Adresse', '無効なメールアドレス', 'Dirección de correo inválida', 'Adresă email invalidă');
  String get wrongPassword => _t('Yanlış şifre', 'Wrong password', 'Falsches Passwort', 'パスワードが間違っています', 'Contraseña incorrecta', 'Parolă greșită');
  String get userNotFound => _t('Kullanıcı bulunamadı', 'User not found', 'Benutzer nicht gefunden', 'ユーザーが見つかりません', 'Usuario no encontrado', 'Utilizator negăsit');
  String get emailRequired => _t('E-posta gerekli', 'Email is required', 'E-Mail erforderlich', 'メールアドレスが必要です', 'Correo requerido', 'Email necesar');
  String get passwordRequired => _t('Şifre gerekli', 'Password is required', 'Passwort erforderlich', 'パスワードが必要です', 'Contraseña requerida', 'Parolă necesară');
  String get weakPassword => _t('Şifre çok zayıf. En az 6 karakter olmalı.', 'Password is too weak. Must be at least 6 characters.', 'Passwort ist zu schwach. Mindestens 6 Zeichen erforderlich.', 'パスワードが弱すぎます。6文字以上必要です。', 'Contraseña muy débil. Mínimo 6 caracteres.', 'Parolă prea slabă. Minim 6 caractere.');
  String get accountExistsWithDifferentCredential => _t(
    'Bu e-posta başka bir hesapla kaydedilmiş',
    'This email is already registered with a different account',
    'Diese E-Mail ist bereits mit einem anderen Konto registriert',
    'このメールアドレスは別のアカウントで登録されています',
    'Este correo ya está registrado con otra cuenta',
    'Acest email este deja înregistrat cu alt cont',
  );
  
  /// Hata kodu çevirisi
  String translateError(String errorCode) {
    switch (errorCode) {
      case 'GOOGLE_SIGN_IN_CANCELLED':
        return googleSignInCancelled;
      case 'weak-password':
        return weakPassword;
      case 'email-already-in-use':
        return emailAlreadyInUse;
      case 'invalid-email':
        return invalidEmail;
      case 'user-not-found':
        return userNotFound;
      case 'wrong-password':
        return wrongPassword;
      case 'account-exists-with-different-credential':
        return accountExistsWithDifferentCredential;
      case 'device_already_used':
        return deviceAlreadyUsedError;
      default:
        return _t('Hata: $errorCode', 'Error: $errorCode', 'Fehler: $errorCode', 'エラー: $errorCode', 'Error: $errorCode', 'Eroare: $errorCode');
    }
  }
  
  // Device Error (Fraud Prevention)
  String get deviceAlreadyUsedError => _t(
    'Bu cihaz bugün başka bir hesapla kullanıldı. Her cihaz günde sadece bir hesapla adım dönüştürebilir.',
    'This device was used with another account today. Each device can only convert steps with one account per day.',
    'Dieses Gerät wurde heute mit einem anderen Konto verwendet. Jedes Gerät kann nur einmal pro Tag Schritte umwandeln.',
    'このデバイスは今日別のアカウントで使用されました。各デバイスは1日1アカウントのみ歩数変換できます。',
    'Este dispositivo se usó con otra cuenta hoy. Cada dispositivo solo puede convertir pasos con una cuenta por día.',
    'Acest dispozitiv a fost folosit cu alt cont azi. Fiecare dispozitiv poate converti pași doar cu un cont pe zi.',
  );
  String get deviceFraudWarningTitle => _t(
    'Cihaz Kısıtlaması',
    'Device Restriction',
    'Gerätebeschränkung',
    'デバイス制限',
    'Restricción de Dispositivo',
    'Restricție Dispozitiv',
  );
  
  // Success
  String get profileUpdated => _t('Profil güncellendi!', 'Profile updated!', 'Profil aktualisiert!', 'プロフィール更新！', '¡Perfil actualizado!', 'Profil actualizat!');
  String get passwordResetSent => _t(
    'Şifre sıfırlama e-postası gönderildi',
    'Password reset email sent',
    'E-Mail zum Zurücksetzen des Passworts gesendet',
    'パスワードリセットメールを送信しました',
    'Correo de restablecimiento enviado',
    'Email de resetare parolă trimis',
  );
  
  // Sign Up Screen
  String get createAccount => _t('Hesap Oluştur', 'Create Account', 'Konto erstellen', 'アカウント作成', 'Crear Cuenta', 'Creează Cont');
  String get signUpWelcome => _t(
    'Aramıza katıl ve umut yaymaya başla!',
    'Join us and start spreading hope!',
    'Schließ dich uns an und verbreite Hoffnung!',
    '私たちに参加して希望を広げよう！',
    '¡Únete y comienza a difundir esperanza!',
    'Alătură-te și începe să răspândești speranță!',
  );
  String get confirmPassword => _t('Şifre Tekrar', 'Confirm Password', 'Passwort bestätigen', 'パスワード確認', 'Confirmar Contraseña', 'Confirmă Parola');
  String get alreadyHaveAccount => _t('Zaten hesabın var mı?', 'Already have an account?', 'Haben Sie bereits ein Konto?', 'すでにアカウントをお持ちですか？', '¿Ya tienes cuenta?', 'Ai deja un cont?');
  String get passwordsNotMatch => _t('Şifreler eşleşmiyor', 'Passwords do not match', 'Passwörter stimmen nicht überein', 'パスワードが一致しません', 'Las contraseñas no coinciden', 'Parolele nu se potrivesc');
  String get passwordTooShort => _t('Şifre en az 6 karakter olmalı', 'Password must be at least 6 characters', 'Passwort muss mindestens 6 Zeichen haben', 'パスワードは6文字以上必要です', 'La contraseña debe tener al menos 6 caracteres', 'Parola trebuie să aibă minim 6 caractere');
  String get signUpSuccess => _t('Kayıt başarılı!', 'Registration successful!', 'Registrierung erfolgreich!', '登録成功！', '¡Registro exitoso!', 'Înregistrare reușită!');
  String get signUpFailed => _t('Kayıt başarısız', 'Registration failed', 'Registrierung fehlgeschlagen', '登録失敗', 'Error en el registro', 'Înregistrare eșuată');
  String get emailAlreadyInUse => _t('Bu mail adresine kayıtlı başka kullanıcı mevcut', 'This email is already registered to another account', 'Diese E-Mail ist bereits für ein anderes Konto registriert', 'このメールアドレスは既に登録されています', 'Este correo ya está registrado', 'Acest email este deja înregistrat');
  String get nameRequired => _t('Ad Soyad gerekli', 'Full name is required', 'Vollständiger Name erforderlich', '氏名が必要です', 'Nombre completo requerido', 'Nume complet necesar');
  String get fullNameHint => _t('Örn: Ahmet Yılmaz', 'E.g: John Doe', 'z.B.: Max Mustermann', '例：山田太郎', 'Ej: Juan García', 'Ex: Ion Popescu');
  
  // Password Reset
  String get resetPassword => _t('Şifre Sıfırla', 'Reset Password', 'Passwort zurücksetzen', 'パスワードをリセット', 'Restablecer Contraseña', 'Resetează Parola');
  String get resetPasswordDesc => _t(
    'E-posta adresinizi girin, şifre sıfırlama bağlantısı göndereceğiz.',
    'Enter your email address and we\'ll send you a password reset link.',
    'Geben Sie Ihre E-Mail-Adresse ein, wir senden Ihnen einen Link zum Zurücksetzen.',
    'メールアドレスを入力してください。リセットリンクを送信します。',
    'Ingresa tu correo y te enviaremos un enlace para restablecer.',
    'Introdu emailul și îți vom trimite un link de resetare.',
  );
  String get sendResetLink => _t('Sıfırlama Bağlantısı Gönder', 'Send Reset Link', 'Link senden', 'リセットリンクを送信', 'Enviar Enlace', 'Trimite Link');
  String get backToLogin => _t('Girişe Dön', 'Back to Login', 'Zurück zur Anmeldung', 'ログインに戻る', 'Volver al Inicio', 'Înapoi la Conectare');
  String get checkYourEmail => _t('E-postanızı kontrol edin', 'Check your email', 'Überprüfen Sie Ihre E-Mail', 'メールを確認してください', 'Revisa tu correo', 'Verifică emailul');
  
  // Dashboard extras
  String get welcome => _t('Hoşgeldiniz', 'Welcome', 'Willkommen', 'ようこそ', 'Bienvenido', 'Bun venit');
  String get hopeBalanceTitle => _t('Hope Bakiyesi', 'Hope Balance', 'Hope-Guthaben', 'Hope残高', 'Balance de Hope', 'Sold Hope');
  String get availableToConvert => _t('Dönüştürülebilir Adım', 'Available to Convert', 'Verfügbar zum Umwandeln', '変換可能な歩数', 'Disponible para Convertir', 'Disponibil de Convertit');
  String get todayProgress => _t('Bugünkü İlerleme', 'Today\'s Progress', 'Heutiger Fortschritt', '今日の進捗', 'Progreso de Hoy', 'Progresul de Azi');
  String get dailySteps => _t('Günlük Adım', 'Daily Steps', 'Tägliche Schritte', '毎日の歩数', 'Pasos Diarios', 'Pași Zilnici');
  String get converted => _t('Dönüştürüldü', 'Converted', 'Umgewandelt', '変換済み', 'Convertido', 'Convertit');
  String get remaining => _t('Kalan', 'Remaining', 'Verbleibend', '残り', 'Restante', 'Rămas');
  String get carryOver => _t('Taşınan', 'Carry Over', 'Übertragen', '繰り越し', 'Transferido', 'Reportat');
  String get weeklyProgress => _t('Haftalık İlerleme', 'Weekly Progress', 'Wöchentlicher Fortschritt', '週間進捗', 'Progreso Semanal', 'Progres Săptămânal');
  String get convertStepsButton => _t('Adımları Dönüştür', 'Convert Steps', 'Schritte umwandeln', '歩数を変換', 'Convertir Pasos', 'Convertește Pași');
  String get cooldownActive => _t('Bekleme Süresi', 'Cooldown Active', 'Wartezeit aktiv', 'クールダウン中', 'Tiempo de Espera', 'Perioadă de Așteptare');
  String get noStepsToConvert => _t('Dönüştürülecek adım yok', 'No steps to convert', 'Keine Schritte zum Umwandeln', '変換する歩数がありません', 'Sin pasos para convertir', 'Fără pași de convertit');
  String get conversionSuccess => _t('Dönüştürme başarılı!', 'Conversion successful!', 'Umwandlung erfolgreich!', '変換成功！', '¡Conversión exitosa!', 'Conversie reușită!');
  String get stepsConverted => _t('adım dönüştürüldü', 'steps converted', 'Schritte umgewandelt', '歩数が変換されました', 'pasos convertidos', 'pași convertiți');
  String get hopeEarned => _t('Hope kazanıldı', 'Hope earned', 'Hope verdient', 'Hope獲得', 'Hope ganado', 'Hope câștigat');
  
  // Leaderboard
  String get leaderboardTitle => _t('Liderlik Tablosu', 'Leaderboard', 'Rangliste', 'リーダーボード', 'Tabla de Líderes', 'Clasament');
  String get stepChampions => _t('Adım Şampiyonları', 'Step Champions', 'Schritt-Champions', '歩数チャンピオン', 'Campeones de Pasos', 'Campionii Pașilor');
  String get hopeHeroes => _t('Umut Kahramanları', 'Hope Heroes', 'Hope-Helden', 'Hopeヒーロー', 'Héroes de Hope', 'Eroii Speranței');
  String get topTeams => _t('En İyi Takımlar', 'Top Teams', 'Top-Teams', 'トップチーム', 'Mejores Equipos', 'Top Echipe');
  String get monthlyRanking => _t('Aylık Sıralama', 'Monthly Ranking', 'Monatliches Ranking', '月間ランキング', 'Ranking Mensual', 'Clasament Lunar');
  String get rank => _t('Sıra', 'Rank', 'Rang', '順位', 'Puesto', 'Loc');
  String get yourRank => _t('Sıralamanız', 'Your Rank', 'Ihr Rang', 'あなたの順位', 'Tu Puesto', 'Locul Tău');
  String get notRanked => _t('Sıralamada değil', 'Not ranked', 'Nicht platziert', 'ランク外', 'Sin clasificación', 'Neclasificat');
  String get totalConverted => _t('Toplam Dönüştürülen', 'Total Converted', 'Gesamt umgewandelt', '合計変換', 'Total Convertido', 'Total Convertit');
  String get totalDonated => _t('Toplam Bağışlanan', 'Total Donated', 'Gesamt gespendet', '合計寄付', 'Total Donado', 'Total Donat');
  
  // Teams extras
  String get teamDescription => _t('Takım Açıklaması', 'Team Description', 'Teambeschreibung', 'チーム説明', 'Descripción del Equipo', 'Descriere Echipă');
  String get createNewTeam => _t('Yeni Takım Oluştur', 'Create New Team', 'Neues Team erstellen', '新しいチームを作成', 'Crear Nuevo Equipo', 'Creează Echipă Nouă');
  String get joinExistingTeam => _t('Mevcut Takıma Katıl', 'Join Existing Team', 'Bestehendem Team beitreten', '既存のチームに参加', 'Unirse a Equipo Existente', 'Alătură-te Echipei Existente');
  String get teamCode => _t('Takım Kodu', 'Team Code', 'Team-Code', 'チームコード', 'Código del Equipo', 'Cod Echipă');
  String get enterTeamCode => _t('Takım kodunu girin', 'Enter team code', 'Team-Code eingeben', 'チームコードを入力', 'Ingresa el código', 'Introdu codul echipei');
  String get joinWithCode => _t('Kodla Katıl', 'Join with Code', 'Mit Code beitreten', 'コードで参加', 'Unirse con Código', 'Alătură-te cu Cod');
  String get teamNotFound => _t('Takım bulunamadı', 'Team not found', 'Team nicht gefunden', 'チームが見つかりません', 'Equipo no encontrado', 'Echipa nu a fost găsită');
  String get teamFull => _t('Takım dolu', 'Team is full', 'Team ist voll', 'チームが満員です', 'Equipo lleno', 'Echipa este plină');
  String get leaderLabel => _t('Lider', 'Leader', 'Leiter', 'リーダー', 'Líder', 'Lider');
  String get memberLabel => _t('Üye', 'Member', 'Mitglied', 'メンバー', 'Miembro', 'Membru');
  String get kickMember => _t('Üyeyi Çıkar', 'Kick Member', 'Mitglied entfernen', 'メンバーを削除', 'Expulsar Miembro', 'Elimină Membru');
  String get promoteToLeader => _t('Lider Yap', 'Promote to Leader', 'Zum Leiter befördern', 'リーダーに昇格', 'Promover a Líder', 'Promovează la Lider');
  String get disbandTeam => _t('Takımı Dağıt', 'Disband Team', 'Team auflösen', 'チームを解散', 'Disolver Equipo', 'Desființează Echipa');
  String get copyCode => _t('Kodu Kopyala', 'Copy Code', 'Code kopieren', 'コードをコピー', 'Copiar Código', 'Copiază Codul');
  String get codeCopied => _t('Kod kopyalandı!', 'Code copied!', 'Code kopiert!', 'コードがコピーされました！', '¡Código copiado!', 'Cod copiat!');
  String get shareTeam => _t('Takımı Paylaş', 'Share Team', 'Team teilen', 'チームを共有', 'Compartir Equipo', 'Distribuie Echipa');
  
  // Charity/Donate extras
  String get beHope => _t('Umut Ol', 'Be Hope', 'Sei Hoffnung', '希望になろう', 'Sé Esperanza', 'Fii Speranță');
  String get donateToCharity => _t('Vakfa Bağış Yap', 'Donate to Charity', 'An Organisation spenden', '慈善団体に寄付', 'Donar a Organización', 'Donează la Organizație');
  String get howMuchDonate => _t('Ne kadar bağışlamak istiyorsun?', 'How much do you want to donate?', 'Wie viel möchten Sie spenden?', 'いくら寄付しますか？', '¿Cuánto quieres donar?', 'Cât vrei să donezi?');
  String get currentBalance => _t('Mevcut Bakiye', 'Current Balance', 'Aktuelles Guthaben', '現在の残高', 'Balance Actual', 'Sold Curent');
  String get donateAll => _t('Tümünü Bağışla', 'Donate All', 'Alles spenden', 'すべて寄付', 'Donar Todo', 'Donează Tot');
  String get confirmDonation => _t('Bağışı Onayla', 'Confirm Donation', 'Spende bestätigen', '寄付を確認', 'Confirmar Donación', 'Confirmă Donația');
  String get donationConfirmMsg => _t(
    'Hope bağışlamak istediğinize emin misiniz?',
    'Are you sure you want to donate Hope?',
    'Sind Sie sicher, dass Sie Hope spenden möchten?',
    'Hopeを寄付してもよろしいですか？',
    '¿Estás seguro de donar Hope?',
    'Ești sigur că vrei să donezi Hope?',
  );
  String get thankYou => _t('Teşekkürler!', 'Thank You!', 'Danke!', 'ありがとう！', '¡Gracias!', 'Mulțumim!');
  String get donationThankMsg => _t(
    'Bağışınız için teşekkür ederiz!',
    'Thank you for your donation!',
    'Vielen Dank für Ihre Spende!',
    'ご寄付ありがとうございます！',
    '¡Gracias por tu donación!',
    'Mulțumim pentru donația ta!',
  );
  String get close => _t('Kapat', 'Close', 'Schließen', '閉じる', 'Cerrar', 'Închide');
  String get searchCharities => _t('Vakıf Ara...', 'Search charities...', 'Organisationen suchen...', '慈善団体を検索...', 'Buscar organizaciones...', 'Caută organizații...');
  
  // Activity History
  String get activityHistoryTitle => _t('Aktivite Geçmişi', 'Activity History', 'Aktivitätsverlauf', 'アクティビティ履歴', 'Historial de Actividad', 'Istoric Activitate');
  String get donationTo => _t('Bağış', 'Donation to', 'Spende an', '寄付先', 'Donación a', 'Donație către');
  String get hopeDonated => _t('Hope bağışlandı', 'Hope donated', 'Hope gespendet', 'Hope寄付', 'Hope donado', 'Hope donat');
  String get stepsToHope => _t('adım → Hope', 'steps → Hope', 'Schritte → Hope', '歩数 → Hope', 'pasos → Hope', 'pași → Hope');
  
  // Snackbar / Toast messages
  String get loginSuccess => _t('Giriş başarılı!', 'Login successful!', 'Anmeldung erfolgreich!', 'ログイン成功！', '¡Inicio exitoso!', 'Conectare reușită!');
  String get logoutSuccess => _t('Çıkış yapıldı', 'Logged out', 'Abgemeldet', 'ログアウトしました', 'Sesión cerrada', 'Deconectat');
  String get photoUpdated => _t('Fotoğraf güncellendi!', 'Photo updated!', 'Foto aktualisiert!', '写真が更新されました！', '¡Foto actualizada!', 'Poză actualizată!');
  String get photoUpdateFailed => _t('Fotoğraf yüklenemedi', 'Failed to upload photo', 'Foto konnte nicht hochgeladen werden', '写真のアップロードに失敗', 'Error al subir foto', 'Eroare la încărcare poză');
  String get copied => _t('Kopyalandı!', 'Copied!', 'Kopiert!', 'コピーしました！', '¡Copiado!', 'Copiat!');
  String get pleaseWait => _t('Lütfen bekleyin...', 'Please wait...', 'Bitte warten...', 'お待ちください...', 'Por favor espera...', 'Te rugăm așteaptă...');
  String get networkError => _t('Bağlantı hatası', 'Network error', 'Netzwerkfehler', '接続エラー', 'Error de red', 'Eroare de rețea');
  String get unknownError => _t('Bilinmeyen hata', 'Unknown error', 'Unbekannter Fehler', '不明なエラー', 'Error desconocido', 'Eroare necunoscută');
  String get tryAgain => _t('Tekrar deneyin', 'Try again', 'Erneut versuchen', 'もう一度お試しください', 'Inténtalo de nuevo', 'Încearcă din nou');
  String get ok => 'OK';
  
  // Dashboard Snackbar messages
  String get stepsAdded => _t('➕ 1000 adım eklendi!', '➕ 1000 steps added!', '➕ 1000 Schritte hinzugefügt!', '➕ 1000歩追加！', '➕ ¡1000 pasos añadidos!', '➕ 1000 pași adăugați!');
  String get hopeAdded => _t('💜 +50 Hope eklendi!', '💜 +50 Hope added!', '💜 +50 Hope hinzugefügt!', '💜 +50 Hope追加！', '💜 +50 Hope añadido!', '💜 +50 Hope adăugat!');
  String hopeEarnedMsg(String amount) => _t('$amount Hope kazandınız!', 'You earned $amount Hope!', 'Sie haben $amount Hope verdient!', '$amount Hope獲得！', '¡Ganaste $amount Hope!', 'Ai câștigat $amount Hope!');
  String carryOverHopeEarned(String amount) => _t(
      '🔥 Taşınan adımlardan $amount Hope kazandınız!',
      '🔥 You earned $amount Hope from carry-over steps!',
      '🔥 Sie haben $amount Hope aus übertragenen Schritten verdient!',
      '🔥 繰り越し歩数から$amount Hope獲得！',
      '🔥 ¡Ganaste $amount Hope de pasos transferidos!',
      '🔥 Ai câștigat $amount Hope din pași reportați!');
  String get teamJoinedMsg => _t('🎉 Takıma katıldınız!', '🎉 You joined the team!', '🎉 Sie sind dem Team beigetreten!', '🎉 チームに参加しました！', '🎉 ¡Te uniste al equipo!', '🎉 Te-ai alăturat echipei!');
  String get inviteRejected => _t('Davet reddedildi', 'Invite rejected', 'Einladung abgelehnt', '招待を拒否しました', 'Invitación rechazada', 'Invitație respinsă');
  String errorMsg(String error) => _t('Hata: $error', 'Error: $error', 'Fehler: $error', 'エラー: $error', 'Error: $error', 'Eroare: $error');
  
  // Ad Dialog
  String get watchingAd => _t('Reklam İzleniyor...', 'Watching Ad...', 'Werbung ansehen...', '広告視聴中...', 'Viendo anuncio...', 'Se vizionează reclama...');
  String get adCountdown => _t('saniye', 'seconds', 'Sekunden', '秒', 'segundos', 'secunde');
  String get adSkip => _t('Reklamı Geç', 'Skip Ad', 'Werbung überspringen', '広告をスキップ', 'Saltar anuncio', 'Sari peste reclamă');
  String get adTitle => _t('Reklam', 'Ad', 'Werbung', '広告', 'Anuncio', 'Reclamă');
  String get adArea => _t('Reklam Alanı', 'Ad Area', 'Werbebereich', '広告エリア', 'Área de anuncio', 'Zonă reclamă');
  String get adIntegration => _t('(Google AdMob entegrasyonu)', '(Google AdMob integration)', '(Google AdMob Integration)', '(Google AdMob統合)', '(Integración Google AdMob)', '(Integrare Google AdMob)');
  String adClosingIn(int seconds) => _t(
      'Reklam $seconds saniye sonra kapanacak...',
      'Ad closing in $seconds seconds...',
      'Werbung schließt in $seconds Sekunden...',
      '広告は$seconds秒後に閉じます...',
      'El anuncio se cerrará en $seconds segundos...',
      'Reclama se închide în $seconds secunde...');
  
  // Teams Screen - extended
  String get myTeamTitle => _t('Takımım', 'My Team', 'Mein Team', 'マイチーム', 'Mi Equipo', 'Echipa Mea');
  String get competeWithTeam => _t('Adımlarımız farklı olsa da yolumuz bir.', 'Though our steps differ, our path is one.', 'Auch wenn unsere Schritte unterschiedlich sind, unser Weg ist einer.', '歩みは違えど、道は一つ。', 'Aunque nuestros pasos difieran, nuestro camino es uno.', 'Deși pașii noștri diferă, drumul nostru e unul.');
  String get createOrJoinTeam => _t('Takım kur veya katıl', 'Create or join a team', 'Team erstellen oder beitreten', 'チームを作成または参加', 'Crea o únete a un equipo', 'Creează sau alătură-te unei echipe');
  String get teamLogo => _t('Takım Logosu', 'Team Logo', 'Team-Logo', 'チームロゴ', 'Logo del Equipo', 'Logo Echipă');
  String get chooseFromGalleryOption => _t('Galeriden Seç', 'Choose from Gallery', 'Aus Galerie auswählen', 'ギャラリーから選択', 'Elegir de Galería', 'Alege din Galerie');
  String get takePhotoOption => _t('Kamera ile Çek', 'Take Photo', 'Foto aufnehmen', '写真を撮る', 'Tomar Foto', 'Fă o Poză');
  String get removeLogo => _t('Logoyu Kaldır', 'Remove Logo', 'Logo entfernen', 'ロゴを削除', 'Eliminar Logo', 'Elimină Logo');
  String get logoUpdated => _t('✅ Takım logosu güncellendi!', '✅ Team logo updated!', '✅ Team-Logo aktualisiert!', '✅ チームロゴが更新されました！', '✅ ¡Logo actualizado!', '✅ Logo actualizat!');
  String get logoUploadFailed => _t('❌ Logo yüklenemedi', '❌ Failed to upload logo', '❌ Logo konnte nicht hochgeladen werden', '❌ ロゴのアップロードに失敗', '❌ Error al subir logo', '❌ Eroare la încărcare logo');
  String get logoRemoved => _t('✅ Logo kaldırıldı', '✅ Logo removed', '✅ Logo entfernt', '✅ ロゴが削除されました', '✅ Logo eliminado', '✅ Logo eliminat');
  String get leader => _t('👑 Lider', '👑 Leader', '👑 Leiter', '👑 リーダー', '👑 Líder', '👑 Lider');
  String get referralCodeLabel => _t('Referans Kodu: ', 'Referral Code: ', 'Empfehlungscode: ', '紹介コード: ', 'Código de Referencia: ', 'Cod de Referință: ');
  String codeCopiedMsg(String code) => _t('✅ Kod kopyalandı: $code', '✅ Code copied: $code', '✅ Code kopiert: $code', '✅ コードがコピーされました: $code', '✅ Código copiado: $code', '✅ Cod copiat: $code');
  String get membersLabel => _t('Üyeler', 'Members', 'Mitglieder', 'メンバー', 'Miembros', 'Membri');
  String get totalHopeLabel => _t('Bağışlanan Hope', 'Donated Hope', 'Gespendete Hope', '寄付Hope', 'Hope Donado', 'Hope Donat');
  String get leaderPrivileges => _t('Lider Yetkileri', 'Leader Privileges', 'Leiter-Privilegien', 'リーダー権限', 'Privilegios de Líder', 'Privilegii Lider');
  String get inviteMember => _t('Üye Davet Et', 'Invite Member', 'Mitglied einladen', 'メンバーを招待', 'Invitar Miembro', 'Invită Membru');
  String get teamMembersTitle => _t('Takım Üyeleri', 'Team Members', 'Teammitglieder', 'チームメンバー', 'Miembros del Equipo', 'Membrii Echipei');
  String membersCount(int count) => _t('$count üye', '$count members', '$count Mitglieder', '$count メンバー', '$count miembros', '$count membri');
  String get youLabel => _t('Sen', 'You', 'Du', 'あなた', 'Tú', 'Tu');
  String todayStepsLabel(int steps) => _t('Bugün: $steps adım', 'Today: $steps steps', 'Heute: $steps Schritte', '今日: $steps歩', 'Hoy: $steps pasos', 'Azi: $steps pași');
  String get createTeamOption => _t('Takım Kur', 'Create Team', 'Team erstellen', 'チームを作成', 'Crear Equipo', 'Creează Echipă');
  String get createTeamDesc => _t('Adımlarımız farklı olsa da yolumuz bir', 'Though our steps differ, our path is one', 'Auch wenn unsere Schritte unterschiedlich sind, unser Weg ist einer', '歩みは違えど、道は一つ', 'Aunque nuestros pasos difieran, nuestro camino es uno', 'Deși pașii noștri diferă, drumul nostru e unul');
  String get joinTeamOption => _t('Takıma Katıl', 'Join Team', 'Team beitreten', 'チームに参加', 'Unirse al Equipo', 'Alătură-te Echipei');
  String get joinTeamDesc => _t('Referans kodu ile mevcut takıma katıl', 'Join an existing team with referral code', 'Mit Empfehlungscode einem Team beitreten', '紹介コードで既存のチームに参加', 'Únete a un equipo con código de referencia', 'Alătură-te unei echipe cu cod de referință');
  String get whyTeamsImportant => _t('Takımlar Neden Önemli?', 'Why Teams Matter?', 'Warum sind Teams wichtig?', 'なぜチームが重要？', '¿Por qué importan los equipos?', 'De ce contează echipele?');
  String get teamBenefits => _t(
      '• Takım arkadaşlarınla yarış\n• Birlikte daha çok Hope kazan\n• Takım sıralamasında yüksel\n• Sosyal motivasyon ile daha çok adım at',
      '• Compete with teammates\n• Earn more Hope together\n• Rise in team rankings\n• Walk more with social motivation',
      '• Mit Teamkollegen konkurrieren\n• Zusammen mehr Hope verdienen\n• In der Teamrangliste aufsteigen\n• Mit sozialer Motivation mehr gehen',
      '• チームメイトと競争\n• 一緒にもっとHopeを獲得\n• チームランキングで上昇\n• 社会的モチベーションでもっと歩く',
      '• Compite con compañeros\n• Gana más Hope juntos\n• Sube en el ranking\n• Camina más con motivación social',
      '• Concurează cu colegii\n• Câștigă mai mult Hope împreună\n• Urcă în clasament\n• Mergi mai mult cu motivație socială');
  String get teamNameLabel => _t('Takım Adı', 'Team Name', 'Teamname', 'チーム名', 'Nombre del Equipo', 'Nume Echipă');
  String get teamNameHint => _t('Örn: Umut Yıldızları', 'E.g: Hope Stars', 'z.B.: Hope Stars', '例：ホープスターズ', 'Ej: Estrellas de Hope', 'Ex: Stelele Speranței');
  String get referralCodeAutoGen => _t('Benzersiz bir referans kodu otomatik oluşturulacak.', 'A unique referral code will be generated automatically.', 'Ein eindeutiger Empfehlungscode wird automatisch generiert.', '固有の紹介コードが自動生成されます。', 'Se generará automáticamente un código único.', 'Un cod unic va fi generat automat.');
  String get create => _t('Oluştur', 'Create', 'Erstellen', '作成', 'Crear', 'Creează');
  String get referralCodeInput => _t('Referans Kodu', 'Referral Code', 'Empfehlungscode', '紹介コード', 'Código de Referencia', 'Cod de Referință');
  String get referralCodeHint => _t('Örn: ABC123', 'E.g: ABC123', 'z.B.: ABC123', '例：ABC123', 'Ej: ABC123', 'Ex: ABC123');
  String get referralCodeInfo => _t('Takım liderinden aldığınız 6 haneli kodu girin.', 'Enter the 6-digit code from the team leader.', 'Geben Sie den 6-stelligen Code vom Teamleiter ein.', 'チームリーダーからの6桁のコードを入力してください。', 'Ingresa el código de 6 dígitos del líder.', 'Introdu codul de 6 cifre de la lider.');
  String get join => _t('Katıl', 'Join', 'Beitreten', '参加', 'Unirse', 'Alătură-te');
  String get searchNameOrNickname => _t('İsim veya Nickname Ara', 'Search Name or Nickname', 'Name oder Nickname suchen', '名前またはニックネームを検索', 'Buscar Nombre o Apodo', 'Caută Nume sau Poreclă');
  String get searchNameHint => _t('Örn: Ahmet Yılmaz', 'E.g: John Doe', 'z.B.: Max Mustermann', '例：山田太郎', 'Ej: Juan García', 'Ex: Ion Popescu');
  String get searchForUsers => _t('İsim veya nickname ile kullanıcı arayın', 'Search for users by name or nickname', 'Suchen Sie Benutzer nach Name oder Nickname', '名前またはニックネームでユーザーを検索', 'Busca usuarios por nombre o apodo', 'Caută utilizatori după nume sau poreclă');
  String get inAnotherTeam => _t('Başka takımda', 'In another team', 'In einem anderen Team', '別のチームに所属', 'En otro equipo', 'În altă echipă');
  String get noTeamStatus => _t('Takımsız', 'No team', 'Kein Team', 'チームなし', 'Sin equipo', 'Fără echipă');
  String get inviteBtn => _t('Davet Et', 'Invite', 'Einladen', '招待', 'Invitar', 'Invită');
  String get leaveTeamTitle => _t('Takımdan Ayrıl', 'Leave Team', 'Team verlassen', 'チームを離れる', 'Abandonar Equipo', 'Părăsește Echipa');
  String get leaveTeamConfirm => _t('Takımdan ayrılmak istediğinize emin misiniz?', 'Are you sure you want to leave the team?', 'Sind Sie sicher, dass Sie das Team verlassen möchten?', 'チームを離れてもよろしいですか？', '¿Seguro que quieres abandonar el equipo?', 'Ești sigur că vrei să părăsești echipa?');
  String get leave => _t('Ayrıl', 'Leave', 'Verlassen', '離れる', 'Abandonar', 'Părăsește');
  String teamCreatedMsg(String code) => _t('🎉 Takım oluşturuldu! Kod: $code', '🎉 Team created! Code: $code', '🎉 Team erstellt! Code: $code', '🎉 チーム作成！コード: $code', '🎉 ¡Equipo creado! Código: $code', '🎉 Echipă creată! Cod: $code');
  String get teamNotFoundError => _t('Takım bulunamadı!', 'Team not found!', 'Team nicht gefunden!', 'チームが見つかりません！', '¡Equipo no encontrado!', 'Echipa nu a fost găsită!');
  String get youJoinedTeam => _t('🎉 Takıma katıldınız!', '🎉 You joined the team!', '🎉 Sie sind dem Team beigetreten!', '🎉 チームに参加しました！', '🎉 ¡Te uniste al equipo!', '🎉 Te-ai alăturat echipei!');
  String inviteSentTo(String name) => _t('📨 $name\'e davet gönderildi!', '📨 Invite sent to $name!', '📨 Einladung an $name gesendet!', '📨 $nameに招待を送信しました！', '📨 ¡Invitación enviada a $name!', '📨 Invitație trimisă către $name!');
  String get youLeftTeam => _t('Takımdan ayrıldınız', 'You left the team', 'Sie haben das Team verlassen', 'チームを離れました', 'Abandonaste el equipo', 'Ai părăsit echipa');
  String get userLabel => _t('Kullanıcı', 'User', 'Benutzer', 'ユーザー', 'Usuario', 'Utilizator');
  
  // Charity Screen
  String get donateTitle => _t('Bağış Yap', 'Donate', 'Spenden', '寄付する', 'Donar', 'Donează');
  String get supportCharitiesWithHope => _t('Hope puanlarınla vakıflara destek ol!', 'Support charities with your Hope points!', 'Unterstützen Sie Organisationen mit Ihren Hope-Punkten!', 'Hopeポイントで慈善団体をサポート！', '¡Apoya organizaciones con tus puntos Hope!', 'Susține organizațiile cu punctele tale Hope!');
  String get hopeBalanceLabel => _t('Hope Bakiyen', 'Your Hope Balance', 'Ihr Hope-Guthaben', 'あなたのHope残高', 'Tu Balance de Hope', 'Soldul Tău Hope');
  String get readyToBeHope => _t('Umut olmaya hazırsın!', 'You\'re ready to be hope!', 'Sie sind bereit, Hoffnung zu sein!', '希望になる準備ができました！', '¡Estás listo para ser esperanza!', 'Ești pregătit să fii speranță!');
  String get needMoreHopeForDonation => _t('Umut olmak için en az 10 Hope gerekli. Biraz daha adım at!', 'You need at least 10 Hope to donate. Take more steps!', 'Sie benötigen mindestens 10 Hope zum Spenden. Machen Sie mehr Schritte!', '寄付には最低10 Hopeが必要です。もっと歩きましょう！', 'Necesitas al menos 10 Hope para donar. ¡Da más pasos!', 'Ai nevoie de cel puțin 10 Hope pentru a dona. Fă mai mulți pași!');
  String get charitiesTitle => _t('Vakıflar', 'Charities', 'Organisationen', '慈善団体', 'Organizaciones', 'Organizații');
  String charitiesCount(int count) => _t('$count vakıf', '$count charities', '$count Organisationen', '$count 慈善団体', '$count organizaciones', '$count organizații');
  String get charityNotFound => _t('Vakıf bulunamadı', 'No charity found', 'Keine Organisation gefunden', '慈善団体が見つかりません', 'No se encontró organización', 'Nu s-a găsit organizație');
  String get beHopeButton => _t('UMUT OL', 'BE HOPE', 'SEI HOFFNUNG', '希望になろう', 'SÉ ESPERANZA', 'FII SPERANȚĂ');
  String get walkMoreTitle => _t('Biraz Daha Adım At!', 'Walk More!', 'Geh mehr!', 'もっと歩こう！', '¡Camina más!', 'Mergi mai mult!');
  String get walkMoreDesc => _t('Umut olmak için en az 10 Hope bakiyen olmalı.\n\nAdımlarını dönüştürerek Hope kazanabilirsin!', 'You need at least 10 Hope to donate.\n\nConvert your steps to earn Hope!', 'Sie benötigen mindestens 10 Hope zum Spenden.\n\nWandeln Sie Ihre Schritte um, um Hope zu verdienen!', '寄付には最低10 Hopeが必要です。\n\n歩数を変換してHopeを獲得！', 'Necesitas al menos 10 Hope para donar.\n\n¡Convierte tus pasos para ganar Hope!', 'Ai nevoie de cel puțin 10 Hope pentru a dona.\n\nConvertește pașii pentru a câștiga Hope!');
  String get donationAmountTitle => _t('Bağış Miktarı', 'Donation Amount', 'Spendenbetrag', '寄付金額', 'Cantidad de Donación', 'Suma Donației');
  String currentBalanceMsg(double balance) => _t('Mevcut bakiye: ${balance.toStringAsFixed(2)} Hope', 'Current balance: ${balance.toStringAsFixed(2)} Hope', 'Aktuelles Guthaben: ${balance.toStringAsFixed(2)} Hope', '現在の残高: ${balance.toStringAsFixed(2)} Hope', 'Balance actual: ${balance.toStringAsFixed(2)} Hope', 'Sold curent: ${balance.toStringAsFixed(2)} Hope');
  String hopeWillBeDonated(double amount) => _t('${amount.toStringAsFixed(0)} Hope bağışlanacak', '${amount.toStringAsFixed(0)} Hope will be donated', '${amount.toStringAsFixed(0)} Hope wird gespendet', '${amount.toStringAsFixed(0)} Hopeが寄付されます', '${amount.toStringAsFixed(0)} Hope serán donados', '${amount.toStringAsFixed(0)} Hope vor fi donați');
  String get continueBtn => _t('Devam Et', 'Continue', 'Weiter', '続ける', 'Continuar', 'Continuă');
  String get youBecameHope => _t('UMUT OLDUNUZ!', 'YOU BECAME HOPE!', 'SIE WURDEN HOFFNUNG!', '希望になりました！', '¡TE CONVERTISTE EN ESPERANZA!', 'AI DEVENIT SPERANȚĂ!');
  String get donatedTo => _t('için bağış yaptınız!', 'donation completed!', 'Spende abgeschlossen!', '寄付が完了しました！', '¡donación completada!', 'donație finalizată!');
  String remainingBalance(double balance) => _t('Kalan: ${balance.toStringAsFixed(2)} Hope', 'Remaining: ${balance.toStringAsFixed(2)} Hope', 'Verbleibend: ${balance.toStringAsFixed(2)} Hope', '残り: ${balance.toStringAsFixed(2)} Hope', 'Restante: ${balance.toStringAsFixed(2)} Hope', 'Rămas: ${balance.toStringAsFixed(2)} Hope');
  String get awesome => _t('Muhteşem!', 'Awesome!', 'Großartig!', '素晴らしい！', '¡Genial!', 'Minunat!');
  String get donationAdTitle => _t('Bağış Reklamı', 'Donation Ad', 'Spenden-Werbung', '寄付広告', 'Anuncio de Donación', 'Reclamă Donație');
  String get watchAdSupportDonation => _t('Reklam izleyerek\nbağışı destekle!', 'Watch ad to\nsupport donation!', 'Werbung ansehen um\nSpende zu unterstützen!', '広告を見て\n寄付をサポート！', 'Ver anuncio para\napoyar donación!', 'Vizionează reclama pentru\na susține donația!');
  String get donationProcessing => _t('Bağış işleniyor...', 'Processing donation...', 'Spende wird verarbeitet...', '寄付処理中...', 'Procesando donación...', 'Se procesează donația...');
  String get searchCharityHint => _t('Vakıf ara...', 'Search charity...', 'Organisation suchen...', '慈善団体を検索...', 'Buscar organización...', 'Caută organizație...');
  
  // Leaderboard Screen
  String get leaderboardScreenTitle => _t('Sıralama', 'Ranking', 'Rangliste', 'ランキング', 'Clasificación', 'Clasament');
  String get thisMonthsBest => _t('Bu ayın en iyileri! 🏆', 'This month\'s best! 🏆', 'Die Besten dieses Monats! 🏆', '今月のベスト！🏆', '¡Los mejores del mes! 🏆', 'Cei mai buni din această lună! 🏆');
  String get stepChampionsTab => _t('Umut Hareketi', 'Hope Movement', 'Hope-Bewegung', 'ホープムーブメント', 'Movimiento Hope', 'Mișcarea Speranței');
  String get hopeHeroesTab => _t('Umut Elçileri', 'Hope Ambassadors', 'Hope-Botschafter', 'Hopeアンバサダー', 'Embajadores de Hope', 'Ambasadorii Speranței');
  String get teamsTab => _t('Umut Ormanı', 'Hope Forest', 'Hope-Wald', 'ホープの森', 'Bosque de Hope', 'Pădurea Speranței');
  String get noConvertersYet => _t('Bu ay henüz adım dönüştüren yok', 'No one converted steps this month yet', 'Diesen Monat hat noch niemand Schritte umgewandelt', '今月まだ歩数を変換した人がいません', 'Nadie ha convertido pasos este mes aún', 'Nimeni nu a convertit pași luna aceasta încă');
  String get noDonationsYet => _t('Bu ay henüz bağış yapılmamış', 'No donations made this month yet', 'Diesen Monat wurde noch keine Spende gemacht', '今月まだ寄付がありません', 'No se han hecho donaciones este mes aún', 'Nu s-au făcut donații luna aceasta încă');
  String get noTeamDonationsYet => _t('Bu ay henüz takım bağışı yok', 'No team donations this month yet', 'Diesen Monat noch keine Teamspenden', '今月まだチーム寄付がありません', 'No hay donaciones de equipo este mes aún', 'Nu sunt donații de echipă luna aceasta încă');
  String get stepsLabel => _t('adım', 'steps', 'Schritte', '歩', 'pasos', 'pași');
  String get rankingResetsMonthly => _t('Sıralama her ayın başında sıfırlanır', 'Ranking resets at the beginning of each month', 'Rangliste wird jeden Monat zurückgesetzt', 'ランキングは毎月リセットされます', 'El ranking se reinicia cada mes', 'Clasamentul se resetează lunar');
  String get beTheFirst => _t('İlk sen ol! 🚀', 'Be the first! 🚀', 'Sei der Erste! 🚀', '最初になろう！🚀', '¡Sé el primero! 🚀', 'Fii primul! 🚀');
  String get youIndicator => _t('Sen', 'You', 'Du', 'あなた', 'Tú', 'Tu');
  String get yourTeamIndicator => _t('Takımın', 'Your Team', 'Dein Team', 'あなたのチーム', 'Tu Equipo', 'Echipa Ta');
  String get emptyPodium => _t('Boş', 'Empty', 'Leer', '空', 'Vacío', 'Gol');
  String membersUnit(int count) => _t('$count üye', '$count members', '$count Mitglieder', '$count メンバー', '$count miembros', '$count membri');
  String get january => _t('Ocak', 'January', 'Januar', '1月', 'Enero', 'Ianuarie');
  String get february => _t('Şubat', 'February', 'Februar', '2月', 'Febrero', 'Februarie');
  String get march => _t('Mart', 'March', 'März', '3月', 'Marzo', 'Martie');
  String get april => _t('Nisan', 'April', 'April', '4月', 'Abril', 'Aprilie');
  String get may => _t('Mayıs', 'May', 'Mai', '5月', 'Mayo', 'Mai');
  String get june => _t('Haziran', 'June', 'Juni', '6月', 'Junio', 'Iunie');
  String get july => _t('Temmuz', 'July', 'Juli', '7月', 'Julio', 'Iulie');
  String get august => _t('Ağustos', 'August', 'August', '8月', 'Agosto', 'August');
  String get september => _t('Eylül', 'September', 'September', '9月', 'Septiembre', 'Septembrie');
  String get october => _t('Ekim', 'October', 'Oktober', '10月', 'Octubre', 'Octombrie');
  String get november => _t('Kasım', 'November', 'November', '11月', 'Noviembre', 'Noiembrie');
  String get december => _t('Aralık', 'December', 'Dezember', '12月', 'Diciembre', 'Decembrie');
  String getMonthName(int month) {
    switch (month) {
      case 1: return january;
      case 2: return february;
      case 3: return march;
      case 4: return april;
      case 5: return may;
      case 6: return june;
      case 7: return july;
      case 8: return august;
      case 9: return september;
      case 10: return october;
      case 11: return november;
      case 12: return december;
      default: return '';
    }
  }
  
  // Splash Screen
  String get readyToStart => _t('Hazırsan Başlayalım', 'Ready? Let\'s Start', 'Bereit? Los geht\'s', '準備はいい？始めよう', '¿Listo? ¡Empecemos', 'Ești gata? Să începem');
  
  // Steps Screen
  String get myStepsTitle => _t('Adımlarım', 'My Steps', 'Meine Schritte', '私の歩数', 'Mis Pasos', 'Pașii Mei');
  String get trackStepsEarnHope => _t('Bugünkü adımlarını takip et ve Hope kazan!', 'Track your steps today and earn Hope!', 'Verfolgen Sie heute Ihre Schritte und verdienen Sie Hope!', '今日の歩数を追跡してHopeを獲得！', '¡Rastrea tus pasos hoy y gana Hope!', 'Urmărește pașii de azi și câștigă Hope!');
  String get caloriesLabel => _t('Kalori', 'Calories', 'Kalorien', 'カロリー', 'Calorías', 'Calorii');
  String get kmLabel => 'Km';
  String get minutesLabel => _t('Dakika', 'Minutes', 'Minuten', '分', 'Minutos', 'Minute');
  String get stepsLabelLower => _t('adım', 'steps', 'Schritte', '歩', 'pasos', 'pași');
  String get goalLabel => _t('Hedef', 'Goal', 'Ziel', '目標', 'Meta', 'Obiectiv');
  String get convertible => _t('Dönüştürülebilir', 'Convertible', 'Umwandelbar', '変換可能', 'Convertible', 'Convertibil');
  String get convertToHope => _t('Hope\'a Dönüştür', 'Convert to Hope', 'In Hope umwandeln', 'Hopeに変換', 'Convertir a Hope', 'Convertește în Hope');
  String get cooldownNotExpired => _t('Bekleme Süresi Dolmadı', 'Cooldown Not Expired', 'Wartezeit nicht abgelaufen', 'クールダウン中', 'Tiempo de espera no expirado', 'Perioada de așteptare nu a expirat');
  String nextConversionIn(String time) => _t('Sonraki dönüştürme: $time sonra', 'Next conversion: in $time', 'Nächste Umwandlung: in $time', '次の変換: $time後', 'Próxima conversión: en $time', 'Următoarea conversie: în $time');
  String get howItWorks => _t('Nasıl Çalışır?', 'How It Works?', 'Wie funktioniert es?', '仕組み', '¿Cómo funciona?', 'Cum funcționează?');
  String get stepsInfoItem1 => _t('Her 1000 adım = 1 Hope puanı', 'Every 1000 steps = 1 Hope point', 'Alle 1000 Schritte = 1 Hope-Punkt', '1000歩ごとに1 Hopeポイント', 'Cada 1000 pasos = 1 punto Hope', 'Fiecare 1000 pași = 1 punct Hope');
  String get stepsInfoItem2 => _t('Günde maksimum 10 Hope kazanabilirsiniz', 'You can earn up to 10 Hope per day', 'Sie können bis zu 10 Hope pro Tag verdienen', '1日最大10 Hope獲得可能', 'Puedes ganar hasta 10 Hope por día', 'Poți câștiga maxim 10 Hope pe zi');
  String get stepsInfoItem3 => _t('Dönüştürme işlemi 4 saatte bir yapılabilir', 'Conversion can be done every 4 hours', 'Umwandlung alle 4 Stunden möglich', '変換は4時間ごとに可能', 'La conversión se puede hacer cada 4 horas', 'Conversia poate fi făcută la fiecare 4 ore');
  String youEarnedHope(String amount) => _t('$amount Hope kazandınız! 🎉', 'You earned $amount Hope! 🎉', 'Sie haben $amount Hope verdient! 🎉', '$amount Hope獲得！🎉', '¡Ganaste $amount Hope! 🎉', 'Ai câștigat $amount Hope! 🎉');
  String get twoHours => _t('2 saat', '2 hours', '2 Stunden', '2時間', '2 horas', '2 ore');
  
  // Team Invite Dialog
  String get teamInviteTitle => _t('🎉 Takım Daveti', '🎉 Team Invite', '🎉 Team-Einladung', '🎉 チーム招待', '🎉 Invitación de Equipo', '🎉 Invitație Echipă');
  String get unknownText => _t('Bilinmiyor', 'Unknown', 'Unbekannt', '不明', 'Desconocido', 'Necunoscut');
  String invitedYouToTeam(String name) => _t('$name sizi takıma davet etti', '$name invited you to the team', '$name hat Sie zum Team eingeladen', '$nameがチームに招待しました', '$name te invitó al equipo', '$name te-a invitat în echipă');
  String get teamInviteDesc => _t(
      'Bu takıma katılarak diğer üyelerle birlikte adım atabilir, takım sıralamasında yer alabilirsiniz.',
      'Join this team to walk with other members and appear in team rankings.',
      'Treten Sie diesem Team bei, um mit anderen Mitgliedern zu gehen und in der Teamrangliste zu erscheinen.',
      'このチームに参加して他のメンバーと一緒に歩き、チームランキングに参加しましょう。',
      'Únete a este equipo para caminar con otros miembros y aparecer en los rankings.',
      'Alătură-te acestei echipe pentru a merge cu alți membri și a apărea în clasament.');
  String get reject => _t('Reddet', 'Reject', 'Ablehnen', '拒否', 'Rechazar', 'Respinge');
  String get accept => _t('Kabul Et', 'Accept', 'Akzeptieren', '承認', 'Aceptar', 'Acceptă');
  String successfullyJoinedTeam(String teamName) => _t(
      '✅ $teamName başarıyla katıldınız!',
      '✅ Successfully joined $teamName!',
      '✅ Erfolgreich $teamName beigetreten!',
      '✅ $teamNameに正常に参加しました！',
      '✅ ¡Te uniste exitosamente a $teamName!',
      '✅ Te-ai alăturat cu succes la $teamName!');
  String errorWithMessage(String error) => _t('❌ Hata: $error', '❌ Error: $error', '❌ Fehler: $error', '❌ エラー: $error', '❌ Error: $error', '❌ Eroare: $error');
  String get inviteRejectedMsg => _t('👋 Davet reddedildi.', '👋 Invite rejected.', '👋 Einladung abgelehnt.', '👋 招待が拒否されました。', '👋 Invitación rechazada.', '👋 Invitație respinsă.');
  
  // Nested Progress Bar Widget
  String get dailyStepGoal => _t('Günlük Adım Hedefi', 'Daily Step Goal', 'Tägliches Schrittziel', '毎日の歩数目標', 'Meta de Pasos Diaria', 'Obiectiv Zilnic de Pași');
  String get goalCompleted => _t('✅ Hedef Tamamlandı!', '✅ Goal Completed!', '✅ Ziel erreicht!', '✅ 目標達成！', '✅ ¡Meta Completada!', '✅ Obiectiv Îndeplinit!');
  String stepsRemaining(int steps) => _t('$steps adım kaldı', '$steps steps remaining', '$steps Schritte übrig', '残り$steps歩', '$steps pasos restantes', '$steps pași rămași');
  String carryOverStepsLabel(int steps) => _t('Taşınan Adımlar: $steps', 'Carry-over Steps: $steps', 'Übertragene Schritte: $steps', '繰り越し歩数: $steps', 'Pasos Transferidos: $steps', 'Pași Reportați: $steps');
  String get use7Days => _t('7 gün içinde kullan!', 'Use within 7 days!', 'Innerhalb von 7 Tagen verwenden!', '7日以内に使用！', '¡Usa en 7 días!', 'Folosește în 7 zile!');
  String get convertedLabel => _t('Dönüştürülen', 'Converted', 'Umgewandelt', '変換済み', 'Convertido', 'Convertit');
  String stepsAmount(int steps) => _t('$steps adım', '$steps steps', '$steps Schritte', '$steps歩', '$steps pasos', '$steps pași');
  String get convertibleLabel => _t('Dönüştürülebilir', 'Convertible', 'Umwandelbar', '変換可能', 'Convertible', 'Convertibil');
  String get convertStepsToHope => _t('Adımları Hope\'e Dönüştür', 'Convert Steps to Hope', 'Schritte in Hope umwandeln', '歩数をHopeに変換', 'Convertir Pasos a Hope', 'Convertește Pașii în Hope');
  String canEarnHope(String amount) => _t('$amount Hope kazanabilirsin', 'You can earn $amount Hope', 'Sie können $amount Hope verdienen', '$amount Hope獲得可能', 'Puedes ganar $amount Hope', 'Poți câștiga $amount Hope');
  String get convertCarryOverSteps => _t('🔥 Taşınan Adımları Dönüştür', '🔥 Convert Carry-over Steps', '🔥 Übertragene Schritte umwandeln', '🔥 繰り越し歩数を変換', '🔥 Convertir Pasos Transferidos', '🔥 Convertește Pașii Reportați');
  String stepsWaiting(int steps, String hopeAmount) => _t(
      '$steps adım bekliyor ($hopeAmount Hope)',
      '$steps steps waiting ($hopeAmount Hope)',
      '$steps Schritte warten ($hopeAmount Hope)',
      '$steps歩が待機中 ($hopeAmount Hope)',
      '$steps pasos esperando ($hopeAmount Hope)',
      '$steps pași în așteptare ($hopeAmount Hope)');
  String minutesUntilNextConversion(int minutes) => _t(
      'Sonraki dönüştürmeye $minutes dakika kaldı',
      '$minutes minutes until next conversion',
      '$minutes Minuten bis zur nächsten Umwandlung',
      '次の変換まで$minutes分',
      '$minutes minutos hasta la próxima conversión',
      '$minutes minute până la următoarea conversie');
  String get watchAdRequired => _t(
      'Dönüştürmek için bir reklam izlemeniz gerekmektedir.',
      'You need to watch an ad to convert.',
      'Sie müssen eine Werbung ansehen, um umzuwandeln.',
      '変換するには広告を見る必要があります。',
      'Necesitas ver un anuncio para convertir.',
      'Trebuie să vizionezi o reclamă pentru a converti.');
  
  // Dashboard - Additional
  String get pendingSteps => _t('Bekleyen Adım', 'Pending Steps', 'Ausstehende Schritte', '保留中の歩数', 'Pasos Pendientes', 'Pași în Așteptare');
  String get canBeHope => _t('Umut olabilirsiniz →', 'You can be hope →', 'Sie können Hoffnung sein →', '希望になれます →', 'Puedes ser esperanza →', 'Poți fi speranță →');
  String get minHopeRequired => _t('Min 5 H gerekli', 'Min 5 H required', 'Min. 5 H erforderlich', '最低5 H必要', 'Mín. 5 H requerido', 'Min. 5 H necesar');
  
  // Charity Detail Page
  String get donationHistory => _t('Hareketler', 'Activity', 'Aktivität', 'アクティビティ', 'Actividad', 'Activitate');
  String get noDonationsYetCharity => _t('Henüz bağış yapılmamış', 'No donations yet', 'Noch keine Spenden', 'まだ寄付がありません', 'Sin donaciones aún', 'Nicio donație încă');
  String get beFirstHope => _t('İlk umut sen ol!', 'Be the first hope!', 'Sei die erste Hoffnung!', '最初の希望になろう！', '¡Sé la primera esperanza!', 'Fii prima speranță!');
  String get loadingText => _t('Yükleniyor...', 'Loading...', 'Laden...', '読み込み中...', 'Cargando...', 'Se încarcă...');
  String get anonymous => _t('Anonim', 'Anonymous', 'Anonym', '匿名', 'Anónimo', 'Anonim');
  String hopeAmount(String amount) => '$amount Hope';
  
  // Charity Detail Tabs
  String get rankingTab => _t('Sıralama', 'Ranking', 'Rangliste', 'ランキング', 'Clasificación', 'Clasament');
  String get commentsTab => _t('Yorumlar', 'Comments', 'Kommentare', 'コメント', 'Comentarios', 'Comentarii');
  String get writeYourComment => _t('Yorumunuzu Yazın', 'Write Your Comment', 'Schreiben Sie Ihren Kommentar', 'コメントを書く', 'Escribe tu Comentario', 'Scrie Comentariul');
  String get noCommentsYet => _t('Henüz yorum yapılmamış', 'No comments yet', 'Noch keine Kommentare', 'まだコメントがありません', 'Sin comentarios aún', 'Niciun comentariu încă');
  String get beFirstToComment => _t('İlk yorumu sen yap!', 'Be the first to comment!', 'Sei der Erste, der kommentiert!', '最初にコメントしよう！', '¡Sé el primero en comentar!', 'Fii primul care comentează!');
  String get noRankingsYet => _t('Henüz sıralama yok', 'No rankings yet', 'Noch keine Rangliste', 'まだランキングがありません', 'Sin rankings aún', 'Niciun clasament încă');
  String get topDonors => _t('En Çok Bağış Yapanlar', 'Top Donors', 'Top-Spender', 'トップドナー', 'Principales Donantes', 'Top Donatori');
  String get commentHint => _t('Yorumunuzu buraya yazın...', 'Write your comment here...', 'Schreiben Sie hier Ihren Kommentar...', 'ここにコメントを書いてください...', 'Escribe tu comentario aquí...', 'Scrie comentariul aici...');
  String get send => _t('Gönder', 'Send', 'Senden', '送信', 'Enviar', 'Trimite');
  String get commentSent => _t('Yorumunuz gönderildi!', 'Your comment has been sent!', 'Ihr Kommentar wurde gesendet!', 'コメントが送信されました！', '¡Tu comentario ha sido enviado!', 'Comentariul tău a fost trimis!');
  String get commentError => _t('Yorum gönderilemedi', 'Could not send comment', 'Kommentar konnte nicht gesendet werden', 'コメントを送信できませんでした', 'No se pudo enviar el comentario', 'Nu s-a putut trimite comentariul');
  String get pleaseLogin => _t('Lütfen giriş yapın', 'Please login', 'Bitte einloggen', 'ログインしてください', 'Por favor inicie sesión', 'Vă rugăm să vă autentificați');
  String get commentAdded => _t('Yorumunuz eklendi!', 'Your comment has been added!', 'Ihr Kommentar wurde hinzugefügt!', 'コメントが追加されました！', '¡Tu comentario ha sido añadido!', 'Comentariul tău a fost adăugat!');
  String currentDonationAmount(double amount) => _t('${amount.toStringAsFixed(0)} Hope', '${amount.toStringAsFixed(0)} Hope', '${amount.toStringAsFixed(0)} Hope', '${amount.toStringAsFixed(0)} Hope', '${amount.toStringAsFixed(0)} Hope', '${amount.toStringAsFixed(0)} Hope');
  
  // Charity Descriptions
  String get temaDesc => _t('Türkiye\'nin doğal varlıklarını koruma vakfı', 'Turkey\'s nature conservation foundation', 'Naturschutzstiftung der Türkei', 'トルコの自然保護財団', 'Fundación de conservación de la naturaleza de Turquía', 'Fundația pentru conservarea naturii din Turcia');
  String get losevDesc => _t('Lösemili Çocuklar Sağlık ve Eğitim Vakfı', 'Leukemia Children Health and Education Foundation', 'Stiftung für Gesundheit und Bildung von Leukämiekindern', '白血病の子供の健康と教育財団', 'Fundación de Salud y Educación para Niños con Leucemia', 'Fundația pentru Sănătatea și Educația Copiilor cu Leucemie');
  String get tegvDesc => _t('Türkiye Eğitim Gönüllüleri Vakfı', 'Turkey Education Volunteers Foundation', 'Türkei Bildungsfreiwilligen Stiftung', 'トルコ教育ボランティア財団', 'Fundación de Voluntarios de Educación de Turquía', 'Fundația Voluntarilor pentru Educație din Turcia');
  String get kizilayDesc => _t('İnsani yardım ve kan bağışı kuruluşu', 'Humanitarian aid and blood donation organization', 'Humanitäre Hilfe und Blutspende Organisation', '人道支援と献血組織', 'Organización de ayuda humanitaria y donación de sangre', 'Organizație de ajutor umanitar și donare de sânge');
  String get darussafakaDesc => _t('Yetim ve yoksul çocukların eğitim vakfı', 'Education foundation for orphan and poor children', 'Bildungsstiftung für Waisen und arme Kinder', '孤児と貧しい子供の教育財団', 'Fundación educativa para niños huérfanos y pobres', 'Fundația educațională pentru copii orfani și săraci');
  String get koruncukDesc => _t('Korunmaya muhtaç çocuklar için destek', 'Support for children in need of protection', 'Unterstützung für schutzbedürftige Kinder', '保護が必要な子供への支援', 'Apoyo para niños que necesitan protección', 'Sprijin pentru copiii care au nevoie de protecție');
  
  // Language Selection
  String get languageSelection => _t('Dil Seçimi', 'Language Selection', 'Sprachauswahl', '言語選択', 'Selección de Idioma', 'Selectare Limbă');
  String get selectLanguage => _t('Dil Seç', 'Select Language', 'Sprache auswählen', '言語を選択', 'Seleccionar Idioma', 'Selectează Limba');
  
  // Language names
  String get turkishLanguage => 'Türkçe';
  String get englishLanguage => 'English';
  String get germanLanguage => 'Deutsch';
  String get japaneseLanguage => '日本語';
  String get spanishLanguage => 'Español';
  String get romanianLanguage => 'Română';
  
  /// Get current language display name
  String get currentLanguageName {
    switch (_currentLocale.languageCode) {
      case 'tr': return turkishLanguage;
      case 'en': return englishLanguage;
      case 'de': return germanLanguage;
      case 'ja': return japaneseLanguage;
      case 'es': return spanishLanguage;
      case 'ro': return romanianLanguage;
      default: return englishLanguage;
    }
  }
}
