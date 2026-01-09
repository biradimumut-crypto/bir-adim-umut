import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import '../badges/badges_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../../providers/language_provider.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/success_dialog.dart';

/// Profil Ekranı
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final AdminService _adminService = AdminService();
  final ImagePicker _imagePicker = ImagePicker();
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isAdmin = false;
  
  // Sıralama bilgisi
  int? _stepRank;
  int? _donationRank;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadUserRankings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Uygulama arka plandan döndüğünde otomatik yenile
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 ProfileScreen resumed - refreshing data...');
      _loadUserData();
      _loadUserRankings();
    }
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUser();
    final isAdmin = await _adminService.isCurrentUserAdmin();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    }
  }
  
  /// Bu ayın başlangıcını al
  DateTime _getMonthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }
  
  /// Kullanıcının sıralama bilgilerini yükle (Sıralama sayfasıyla aynı mantık - aylık bazda)
  Future<void> _loadUserRankings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    try {
      final monthStart = _getMonthStart();
      final firestore = FirebaseFirestore.instance;
      
      // ========== ADIM SIRALAMASI (Umut Hareketi) ==========
      // Sıralama sayfasıyla aynı: Bu ay dönüştürülen adımlar
      final validActivityTypes = [
        'step_conversion',
        'step_conversion_2x',
        'carryover_conversion',
      ];
      
      final Map<String, int> userSteps = {};
      
      for (final activityType in validActivityTypes) {
        final logsSnapshot = await firestore
            .collection('activity_logs')
            .where('activity_type', isEqualTo: activityType)
            .get();
        
        for (var doc in logsSnapshot.docs) {
          final data = doc.data();
          
          // Tarih kontrolü - bu ay mı?
          DateTime? logDate;
          if (data['created_at'] != null) {
            logDate = (data['created_at'] as Timestamp).toDate();
          } else if (data['timestamp'] != null) {
            logDate = (data['timestamp'] as Timestamp).toDate();
          }
          
          if (logDate == null || logDate.isBefore(monthStart)) continue;
          
          final oduid = data['user_id'] ?? '';
          final steps = (data['steps_converted'] ?? 0) as int;
          
          if (oduid.isNotEmpty && steps > 0) {
            userSteps[oduid] = (userSteps[oduid] ?? 0) + steps;
          }
        }
      }
      
      // Sırala ve kullanıcının sırasını bul
      final stepsList = userSteps.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      int stepRank = stepsList.indexWhere((e) => e.key == uid);
      stepRank = stepRank == -1 ? stepsList.length + 1 : stepRank + 1;
      
      // ========== BAĞIŞ SIRALAMASI (Umut Elçileri) ==========
      // Sıralama sayfasıyla aynı: Bu ay yapılan bağışlar
      final logsSnapshot1 = await firestore
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'donation')
          .get();
      
      final logsSnapshot2 = await firestore
          .collection('activity_logs')
          .where('action_type', isEqualTo: 'donation')
          .get();
      
      final allDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (var doc in logsSnapshot1.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in logsSnapshot2.docs) {
        allDocs[doc.id] = doc;
      }
      
      final Map<String, double> userDonations = {};
      
      for (var doc in allDocs.values) {
        final data = doc.data();
        
        DateTime? logDate;
        if (data['created_at'] != null) {
          logDate = (data['created_at'] as Timestamp).toDate();
        } else if (data['timestamp'] != null) {
          logDate = (data['timestamp'] as Timestamp).toDate();
        }
        
        if (logDate == null || logDate.isBefore(monthStart)) continue;
        
        final oduid = data['user_id'] ?? '';
        final amount = (data['amount'] ?? data['hope_amount'] ?? 0).toDouble();
        
        if (oduid.isNotEmpty && amount > 0) {
          userDonations[oduid] = (userDonations[oduid] ?? 0) + amount;
        }
      }
      
      // Sırala ve kullanıcının sırasını bul
      final donationsList = userDonations.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      int donationRank = donationsList.indexWhere((e) => e.key == uid);
      donationRank = donationRank == -1 ? donationsList.length + 1 : donationRank + 1;
      
      if (mounted) {
        setState(() {
          _stepRank = stepRank;
          _donationRank = donationRank;
        });
      }
    } catch (e) {
      print('Sıralama yükleme hatası: $e');
    }
  }

  /// Fotoğraf seçme ve yükleme
  Future<void> _pickAndUploadPhoto() async {
    final lang = context.read<LanguageProvider>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang.selectPhoto,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.camera_alt, color: const Color(0xFF6EC6B5)),
              ),
              title: Text(lang.camera),
              subtitle: Text(lang.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.photo_library, color: const Color(0xFFE07A5F)),
              ),
              title: Text(lang.gallery),
              subtitle: Text(lang.chooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      // Web için bytes olarak oku
      final Uint8List bytes = await pickedFile.readAsBytes();
      
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Firebase Storage'a yükle
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');

      final uploadTask = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Firestore'da kullanıcı profilini güncelle
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profile_image_url': downloadUrl,
      });

      // Kullanıcı verisini yenile
      await _loadUserData();

      if (mounted) {
        await showSuccessDialog(
          context: context,
          title: lang.isTurkish ? 'Başarılı!' : 'Success!',
          message: lang.photoUpdated,
          icon: Icons.camera_alt,
          gradientColors: [const Color(0xFF6EC6B5), const Color(0xFF4CAF50)],
          buttonText: lang.ok,
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Text(lang.isTurkish ? 'Hata' : 'Error'),
              ],
            ),
            content: Text(lang.errorMsg(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(lang.ok),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  /// Profil Düzenle Dialog içinde Şifre Oluştur Bölümü
  Widget _buildPasswordSection(LanguageProvider lang, bool hasPassword) {
    final authProvider = _currentUser?.authProvider;
    
    // Sadece Google veya Apple kullanıcıları için göster
    if (authProvider != 'google' && authProvider != 'apple') {
      return const SizedBox.shrink();
    }
    
    // Zaten şifresi varsa gösterme
    if (hasPassword) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            Navigator.pop(context); // Önce edit dialog'u kapat
            _showCreatePasswordDialog(lang);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6EC6B5).withOpacity(0.1),
                  const Color(0xFFE07A5F).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6EC6B5).withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_outline, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.isTurkish ? 'Şifre Oluştur' : 'Create Password',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        lang.isTurkish 
                            ? 'E-posta ile de giriş yap'
                            : 'Also login with email',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF6EC6B5)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Profil düzenleme dialogu
  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _currentUser?.fullName ?? '');
    final nicknameController = TextEditingController(text: _currentUser?.nickname ?? '');
    final lang = context.read<LanguageProvider>();
    
    // Şifre durumunu önceden kontrol et
    final hasPassword = await AuthService().hasEmailPasswordProvider();
    
    if (!mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit, color: Color(0xFF6EC6B5)),
            const SizedBox(width: 8),
            Text(lang.editProfile),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: lang.fullName,
                  hintText: lang.fullNameHint,
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nicknameController,
                decoration: InputDecoration(
                  labelText: lang.isTurkish ? 'Takma Ad (Opsiyonel)' : 'Nickname (Optional)',
                  hintText: lang.isTurkish ? 'Örn: HopeWalker' : 'E.g: HopeWalker',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lang.isTurkish 
                    ? 'İsminiz bağış geçmişinde kısaltılmış şeklinde görünecek. Takma adınız sıralamada görünür.'
                    : 'Your name will appear abbreviated in donation history. Nickname appears in leaderboards.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              // Şifre Oluştur Butonu - Google/Apple kullanıcıları için
              _buildPasswordSection(lang, hasPassword),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6EC6B5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(lang.save),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'full_name': nameController.text.trim(),
          'full_name_lowercase': nameController.text.trim().toLowerCase(),
          'nickname': nicknameController.text.trim().isNotEmpty ? nicknameController.text.trim() : null,
        });

        await _loadUserData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.profileUpdated),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.errorMsg(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profil Fotoğrafı - Tıklanabilir
            GestureDetector(
              onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFE8F7F5),
                    backgroundImage: _currentUser?.profileImageUrl != null
                        ? NetworkImage(_currentUser!.profileImageUrl!)
                        : null,
                    child: _currentUser?.profileImageUrl == null
                        ? Text(
                            _currentUser?.fullName.isNotEmpty == true
                                ? _currentUser!.fullName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFE07A5F),
                            ),
                          )
                        : null,
                  ),
                  // Yükleme göstergesi
                  if (_isUploadingPhoto)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                  // Kamera ikonu
                  if (!_isUploadingPhoto)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6EC6B5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // İsim
            Text(
              _currentUser?.fullName ?? 'Kullanıcı',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            // E-posta
            Text(
              _currentUser?.email ?? '',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            
            // Takma Ad (varsa)
            if (_currentUser?.nickname != null && _currentUser!.nickname!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6EC6B5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '@${_currentUser!.nickname}',
                    style: const TextStyle(
                      color: Color(0xFF6EC6B5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // İstatistikler - Ana Kartlar
            Consumer<LanguageProvider>(
              builder: (context, lang, _) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Hope bakiyesi - Real-time Firestore'dan al
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        double hopeBalance = 0;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          hopeBalance = (data?['wallet_balance_hope'] ?? 0).toDouble();
                        }
                        return _buildProfileStatWithImage(
                          lang.hope,
                          hopeBalance.toStringAsFixed(0),
                          'assets/hp.png',
                        );
                      },
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey[300],
                    ),
                    _buildProfileStatWithImage(
                      lang.team,
                      _currentUser?.currentTeamId != null ? lang.hasTeam : lang.noTeam,
                      'assets/icons/takım.png',
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey[300],
                    ),
                    _buildProfileStatWithImage(
                      lang.membership,
                      _getDaysSinceJoin(),
                      'assets/icons/saat.png',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 🏆 Sıralama Bilgisi
            Consumer<LanguageProvider>(
              builder: (context, lang, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF2C94C), Color(0xFFE07A5F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRankingStatWithImage(
                      lang.isTurkish ? 'Umut Hareketi' : 'Hope Movement',
                      _stepRank != null ? '#$_stepRank' : '-',
                      'assets/badges/adimm.png',
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildRankingStatWithImage(
                      lang.isTurkish ? 'Umut Elçileri' : 'Hope Ambassadors',
                      _donationRank != null ? '#$_donationRank' : '-',
                      'assets/badges/bagiss.png',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Menü Öğeleri - Consumer ile çeviri
            Consumer<LanguageProvider>(
              builder: (context, lang, _) => Column(
                children: [
                  // 📊 Toplam İstatistiklerim Butonu - En üstte
                  _buildMenuItem(
                    icon: Icons.analytics_outlined,
                    title: lang.isTurkish ? 'Toplam İstatistiklerim' : 'My Total Statistics',
                    onTap: () {
                      _showTotalStatisticsDialog(lang);
                    },
                    isHighlighted: true,
                  ),
                  
                  // 🎖️ Rozetlerim Butonu
                  _buildMenuItem(
                    icon: Icons.emoji_events,
                    title: lang.isTurkish ? 'Rozetlerim' : 'My Badges',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BadgesScreen()),
                      );
                    },
                    isHighlighted: true,
                  ),

                  // 🎁 Davet Kodu - Kişisel Referral
                  _buildReferralMenuItem(lang),

                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: lang.editProfile,
                    onTap: _showEditProfileDialog,
                  ),

                  _buildMenuItem(
                    icon: Icons.history,
                    title: lang.activityHistory,
                    onTap: () {
                      _showActivityHistory();
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.notifications_outlined,
                    title: lang.notifications,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(lang.comingSoon)),
                      );
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    title: lang.settings,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(lang.comingSoon)),
                      );
                    },
                  ),

                  // Dil Seçimi
                  _buildMenuItem(
                    icon: Icons.language,
                    title: '${lang.language}: ${lang.currentLanguageName}',
                    onTap: () {
                      _showLanguageSelectionDialog(context, lang);
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: lang.helpSupport,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(lang.comingSoon)),
                      );
                    },
                  ),

                  // Gizlilik Politikası
                  _buildMenuItem(
                    icon: Icons.privacy_tip_outlined,
                    title: lang.privacyPolicy,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyPage(),
                        ),
                      );
                    },
                  ),

                  // Kullanım Koşulları
                  _buildMenuItem(
                    icon: Icons.description_outlined,
                    title: lang.termsOfService,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsOfServicePage(),
                        ),
                      );
                    },
                  ),
                  
                  // Admin Paneli - Sadece admin kullanıcılar için
                  if (_isAdmin)
                    _buildMenuItem(
                      icon: Icons.admin_panel_settings,
                      title: lang.isTurkish ? 'Admin Paneli' : 'Admin Panel',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminPanelScreen(),
                          ),
                        );
                      },
                      isHighlighted: true,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Çıkış Yap
            Consumer<LanguageProvider>(
              builder: (context, lang, _) => SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: Text(
                    lang.logout,
                    style: const TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Versiyon
            Consumer<LanguageProvider>(
              builder: (context, lang, _) => Text(
                lang.version,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            const BannerAdWidget(), // Reklam Alanı
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStatWithImage(String label, String value, String imagePath) {
    return Column(
      children: [
        Image.asset(imagePath, width: 36, height: 36),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  /// Sıralama istatistik widget'ı (icon ile)
  Widget _buildRankingStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.white),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
  
  /// Sıralama istatistik widget'ı (image ile)
  Widget _buildRankingStatWithImage(String label, String value, String imagePath) {
    return Column(
      children: [
        Image.asset(imagePath, width: 28, height: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// Detaylı İstatistikler Kartı
  Widget _buildDetailedStatsCard(LanguageProvider lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _getLifetimeStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final lifetimeSteps = stats['lifetime_converted_steps'] ?? 0;
        final lifetimeDonations = stats['lifetime_donated_hope'] ?? 0.0;
        final donationCount = stats['total_donation_count'] ?? 0;
        final lifetimeEarned = stats['lifetime_earned_hope'] ?? 0.0;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: const Color(0xFF6EC6B5),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lang.isTurkish ? 'Toplam İstatistikler' : 'Lifetime Statistics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.directions_walk,
                      label: lang.isTurkish ? 'Dönüştürülen Adım' : 'Converted Steps',
                      value: _formatNumber(lifetimeSteps),
                      color: const Color(0xFF6EC6B5),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.volunteer_activism,
                      label: lang.isTurkish ? 'Toplam Bağış' : 'Total Donated',
                      value: '${lifetimeDonations.toStringAsFixed(0)} H',
                      color: const Color(0xFFE07A5F),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.stars,
                      label: lang.isTurkish ? 'Kazanılan Hope' : 'Earned Hope',
                      value: '${lifetimeEarned.toStringAsFixed(0)} H',
                      color: const Color(0xFFF2C94C),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.favorite,
                      label: lang.isTurkish ? 'Bağış Sayısı' : 'Donation Count',
                      value: donationCount.toString(),
                      color: Colors.pink,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Lifetime istatistiklerini Firestore'dan al
  Future<Map<String, dynamic>> _getLifetimeStats() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return {};
      
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userDoc.exists) return {};
      
      final data = userDoc.data()!;
      return {
        'lifetime_converted_steps': data['lifetime_converted_steps'] ?? 0,
        'lifetime_donated_hope': (data['lifetime_donated_hope'] ?? 0).toDouble(),
        'total_donation_count': data['total_donation_count'] ?? 0,
        'lifetime_earned_hope': (data['lifetime_earned_hope'] ?? 0).toDouble(),
      };
    } catch (e) {
      print('Lifetime stats hatası: $e');
      return {};
    }
  }

  /// Sayıyı formatla (1000 -> 1K, 1000000 -> 1M)
  String _formatNumber(int number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    bool isHighlighted = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        gradient: isHighlighted
            ? LinearGradient(
                colors: [
                  const Color(0xFFF2C94C).withOpacity(0.1),
                  const Color(0xFFE07A5F).withOpacity(0.1),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted 
              ? const Color(0xFFF2C94C).withOpacity(0.5)
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? const Color(0xFFF2C94C).withOpacity(0.15)
                : Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isHighlighted
                        ? const LinearGradient(
                            colors: [Color(0xFFF2C94C), Color(0xFFE07A5F)],
                          )
                        : LinearGradient(
                            colors: [
                              (iconColor ?? const Color(0xFF6EC6B5)).withOpacity(0.15),
                              (iconColor ?? const Color(0xFFE07A5F)).withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isHighlighted ? Colors.white : (iconColor ?? const Color(0xFFE07A5F)),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isHighlighted 
                        ? const Color(0xFFF2C94C).withOpacity(0.2)
                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isHighlighted ? const Color(0xFFF2C94C) : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Davet Kodu (Referral) Menü Öğesi - Rozetler ile aynı boyut
  Widget _buildReferralMenuItem(LanguageProvider lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final referralCode = _currentUser?.personalReferralCode ?? '------';
    final referralCount = _currentUser?.referralCount ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE07A5F).withOpacity(0.1),
            const Color(0xFFF2C94C).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE07A5F).withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE07A5F).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReferralDialog(lang),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE07A5F), Color(0xFFF2C94C)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.card_giftcard, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.isTurkish ? 'Davet Kodu' : 'Invite Code',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            referralCode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE07A5F),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6EC6B5).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$referralCount ${lang.isTurkish ? 'davet' : 'invites'}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6EC6B5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE07A5F).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.share,
                    size: 14,
                    color: Color(0xFFE07A5F),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Şifre Oluştur Dialog
  Future<void> _showCreatePasswordDialog(LanguageProvider lang) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isPasswordVisible = false;
    bool isConfirmVisible = false;
    String? errorMessage;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lang.isTurkish ? 'Şifre Oluştur' : 'Create Password',
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
                      ? 'Şifre oluşturduktan sonra e-posta adresiniz ve şifrenizle de giriş yapabilirsiniz.'
                      : 'After creating a password, you can also login with your email and password.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 20),
                // E-posta (sadece bilgi)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentUser?.email ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Şifre
                TextField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: lang.isTurkish ? 'Şifre' : 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => isPasswordVisible = !isPasswordVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6EC6B5), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Şifre Onay
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !isConfirmVisible,
                  decoration: InputDecoration(
                    labelText: lang.isTurkish ? 'Şifre Tekrar' : 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(isConfirmVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => isConfirmVisible = !isConfirmVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6EC6B5), width: 2),
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                lang.isTurkish ? 'İptal' : 'Cancel',
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
                onPressed: isLoading ? null : () async {
                  final password = passwordController.text;
                  final confirmPassword = confirmPasswordController.text;
                  
                  // Validasyon
                  if (password.isEmpty || confirmPassword.isEmpty) {
                    setDialogState(() => errorMessage = lang.isTurkish 
                        ? 'Tüm alanları doldurun'
                        : 'Fill in all fields');
                    return;
                  }
                  
                  if (password.length < 6) {
                    setDialogState(() => errorMessage = lang.isTurkish 
                        ? 'Şifre en az 6 karakter olmalı'
                        : 'Password must be at least 6 characters');
                    return;
                  }
                  
                  if (password != confirmPassword) {
                    setDialogState(() => errorMessage = lang.isTurkish 
                        ? 'Şifreler eşleşmiyor'
                        : 'Passwords do not match');
                    return;
                  }
                  
                  setDialogState(() {
                    isLoading = true;
                    errorMessage = null;
                  });
                  
                  final result = await AuthService().createPasswordForSocialUser(
                    password: password,
                  );
                  
                  if (result['success'] == true) {
                    Navigator.pop(dialogContext);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🎉 ${result['message']}'),
                          backgroundColor: const Color(0xFF6EC6B5),
                        ),
                      );
                      // Sayfayı yenile
                      setState(() {});
                    }
                  } else {
                    setDialogState(() {
                      isLoading = false;
                      errorMessage = result['error'];
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(lang.isTurkish ? 'Oluştur' : 'Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Davet Kodu Dialog
  void _showReferralDialog(LanguageProvider lang) async {
    String referralCode = _currentUser?.personalReferralCode ?? '';
    final referralCount = _currentUser?.referralCount ?? 0;
    final currentFirebaseUser = FirebaseAuth.instance.currentUser;

    // Kod yoksa otomatik oluştur
    if (referralCode.isEmpty && currentFirebaseUser != null) {
      // Yüklenme dialogu göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6EC6B5)),
        ),
      );

      final authService = AuthService();
      final newCode = await authService.ensurePersonalReferralCode(currentFirebaseUser.uid);
      
      // Yüklenme dialogunu kapat
      if (mounted) Navigator.pop(context);
      
      if (newCode != null) {
        referralCode = newCode;
        // Kullanıcı verisini güncelle
        await _loadUserData();
      }
    }

    if (referralCode.isEmpty) {
      referralCode = '------';
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE07A5F), Color(0xFFF2C94C)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(lang.isTurkish ? 'Davet Kodu' : 'Invite Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE07A5F).withOpacity(0.1),
                    const Color(0xFFF2C94C).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    referralCode,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE07A5F),
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.isTurkish 
                        ? '$referralCount kişi davet ettiniz'
                        : 'You invited $referralCount people',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6EC6B5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF6EC6B5), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang.isTurkish 
                          ? 'Arkadaşlarınız bu kodu kullanarak kayıt olduğunda, ikiniz de 100.000 bonus adım kazanırsınız!'
                          : 'When your friends sign up using this code, both of you get 100,000 bonus steps!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.isTurkish ? 'Kapat' : 'Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final shareText = lang.isTurkish 
                  ? 'OneHopeStep uygulamasına katıl ve adımlarınla umut ol! 🚶‍♂️💚\n\nDavet kodum: $referralCode\n\nKayıt olurken bu kodu gir, ikiniz de 100.000 bonus adım kazanın!'
                  : 'Join OneHopeStep and be hope with your steps! 🚶‍♂️💚\n\nMy invite code: $referralCode\n\nEnter this code when signing up, both of you get 100,000 bonus steps!';
              
              Share.share(shareText);
            },
            icon: const Icon(Icons.share, size: 18),
            label: Text(lang.isTurkish ? 'Paylaş' : 'Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE07A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  String _getDaysSinceJoin() {
    final lang = context.read<LanguageProvider>();
    
    // Önce Firestore'daki created_at'a bak
    DateTime? joinDate = _currentUser?.createdAt;
    
    // Eğer Firestore'da yoksa, Firebase Auth'daki creationTime'ı kullan
    if (joinDate == null || joinDate.isAfter(DateTime.now().subtract(const Duration(hours: 1)))) {
      final authUser = _authService.currentFirebaseUser;
      joinDate = authUser?.metadata.creationTime;
    }
    
    if (joinDate == null) return '1 ${lang.days}';
    
    final days = DateTime.now().difference(joinDate).inDays + 1; // +1 for join day
    return '$days ${lang.days}';
  }

  Future<void> _handleLogout() async {
    final lang = context.read<LanguageProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.logout),
        content: Text(lang.isTurkish 
            ? 'Hesabınızdan çıkış yapmak istediğinize emin misiniz?' 
            : 'Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lang.logout),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  /// Toplam İstatistikler Dialog'u
  void _showTotalStatisticsDialog(LanguageProvider lang) {
    final user = _currentUser;
    if (user == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _getLifetimeStats(),
          builder: (context, snapshot) {
            final stats = snapshot.data ?? {};
            final convertedSteps = stats['lifetime_converted_steps'] ?? 0;
            final lifetimeDonatedHope = (stats['lifetime_donated_hope'] ?? 0.0) as double;
            final lifetimeEarnedHope = (stats['lifetime_earned_hope'] ?? 0.0) as double;
            final totalDonationCount = stats['total_donation_count'] ?? 0;
            
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.analytics, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        lang.isTurkish ? 'Toplam İstatistiklerim' : 'My Total Statistics',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // İstatistik Kartları - 2x2 Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          imagePath: 'assets/badges/adimm.png',
                          iconColor: const Color(0xFF6EC6B5),
                          value: _formatLargeNumber(convertedSteps),
                          label: lang.isTurkish ? 'Dönüştürülen Adım' : 'Converted Steps',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          imagePath: 'assets/hp.png',
                          iconColor: const Color(0xFFF2C94C),
                          value: lifetimeEarnedHope.toStringAsFixed(0),
                          label: lang.isTurkish ? 'Kazanılan Hope' : 'Earned Hope',
                          suffix: 'hp',
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          imagePath: 'assets/badges/bagiss.png',
                          iconColor: const Color(0xFFE07A5F),
                          value: lifetimeDonatedHope.toStringAsFixed(0),
                          label: lang.isTurkish ? 'Bağışlanan Hope' : 'Donated Hope',
                          suffix: 'hp',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          imagePath: 'assets/icons/yonca.png',
                          iconColor: Colors.pink,
                          value: totalDonationCount.toString(),
                          label: lang.isTurkish ? 'Bağış Sayısı' : 'Donation Count',
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Teşekkür mesajı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6EC6B5).withOpacity(0.1),
                          const Color(0xFFE07A5F).withOpacity(0.1),
                          const Color(0xFFF2C94C).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.favorite, color: Color(0xFFE07A5F), size: 28),
                        const SizedBox(height: 8),
                        Text(
                          lang.isTurkish 
                              ? 'Her adımınız umut oluyor, teşekkürler!'
                              : 'Every step becomes hope, thank you!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE07A5F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildStatCard({
    required String imagePath,
    required Color iconColor,
    required String value,
    required String label,
    String? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(imagePath, width: 22, height: 22),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatLargeNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// Aktivite Geçmişi Sayfasını Göster
  void _showActivityHistory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityHistoryPage(userId: uid),
      ),
    );
  }

  /// Dil seçim dialog'u
  void _showLanguageSelectionDialog(BuildContext context, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.languageSelection,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildLanguageOption(context, lang, 'tr', '🇹🇷', lang.turkishLanguage),
              _buildLanguageOption(context, lang, 'en', '🇬🇧', lang.englishLanguage),
              _buildLanguageOption(context, lang, 'de', '🇩🇪', lang.germanLanguage),
              _buildLanguageOption(context, lang, 'ja', '🇯🇵', lang.japaneseLanguage),
              _buildLanguageOption(context, lang, 'es', '🇪🇸', lang.spanishLanguage),
              _buildLanguageOption(context, lang, 'ro', '🇷🇴', lang.romanianLanguage),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context, LanguageProvider lang, String code, String flag, String name) {
    final isSelected = lang.languageCode == code;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 28)),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
          : null,
      onTap: () {
        lang.setLanguage(code);
        Navigator.pop(context);
      },
    );
  }
}

/// Aktivite Geçmişi Sayfası
class ActivityHistoryPage extends StatelessWidget {
  final String userId;
  
  const ActivityHistoryPage({Key? key, required this.userId}) : super(key: key);
  
  /// Sayı formatlama (100000 -> "100.000")
  String _formatActivityNumber(int number) {
    return NumberFormat.decimalPattern('tr').format(number);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.activityHistoryTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('activity_logs')
            .where('user_id', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Hata kontrolü
          if (snapshot.hasError) {
            print('Activity log hatası: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    lang.dataLoadError,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    lang.noActivityYet,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.startWalking,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          // Client-side sıralama (index gerekmiyor)
          final activities = snapshot.data!.docs.toList();
          activities.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            // Hem created_at hem timestamp'ı destekle
            final aTime = (aData['created_at'] ?? aData['timestamp']) as Timestamp?;
            final bTime = (bData['created_at'] ?? bData['timestamp']) as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Descending
          });

          // Limit 50
          final limitedActivities = activities.take(50).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: limitedActivities.length,
            itemBuilder: (context, index) {
              final activity = limitedActivities[index].data() as Map<String, dynamic>;
              return _buildActivityItem(context, activity);
            },
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, Map<String, dynamic> activity) {
    final lang = context.read<LanguageProvider>();
    // Hem yeni hem eski alan adlarını destekle
    final type = activity['activity_type'] ?? activity['action_type'] ?? '';
    final timestamp = (activity['created_at'] ?? activity['timestamp']) as Timestamp?;
    final dateStr = timestamp != null 
        ? DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate())
        : '';

    String? imagePath;
    String? imageUrl; // Bağış yapılan yerin logosu için
    IconData icon = Icons.info;
    Color color;
    String title;
    String subtitle;

    switch (type) {
      case 'donation':
        // Bağış yapılan yerin logosu varsa onu kullan
        imageUrl = activity['charity_logo_url'];
        if (imageUrl == null || imageUrl.isEmpty) {
          imagePath = 'assets/icons/umut ol buton .png';
        }
        color = const Color(0xFFE07A5F);
        final charityName = activity['charity_name'] ?? activity['target_name'] ?? (lang.isTurkish ? 'Vakıf' : 'Charity');
        final donationAmount = activity['amount'] ?? activity['hope_amount'] ?? 0;
        final amountStr = (donationAmount as num).toStringAsFixed(1);
        title = lang.isTurkish ? '$charityName\'a Bağış' : 'Donation to $charityName';
        subtitle = '$amountStr ${lang.hopeDonated}';
        break;
      case 'step_conversion':
        imagePath = 'assets/icons/adim.png';
        color = const Color(0xFF6EC6B5);
        final steps = activity['steps_converted'] ?? 0;
        final hope = (activity['hope_earned'] ?? activity['amount'] as num?)?.toStringAsFixed(1) ?? '0';
        title = lang.isTurkish ? 'Günlük Adım Dönüşümü' : 'Daily Step Conversion';
        subtitle = lang.isTurkish 
            ? '$steps adım → $hope Hope kazanıldı' 
            : '$steps steps → $hope Hope earned';
        break;
      case 'step_conversion_2x':
        imagePath = 'assets/icons/adim.png';
        color = const Color(0xFF9B59B6);
        final steps = activity['steps_converted'] ?? 0;
        final hope = (activity['hope_earned'] ?? activity['amount'] as num?)?.toStringAsFixed(1) ?? '0';
        title = lang.isTurkish ? '2x Bonus Adım Dönüşümü' : '2x Bonus Step Conversion';
        subtitle = lang.isTurkish 
            ? '$steps adım → $hope Hope kazanıldı' 
            : '$steps steps → $hope Hope earned';
        break;
      case 'carryover_conversion':
        imagePath = 'assets/icons/adim.png';
        color = Colors.deepOrange;
        final steps = activity['steps_converted'] ?? 0;
        final hope = (activity['hope_earned'] ?? activity['amount'] as num?)?.toStringAsFixed(1) ?? '0';
        title = lang.isTurkish ? 'Aktarılan Adım Dönüşümü' : 'Carryover Step Conversion';
        subtitle = lang.isTurkish 
            ? '$steps adım → $hope Hope kazanıldı' 
            : '$steps steps → $hope Hope earned';
        break;
      case 'bonus_conversion':
        imagePath = 'assets/icons/adim.png';
        color = const Color(0xFF9B59B6); // Mor
        final bonusSteps = activity['steps_converted'] ?? 0;
        final bonusHope = (activity['hope_earned'] ?? activity['amount'] as num?)?.toStringAsFixed(1) ?? '0';
        title = lang.isTurkish ? 'Davet Bonus Dönüşümü' : 'Referral Bonus Conversion';
        subtitle = lang.isTurkish 
            ? '$bonusSteps adım → $bonusHope Hope kazanıldı' 
            : '$bonusSteps steps → $bonusHope Hope earned';
        break;
      case 'leaderboard_bonus_conversion':
        imagePath = 'assets/icons/adim.png';
        color = const Color(0xFFF2C94C); // Altın
        final lbSteps = activity['steps_converted'] ?? 0;
        final lbHope = (activity['hope_earned'] ?? activity['amount'] as num?)?.toStringAsFixed(1) ?? '0';
        title = lang.isTurkish ? 'Sıralama Ödülü Dönüşümü' : 'Ranking Reward Conversion';
        subtitle = lang.isTurkish 
            ? '$lbSteps adım → $lbHope Hope kazanıldı' 
            : '$lbSteps steps → $lbHope Hope earned';
        break;
      case 'team_bonus_conversion':
        imagePath = 'assets/icons/adim.png';
        color = const Color(0xFF6EC6B5); // Turkuaz
        final teamBonusSteps = activity['steps_converted'] ?? 0;
        final teamBonusHope = (activity['hope_earned'] ?? activity['amount'] as num?)?.toStringAsFixed(1) ?? '0';
        title = lang.isTurkish ? 'Takım Bonus Dönüşümü' : 'Team Bonus Conversion';
        subtitle = lang.isTurkish 
            ? '$teamBonusSteps adım → $teamBonusHope Hope kazanıldı' 
            : '$teamBonusSteps steps → $teamBonusHope Hope earned';
        break;
      case 'team_referral_bonus':
        icon = Icons.group_add;
        color = const Color(0xFF27AE60); // Yeşil
        final teamBonusAmount = activity['bonus_steps'] ?? 100000;
        title = lang.isTurkish ? 'Takım Davet Bonusu' : 'Team Referral Bonus';
        subtitle = lang.isTurkish 
            ? '+${_formatActivityNumber(teamBonusAmount)} bonus adım kazanıldı' 
            : '+${_formatActivityNumber(teamBonusAmount)} bonus steps earned';
        break;
      case 'reward_ad_bonus':
        imagePath = 'assets/icons/adim.png';
        color = const Color(0xFFF2C94C);
        final adSteps = activity['steps_converted'] ?? 0;
        final adHope = (activity['hope_earned'] ?? activity['amount'] as num?)?.toStringAsFixed(1) ?? '0';
        title = lang.isTurkish ? 'Bonus Adım Dönüşümü' : 'Bonus Step Conversion';
        subtitle = lang.isTurkish 
            ? '$adSteps adım → $adHope Hope kazanıldı' 
            : '$adSteps steps → $adHope Hope earned';
        break;
      case 'team_joined':
        icon = Icons.group_add;
        color = Colors.green;
        final teamName = activity['team_name'] ?? (lang.isTurkish ? 'Takım' : 'Team');
        title = lang.teamJoinedActivity;
        subtitle = teamName;
        break;
      case 'team_created':
        icon = Icons.add_circle;
        color = Colors.orange;
        final teamName = activity['team_name'] ?? (lang.isTurkish ? 'Takım' : 'Team');
        title = lang.teamCreatedActivity;
        subtitle = teamName;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        title = lang.activity;
        subtitle = type.isNotEmpty ? type.replaceAll('_', ' ').toUpperCase() : '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl, 
                      width: 48, 
                      height: 48, 
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.volunteer_activism, color: color, size: 28),
                    ),
                  )
                : (imagePath != null
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(imagePath, width: 28, height: 28, fit: BoxFit.contain),
                      )
                    : Icon(icon, color: color, size: 28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            dateStr,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Gizlilik Politikası Sayfası
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final languageCode = lang.languageCode;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.privacyPolicy),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/badges/jolly.png',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                    ).createShader(bounds),
                    child: const Text(
                      'OneHopeStep',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'Bir Adım Umut',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            ..._buildPrivacyPolicyContent(context, languageCode),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPrivacyPolicyContent(BuildContext context, String languageCode) {
    switch (languageCode) {
      case 'en':
        return _buildEnglishPrivacyPolicy(context);
      case 'de':
        return _buildGermanPrivacyPolicy(context);
      case 'ja':
        return _buildJapanesePrivacyPolicy(context);
      case 'es':
        return _buildSpanishPrivacyPolicy(context);
      case 'ro':
        return _buildRomanianPrivacyPolicy(context);
      default:
        return _buildTurkishPrivacyPolicy(context);
    }
  }

  List<Widget> _buildTurkishPrivacyPolicy(BuildContext context) {
    return [
      _buildSectionTitle('6698 SAYILI KİŞİSEL VERİLERİN KORUNMASI KANUNU UYARINCA GENEL GİZLİLİK POLİTİKASI VE AYDINLATMA METNİ'),
      _buildHighlightBox(
        'İşbu Kişisel Verilerin İşlenmesi Genel Gizlilik Politikası ve Aydınlatma Metni, OneHopeStep (Bir Adım Umut) mobil uygulaması işletilmesi sırasında paylaştığınız kişisel verilerinizin, veri sorumlusu sıfatıyla tarafımızca, 6698 sayılı Kişisel Verilerin Korunması Kanunu\'nun ("KVKK") 10. maddesi ile Aydınlatma Yükümlülüğünün Yerine Getirilmesinde Uyulacak Usul ve Esaslar Hakkında Tebliğ kapsamında ilgili kişilerin ("Kullanıcılar") KVKK\'dan kaynaklanan hakları konusunda bilgilendirilmesi amacıyla hazırlanmıştır.',
      ),
      
      _buildSectionTitle('Veri Sorumlusunun Kimliği'),
      _buildBulletPoint('Uygulama Adı: OneHopeStep (Bir Adım Umut)'),
      _buildBulletPoint('E-posta: hopesteps.app@gmail.com'),
      _buildBulletPoint('Ülke: Türkiye'),
      
      _buildSectionTitle('1. Toplanan Veriler'),
      _buildSubSectionTitle('1.1 Hesap Bilgileri'),
      _buildBulletPoint('E-posta adresi (kayıt ve giriş için)'),
      _buildBulletPoint('Profil adı (görünen ad)'),
      _buildBulletPoint('Profil fotoğrafı (isteğe bağlı)'),
      _buildBulletPoint('Google hesap bilgileri (Google ile giriş tercih edildiğinde)'),
      
      _buildSubSectionTitle('1.2 Aktivite ve Uygulama Verileri'),
      _buildBulletPoint('Adım sayısı (cihazınızın sağlık sensörlerinden)'),
      _buildBulletPoint('Dönüştürülen adım miktarı'),
      _buildBulletPoint('Hope bakiyesi ve işlem geçmişi'),
      _buildBulletPoint('Bağış geçmişi (hangi vakfa ne kadar bağışlandığı)'),
      _buildBulletPoint('Rozet ve başarı bilgileri'),
      _buildBulletPoint('Takım üyelik bilgileri (takım adı, üyelik durumu)'),
      _buildBulletPoint('Leaderboard sıralaması (maskelenmiş isim ile)'),
      
      _buildSubSectionTitle('1.3 Cihaz Bilgileri'),
      _buildBulletPoint('Cihaz modeli ve işletim sistemi'),
      _buildBulletPoint('Uygulama sürümü'),
      _buildBulletPoint('Benzersiz cihaz tanımlayıcısı (fraud önleme ve güvenlik için)'),
      _buildBulletPoint('Dil tercihi'),
      
      _buildWarningBox('Not: Konum verisi, boy, kilo, cinsiyet gibi hassas kişisel veriler uygulamamız tarafından toplanmamaktadır.'),
      
      _buildSectionTitle('2. Kişisel Verileriniz Hangi Amaçlarla İşlenmektedir?'),
      _buildBulletPoint('Kullanıcılara hizmet sunmak'),
      _buildBulletPoint('Adım takibi ve Hope dönüşümü sağlamak'),
      _buildBulletPoint('Hayır kurumlarına bağış işlemlerini gerçekleştirmek'),
      _buildBulletPoint('Takım ve liderlik tablosu özelliklerini sunmak'),
      _buildBulletPoint('Rozet ve başarı sistemini yönetmek'),
      _buildBulletPoint('Aynı cihazdan birden fazla hesapla suistimali önlemek (fraud koruması)'),
      _buildBulletPoint('Kişiselleştirilmiş deneyim sunmak'),
      _buildBulletPoint('Uygulama performansını iyileştirmek'),
      
      _buildSectionTitle('3. Veri Güvenliği'),
      _buildBulletPoint('SSL/TLS şifreleme ile veri iletimi'),
      _buildBulletPoint('Firebase güvenlik kuralları ile veri erişim kontrolü'),
      _buildBulletPoint('Düzenli güvenlik güncellemeleri'),
      _buildBulletPoint('Erişim yetkisi kontrolü ve kısıtlaması'),
      
      _buildSectionTitle('4. Veri Saklama'),
      const Text('Verilerinizi hesabınız aktif olduğu sürece saklarız. Hesabınızı silmeniz durumunda tüm kişisel verileriniz 30 gün içinde kalıcı olarak silinir.'),
      const SizedBox(height: 16),
      
      _buildSectionTitle('5. KVKK Kapsamında Haklarınız'),
      _buildBulletPoint('Kişisel verilerinizin işlenip işlenmediğini öğrenme'),
      _buildBulletPoint('Kişisel verileriniz işlenmişse buna ilişkin bilgi talep etme'),
      _buildBulletPoint('Kişisel verilerinizin işlenme amacını öğrenme'),
      _buildBulletPoint('Yurt içinde veya yurt dışında kişisel verilerinizin aktarıldığı üçüncü kişileri bilme'),
      _buildBulletPoint('Kişisel verilerinizin eksik veya yanlış işlenmiş olması hâlinde düzeltilmesini isteme'),
      _buildBulletPoint('KVKK\'nın 7. maddesinde öngörülen şartlar çerçevesinde silinmesini veya yok edilmesini isteme'),
      _buildBulletPoint('Kişisel verilerinizin kanuna aykırı olarak işlenmesi sebebiyle zarara uğramanız hâlinde zararın giderilmesini talep etme'),
      
      _buildSectionTitle('6. İletişim'),
      const Text('Gizlilik ile ilgili sorularınız için:'),
      const SizedBox(height: 8),
      _buildBulletPoint('E-posta: hopesteps.app@gmail.com'),
      _buildBulletPoint('Kişisel Verileri Koruma Kurumu: www.kvkk.gov.tr'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          'Son Güncelleme: 23 Aralık 2025',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  List<Widget> _buildEnglishPrivacyPolicy(BuildContext context) {
    return [
      _buildSectionTitle('Privacy Policy'),
      _buildHighlightBox(
        'OneHopeStep respects the privacy of its users. This policy explains what data our application collects and how it is used.',
      ),
      
      _buildSectionTitle('Data Controller'),
      _buildBulletPoint('Application Name: OneHopeStep (Bir Adım Umut)'),
      _buildBulletPoint('Email: hopesteps.app@gmail.com'),
      _buildBulletPoint('Country: Turkey'),
      
      _buildSectionTitle('1. Data We Collect'),
      _buildSubSectionTitle('1.1 Account Information'),
      _buildBulletPoint('Email address (for registration and login)'),
      _buildBulletPoint('Profile name (display name)'),
      _buildBulletPoint('Profile photo (optional)'),
      _buildBulletPoint('Google account information (when using Google Sign-In)'),
      
      _buildSubSectionTitle('1.2 Activity and Application Data'),
      _buildBulletPoint('Step count (from your device\'s health sensors)'),
      _buildBulletPoint('Converted step amount'),
      _buildBulletPoint('Hope balance and transaction history'),
      _buildBulletPoint('Donation history (which charity and how much donated)'),
      _buildBulletPoint('Badge and achievement information'),
      _buildBulletPoint('Team membership information (team name, membership status)'),
      _buildBulletPoint('Leaderboard ranking (with masked name)'),
      
      _buildSubSectionTitle('1.3 Device Information'),
      _buildBulletPoint('Device model and operating system'),
      _buildBulletPoint('Application version'),
      _buildBulletPoint('Unique device identifier (for fraud prevention and security)'),
      _buildBulletPoint('Language preference'),
      
      _buildWarningBox('Note: Location data, height, weight, gender and other sensitive personal data are NOT collected by our application.'),
      
      _buildSectionTitle('2. How We Use Your Data'),
      _buildBulletPoint('To provide services to users'),
      _buildBulletPoint('To enable step tracking and Hope conversion'),
      _buildBulletPoint('To process donations to charities'),
      _buildBulletPoint('To provide team and leaderboard features'),
      _buildBulletPoint('To manage badge and achievement system'),
      _buildBulletPoint('To prevent multi-account fraud from same device'),
      _buildBulletPoint('To provide personalized experience'),
      _buildBulletPoint('To improve application performance'),
      
      _buildSectionTitle('3. Data Security'),
      _buildBulletPoint('Data transmission with SSL/TLS encryption'),
      _buildBulletPoint('Data access control with Firebase security rules'),
      _buildBulletPoint('Regular security updates'),
      _buildBulletPoint('Access authorization control and restriction'),
      
      _buildSectionTitle('4. Data Retention'),
      const Text('We store your data as long as your account is active. If you delete your account, all your personal data will be permanently deleted within 30 days.'),
      const SizedBox(height: 16),
      
      _buildSectionTitle('5. Your Rights'),
      _buildBulletPoint('Learn whether your personal data is being processed'),
      _buildBulletPoint('Request information about processing'),
      _buildBulletPoint('Learn the purpose of processing'),
      _buildBulletPoint('Know the third parties to whom your data is transferred'),
      _buildBulletPoint('Request correction if your data is incomplete or incorrect'),
      _buildBulletPoint('Request deletion under legal conditions'),
      _buildBulletPoint('Claim damages if you suffer harm due to unlawful processing'),
      
      _buildSectionTitle('6. Contact'),
      const Text('For privacy-related questions:'),
      const SizedBox(height: 8),
      _buildBulletPoint('Email: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          'Last Updated: December 23, 2025',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  // German Privacy Policy
  List<Widget> _buildGermanPrivacyPolicy(BuildContext context) {
    return [
      _buildSectionTitle('Datenschutzrichtlinie'),
      _buildHighlightBox(
        'OneHopeStep respektiert die Privatsphäre seiner Nutzer. Diese Richtlinie erklärt, welche Daten unsere Anwendung sammelt und wie sie verwendet werden.',
      ),
      
      _buildSectionTitle('Datenverantwortlicher'),
      _buildBulletPoint('Anwendungsname: OneHopeStep (Bir Adım Umut)'),
      _buildBulletPoint('E-Mail: hopesteps.app@gmail.com'),
      _buildBulletPoint('Land: Türkei'),
      
      _buildSectionTitle('1. Gesammelte Daten'),
      _buildSubSectionTitle('1.1 Kontoinformationen'),
      _buildBulletPoint('E-Mail-Adresse (für Registrierung und Anmeldung)'),
      _buildBulletPoint('Profilname (Anzeigename)'),
      _buildBulletPoint('Profilfoto (optional)'),
      _buildBulletPoint('Google-Kontoinformationen (bei Google-Anmeldung)'),
      
      _buildSubSectionTitle('1.2 Aktivitäts- und Anwendungsdaten'),
      _buildBulletPoint('Schrittzahl (von den Gesundheitssensoren Ihres Geräts)'),
      _buildBulletPoint('Umgewandelte Schrittmenge'),
      _buildBulletPoint('Hope-Guthaben und Transaktionsverlauf'),
      _buildBulletPoint('Spendenverlauf'),
      _buildBulletPoint('Abzeichen und Erfolge'),
      _buildBulletPoint('Team-Mitgliedschaftsinformationen'),
      
      _buildWarningBox('Hinweis: Standortdaten, Größe, Gewicht, Geschlecht und andere sensible persönliche Daten werden von unserer Anwendung NICHT erfasst.'),
      
      _buildSectionTitle('2. Datensicherheit'),
      _buildBulletPoint('Datenübertragung mit SSL/TLS-Verschlüsselung'),
      _buildBulletPoint('Firebase-Sicherheitsregeln'),
      _buildBulletPoint('Regelmäßige Sicherheitsupdates'),
      
      _buildSectionTitle('3. Kontakt'),
      _buildBulletPoint('E-Mail: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          'Letzte Aktualisierung: 23. Dezember 2025',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  // Japanese Privacy Policy
  List<Widget> _buildJapanesePrivacyPolicy(BuildContext context) {
    return [
      _buildSectionTitle('プライバシーポリシー'),
      _buildHighlightBox(
        'OneHopeStepはユーザーのプライバシーを尊重します。このポリシーでは、アプリケーションが収集するデータとその使用方法について説明します。',
      ),
      
      _buildSectionTitle('データ管理者'),
      _buildBulletPoint('アプリ名: OneHopeStep (Bir Adım Umut)'),
      _buildBulletPoint('メール: hopesteps.app@gmail.com'),
      _buildBulletPoint('国: トルコ'),
      
      _buildSectionTitle('1. 収集するデータ'),
      _buildSubSectionTitle('1.1 アカウント情報'),
      _buildBulletPoint('メールアドレス（登録・ログイン用）'),
      _buildBulletPoint('プロフィール名（表示名）'),
      _buildBulletPoint('プロフィール写真（任意）'),
      _buildBulletPoint('Googleアカウント情報（Googleログイン時）'),
      
      _buildSubSectionTitle('1.2 アクティビティとアプリデータ'),
      _buildBulletPoint('歩数（デバイスの健康センサーから）'),
      _buildBulletPoint('変換された歩数'),
      _buildBulletPoint('Hope残高と取引履歴'),
      _buildBulletPoint('寄付履歴'),
      _buildBulletPoint('バッジと実績'),
      _buildBulletPoint('チームメンバーシップ情報'),
      
      _buildWarningBox('注意: 位置情報、身長、体重、性別などの機密個人データはアプリケーションによって収集されません。'),
      
      _buildSectionTitle('2. データセキュリティ'),
      _buildBulletPoint('SSL/TLS暗号化によるデータ転送'),
      _buildBulletPoint('Firebaseセキュリティルール'),
      _buildBulletPoint('定期的なセキュリティアップデート'),
      
      _buildSectionTitle('3. お問い合わせ'),
      _buildBulletPoint('メール: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          '最終更新日: 2025年12月23日',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  // Spanish Privacy Policy
  List<Widget> _buildSpanishPrivacyPolicy(BuildContext context) {
    return [
      _buildSectionTitle('Política de Privacidad'),
      _buildHighlightBox(
        'OneHopeStep respeta la privacidad de sus usuarios. Esta política explica qué datos recopila nuestra aplicación y cómo se utilizan.',
      ),
      
      _buildSectionTitle('Responsable del Tratamiento'),
      _buildBulletPoint('Nombre de la Aplicación: OneHopeStep (Bir Adım Umut)'),
      _buildBulletPoint('Correo electrónico: hopesteps.app@gmail.com'),
      _buildBulletPoint('País: Turquía'),
      
      _buildSectionTitle('1. Datos Recopilados'),
      _buildSubSectionTitle('1.1 Información de la Cuenta'),
      _buildBulletPoint('Dirección de correo electrónico (para registro e inicio de sesión)'),
      _buildBulletPoint('Nombre de perfil (nombre visible)'),
      _buildBulletPoint('Foto de perfil (opcional)'),
      _buildBulletPoint('Información de cuenta de Google (al usar Google Sign-In)'),
      
      _buildSubSectionTitle('1.2 Datos de Actividad y Aplicación'),
      _buildBulletPoint('Conteo de pasos (de los sensores de salud de su dispositivo)'),
      _buildBulletPoint('Cantidad de pasos convertidos'),
      _buildBulletPoint('Balance de Hope e historial de transacciones'),
      _buildBulletPoint('Historial de donaciones'),
      _buildBulletPoint('Insignias y logros'),
      _buildBulletPoint('Información de membresía de equipo'),
      
      _buildWarningBox('Nota: Los datos de ubicación, altura, peso, género y otros datos personales sensibles NO son recopilados por nuestra aplicación.'),
      
      _buildSectionTitle('2. Seguridad de Datos'),
      _buildBulletPoint('Transmisión de datos con cifrado SSL/TLS'),
      _buildBulletPoint('Reglas de seguridad de Firebase'),
      _buildBulletPoint('Actualizaciones de seguridad regulares'),
      
      _buildSectionTitle('3. Contacto'),
      _buildBulletPoint('Correo electrónico: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          'Última Actualización: 23 de Diciembre de 2025',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  // Romanian Privacy Policy
  List<Widget> _buildRomanianPrivacyPolicy(BuildContext context) {
    return [
      _buildSectionTitle('Politica de Confidențialitate'),
      _buildHighlightBox(
        'OneHopeStep respectă confidențialitatea utilizatorilor săi. Această politică explică ce date colectează aplicația noastră și cum sunt utilizate.',
      ),
      
      _buildSectionTitle('Operator de Date'),
      _buildBulletPoint('Numele Aplicației: OneHopeStep (Bir Adım Umut)'),
      _buildBulletPoint('Email: hopesteps.app@gmail.com'),
      _buildBulletPoint('Țara: Turcia'),
      
      _buildSectionTitle('1. Date Colectate'),
      _buildSubSectionTitle('1.1 Informații despre Cont'),
      _buildBulletPoint('Adresa de email (pentru înregistrare și autentificare)'),
      _buildBulletPoint('Numele profilului (numele afișat)'),
      _buildBulletPoint('Fotografia de profil (opțional)'),
      _buildBulletPoint('Informații cont Google (când se folosește Google Sign-In)'),
      
      _buildSubSectionTitle('1.2 Date de Activitate și Aplicație'),
      _buildBulletPoint('Numărul de pași (de la senzorii de sănătate ai dispozitivului)'),
      _buildBulletPoint('Cantitatea de pași convertiți'),
      _buildBulletPoint('Soldul Hope și istoricul tranzacțiilor'),
      _buildBulletPoint('Istoricul donațiilor'),
      _buildBulletPoint('Insigne și realizări'),
      _buildBulletPoint('Informații despre calitatea de membru al echipei'),
      
      _buildWarningBox('Notă: Datele despre locație, înălțime, greutate, gen și alte date personale sensibile NU sunt colectate de aplicația noastră.'),
      
      _buildSectionTitle('2. Securitatea Datelor'),
      _buildBulletPoint('Transmiterea datelor cu criptare SSL/TLS'),
      _buildBulletPoint('Reguli de securitate Firebase'),
      _buildBulletPoint('Actualizări regulate de securitate'),
      
      _buildSectionTitle('3. Contact'),
      _buildBulletPoint('Email: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          'Ultima Actualizare: 23 Decembrie 2025',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF2C94C),
        ),
      ),
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildHighlightBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF2C94C).withOpacity(0.1),
            const Color(0xFFE07A5F).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Color(0xFFF2C94C), width: 4)),
      ),
      child: Text(text),
    );
  }

  Widget _buildWarningBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Colors.orange, width: 4)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}

/// Kullanım Koşulları Sayfası
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final languageCode = lang.languageCode;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.termsOfService),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/badges/jolly.png',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F), Color(0xFFF2C94C)],
                    ).createShader(bounds),
                    child: const Text(
                      'OneHopeStep',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'Bir Adım Umut',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            ..._buildTermsContent(context, languageCode),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTermsContent(BuildContext context, String languageCode) {
    switch (languageCode) {
      case 'en':
        return _buildEnglishTerms(context);
      case 'de':
        return _buildGermanTerms(context);
      case 'ja':
        return _buildJapaneseTerms(context);
      case 'es':
        return _buildSpanishTerms(context);
      case 'ro':
        return _buildRomanianTerms(context);
      default:
        return _buildTurkishTerms(context);
    }
  }

  List<Widget> _buildTurkishTerms(BuildContext context) {
    return [
      _buildSectionTitle('HOPESTEPS KULLANIM KOŞULLARI VE LİSANS SÖZLEŞMESİ'),
      _buildHighlightBox(
        'Son Güncelleme: 9 Ocak 2026\n\nBu Kullanım Koşulları, OneHopeStep (Bir Adım Umut) mobil uygulamasını kullanımınızı düzenleyen yasal bir sözleşmedir. Uygulamayı indirip kullanarak bu koşulları kabul etmiş sayılırsınız.',
      ),
      
      _buildSectionTitle('1. Tanım ve Taraflar'),
      _buildBulletPoint('"Uygulama" veya "OneHopeStep": OneHopeStep (Bir Adım Umut) mobil uygulaması'),
      _buildBulletPoint('"Kullanıcı": Uygulamayı indiren ve kullanan gerçek kişi'),
      _buildBulletPoint('"Hope": Uygulama içinde adımların dönüştürüldüğü sanal puan birimi'),
      _buildBulletPoint('"Bağış": Hope puanlarının bağış alıcılarına aktarılması işlemi'),
      _buildBulletPoint('"Bağış Alıcıları": Uygulama içinde listelenen ve bağış kabul eden kurum/kuruluşlar'),
      const SizedBox(height: 8),
      const Text('OneHopeStep, sosyal sorumluluk amacıyla geliştirilmiş olup, kullanıcıların adımlarını Hope puanına dönüştürerek bağış alıcılarına bağış yapmalarını sağlayan ücretsiz bir mobil uygulamadır.'),
      
      _buildSectionTitle('2. Uygulamaya Katılım'),
      _buildBulletPoint('Uygulamayı App Store veya Google Play Store\'dan ücretsiz olarak indirebilirsiniz'),
      _buildBulletPoint('Hesap oluşturmak için geçerli bir e-posta adresi veya Google hesabı gerekmektedir'),
      _buildBulletPoint('18 yaşından küçük kullanıcıların veli/vasi onayı alması gerekmektedir'),
      _buildBulletPoint('Her kullanıcı yalnızca bir (1) hesap oluşturabilir'),
      
      _buildSectionTitle('3. Adım Dönüştürme Kuralları'),
      _buildBulletPoint('Tek seferde maksimum 2.500 adım dönüştürülebilir'),
      _buildBulletPoint('Her dönüştürme arasında 10 dakika bekleme süresi vardır'),
      _buildBulletPoint('100 adım = 1 Hope oranıyla dönüştürülür'),
      _buildBulletPoint('Progress bar dolduğunda 2x bonus: 2.500 adım = 50 Hope'),
      _buildBulletPoint('Günlük adımlar gece 00:00\'da sıfırlanır'),
      _buildBulletPoint('Her adım dönüştürme işlemi için reklam izlenmesi gerekir'),
      
      _buildSectionTitle('4. Taşıma (Carryover) ve Referans Adımları'),
      _buildBulletPoint('Dönüştürülmemiş günlük adımlar ay sonuna kadar "taşınan adım" olarak saklanır'),
      _buildBulletPoint('Taşınan adımlar her ayın 1\'inde otomatik olarak silinir'),
      _buildBulletPoint('Davet sistemiyle kazanılan referans bonus adımları SÜRESİZ geçerlidir, ayın 1\'inde silinmez'),
      _buildWarningBox('ÖNEMLİ: Günlük adımlarınızı ay sonuna kadar dönüştürmeyi unutmayın. Ayın 1\'inde taşınan adımlar sıfırlanır!'),
      
      _buildSectionTitle('5. Davet (Referans) Sistemi'),
      _buildBulletPoint('Her kullanıcının benzersiz bir kişisel davet kodu vardır'),
      _buildBulletPoint('Davet kodunuzla kayıt olan yeni kullanıcı için her iki tarafa 100.000 bonus adım verilir'),
      _buildBulletPoint('Davet bonus adımları SÜRESİZ geçerlidir (ay sonunda silinmez)'),
      _buildBulletPoint('Davet bonus adımları da reklam izleyerek Hope\'a dönüştürülür'),
      
      _buildSectionTitle('6. Takım Sistemi'),
      _buildBulletPoint('Kullanıcılar takım kurabilir veya mevcut takımlara katılabilir'),
      _buildBulletPoint('Takımların benzersiz davet kodu vardır'),
      _buildBulletPoint('Takım davet koduyla katılan yeni üyeler hem takıma hem kendilerine 100.000 bonus adım kazandırır'),
      _buildBulletPoint('Takım sıralamada ilk 3\'e girdiğinde takıma bonus adım ödülü verilir'),
      _buildBulletPoint('Takım bonus adımlarını takımdaki herhangi bir üye dönüştürebilir'),
      _buildBulletPoint('Takım bonusunu kim dönüştürürse Hope o kullanıcının cüzdanına eklenir'),
      
      _buildSectionTitle('7. Sıralama ve Ödül Sistemi'),
      const Text('Her ay sıfırlanan 3 kategori vardır. Sıralamalar aylık olup, her ayın 1\'inde sıfırlanır:'),
      const SizedBox(height: 8),
      _buildBulletPoint('Umut Hareketi: Bu ay en çok GERÇEK adım dönüştürenler'),
      _buildBulletPoint('Umut Elçileri: Bu ay en çok Hope bağışlayanlar'),
      _buildBulletPoint('Umut Ormanı: Bu ay en çok bağış yapan takımlar'),
      const SizedBox(height: 12),
      const Text('Ödül Dağılımı:', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildBulletPoint('🥇 1. Sıra: 500.000 bonus adım'),
      _buildBulletPoint('🥈 2. Sıra: 300.000 bonus adım'),
      _buildBulletPoint('🥉 3. Sıra: 100.000 bonus adım'),
      const SizedBox(height: 12),
      const Text('Ödül Mantığı:', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildBulletPoint('Bireysel ödüller (Umut Hareketi, Umut Elçileri): Kullanıcının kişisel sıralama bonus adımlarına eklenir'),
      _buildBulletPoint('Takım ödülleri (Umut Ormanı): Takımın bonus adım havuzuna eklenir'),
      _buildBulletPoint('Ödüller ay sonunda Cloud Function tarafından otomatik dağıtılır'),
      _buildWarningBox('NOT: Sıralama ödülü olarak kazanılan bonus adımlar da reklam izleyerek Hope\'a dönüştürülür. Takım bonusunu takımdaki herhangi bir üye dönüştürebilir.'),
      
      _buildSectionTitle('8. Hope\'un Enflasyonist Doğası'),
      _buildHighlightBox('Hope, sabit değerli bir birim DEĞİLDİR. Değeri aylık olarak hesaplanır ve çeşitli faktörlere bağlı olarak her ay DEĞİŞEBİLİR.'),
      const SizedBox(height: 12),
      const Text('Hope Değeri Nasıl Hesaplanır?', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildBulletPoint('Her ayın sonunda toplam reklam geliri hesaplanır'),
      _buildBulletPoint('Operasyonel giderler düşülür (sunucu, altyapı, platform komisyonları)'),
      _buildBulletPoint('Kalan miktar, o ay üretilen toplam Hope miktarına bölünür'),
      _buildBulletPoint('Formül: 1 Hope = (Aylık Reklam Geliri - Giderler) / Toplam Hope'),
      const SizedBox(height: 12),
      const Text('Neden Enflasyonist?', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildBulletPoint('Kullanıcı sayısı arttıkça üretilen Hope miktarı artar'),
      _buildBulletPoint('Reklam gelirleri aynı oranda artmayabilir'),
      _buildBulletPoint('Bu durumda birim Hope değeri AZALIR'),
      _buildBulletPoint('Tersi durumda (az Hope, çok gelir) değer ARTABİLİR'),
      const SizedBox(height: 12),
      const Text('Operasyonel Giderler:', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildBulletPoint('Firebase/Google Cloud sunucu maliyetleri'),
      _buildBulletPoint('Veritabanı ve depolama giderleri'),
      _buildBulletPoint('App Store ve Google Play komisyonları'),
      _buildBulletPoint('Reklam ağı komisyonları (AdMob vb.)'),
      _buildWarningBox('KULLANICI KABULÜ: Hope\'un değerinin sabit olmadığını, her ay değişebileceğini ve bu değişkenliğin tamamen piyasa koşullarına bağlı olduğunu kabul ediyorum. Uygulama, Hope için herhangi bir minimum değer garantisi VERMEZ.'),
      
      _buildSectionTitle('9. Bağış Sistemi ve Aktarım Süreci'),
      _buildBulletPoint('Kullanıcı, cüzdanındaki Hope\'u uygulama içindeki bağış alıcılarına bağışlayabilir'),
      _buildBulletPoint('Bağış yapıldığında Hope o anki TL değeri üzerinden kaydedilir'),
      _buildBulletPoint('Bağışlar "onay bekliyor" statüsünde bekletilir'),
      _buildBulletPoint('Reklam gelirleri kesinleştikten sonra bağışlar bağış alıcılarına aktarılır'),
      _buildBulletPoint('Aktarım süresi 30 güne kadar sürebilir'),
      _buildWarningBox('ÖNEMLİ: Hope puanları para birimi değildir. Nakit olarak talep edilemez, başkasına transfer edilemez, satılamaz veya takas edilemez.'),
      
      _buildSectionTitle('10. Tek Cihaz - Tek Hesap Kuralı'),
      _buildWarningBox('DOLANDIRICILIK ÖNLEMİ:\n\n• Her hesap yalnızca bir cihaza bağlı olabilir\n• Bir cihaz aynı gün içinde yalnızca bir hesaba adım dönüştürebilir\n• Aynı cihazdan birden fazla hesaba adım aktarımı engellenir\n• Bu kuralın ihlalinde hesap askıya alınır veya kalıcı olarak kapatılır'),
      
      _buildSectionTitle('11. Yasaklı Davranışlar ve Yaptırımlar'),
      _buildBulletPoint('Sahte adım verisi oluşturma veya manipüle etme'),
      _buildBulletPoint('Üçüncü parti yazılımlar kullanarak adım sayısını yapay olarak artırma'),
      _buildBulletPoint('Birden fazla hesap oluşturma'),
      _buildBulletPoint('Başkasının hesabını kullanma veya kendi hesabını başkasına kullandırma'),
      _buildBulletPoint('Uygulamanın güvenlik sistemlerini atlatmaya çalışma'),
      _buildBulletPoint('Takım bonus sistemini kötüye kullanma'),
      _buildWarningBox('YAPTRIM: Bu davranışlar tespit edildiğinde hesap kalıcı olarak kapatılır, tüm Hope bakiyesi ve veriler silinir. Hukuki işlem başlatılabilir.'),
      
      _buildSectionTitle('12. Hesap Yönetimi'),
      _buildBulletPoint('Hesabınızın güvenliğinden siz sorumlusunuz'),
      _buildBulletPoint('Şifrenizi kimseyle paylaşmamalısınız'),
      _buildBulletPoint('Hesabınızı istediğiniz zaman uygulama ayarlarından silebilirsiniz'),
      _buildBulletPoint('Hesap silindiğinde tüm Hope bakiyesi ve veriler kalıcı olarak silinir'),
      
      _buildSectionTitle('13. Sorumluluk Sınırlandırması'),
      const Text('OneHopeStep uygulaması "OLDUĞU GİBİ" sunulmaktadır. Aşağıdaki konularda herhangi bir garanti verilmemektedir:'),
      const SizedBox(height: 8),
      _buildBulletPoint('Uygulamanın kesintisiz veya hatasız çalışacağı'),
      _buildBulletPoint('Adım sayımının %100 doğru olacağı'),
      _buildBulletPoint('Hope değerinin belirli bir seviyede kalacağı'),
      _buildBulletPoint('Reklam gelirlerinin belirli bir miktarda olacağı'),
      
      _buildSectionTitle('14. Uygulanacak Hukuk'),
      _buildBulletPoint('Bu sözleşme Türkiye Cumhuriyeti kanunlarına tabidir'),
      _buildBulletPoint('Uyuşmazlıklarda Türkiye Cumhuriyeti mahkemeleri yetkilidir'),
      _buildBulletPoint('Tüketici hakları saklıdır'),
      
      _buildSectionTitle('15. İletişim'),
      const Text('Sorularınız veya şikayetleriniz için:'),
      const SizedBox(height: 8),
      _buildBulletPoint('E-posta: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          'Son Güncelleme: 9 Ocak 2026',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  List<Widget> _buildEnglishTerms(BuildContext context) {
    return [
      _buildSectionTitle('HOPESTEPS TERMS OF SERVICE AND LICENSE AGREEMENT'),
      _buildHighlightBox(
        'Last Updated: January 9, 2026\n\nThese Terms of Service constitute a legal agreement governing your use of the OneHopeStep (Bir Adım Umut) mobile application. By downloading and using the application, you agree to these terms.',
      ),
      
      _buildSectionTitle('1. Definitions and Parties'),
      _buildBulletPoint('"Application" or "OneHopeStep": The OneHopeStep (Bir Adım Umut) mobile application'),
      _buildBulletPoint('"User": The natural person who downloads and uses the application'),
      _buildBulletPoint('"Hope": The virtual point unit into which steps are converted'),
      _buildBulletPoint('"Donation": The process of transferring Hope points to donation recipients'),
      _buildBulletPoint('"Donation Recipients": Organizations listed in the app that accept donations'),
      const SizedBox(height: 8),
      const Text('OneHopeStep is a free mobile application developed for social responsibility purposes, enabling users to convert their steps into Hope points and donate to donation recipients.'),
      
      _buildSectionTitle('2. Participation in the Application'),
      _buildBulletPoint('You can download the application for free from the App Store or Google Play Store'),
      _buildBulletPoint('A valid email address or Google account is required to create an account'),
      _buildBulletPoint('Users under 18 years of age must obtain parental/guardian consent'),
      _buildBulletPoint('Each user may only create one (1) account'),
      
      _buildSectionTitle('3. Step Conversion Rules'),
      _buildBulletPoint('Maximum 2,500 steps can be converted at once'),
      _buildBulletPoint('10-minute cooldown between each conversion'),
      _buildBulletPoint('Conversion rate: 100 steps = 1 Hope'),
      _buildBulletPoint('When progress bar is full, 2x bonus: 2,500 steps = 50 Hope'),
      _buildBulletPoint('Daily steps reset at midnight (00:00)'),
      _buildBulletPoint('Watching an ad is required for each step conversion'),
      
      _buildSectionTitle('4. Carryover and Referral Bonus Steps'),
      _buildBulletPoint('Unconverted daily steps are stored as "carryover steps" until month end'),
      _buildBulletPoint('Carryover steps are automatically deleted on the 1st of each month'),
      _buildBulletPoint('Referral bonus steps earned through invite system are PERMANENT, not deleted on the 1st'),
      _buildWarningBox('IMPORTANT: Don\'t forget to convert your daily steps before month end. Carryover steps are reset on the 1st of each month!'),
      
      _buildSectionTitle('5. Referral System'),
      _buildBulletPoint('Each user has a unique personal invite code'),
      _buildBulletPoint('When a new user registers with your invite code, both parties receive 100,000 bonus steps'),
      _buildBulletPoint('Referral bonus steps are PERMANENT (not deleted at month end)'),
      _buildBulletPoint('Referral bonus steps are also converted to Hope by watching ads'),
      
      _buildSectionTitle('6. Team System'),
      _buildBulletPoint('Users can create teams or join existing teams'),
      _buildBulletPoint('Teams have unique invite codes'),
      _buildBulletPoint('New members joining via team invite code earn 100,000 bonus steps for both the team and themselves'),
      _buildBulletPoint('Teams that rank in top 3 receive bonus step rewards for the team'),
      _buildBulletPoint('Any team member can convert team bonus steps'),
      _buildBulletPoint('Whoever converts team bonus gets the Hope added to their wallet'),
      
      _buildSectionTitle('7. Ranking and Reward System'),
      const Text('There are 3 categories that reset monthly. Rankings are monthly and reset on the 1st of each month:'),
      const SizedBox(height: 8),
      _buildBulletPoint('Step Champions: Most REAL steps converted this month'),
      _buildBulletPoint('Hope Ambassadors: Most Hope donated this month'),
      _buildBulletPoint('Hope Forest: Teams with most donations this month'),
      const SizedBox(height: 12),
      const Text('Reward Distribution:', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildBulletPoint('🥇 1st Place: 500,000 bonus steps'),
      _buildBulletPoint('🥈 2nd Place: 300,000 bonus steps'),
      _buildBulletPoint('🥉 3rd Place: 100,000 bonus steps'),
      const SizedBox(height: 12),
      const Text('Reward Logic:', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildBulletPoint('Individual rewards (Step Champions, Hope Ambassadors): Added to user\'s personal ranking bonus steps'),
      _buildBulletPoint('Team rewards (Hope Forest): Added to team\'s bonus step pool'),
      _buildBulletPoint('Rewards are automatically distributed by Cloud Function at month end'),
      _buildWarningBox('NOTE: Bonus steps earned as ranking rewards are also converted to Hope by watching ads. Any team member can convert team bonus steps.'),
      
      _buildSectionTitle('8. Inflationary Nature of Hope'),
      _buildHighlightBox('Hope is NOT a fixed-value unit. Its value is calculated monthly and may CHANGE each month based on various factors.'),
      const SizedBox(height: 12),
      const Text('How is Hope Value Calculated?', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildBulletPoint('Total ad revenue is calculated at the end of each month'),
      _buildBulletPoint('Operational costs are deducted (servers, infrastructure, platform commissions)'),
      _buildBulletPoint('Remaining amount is divided by total Hope produced that month'),
      _buildBulletPoint('Formula: 1 Hope = (Monthly Ad Revenue - Costs) / Total Hope'),
      const SizedBox(height: 12),
      const Text('Why Inflationary?', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildBulletPoint('As user count increases, Hope production increases'),
      _buildBulletPoint('Ad revenue may not increase at the same rate'),
      _buildBulletPoint('In this case, unit Hope value DECREASES'),
      _buildBulletPoint('In reverse case (less Hope, more revenue), value may INCREASE'),
      const SizedBox(height: 12),
      const Text('Operational Costs:', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildBulletPoint('Firebase/Google Cloud server costs'),
      _buildBulletPoint('Database and storage expenses'),
      _buildBulletPoint('App Store and Google Play commissions'),
      _buildBulletPoint('Ad network commissions (AdMob etc.)'),
      _buildWarningBox('USER ACCEPTANCE: I acknowledge that Hope\'s value is not fixed, may change each month, and this variability is entirely dependent on market conditions. The application provides NO minimum value guarantee for Hope.'),
      
      _buildSectionTitle('9. Donation System and Transfer Process'),
      _buildBulletPoint('User can donate Hope in their wallet to donation recipients within the app'),
      _buildBulletPoint('When donated, Hope is recorded at its current TL value'),
      _buildBulletPoint('Donations are held in "pending approval" status'),
      _buildBulletPoint('After ad revenue is finalized, donations are transferred to donation recipients'),
      _buildBulletPoint('Transfer process may take up to 30 days'),
      _buildWarningBox('IMPORTANT: Hope points are not currency. Cannot be claimed as cash, transferred to others, sold, or exchanged.'),
      
      _buildSectionTitle('10. One Device - One Account Rule'),
      _buildWarningBox('FRAUD PREVENTION:\n\n• Each account can only be linked to one device\n• A device can only convert steps for one account within the same day\n• Step transfers from the same device to multiple accounts are blocked\n• Violation of this rule results in account suspension or permanent closure'),
      
      _buildSectionTitle('11. Prohibited Behaviors and Sanctions'),
      _buildBulletPoint('Creating or manipulating fake step data'),
      _buildBulletPoint('Using third-party software to artificially increase step counts'),
      _buildBulletPoint('Creating multiple accounts'),
      _buildBulletPoint('Using someone else\'s account or allowing others to use your account'),
      _buildBulletPoint('Attempting to bypass the application\'s security systems'),
      _buildBulletPoint('Abusing the team bonus system'),
      _buildWarningBox('SANCTION: When these behaviors are detected, account is permanently closed, all Hope balance and data are deleted. Legal action may be initiated.'),
      
      _buildSectionTitle('12. Account Management'),
      _buildBulletPoint('You are responsible for the security of your account'),
      _buildBulletPoint('You should not share your password with anyone'),
      _buildBulletPoint('You can delete your account at any time from the application settings'),
      _buildBulletPoint('When the account is deleted, all Hope balance and data are permanently deleted'),
      
      _buildSectionTitle('13. Limitation of Liability'),
      const Text('The OneHopeStep application is provided "AS IS". No warranty is given regarding:'),
      const SizedBox(height: 8),
      _buildBulletPoint('That the application will operate without interruption or error'),
      _buildBulletPoint('That step counting will be 100% accurate'),
      _buildBulletPoint('That Hope value will remain at a certain level'),
      _buildBulletPoint('That ad revenue will be a certain amount'),
      
      _buildSectionTitle('14. Applicable Law'),
      _buildBulletPoint('This agreement is subject to the laws of the Republic of Turkey'),
      _buildBulletPoint('Turkish courts have jurisdiction over disputes'),
      _buildBulletPoint('Consumer rights are reserved'),
      
      _buildSectionTitle('15. Contact'),
      const Text('For your questions or complaints:'),
      const SizedBox(height: 8),
      _buildBulletPoint('Email: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          'Last Updated: January 9, 2026',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF2C94C),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildHighlightBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF2C94C).withOpacity(0.1),
            const Color(0xFFE07A5F).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Color(0xFFF2C94C), width: 4)),
      ),
      child: Text(text),
    );
  }

  Widget _buildWarningBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Colors.red, width: 4)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  // German Terms
  List<Widget> _buildGermanTerms(BuildContext context) {
    return [
      _buildSectionTitle('HOPESTEPS NUTZUNGSBEDINGUNGEN'),
      _buildHighlightBox(
        'Letzte Aktualisierung: 23. Dezember 2025\n\nDiese Nutzungsbedingungen bilden eine rechtliche Vereinbarung für Ihre Nutzung der OneHopeStep-Anwendung. Durch Herunterladen und Nutzung stimmen Sie diesen Bedingungen zu.',
      ),
      
      _buildSectionTitle('1. Definitionen'),
      _buildBulletPoint('"Anwendung" oder "OneHopeStep": Die OneHopeStep Mobile-Anwendung'),
      _buildBulletPoint('"Benutzer": Die Person, die die Anwendung herunterlädt und nutzt'),
      _buildBulletPoint('"Hope": Die virtuelle Punkteinheit, in die Schritte umgewandelt werden'),
      _buildBulletPoint('"Spende": Der Prozess der Übertragung von Hope-Punkten an Wohltätigkeitsorganisationen'),
      
      _buildSectionTitle('2. Hope-System'),
      _buildWarningBox('WICHTIG: Hope-Punkte können nur für Spenden an Wohltätigkeitsorganisationen verwendet werden.\n\n• Können nicht in Bargeld umgewandelt werden\n• Können nicht an andere Benutzer übertragen werden\n• Können nicht verkauft oder getauscht werden'),
      
      _buildSectionTitle('3. Ein Gerät - Ein Konto Regel'),
      _buildWarningBox('WARNUNG - BETRUGSPRÄVENTION:\n\n• Jedes Konto kann nur mit einem Gerät verknüpft werden\n• Schrittübertragungen können nicht von demselben Gerät an mehrere Konten erfolgen\n• Bei Verstoß können Konten gesperrt werden'),
      
      _buildSectionTitle('4. Kontakt'),
      _buildBulletPoint('E-Mail: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          'Letzte Aktualisierung: 23. Dezember 2025',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  // Japanese Terms
  List<Widget> _buildJapaneseTerms(BuildContext context) {
    return [
      _buildSectionTitle('HOPESTEPS 利用規約'),
      _buildHighlightBox(
        '最終更新日: 2025年12月23日\n\nこの利用規約は、OneHopeStepアプリケーションの使用を規定する法的契約です。アプリをダウンロードして使用することで、これらの条件に同意したことになります。',
      ),
      
      _buildSectionTitle('1. 定義'),
      _buildBulletPoint('「アプリケーション」または「OneHopeStep」: OneHopeStepモバイルアプリケーション'),
      _buildBulletPoint('「ユーザー」: アプリをダウンロードして使用する自然人'),
      _buildBulletPoint('「Hope」: 歩数が変換される仮想ポイント単位'),
      _buildBulletPoint('「寄付」: Hopeポイントを慈善団体に譲渡するプロセス'),
      
      _buildSectionTitle('2. Hopeシステム'),
      _buildWarningBox('重要: Hopeポイントはアプリ内の慈善団体への寄付にのみ使用できます。\n\n• 現金に変換できません\n• 他のユーザーに譲渡できません\n• 売買や交換はできません'),
      
      _buildSectionTitle('3. 1デバイス1アカウントルール'),
      _buildWarningBox('警告 - 不正防止:\n\n• 各アカウントは1つのデバイスにのみリンクできます\n• 同じデバイスから複数のアカウントに歩数を転送できません\n• 違反した場合、アカウントが停止される場合があります'),
      
      _buildSectionTitle('4. お問い合わせ'),
      _buildBulletPoint('メール: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          '最終更新日: 2025年12月23日',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  // Spanish Terms
  List<Widget> _buildSpanishTerms(BuildContext context) {
    return [
      _buildSectionTitle('TÉRMINOS DE SERVICIO DE HOPESTEPS'),
      _buildHighlightBox(
        'Última Actualización: 23 de Diciembre de 2025\n\nEstos Términos de Servicio constituyen un acuerdo legal que rige su uso de la aplicación OneHopeStep. Al descargar y usar la aplicación, acepta estos términos.',
      ),
      
      _buildSectionTitle('1. Definiciones'),
      _buildBulletPoint('"Aplicación" o "OneHopeStep": La aplicación móvil OneHopeStep'),
      _buildBulletPoint('"Usuario": La persona que descarga y usa la aplicación'),
      _buildBulletPoint('"Hope": La unidad de puntos virtuales en la que se convierten los pasos'),
      _buildBulletPoint('"Donación": El proceso de transferir puntos Hope a organizaciones benéficas'),
      
      _buildSectionTitle('2. Sistema Hope'),
      _buildWarningBox('IMPORTANTE: Los puntos Hope solo se pueden usar para donar a organizaciones benéficas dentro de la aplicación.\n\n• No se pueden convertir en efectivo\n• No se pueden transferir a otros usuarios\n• No se pueden vender o intercambiar'),
      
      _buildSectionTitle('3. Regla de Un Dispositivo - Una Cuenta'),
      _buildWarningBox('ADVERTENCIA - PREVENCIÓN DE FRAUDE:\n\n• Cada cuenta solo puede vincularse a un dispositivo\n• Las transferencias de pasos no pueden realizarse desde el mismo dispositivo a múltiples cuentas\n• Las cuentas pueden suspenderse si se viola esta regla'),
      
      _buildSectionTitle('4. Contacto'),
      _buildBulletPoint('Correo electrónico: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          'Última Actualización: 23 de Diciembre de 2025',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }

  // Romanian Terms
  List<Widget> _buildRomanianTerms(BuildContext context) {
    return [
      _buildSectionTitle('TERMENI ȘI CONDIȚII HOPESTEPS'),
      _buildHighlightBox(
        'Ultima Actualizare: 23 Decembrie 2025\n\nAcești Termeni de Serviciu constituie un acord legal care reglementează utilizarea aplicației OneHopeStep. Prin descărcarea și utilizarea aplicației, sunteți de acord cu acești termeni.',
      ),
      
      _buildSectionTitle('1. Definiții'),
      _buildBulletPoint('"Aplicația" sau "OneHopeStep": Aplicația mobilă OneHopeStep'),
      _buildBulletPoint('"Utilizator": Persoana care descarcă și utilizează aplicația'),
      _buildBulletPoint('"Hope": Unitatea de puncte virtuale în care sunt convertiți pașii'),
      _buildBulletPoint('"Donație": Procesul de transfer al punctelor Hope către organizații caritabile'),
      
      _buildSectionTitle('2. Sistemul Hope'),
      _buildWarningBox('IMPORTANT: Punctele Hope pot fi folosite doar pentru donații către organizații caritabile din aplicație.\n\n• Nu pot fi convertite în numerar\n• Nu pot fi transferate altor utilizatori\n• Nu pot fi vândute sau schimbate'),
      
      _buildSectionTitle('3. Regula Un Dispozitiv - Un Cont'),
      _buildWarningBox('AVERTISMENT - PREVENIREA FRAUDEI:\n\n• Fiecare cont poate fi legat doar de un dispozitiv\n• Transferurile de pași nu pot fi făcute de pe același dispozitiv la mai multe conturi\n• Conturile pot fi suspendate dacă această regulă este încălcată'),
      
      _buildSectionTitle('4. Contact'),
      _buildBulletPoint('Email: hopesteps.app@gmail.com'),
      
      const SizedBox(height: 20),
      Center(
        child: Text(
          'Ultima Actualizare: 23 Decembrie 2025',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    ];
  }
}
