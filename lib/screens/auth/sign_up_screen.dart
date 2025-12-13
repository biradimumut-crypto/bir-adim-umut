import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
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
      TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaydı Ol'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık
            const SizedBox(height: 20),
            Text(
              'Bir Adım Umut Ailesine Hoşgeldin',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Adımlarınla umut yayın, takım kurun, bağış yapın',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),

            // Form alanları
            const SizedBox(height: 32),

            // Ad Soyad
            _buildTextField(
              controller: _fullNameController,
              label: 'Ad Soyad',
              hint: 'Örn: Ahmet Yılmaz',
              prefixIcon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ad soyad gereklidir';
                }
                if (value.split(' ').length < 2) {
                  return 'Lütfen ad ve soyadınızı yazınız';
                }
                return null;
              },
            ),

            // E-posta
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'E-posta',
              hint: 'Örn: ahmet@example.com',
              prefixIcon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'E-posta gereklidir';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Geçersiz e-posta adresi';
                }
                return null;
              },
            ),

            // Şifre
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Şifre',
              hint: 'En az 6 karakter',
              prefixIcon: Icons.lock,
              obscureText: !_isPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Şifre gereklidir';
                }
                if (value.length < 6) {
                  return 'Şifre en az 6 karakter olmalıdır';
                }
                return null;
              },
            ),

            // Şifre Doğrulama
            const SizedBox(height: 16),
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Şifre (Doğrula)',
              hint: 'Şifreyi tekrar yazınız',
              prefixIcon: Icons.lock_outline,
              obscureText: !_isConfirmPasswordVisible,
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
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Şifreler uyuşmuyor';
                }
                return null;
              },
            ),

            // Referral Code (Opsiyonel)
            const SizedBox(height: 16),
            _buildReferralCodeField(),

            // Hata Mesajı
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            // Kayıt Ol Butonu
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSignUp,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
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
                      ),
                    )
                  : const Text(
                      'Kaydı Tamamla',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),

            // Zaten üye misin?
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Zaten üye misin? ',
                  style: TextStyle(color: Colors.grey[600]),
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
                  child: const Text(
                    'Giriş Yap',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Standart Text Field Builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
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
        if (validator != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              validator(controller.text) ?? '',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  /// Referral Code Field (Opsiyonel)
  Widget _buildReferralCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Referral Kodu',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Opsiyonel',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue,
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
            hintText: 'Örn: ABC123',
            helperText:
                'Bir arkadaşınızın takım kodunu girerseniz otomatik o takıma katılırsınız.',
            prefixIcon: const Icon(Icons.card_giftcard, size: 20),
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
  Future<void> _handleSignUp() async {
    setState(() => _errorMessage = null);

    // Validasyon
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Tüm alanları doldurunuz.');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Şifreler uyuşmuyor.');
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Şifre en az 6 karakter olmalıdır.');
      return;
    }

    if (_fullNameController.text.split(' ').length < 2) {
      setState(() => _errorMessage = 'Lütfen ad ve soyadınızı yazınız.');
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
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success']) {
      // Başarılı, ana sayfaya yönlendir
      if (result['teamId'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Başarıyla kayıt oldunuz ve takıma katıldınız!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Başarıyla kayıt oldunuz!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Dashboard'a git
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      setState(
        () => _errorMessage = result['error'] ?? 'Bilinmeyen hata oluştu.',
      );
    }
  }
}
