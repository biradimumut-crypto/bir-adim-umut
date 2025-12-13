import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';

/// Profil Ekranı
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  /// Fotoğraf seçme ve yükleme
  Future<void> _pickAndUploadPhoto() async {
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
            const Text(
              'Fotoğraf Seç',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.camera_alt, color: Colors.blue[600]),
              ),
              title: const Text('Kamera'),
              subtitle: const Text('Fotoğraf çek'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.photo_library, color: Colors.purple[600]),
              ),
              title: const Text('Galeri'),
              subtitle: const Text('Mevcut fotoğraftan seç'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil fotoğrafı güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  /// Profil düzenleme dialogu
  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _currentUser?.fullName ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 8),
            Text('Profili Düzenle'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Ad Soyad',
                hintText: 'Örn: Sercan KARSLI',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Text(
              'İsminiz bağış geçmişinde "Sercan K." şeklinde görünecek.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Kaydet'),
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
        });

        await _loadUserData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil güncellendi!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
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
                    backgroundColor: Colors.blue[100],
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
                              color: Colors.blue[700],
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
                          color: Colors.blue[600],
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

            const SizedBox(height: 24),

            // İstatistikler
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProfileStat(
                    'Hope',
                    '${_currentUser?.walletBalanceHope.toStringAsFixed(0) ?? '0'}',
                    Icons.favorite,
                    Colors.red,
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  _buildProfileStat(
                    'Takım',
                    _currentUser?.currentTeamId != null ? 'Var' : 'Yok',
                    Icons.groups,
                    Colors.blue,
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  _buildProfileStat(
                    'Üyelik',
                    _getDaysSinceJoin(),
                    Icons.calendar_today,
                    Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Menü Öğeleri
            _buildMenuItem(
              icon: Icons.person_outline,
              title: 'Profili Düzenle',
              onTap: _showEditProfileDialog,
            ),

            _buildMenuItem(
              icon: Icons.history,
              title: 'Aktivite Geçmişi',
              onTap: () {
                _showActivityHistory();
              },
            ),

            _buildMenuItem(
              icon: Icons.notifications_outlined,
              title: 'Bildirimler',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yakında!')),
                );
              },
            ),

            _buildMenuItem(
              icon: Icons.settings_outlined,
              title: 'Ayarlar',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yakında!')),
                );
              },
            ),

            _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Yardım & Destek',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yakında!')),
                );
              },
            ),

            const SizedBox(height: 16),

            // Çıkış Yap
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Çıkış Yap',
                  style: TextStyle(color: Colors.red),
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

            const SizedBox(height: 24),

            // Versiyon
            Text(
              'Bir Adım Umut v1.0.0',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  String _getDaysSinceJoin() {
    if (_currentUser?.createdAt == null) return '0 gün';
    final days = DateTime.now().difference(_currentUser!.createdAt).inDays;
    return '$days gün';
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkış Yap'),
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
}

/// Aktivite Geçmişi Sayfası
class ActivityHistoryPage extends StatelessWidget {
  final String userId;
  
  const ActivityHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivite Geçmişi'),
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
                    'Veriler yüklenemedi',
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
                    'Henüz aktivite yok',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adım dönüştür veya bağış yap!',
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
              return _buildActivityItem(activity);
            },
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    // Hem yeni hem eski alan adlarını destekle
    final type = activity['activity_type'] ?? activity['action_type'] ?? '';
    final timestamp = (activity['created_at'] ?? activity['timestamp']) as Timestamp?;
    final dateStr = timestamp != null 
        ? DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate())
        : '';

    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (type) {
      case 'donation':
        icon = Icons.volunteer_activism;
        color = Colors.purple;
        // Hem charity_name hem target_name destekle
        final charityName = activity['charity_name'] ?? activity['target_name'] ?? 'Vakıf';
        final amount = (activity['amount'] as num?)?.toStringAsFixed(1) ?? '0';
        title = '$charityName\'a Bağış';
        subtitle = '$amount Hope bağışlandı';
        break;
      case 'step_conversion':
        icon = Icons.directions_walk;
        color = Colors.blue;
        final steps = activity['steps_converted'] ?? 0;
        final hope = (activity['hope_earned'] as num?)?.toStringAsFixed(2) ?? '0';
        title = 'Adım Dönüştürüldü';
        subtitle = '$steps adım → $hope Hope';
        break;
      case 'carryover_conversion':
        icon = Icons.history;
        color = Colors.deepOrange;
        final steps = activity['steps_converted'] ?? 0;
        final hope = (activity['hope_earned'] as num?)?.toStringAsFixed(2) ?? '0';
        title = 'Taşınan Adım Dönüştürüldü';
        subtitle = '$steps adım → $hope Hope';
        break;
      case 'team_joined':
        icon = Icons.group_add;
        color = Colors.green;
        final teamName = activity['team_name'] ?? 'Takım';
        title = 'Takıma Katıldı';
        subtitle = teamName;
        break;
      case 'team_created':
        icon = Icons.add_circle;
        color = Colors.orange;
        final teamName = activity['team_name'] ?? 'Takım';
        title = 'Takım Kuruldu';
        subtitle = teamName;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        title = 'Aktivite';
        subtitle = type;
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
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
