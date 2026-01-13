import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../providers/language_provider.dart';
import '../../widgets/hope_liquid_progress.dart';
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
                  // Üst bar - Geri butonu ve dil değiştirme
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Geri butonu
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                      // Dil değiştirme butonu
                      GestureDetector(
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
                    ],
                  ),
                  
                  // GIF Logo - Login ile aynı boyut
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/videos/yeni.gif',
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
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

    // Basit kayıt işlemi (referral kodları sonra sorulacak)
    final result = await _authService.signUpSimple(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
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

      // Referral dialog göster (Google/Apple ile aynı)
      if (mounted) {
        await _showReferralDialog(lang);
      }

      // Dashboard'a yönlendir
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

  /// Referral Dialog (Kayıt sonrası) - Sıvı Dolu Hope Bardağı ile
  /// Her kod girildiğinde anlık kontrol yapılır
  /// İsim boşsa zorunlu isim girişi ister
  Future<void> _showReferralDialog(LanguageProvider lang) async {
    final teamCodeController = TextEditingController();
    final personalCodeController = TextEditingController();
    final nameController = TextEditingController();
    
    double hopeProgress = 0.0;
    bool isCheckingPersonal = false;
    bool isCheckingTeam = false;
    bool isApplying = false;
    String? personalError;
    String? teamError;
    String? nameError;
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
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const DashboardScreen()),
                            );
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
                                    // Ana sayfaya yönlendir
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                                    );
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
            await _showReferralDialog(lang);
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
            await _showReferralDialog(lang);
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
}
