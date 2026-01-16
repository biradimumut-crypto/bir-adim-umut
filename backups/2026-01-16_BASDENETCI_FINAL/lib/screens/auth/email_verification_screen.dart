import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import '../../services/badge_service.dart';
import '../../services/auth_service.dart';
import '../../providers/language_provider.dart';
import '../../widgets/hope_liquid_progress.dart';
import '../dashboard/dashboard_screen.dart';

/// Email doğrulama kodu giriş ekranı
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final VoidCallback? onVerified;
  final bool isNewUser; // Yeni kayıt mı yoksa login mi?

  const EmailVerificationScreen({
    Key? key,
    required this.email,
    this.onVerified,
    this.isNewUser = false,
  }) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isSendingCode = false;
  String? _errorMessage;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    // İlk kod otomatik gönderildi (kayıt sırasında)
    _startResendCooldown();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() {
      _resendCooldown = 60;
    });
    _countDown();
  }

  void _countDown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
        _countDown();
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _sendCode() async {
    if (_isSendingCode || _resendCooldown > 0) return;

    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendVerificationCode');
      await callable.call();

      _startResendCooldown();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doğrulama kodu gönderildi!'),
            backgroundColor: Color(0xFF6EC6B5),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Kod gönderilemedi';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Bir hata oluştu';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_code.length != 6) {
      setState(() {
        _errorMessage = 'Lütfen 6 haneli kodu girin';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('verifyEmailCode');
      await callable.call({'code': _code});

      // Başarılı!
      if (mounted) {
        // Kısa bir başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email doğrulandı! 🎉'),
            backgroundColor: Color(0xFF6EC6B5),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Yeni kullanıcı ise rozet kontrolü yap
        if (widget.isNewUser) {
          try {
            await BadgeService().updateLoginStreak();
            await BadgeService().checkAllBadges();
          } catch (e) {
            debugPrint('Badge kontrolü hatası: $e');
          }
          
          // Referral dialog göster
          if (mounted) {
            await _showReferralDialog();
          }
        }
        
        // Dashboard'a yönlendir
        if (mounted) {
          if (widget.onVerified != null) {
            widget.onVerified!();
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (route) => false,
            );
          }
        }
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Doğrulama başarısız';
      });
      // Yanlış kod girildiğinde input'ları temizle
      if (e.code == 'invalid-argument') {
        _clearInputs();
      }
    } catch (e) {
      debugPrint('verifyCode hatası: $e');
      setState(() {
        _errorMessage = 'Bir hata oluştu';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearInputs() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  /// Referral Dialog (Email doğrulama sonrası) - Sign_up_screen ile aynı
  /// Sıvı Dolu Hope Bardağı ile
  Future<void> _showReferralDialog() async {
    final lang = context.read<LanguageProvider>();
    final authService = AuthService();
    
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
    
    // Doğrulanan kodları sakla
    String? validatedPersonalCode;
    String? validatedTeamCode;
    
    // Kullanıcının mevcut ismini kontrol et
    final currentUser = authService.currentFirebaseUser;
    String? existingName;
    bool needsName = false;
    
    if (currentUser != null) {
      final userDoc = await authService.firestore.collection('users').doc(currentUser.uid).get();
      existingName = userDoc.data()?['full_name'] as String?;
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
          
          bool isNameValid() {
            if (!needsName) return true;
            final name = nameController.text.trim();
            return name.length >= 3 && name.contains(' ');
          }
          
          Future<void> saveName() async {
            if (!needsName) return;
            final name = nameController.text.trim();
            if (name.length >= 3 && currentUser != null) {
              await authService.firestore.collection('users').doc(currentUser.uid).update({
                'full_name': name,
                'full_name_lowercase': name.toLowerCase(),
                'masked_name': name.length > 2 ? '${name.substring(0, 2)}***' : name,
              });
            }
          }
          
          Future<void> checkPersonalCode() async {
            final code = personalCodeController.text.trim();
            if (code.isEmpty || personalCodeValid) return;
            
            setDialogState(() {
              isCheckingPersonal = true;
              personalError = null;
            });
            
            final query = await authService.firestore
                .collection('users')
                .where('personal_referral_code', isEqualTo: code.toUpperCase())
                .limit(1)
                .get();
            
            if (query.docs.isNotEmpty) {
              final uid = authService.currentFirebaseUser?.uid;
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
          
          Future<void> checkTeamCode() async {
            final code = teamCodeController.text.trim();
            if (code.isEmpty || teamCodeValid) return;
            
            setDialogState(() {
              isCheckingTeam = true;
              teamError = null;
            });
            
            final query = await authService.firestore
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
                          
                          // İsim alanı (sadece isim boşsa)
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
                          
                          // Hope Sıvı Bardağı
                          SizedBox(
                            height: 130,
                            width: 220,
                            child: HopeLiquidProgress(
                              progress: hopeProgress,
                              width: 220,
                              height: 130,
                            ),
                          ),
                          
                          if (hopeProgress == 1.0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                lang.isTurkish ? '🎉 Tebrikler! Maksimum bonus!' : '🎉 Congrats! Maximum bonus!',
                                style: const TextStyle(color: Color(0xFF6EC6B5), fontWeight: FontWeight.w600),
                              ),
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Kişisel davet kodu
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
                              if (value.length >= 6 && !personalCodeValid && !isCheckingPersonal) {
                                checkPersonalCode();
                              }
                            },
                            lang: lang,
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Takım davet kodu
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
                  
                  const SizedBox(height: 16),
                  
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
                      Expanded(
                        child: OutlinedButton(
                          onPressed: (isApplying || !isNameValid()) ? null : () async {
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
                            onPressed: (isApplying || !isNameValid() || (!personalCodeValid && !teamCodeValid)) ? null : () async {
                              setDialogState(() => isApplying = true);
                              
                              await saveName();
                              
                              final uid = authService.currentFirebaseUser?.uid;
                              if (uid != null) {
                                final result = await authService.processReferralCodesForSocialLogin(
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
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          enabled: !isValid,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon: Icon(icon, color: color),
            suffixIcon: isChecking
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : isValid
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
            filled: true,
            fillColor: isValid ? Colors.green.withOpacity(0.1) : const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: isValid 
                  ? const BorderSide(color: Colors.green, width: 2)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 2),
            ),
            errorText: error,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            bonus,
            style: TextStyle(
              fontSize: 11,
              color: isValid ? Colors.green : Colors.grey[500],
              fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F7F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF6EC6B5),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Email Doğrulandı!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hesabınız başarıyla doğrulandı.\nArtık uygulamayı kullanabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onVerified != null) {
                  widget.onVerified!();
                } else {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6EC6B5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Devam Et',
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
    if (value.isNotEmpty) {
      // Sonraki input'a geç
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Son hane girildi, doğrula
        _focusNodes[index].unfocus();
        _verifyCode();
      }
    }
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controllers[index].text.isEmpty && index > 0) {
          _focusNodes[index - 1].requestFocus();
          _controllers[index - 1].clear();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F7F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF6EC6B5),
                  size: 48,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Email Doğrulama',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                '${_maskEmail(widget.email)} adresine\n6 haneli doğrulama kodu gönderdik.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // Code Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 48,
                    height: 56,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : 8,
                      right: index == 2 ? 16 : 0, // Ortada boşluk
                    ),
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) => _onKeyDown(index, event),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
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
                              color: Color(0xFF6EC6B5),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.red,
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

              const SizedBox(height: 16),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6EC6B5),
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Doğrula',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const Spacer(),

              // Resend Code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Kod gelmedi mi? ',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (_resendCooldown > 0)
                    Text(
                      '$_resendCooldown saniye bekleyin',
                      style: const TextStyle(
                        color: Color(0xFF6EC6B5),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _isSendingCode ? null : _sendCode,
                      child: Text(
                        _isSendingCode ? 'Gönderiliyor...' : 'Tekrar Gönder',
                        style: TextStyle(
                          color: _isSendingCode
                              ? Colors.grey
                              : const Color(0xFF6EC6B5),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final localPart = parts[0];
    final domain = parts[1];
    if (localPart.length <= 2) {
      return '${localPart[0]}***@$domain';
    }
    return '${localPart.substring(0, 2)}***@$domain';
  }
}
