import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/language_provider.dart';
import '../../services/badge_service.dart';

/// Şifre sıfırlama ekranı - 6 haneli kod ile
class PasswordResetScreen extends StatefulWidget {
  final String? initialEmail;

  const PasswordResetScreen({
    Key? key,
    this.initialEmail,
  }) : super(key: key);

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _codeSent = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _errorMessage;
  String? _maskedEmail;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _codeControllers) {
      c.dispose();
    }
    for (var f in _codeFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _codeControllers.map((c) => c.text).join();

  void _startResendCooldown() {
    setState(() => _resendCooldown = 60);
    _countDown();
  }

  void _countDown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCooldown > 0) {
        setState(() => _resendCooldown--);
        _countDown();
      }
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Email adresi girin');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Geçerli bir email adresi girin');
      return;
    }

    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendPasswordResetCode');
      final result = await callable.call({'email': email});

      _maskedEmail = result.data['email'];
      _startResendCooldown();

      setState(() {
        _codeSent = true;
        _isSendingCode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kod gönderildi: $_maskedEmail'),
            backgroundColor: const Color(0xFF6EC6B5),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Kod gönderilemedi';
        _isSendingCode = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Bir hata oluştu';
        _isSendingCode = false;
      });
    }
  }

  Future<void> _verifyCodeAndResetPassword() async {
    if (_code.length != 6) {
      setState(() => _errorMessage = 'Lütfen 6 haneli kodu girin');
      return;
    }

    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 6) {
      setState(() => _errorMessage = 'Şifre en az 6 karakter olmalı');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Şifreler eşleşmiyor');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('resetPasswordWithCode');
      await callable.call({
        'email': _emailController.text.trim(),
        'code': _code,
        'newPassword': newPassword,
      });

      // Başarılı! Otomatik giriş yap ve dashboard'a git
      if (mounted) {
        await _autoLoginAndNavigate();
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Şifre sıfırlama başarısız';
      });
      // Yanlış kod ise input'ları temizle
      if (e.code == 'invalid-argument' && e.message?.contains('Yanlış kod') == true) {
        _clearCodeInputs();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Bir hata oluştu';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearCodeInputs() {
    for (var c in _codeControllers) {
      c.clear();
    }
    _codeFocusNodes[0].requestFocus();
  }

  /// Şifre değiştirildikten sonra otomatik giriş yap
  Future<void> _autoLoginAndNavigate() async {
    try {
      // Yeni şifreyle otomatik giriş yap
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _newPasswordController.text,
      );
      
      // Badge kontrolü
      try {
        await BadgeService().updateLoginStreak();
        await BadgeService().checkAllBadges();
      } catch (e) {
        debugPrint('Badge kontrolü hatası: $e');
      }

      if (mounted) {
        // Başarı dialogunu göster ve dashboard'a git
        _showSuccessDialogThenNavigate();
      }
    } catch (e) {
      debugPrint('Otomatik giriş hatası: $e');
      // Otomatik giriş başarısız olduysa sadece login sayfasına dön
      if (mounted) {
        _showSuccessDialogFallback();
      }
    }
  }

  /// Başarı dialogu - Dashboard'a yönlendirir
  void _showSuccessDialogThenNavigate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE07A5F).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Şifre Güncellendi!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Şifreniz başarıyla güncellendi.\nAna sayfaya yönlendiriliyorsunuz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            width: double.infinity,
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
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dialog'u kapat
                // Ana sayfaya git (tüm stack'i temizle)
                Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ana Sayfaya Git',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback başarı dialogu - Login sayfasına döner
  void _showSuccessDialogFallback() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE07A5F).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Şifre Güncellendi!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Şifreniz başarıyla güncellendi.\nYeni şifrenizle giriş yapabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            width: double.infinity,
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
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dialog'u kapat
                Navigator.of(context).pop(); // PasswordResetScreen'den çık
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Giriş Yap',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _codeFocusNodes[index + 1].requestFocus();
    }
  }

  void _onCodeKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_codeControllers[index].text.isEmpty && index > 0) {
          _codeFocusNodes[index - 1].requestFocus();
          _codeControllers[index - 1].clear();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          lang.isTurkish ? 'Şifremi Unuttum' : 'Forgot Password',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE07A5F).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    color: Color(0xFFE07A5F),
                    size: 48,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Açıklama
              Text(
                _codeSent
                    ? (lang.isTurkish 
                        ? 'Email adresinize gönderilen 6 haneli kodu girin ve yeni şifrenizi belirleyin.'
                        : 'Enter the 6-digit code sent to your email and set your new password.')
                    : (lang.isTurkish
                        ? 'Email adresinizi girin, size şifre sıfırlama kodu göndereceğiz.'
                        : 'Enter your email address and we\'ll send you a password reset code.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 32),

              // Email alanı (sadece kod gönderilmemişse düzenlenebilir)
              TextField(
                controller: _emailController,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'ornek@email.com',
                  prefixIcon: const Icon(Icons.email, color: Color(0xFFE07A5F)),
                  filled: true,
                  fillColor: _codeSent ? Colors.grey[100] : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE07A5F), width: 2),
                  ),
                ),
              ),

              // Kod gönderilmişse
              if (_codeSent) ...[
                const SizedBox(height: 24),

                // Kod input alanları
                Text(
                  lang.isTurkish ? 'Doğrulama Kodu' : 'Verification Code',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 48,
                      height: 56,
                      margin: EdgeInsets.only(
                        left: index == 0 ? 0 : 6,
                        right: index == 2 ? 12 : 0,
                      ),
                      child: RawKeyboardListener(
                        focusNode: FocusNode(),
                        onKey: (event) => _onCodeKeyDown(index, event),
                        child: TextField(
                          controller: _codeControllers[index],
                          focusNode: _codeFocusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE07A5F),
                                width: 2,
                              ),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) => _onCodeChanged(index, value),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // Yeni şifre
                TextField(
                  controller: _newPasswordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: lang.isTurkish ? 'Yeni Şifre' : 'New Password',
                    hintText: lang.isTurkish ? 'En az 6 karakter' : 'At least 6 characters',
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFFE07A5F)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE07A5F), width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Şifre tekrar
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: lang.isTurkish ? 'Şifre Tekrar' : 'Confirm Password',
                    hintText: lang.isTurkish ? 'Şifreyi tekrar girin' : 'Re-enter password',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFE07A5F)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE07A5F), width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Tekrar gönder
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lang.isTurkish ? 'Kod gelmedi mi? ' : 'Didn\'t receive code? ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    if (_resendCooldown > 0)
                      Text(
                        '${_resendCooldown}s',
                        style: const TextStyle(
                          color: Color(0xFFE07A5F),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _isSendingCode ? null : _sendCode,
                        child: Text(
                          lang.isTurkish ? 'Tekrar Gönder' : 'Resend',
                          style: TextStyle(
                            color: _isSendingCode ? Colors.grey : const Color(0xFFE07A5F),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Hata mesajı
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Ana buton
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isSendingCode)
                      ? null
                      : (_codeSent ? _verifyCodeAndResetPassword : _sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE07A5F),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: (_isLoading || _isSendingCode)
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _codeSent
                              ? (lang.isTurkish ? 'Şifreyi Güncelle' : 'Update Password')
                              : (lang.isTurkish ? 'Kod Gönder' : 'Send Code'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
