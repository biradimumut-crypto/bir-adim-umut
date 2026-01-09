import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../providers/language_provider.dart';
import 'sign_up_screen.dart';

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
                  const SizedBox(height: 10),
                  
                  // Logo GIF - Tek seferlik, son karede kalır
                  Center(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: _gifFinished && _frozenGifImage != null
                          ? Image.memory(
                              _frozenGifImage!,
                              width: 220,
                              height: 220,
                              gaplessPlayback: true,
                            )
                          : RepaintBoundary(
                              key: _gifKey,
                              child: Image.asset(
                                'assets/videos/yeni.gif',
                                width: 220,
                                height: 220,
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
        
        // Kullanıcı bulunamadıysa veya geçersiz credential ise kayıt sayfasına yönlendir
        if (errorCode == 'user-not-found' || errorCode == 'invalid-credential' || errorCode.contains('user-not-found') || errorCode.contains('invalid-credential')) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const SignUpScreen(),
              ),
            );
          }
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

  /// Şifremi unuttum
  void _handleForgotPassword() {
    final lang = context.read<LanguageProvider>();
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.resetPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang.resetPasswordDesc),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: lang.email,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6EC6B5),
            ),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty) {
                await _authService.resetPassword(emailController.text.trim());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('📧 ${lang.passwordResetSent}'),
                      backgroundColor: const Color(0xFF6EC6B5),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6EC6B5),
              foregroundColor: Colors.white,
            ),
            child: Text(lang.isTurkish ? 'Gönder' : 'Send'),
          ),
        ],
      ),
    );
  }

  /// Google/Apple ile kayıt sonrası referral kodu girme dialogu
  Future<void> _showReferralDialog() async {
    final lang = context.read<LanguageProvider>();
    final teamCodeController = TextEditingController();
    final personalCodeController = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.isTurkish ? 'Davet Kodunuz Var mı?' : 'Have a Referral Code?',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.isTurkish 
                    ? 'Kodları girerek 100.000 bonus adım kazanabilirsiniz!'
                    : 'Enter codes to earn 100,000 bonus steps!',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 20),
              // Takım referral kodu
              Text(
                lang.isTurkish ? 'Takım Davet Kodu (Opsiyonel)' : 'Team Referral Code (Optional)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: teamCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: lang.isTurkish ? 'Örn: ABC123' : 'e.g., ABC123',
                  prefixIcon: const Icon(Icons.groups, color: Color(0xFF6EC6B5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6EC6B5), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Kişisel davet kodu
              Text(
                lang.isTurkish ? 'Kişisel Davet Kodu (Opsiyonel)' : 'Personal Referral Code (Optional)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: personalCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: lang.isTurkish ? 'Örn: XYZ789' : 'e.g., XYZ789',
                  prefixIcon: const Icon(Icons.person_add, color: Color(0xFFE07A5F)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE07A5F), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              lang.isTurkish ? 'Atla' : 'Skip',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () async {
                final teamCode = teamCodeController.text.trim();
                final personalCode = personalCodeController.text.trim();
                
                if (teamCode.isNotEmpty || personalCode.isNotEmpty) {
                  final uid = _authService.currentFirebaseUser?.uid;
                  if (uid != null) {
                    final result = await _authService.processReferralCodesForSocialLogin(
                      userId: uid,
                      teamReferralCode: teamCode.isNotEmpty ? teamCode : null,
                      personalReferralCode: personalCode.isNotEmpty ? personalCode : null,
                    );
                    
                    if (result['success'] == true && result['message'] != null && result['message'].toString().isNotEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 ${result['message']}'),
                            backgroundColor: const Color(0xFF6EC6B5),
                          ),
                        );
                      }
                    }
                  }
                }
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(lang.isTurkish ? 'Uygula' : 'Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
