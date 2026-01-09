import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../providers/language_provider.dart';
import '../dashboard/dashboard_screen.dart';
import 'login_screen.dart';

/// Kayıt Ol Sayfası
/// 
/// Kullanıcıların e-posta, şifre ve **referral kodu** ile kayıt olabileceği sayfa.
/// Referral kodu girişi opsiyoneldir ama girilirse kullanıcı otomatik takıma eklenir.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();

  // Form kontrolleri
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralCodeController =
      TextEditingController(); // Takım referral kodu
  final TextEditingController _personalReferralCodeController =
      TextEditingController(); // Kişisel referral kodu

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _errorMessage;
  
  // GIF kontrolü
  final GlobalKey _gifKey = GlobalKey();
  // ignore: unused_field
  Uint8List? _frozenGifImage;
  // ignore: unused_field
  bool _gifFinished = false;

  @override
  void initState() {
    super.initState();
    // GIF süresi kadar bekle
    Future.delayed(const Duration(milliseconds: 2900), () {
      _captureGifFrame();
    });
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
      print('GIF capture hatası: $e');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _personalReferralCodeController.dispose();
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
                  // Geri butonu
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  
                  // GIF Logo - Küçük
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/videos/yeni.gif',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang.signUpWelcome,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  // Form alanları - Expanded içinde
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Ad Soyad
                          _buildTextField(
                            controller: _fullNameController,
                            label: lang.fullName,
                            hint: lang.fullNameHint,
                            prefixIcon: Icons.person,
                            lang: lang,
                          ),

                          // E-posta
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            label: lang.email,
                            hint: lang.emailHint,
                            prefixIcon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            lang: lang,
                          ),

                          // Şifre
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _passwordController,
                            label: lang.password,
                            hint: lang.isTurkish ? 'En az 6 karakter' : 'At least 6 characters',
                            prefixIcon: Icons.lock,
                            obscureText: !_isPasswordVisible,
                            lang: lang,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() => _isPasswordVisible = !_isPasswordVisible);
                              },
                            ),
                          ),

                          // Şifre Doğrulama
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: lang.confirmPassword,
                            hint: lang.isTurkish ? 'Şifreyi tekrar yazınız' : 'Re-enter password',
                            prefixIcon: Icons.lock_outline,
                            obscureText: !_isConfirmPasswordVisible,
                            lang: lang,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() =>
                                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                              },
                            ),
                          ),

                          // Takım Referral Code (Opsiyonel)
                          const SizedBox(height: 8),
                          _buildReferralCodeField(lang),

                          // Kişisel Referral Code (Opsiyonel) - 100.000 bonus adım
                          const SizedBox(height: 8),
                          _buildPersonalReferralCodeField(lang),

                          // Hata Mesajı - Premium Görünüm
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red.shade50,
                                      Colors.red.shade100.withOpacity(0.5),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.red.shade700,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Kayıt Ol Butonu - Gradient
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE07A5F).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () => _handleSignUp(lang),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
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
                                      lang.signUp,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          // Zaten üye misin?
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${lang.alreadyHaveAccount} ',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                  );
                                },
                                child: ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                                  ).createShader(bounds),
                                  child: Text(
                                    lang.login,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // Veya ayırıcı
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey[300])),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  lang.or,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey[300])),
                            ],
                          ),
                          
                          // Sosyal giriş butonları
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google butonu
                              _buildSocialButton(
                                onTap: _handleGoogleSignUp,
                                child: SvgPicture.asset(
                                  'assets/icons/google_logo.svg',
                                  width: 24,
                                  height: 24,
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Apple butonu
                              _buildSocialButton(
                                onTap: _handleAppleSignUp,
                                child: const Icon(
                                  Icons.apple,
                                  size: 28,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Standart Text Field Builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    required LanguageProvider lang,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(prefixIcon, size: 20),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  /// Referral Code Field (Opsiyonel) - Takım için
  Widget _buildReferralCodeField(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.group, size: 16, color: Color(0xFF6EC6B5)),
            const SizedBox(width: 6),
            Text(
              lang.isTurkish ? 'Takım Referral Kodu' : 'Team Referral Code',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6EC6B5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                lang.isTurkish ? 'Opsiyonel' : 'Optional',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6EC6B5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _referralCodeController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: lang.isTurkish ? 'Örn: ABC123' : 'E.g: ABC123',
            
            prefixIcon: const Icon(Icons.group_add, size: 20, color: Color(0xFF6EC6B5)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  /// Kişisel Referral Code Field (Opsiyonel) - 100.000 bonus adım
  Widget _buildPersonalReferralCodeField(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_add, size: 16, color: Color(0xFFE07A5F)),
            const SizedBox(width: 6),
            Text(
              lang.isTurkish ? 'Davet Kodu' : 'Invite Code',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE07A5F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                lang.isTurkish ? '+100K Adım' : '+100K Steps',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFE07A5F),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          lang.isTurkish 
              ? 'Bir arkadaşınızdan davet kodu girin, ikiniz de 100.000 bonus adım kazanın!'
              : 'Enter an invite code from a friend, both of you get 100,000 bonus steps!',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _personalReferralCodeController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: lang.isTurkish ? 'Örn: XYZ789' : 'E.g: XYZ789',
            prefixIcon: const Icon(Icons.card_giftcard, size: 20, color: Color(0xFFE07A5F)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: const Color(0xFFE07A5F).withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE07A5F), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  /// Kayıt Olma İşlemi
  Future<void> _handleSignUp(LanguageProvider lang) async {
    setState(() => _errorMessage = null);

    // Validasyon
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = lang.isTurkish ? 'Tüm alanları doldurunuz.' : 'Please fill in all fields.');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = lang.passwordsNotMatch);
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = lang.passwordTooShort);
      return;
    }

    if (_fullNameController.text.split(' ').length < 2) {
      setState(() => _errorMessage = lang.isTurkish ? 'Lütfen ad ve soyadınızı yazınız.' : 'Please enter your full name.');
      return;
    }

    setState(() => _isLoading = true);

    // Kayıt işlemi
    final result = await _authService.signUpWithReferral(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      referralCode: _referralCodeController.text.trim().isNotEmpty
          ? _referralCodeController.text.trim().toUpperCase()
          : null,
      personalReferralCode: _personalReferralCodeController.text.trim().isNotEmpty
          ? _personalReferralCodeController.text.trim().toUpperCase()
          : null,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success']) {
      // Başarılı, rozet kontrolü yap
      try {
        await BadgeService().updateLoginStreak();
        await BadgeService().checkAllBadges();
      } catch (e) {
        debugPrint('Badge kontrolü hatası: $e');
      }

      // Dashboard'a yönlendir (iOS Health izni otomatik istenecek)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const DashboardScreen(),
          ),
        );
      }
    } else {
      setState(
        () => _errorMessage = lang.translateError(result['error'] ?? 'unknown'),
      );
    }
  }

  /// Sosyal giriş butonu widget'ı
  Widget _buildSocialButton({required VoidCallback onTap, required Widget child}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 50,
        height: 50,
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

  /// Kayıt sonrası izin kontrolü ve yönlendirme
  Future<void> _navigateAfterSignUp() async {
    if (!mounted) return;
    
    // Rozet kontrolü yap
    try {
      await BadgeService().updateLoginStreak();
      await BadgeService().checkAllBadges();
    } catch (e) {
      debugPrint('Badge kontrolü hatası: $e');
    }
    
    // Dashboard'a yönlendir (iOS Health izni otomatik istenecek)
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        ),
      );
    }
  }

  /// Google ile kayıt
  Future<void> _handleGoogleSignUp() async {
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
          await _navigateAfterSignUp();
        }
      } else {
        final error = result['error'] ?? '';
        setState(() => _errorMessage = lang.translateError(error));
      }
    } catch (e) {
      setState(() => _errorMessage = lang.isTurkish 
          ? 'Google ile kayıt başarısız oldu.' 
          : 'Google sign-up failed.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Apple ile kayıt
  Future<void> _handleAppleSignUp() async {
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
          await _navigateAfterSignUp();
        }
      } else {
        final error = result['error'] ?? '';
        setState(() => _errorMessage = lang.translateError(error));
      }
    } catch (e) {
      setState(() => _errorMessage = lang.isTurkish 
          ? 'Apple ile kayıt başarısız oldu.' 
          : 'Apple sign-up failed.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
