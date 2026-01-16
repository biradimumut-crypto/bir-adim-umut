/// App Check Güvenlik Durumu Servisi
/// 
/// P1-2 REV.2: Release modda App Check init başarısız olursa
/// kritik aksiyonlar (conversion, callable functions) kilitlenir.
/// 
/// Singleton pattern - tüm uygulama genelinde aynı state.

class AppSecurityService {
  static final AppSecurityService _instance = AppSecurityService._internal();
  factory AppSecurityService() => _instance;
  AppSecurityService._internal();

  /// App Check başarıyla başlatıldı mı?
  bool _appCheckInitialized = false;
  
  /// App Check init hatası mesajı (varsa)
  String? _initError;

  /// App Check durumunu ayarla
  void setAppCheckStatus({required bool initialized, String? error}) {
    _appCheckInitialized = initialized;
    _initError = error;
  }

  /// App Check başarıyla başlatıldı mı?
  bool get isAppCheckInitialized => _appCheckInitialized;

  /// Init hata mesajı
  String? get initError => _initError;

  /// Kritik aksiyonlar (conversion, functions) için güvenlik kontrolü
  /// 
  /// Debug modda: Her zaman true (geliştirme kolaylığı)
  /// Release modda: App Check init başarılı ise true
  /// 
  /// [isReleaseMode] parametresi test edilebilirlik için eklendi
  bool canPerformCriticalAction({bool isReleaseMode = true}) {
    // Debug modda her zaman izin ver
    if (!isReleaseMode) {
      return true;
    }
    // Release modda App Check init kontrolü
    return _appCheckInitialized;
  }

  /// Güvenlik hatası mesajı (UI'da göstermek için)
  String get securityErrorMessage {
    if (_appCheckInitialized) {
      return '';
    }
    return 'Güvenlik doğrulaması başarısız. Lütfen uygulamayı güncelleyin veya internet bağlantınızı kontrol edin.';
  }
}
