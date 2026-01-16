import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import 'success_dialog.dart';

/// Hesap Silme Dialog'u (BUG-006)
/// Apple App Store, Google Play Store, GDPR ve KVKK zorunluluğu
class DeleteAccountDialog extends StatefulWidget {
  final VoidCallback onAccountDeleted;

  const DeleteAccountDialog({
    Key? key,
    required this.onAccountDeleted,
  }) : super(key: key);

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();

  /// Dialog'u göster
  static Future<void> show(BuildContext context, {required VoidCallback onAccountDeleted}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteAccountDialog(onAccountDeleted: onAccountDeleted),
    );
  }
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final AuthService _authService = AuthService();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _confirmChecked = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteAccount() async {
    final lang = context.read<LanguageProvider>();
    
    // Validasyon
    if (!_confirmChecked) {
      setState(() => _errorMessage = lang.isTurkish 
          ? 'Lütfen onay kutusunu işaretleyin' 
          : 'Please check the confirmation box');
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = lang.isTurkish 
          ? 'Şifrenizi girin' 
          : 'Enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Re-authenticate
    final reauthResult = await _authService.reauthenticate(_passwordController.text);
    
    if (reauthResult['success'] != true) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = reauthResult['error'] ?? (lang.isTurkish ? 'Şifre yanlış' : 'Wrong password');
        });
      }
      return;
    }

    // 2. Hesabı sil
    final deleteResult = await _authService.deleteAccount();

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (deleteResult['success'] == true) {
      Navigator.pop(context);
      
      // Başarı bildirimi
      await showSuccessDialog(
        context: context,
        title: lang.isTurkish ? 'Hesap Silindi' : 'Account Deleted',
        message: lang.isTurkish 
            ? 'Hesabınız ve tüm verileriniz başarıyla silindi. Umarız tekrar görüşürüz!' 
            : 'Your account and all data have been successfully deleted. Hope to see you again!',
        icon: Icons.check_circle,
        gradientColors: [const Color(0xFF6EC6B5), const Color(0xFF4CAF50)],
        buttonText: lang.isTurkish ? 'Tamam' : 'OK',
      );
      
      widget.onAccountDeleted();
    } else {
      setState(() {
        _errorMessage = deleteResult['error'] ?? (lang.isTurkish 
            ? 'Hesap silinemedi' 
            : 'Failed to delete account');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.isTurkish ? 'Hesabı Sil' : 'Delete Account',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Uyarı kutusu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          lang.isTurkish ? 'DİKKAT!' : 'WARNING!',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lang.isTurkish 
                          ? 'Bu işlem geri alınamaz. Aşağıdaki verileriniz kalıcı olarak silinecek:'
                          : 'This action cannot be undone. The following data will be permanently deleted:',
                      style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _buildDeleteItem(lang.isTurkish ? 'Profil bilgileriniz' : 'Your profile information'),
                    _buildDeleteItem(lang.isTurkish ? 'Adım geçmişiniz' : 'Your step history'),
                    _buildDeleteItem(lang.isTurkish ? 'Takım üyelikleriniz' : 'Your team memberships'),
                    _buildDeleteItem(lang.isTurkish ? 'Kazandığınız rozetler' : 'Your earned badges'),
                    _buildDeleteItem(lang.isTurkish ? 'Tüm bildirimleriniz' : 'All your notifications'),
                    _buildDeleteItem(lang.isTurkish ? 'Hope bakiyeniz' : 'Your Hope balance'),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Şifre alanı
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: lang.isTurkish ? 'Şifrenizi girin' : 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _errorMessage,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Onay checkbox
              CheckboxListTile(
                value: _confirmChecked,
                onChanged: _isLoading ? null : (value) => setState(() => _confirmChecked = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  lang.isTurkish 
                      ? 'Hesabımı ve tüm verilerimi kalıcı olarak silmek istediğimi onaylıyorum.'
                      : 'I confirm that I want to permanently delete my account and all data.',
                  style: const TextStyle(fontSize: 13),
                ),
                activeColor: Colors.red,
              ),
              
              const SizedBox(height: 20),
              
              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(lang.isTurkish ? 'İptal' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleDeleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_forever, size: 20),
                                const SizedBox(width: 8),
                                Text(lang.isTurkish ? 'Hesabı Sil' : 'Delete Account'),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
