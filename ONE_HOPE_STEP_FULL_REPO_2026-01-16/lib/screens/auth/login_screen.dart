import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/hope_liquid_progress.dart';
import '../dashboard/dashboard_screen.dart';
import 'sign_up_screen.dart';
import 'email_verification_screen.dart';
import 'password_reset_screen.dart';

/// Giriş Yap Sayfası
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  
  // GIF kontrolü
  final GlobalKey _gifKey = GlobalKey();
  Uint8List? _frozenGifImage;
  bool _gifFinished = false;

  @override
  void initState() {
    super.initState();
    // GIF süresi kadar bekle ve son kareyi yakala
    Future.delayed(const Duration(milliseconds: 2900), () {
      _captureGifFrame();
    });
  }

  /// Login sonrası yönlendirme (iOS Health izni otomatik istenecek)
  Future<void> _navigateAfterLogin() async {
    if (!mounted) return;
    
    // Login başarılı olduğunda rozet kontrolü yap
    try {
      await BadgeService().updateLoginStreak();
      await BadgeService().checkAllBadges();
    } catch (e) {
      debugPrint('Badge kontrolü hatası: $e');
    }
    
    // Tema tercihini Firestore'dan senkronize et
    if (mounted) {
      try {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        await themeProvider.onUserLogin();
      } catch (e) {
        debugPrint('Tema senkronizasyonu hatası: $e');
      }
    }
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  Future<void> _captureGifFrame() async {
    try {
      final boundary = _gifKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted) {
          setState(() {
            _frozenGifImage = byteData.buffer.asUint8List();
            _gifFinished = true;
          });
        }
      }
    } catch (e) {
      // Hata durumunda GIF devam eder
      print('GIF capture hatası: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, _) {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dil değiştirme butonu - Sağ üst köşe
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => lang.setLanguage(lang.isTurkish ? 'en' : 'tr'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6EC6B5),
                              const Color(0xFFE07A5F),
                              const Color(0xFFF2C94C),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.language,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              lang.isTurkish ? 'TR' : 'EN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Logo GIF - Tek seferlik, son karede kalır
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: _gifFinished && _frozenGifImage != null
                          ? Image.memory(
                              _frozenGifImage!,
                              width: 180,
                              height: 180,
                              gaplessPlayback: true,
                            )
                          : RepaintBoundary(
                              key: _gifKey,
                              child: Image.asset(
                                'assets/videos/yeni.gif',
                                width: 180,
                                height: 180,
                                gaplessPlayback: true,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Slogan
                  Text(
                    lang.welcomeMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Hata mesajı
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              // E-posta
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: lang.email,
                  hintText: lang.emailHint,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Şifre
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: lang.password,
                  hintText: lang.passwordHint,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // Şifremi Unuttum
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6EC6B5),
                  ),
                  child: Text(lang.forgotPassword),
                ),
              ),

              const SizedBox(height: 16),

              // Giriş Yap Butonu - Gradient
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE07A5F).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          lang.login,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Veya ayırıcı
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      lang.or,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),

              const SizedBox(height: 16),

              // Sosyal giriş butonları
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google butonu
                  _buildSocialButton(
                    onTap: _handleGoogleSignIn,
                    child: SvgPicture.asset(
                      'assets/icons/google_logo.svg',
                      width: 28,
                      height: 28,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Apple butonu
                  _buildSocialButton(
                    onTap: _handleAppleSignIn,
                    child: const Icon(
                      Icons.apple,
                      size: 32,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Kayıt Ol linki
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${lang.noAccount} ',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                      ).createShader(bounds),
                      child: Text(
                        lang.signUp,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),                const SizedBox(height: 20),            ],
          ),
        ),
      ),
    );
      },
    );
  }

  /// Sosyal giriş butonu widget'ı
  Widget _buildSocialButton({required VoidCallback onTap, required Widget child}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  /// Google ile giriş
  Future<void> _handleGoogleSignIn() async {
    final lang = context.read<LanguageProvider>();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithGoogle();

      if (result['success'] == true) {
        if (mounted) {
          // Yeni kullanıcı ise referral dialog göster
          if (result['isNewUser'] == true) {
            await _showReferralDialog();
          }
          await _navigateAfterLogin();
        }
      } else {
        final error = result['error'] ?? '';
        setState(() => _errorMessage = lang.translateError(error));
      }
    } catch (e) {
      setState(() => _errorMessage = lang.googleLoginFailed);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  /// Apple ile giriş
  Future<void> _handleAppleSignIn() async {
    final lang = context.read<LanguageProvider>();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithApple();

      if (result['success'] == true) {
        if (mounted) {
          // Yeni kullanıcı ise referral dialog göster
          if (result['isNewUser'] == true) {
            await _showReferralDialog();
          }
          await _navigateAfterLogin();
        }
      } else {
        final error = result['error'] ?? '';
        setState(() => _errorMessage = lang.translateError(error));
      }
    } catch (e) {
      setState(() => _errorMessage = lang.isTurkish 
          ? 'Apple ile giriş başarısız oldu.' 
          : 'Apple sign-in failed.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Giriş işlemi
  Future<void> _handleLogin() async {
    final lang = context.read<LanguageProvider>();
    setState(() => _errorMessage = null);

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = lang.isTurkish ? 'E-posta ve şifre gereklidir.' : 'Email and password are required.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success']) {
        await _navigateAfterLogin();
      } else {
        final errorCode = result['error'] ?? '';
        final email = result['email'] ?? _emailController.text.trim();
        
        // Email doğrulanmamış ise kod ekranına yönlendir
        if (errorCode == 'email-not-verified') {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmailVerificationScreen(
                  email: email,
                  isNewUser: false, // Login'den geldi, yeni değil
                  onVerified: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                      (route) => false,
                    );
                  },
                ),
              ),
            );
          }
          return;
        }
        
        // Kullanıcı bulunamadıysa kayıt sayfasına yönlendir (geri dönebilir şekilde)
        if (errorCode == 'user-not-found' || errorCode.contains('user-not-found')) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SignUpScreen(),
              ),
            );
          }
        } else if (errorCode == 'invalid-credential' || errorCode.contains('invalid-credential')) {
          // invalid-credential: Şifre yanlış veya kullanıcı yok olabilir
          // Not: Firebase yeni sürümlerde bu iki durumu ayırt etmiyor (güvenlik için)
          setState(() => _errorMessage = lang.isTurkish 
              ? 'E-posta veya şifre hatalı.' 
              : 'Invalid email or password.');
        } else {
          setState(() => _errorMessage = lang.translateError(errorCode));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '${lang.error}: $e';
      });
    }
  }

  /// Kullanıcının var olup olmadığını kontrol et ve uygun sayfaya yönlendir
  Future<void> _checkUserExistsAndNavigate(String email) async {
    final lang = context.read<LanguageProvider>();
    try {
      // Firebase'de bu email ile kayıtlı kullanıcı var mı kontrol et (Firestore'dan)
      final userExists = await _authService.checkIfUserExists(email);
      
      if (!mounted) return;
      
      if (!userExists) {
        // Kullanıcı yok - kayıt ol sayfasına yönlendir
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SignUpScreen(),
          ),
        );
      } else {
        // Kullanıcı var ama şifre yanlış
        setState(() => _errorMessage = lang.isTurkish 
            ? 'Şifre hatalı. Lütfen tekrar deneyin.' 
            : 'Wrong password. Please try again.');
      }
    } catch (e) {
      // Hata durumunda genel mesaj göster
      setState(() => _errorMessage = lang.isTurkish 
          ? 'E-posta veya şifre hatalı.' 
          : 'Invalid email or password.');
    }
  }

  /// Email doğrulama dialog'u - Artık kullanılmıyor, kod ekranına yönlendirme var
  @Deprecated('Artık EmailVerificationScreen kullanılıyor')
  void _showEmailVerificationDialog(LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.mark_email_unread, color: const Color(0xFFE07A5F)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lang.isTurkish ? 'Email Doğrulanmadı' : 'Email Not Verified',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.isTurkish 
                  ? 'Giriş yapabilmek için email adresinizi doğrulamanız gerekmektedir.\n\nLütfen email kutunuzu kontrol edin ve doğrulama linkine tıklayın.'
                  : 'You need to verify your email address to log in.\n\nPlease check your inbox and click the verification link.',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: Text(lang.isTurkish ? 'Kapat' : 'Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              // Önce tekrar giriş yap (token almak için)
              await _authService.signIn(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              );
              
              final result = await _authService.resendVerificationEmail();
              
              await _authService.signOut();
              
              if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['success'] == true
                          ? (lang.isTurkish ? '📧 Doğrulama maili gönderildi!' : '📧 Verification email sent!')
                          : (lang.isTurkish ? '❌ Mail gönderilemedi' : '❌ Failed to send email'),
                    ),
                    backgroundColor: result['success'] == true ? const Color(0xFF6EC6B5) : Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.send, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6EC6B5),
              foregroundColor: Colors.white,
            ),
            label: Text(lang.isTurkish ? 'Tekrar Gönder' : 'Resend'),
          ),
        ],
      ),
    );
  }

  /// Şifremi unuttum - Yeni kod tabanlı şifre sıfırlama ekranına yönlendir
  void _handleForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PasswordResetScreen(
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  /// Google/Apple ile kayıt sonrası referral kodu girme dialogu (Güncellenmiş versiyon)
  Future<void> _showReferralDialog() async {
    final lang = context.read<LanguageProvider>();
    final teamCodeController = TextEditingController();
    final personalCodeController = TextEditingController();
    final nameController = TextEditingController();
    
    double hopeProgress = 0.0;
    bool isCheckingPersonal = false;
    bool isCheckingTeam = false;
    bool isApplying = false;
    String? personalError;
    String? teamError;
    bool personalCodeValid = false;
    bool teamCodeValid = false;
    
    // Doğrulanan kodları sakla (sonra uygula için)
    String? validatedPersonalCode;
    String? validatedTeamCode;
    
    // Kullanıcının mevcut ismini kontrol et
    final currentUser = _authService.currentFirebaseUser;
    String? existingName;
    bool needsName = false;
    
    if (currentUser != null) {
      final userDoc = await _authService.firestore.collection('users').doc(currentUser.uid).get();
      existingName = userDoc.data()?['full_name'] as String?;
      // İsim boş, null, "Kullanıcı", "Apple Kullanıcısı" veya çok kısa ise isim iste
      needsName = existingName == null || 
                  existingName.isEmpty || 
                  existingName == 'Kullanıcı' || 
                  existingName == 'Apple Kullanıcısı' ||
                  existingName.length < 3 ||
                  !existingName.contains(' ');
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          // İsim geçerli mi kontrol et (en az 3 karakter, boşluk içermeli)
          bool isNameValid() {
            if (!needsName) return true;
            final name = nameController.text.trim();
            return name.length >= 3 && name.contains(' ');
          }
          
          // İsmi Firestore'a kaydet
          Future<void> saveName() async {
            if (!needsName) return;
            final name = nameController.text.trim();
            if (name.length >= 3 && currentUser != null) {
              await _authService.firestore.collection('users').doc(currentUser.uid).update({
                'full_name': name,
                'full_name_lowercase': name.toLowerCase(),
                'masked_name': name.length > 2 ? '${name.substring(0, 2)}***' : name,
              });
            }
          }
          
          // Kişisel kodu kontrol et
          Future<void> checkPersonalCode() async {
            final code = personalCodeController.text.trim();
            if (code.isEmpty || personalCodeValid) return;
            
            setDialogState(() {
              isCheckingPersonal = true;
              personalError = null;
            });
            
            // Firestore'da kodu kontrol et
            final query = await _authService.firestore
                .collection('users')
                .where('personal_referral_code', isEqualTo: code.toUpperCase())
                .limit(1)
                .get();
            
            if (query.docs.isNotEmpty) {
              // Kendi kodunu mu girdi?
              final uid = _authService.currentFirebaseUser?.uid;
              if (query.docs.first.id == uid) {
                setDialogState(() {
                  isCheckingPersonal = false;
                  personalError = lang.isTurkish ? 'Kendi kodunuzu kullanamazsınız' : 'Cannot use your own code';
                });
                return;
              }
              
              validatedPersonalCode = code.toUpperCase();
              setDialogState(() {
                isCheckingPersonal = false;
                personalCodeValid = true;
                hopeProgress += 0.5;
              });
            } else {
              setDialogState(() {
                isCheckingPersonal = false;
                personalError = lang.isTurkish ? 'Geçersiz kod' : 'Invalid code';
              });
            }
          }
          
          // Takım kodunu kontrol et
          Future<void> checkTeamCode() async {
            final code = teamCodeController.text.trim();
            if (code.isEmpty || teamCodeValid) return;
            
            setDialogState(() {
              isCheckingTeam = true;
              teamError = null;
            });
            
            // Firestore'da takım kodunu kontrol et
            final query = await _authService.firestore
                .collection('teams')
                .where('referral_code', isEqualTo: code.toUpperCase())
                .limit(1)
                .get();
            
            if (query.docs.isNotEmpty) {
              validatedTeamCode = code.toUpperCase();
              setDialogState(() {
                isCheckingTeam = false;
                teamCodeValid = true;
                hopeProgress += 0.5;
              });
            } else {
              setDialogState(() {
                isCheckingTeam = false;
                teamError = lang.isTurkish ? 'Geçersiz takım kodu' : 'Invalid team code';
              });
            }
          }
          
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: MediaQuery.of(dialogContext).size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scrollable içerik
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Başlık
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.card_giftcard, color: Color(0xFF6EC6B5), size: 28),
                              const SizedBox(width: 8),
                              Text(
                                lang.isTurkish ? 'Bonus Kazan!' : 'Earn Bonus!',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lang.isTurkish
                                ? 'Davet kodları girerek Hope Adımlarını doldur!'
                                : 'Fill the Hope Steps by entering referral codes!',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          
                          // İsim alanı (sadece isim boşsa göster)
                          if (needsName) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isNameValid() ? Colors.green : Colors.orange,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isNameValid() ? Icons.check_circle : Icons.warning_amber_rounded,
                                        color: isNameValid() ? Colors.green : Colors.orange,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        lang.isTurkish ? 'Profilinizi Tamamlayın' : 'Complete Your Profile',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isNameValid() ? Colors.green : Colors.orange[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: nameController,
                                    textCapitalization: TextCapitalization.words,
                                    onChanged: (_) => setDialogState(() {}),
                                    decoration: InputDecoration(
                                      hintText: lang.isTurkish ? 'İsim Soyisim' : 'Full Name',
                                      prefixIcon: const Icon(Icons.person, color: Colors.orange),
                                      suffixIcon: isNameValid()
                                          ? const Icon(Icons.check_circle, color: Colors.green)
                                          : null,
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Colors.orange, width: 2),
                                      ),
                                    ),
                                  ),
                                  if (!isNameValid() && nameController.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        lang.isTurkish 
                                            ? 'İsim ve soyisim girin (örn: Ali Yılmaz)' 
                                            : 'Enter first and last name',
                                        style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 8),
                          
                          // Hope Sıvı Bardağı - Geniş ve dolu
                          SizedBox(
                            height: 130,
                            width: 220,
                            child: HopeLiquidProgress(
                              progress: hopeProgress,
                              width: 220,
                              height: 130,
                            ),
                          ),
                          
                          // Tebrikler mesajı (sadece %100'de)
                          if (hopeProgress == 1.0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                lang.isTurkish ? '🎉 Tebrikler! Maksimum bonus!' : '🎉 Congrats! Maximum bonus!',
                                style: const TextStyle(color: Color(0xFF6EC6B5), fontWeight: FontWeight.w600),
                              ),
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Kişisel davet kodu (ilk %50) - Otomatik kontrol
                          _buildAutoCheckReferralField(
                            controller: personalCodeController,
                            label: lang.isTurkish ? 'Kişisel Davet Kodu' : 'Personal Referral Code',
                            hint: lang.isTurkish ? 'Kodu girin...' : 'Enter code...',
                            icon: Icons.person_add,
                            color: const Color(0xFFE07A5F),
                            isValid: personalCodeValid,
                            isChecking: isCheckingPersonal,
                            error: personalError,
                            bonus: lang.isTurkish ? 'Siz +100K, Davet +100K' : 'You +100K, Ref +100K',
                            onChanged: (value) {
                              // 6+ karakter olunca otomatik kontrol et
                              if (value.length >= 6 && !personalCodeValid && !isCheckingPersonal) {
                                checkPersonalCode();
                              }
                            },
                            lang: lang,
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Takım davet kodu (ikinci %50) - Otomatik kontrol
                          _buildAutoCheckReferralField(
                            controller: teamCodeController,
                            label: lang.isTurkish ? 'Takım Davet Kodu' : 'Team Referral Code',
                            hint: lang.isTurkish ? 'Kodu girin...' : 'Enter code...',
                            icon: Icons.groups,
                            color: const Color(0xFF6EC6B5),
                            isValid: teamCodeValid,
                            isChecking: isCheckingTeam,
                            error: teamError,
                            bonus: lang.isTurkish ? 'Siz +100K, Takım +100K' : 'You +100K, Team +100K',
                            onChanged: (value) {
                              // 6+ karakter olunca otomatik kontrol et
                              if (value.length >= 6 && !teamCodeValid && !isCheckingTeam) {
                                checkTeamCode();
                              }
                            },
                            lang: lang,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Butonlar - Scroll dışında sabit
                  const SizedBox(height: 16),
                  
                  // İsim gerekiyorsa ve dolu değilse uyarı göster
                  if (needsName && !isNameValid())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        lang.isTurkish 
                            ? '⚠️ Devam etmek için isim soyisim girin' 
                            : '⚠️ Enter your name to continue',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  Row(
                    children: [
                      // Atla butonu - İsim doluysa aktif
                      Expanded(
                        child: OutlinedButton(
                          onPressed: (isApplying || !isNameValid()) ? null : () async {
                            // İsmi kaydet
                            await saveName();
                            Navigator.pop(dialogContext);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            lang.isTurkish ? 'Atla' : 'Skip',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bonusları Al butonu - İsim dolu VE kod doğrulandıysa aktif
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: (hopeProgress > 0 && isNameValid())
                                  ? [const Color(0xFF6EC6B5), const Color(0xFFE07A5F)]
                                  : [Colors.grey[400]!, Colors.grey[500]!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            // İsim ve kod doğrulanmadıysa buton devre dışı
                            onPressed: (isApplying || !isNameValid() || (!personalCodeValid && !teamCodeValid)) ? null : () async {
                              
                              setDialogState(() => isApplying = true);
                              
                              // Önce ismi kaydet
                              await saveName();
                              
                              final uid = _authService.currentFirebaseUser?.uid;
                              if (uid != null) {
                                final result = await _authService.processReferralCodesForSocialLogin(
                                  userId: uid,
                                  teamReferralCode: validatedTeamCode,
                                  personalReferralCode: validatedPersonalCode,
                                );
                                
                                if (result['success'] == true && mounted) {
                                  Navigator.pop(dialogContext);
                                } else {
                                  setDialogState(() => isApplying = false);
                                }
                              } else {
                                setDialogState(() => isApplying = false);
                                Navigator.pop(dialogContext);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isApplying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    lang.isTurkish ? 'Bonusları Al' : 'Get Bonuses',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  /// Auto-check referral input field helper
  Widget _buildAutoCheckReferralField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    required bool isValid,
    required bool isChecking,
    required String? error,
    required String bonus,
    required void Function(String) onChanged,
    required dynamic lang,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        // Bonus açıklaması (ayrı satırda)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isValid ? Colors.green.withOpacity(0.1) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isValid ? '✓ ${lang.isTurkish ? 'Kazanıldı' : 'Earned'}' : bonus,
            style: TextStyle(
              color: isValid ? Colors.green : color, 
              fontSize: 11, 
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          enabled: !isValid,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: isValid ? Colors.green : color),
            suffixIcon: isChecking
                ? Container(
                    width: 20,
                    height: 20,
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : isValid
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
            filled: isValid,
            fillColor: isValid ? Colors.green.withOpacity(0.05) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: error != null ? Colors.red : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(color: Colors.red, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
