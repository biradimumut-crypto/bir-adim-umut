import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../models/team_model.dart';

/// Takım Ekranı - Detaylı üye görünümü, lider yetkileri, davet sistemi
class TeamsScreen extends StatefulWidget {
  const TeamsScreen({Key? key}) : super(key: key);

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  TeamModel? _currentTeam;
  bool _isLoading = true;
  bool _hasTeam = false;
  bool _isLeader = false;
  List<Map<String, dynamic>> _teamMembers = [];

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final teamId = userDoc.data()?['current_team_id'];

      if (teamId != null) {
        final teamDoc = await _firestore.collection('teams').doc(teamId).get();
        if (teamDoc.exists) {
          final team = TeamModel.fromFirestore(teamDoc);
          
          // Üyeleri yükle
          final membersSnapshot = await _firestore
              .collection('teams')
              .doc(teamId)
              .collection('team_members')
              .get();

          List<Map<String, dynamic>> members = [];
          for (var memberDoc in membersSnapshot.docs) {
            final memberData = memberDoc.data();
            // Kullanıcı bilgilerini al
            final userDoc = await _firestore
                .collection('users')
                .doc(memberDoc.id)
                .get();
            
            members.add({
              'uid': memberDoc.id,
              'name': userDoc.data()?['full_name'] ?? 'Kullanıcı',
              'daily_steps': memberData['member_daily_steps'] ?? 0,
              'total_hope': memberData['member_total_hope'] ?? 0.0,
              'join_date': memberData['join_date'],
              'isLeader': team.leaderUid == memberDoc.id,
            });
          }

          // Lideri en üste al
          members.sort((a, b) {
            if (a['isLeader']) return -1;
            if (b['isLeader']) return 1;
            return (b['total_hope'] as num).compareTo(a['total_hope'] as num);
          });

          setState(() {
            _currentTeam = team;
            _hasTeam = true;
            _isLeader = team.leaderUid == uid;
            _teamMembers = members;
          });
        }
      }
    } catch (e) {
      print('Takım yükleme hatası: $e');
    }

    setState(() => _isLoading = false);
  }

  /// Logo seçeneklerini göster (lider için)
  void _showLogoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Takım Logosu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library, color: Colors.blue[600]),
                ),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadLogo(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt, color: Colors.green[600]),
                ),
                title: const Text('Kamera ile Çek'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadLogo(ImageSource.camera);
                },
              ),
              if (_currentTeam?.logoUrl != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete, color: Colors.red[600]),
                  ),
                  title: const Text('Logoyu Kaldır'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeLogo();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Logo seç ve yükle
  Future<void> _pickAndUploadLogo(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      // Firebase Storage'a yükle
      final ref = FirebaseStorage.instance
          .ref()
          .child('team_logos')
          .child('${_currentTeam!.teamId}.jpg');

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(pickedFile.path));
      }

      final downloadUrl = await ref.getDownloadURL();

      // Firestore'u güncelle
      await _firestore
          .collection('teams')
          .doc(_currentTeam!.teamId)
          .update({'logo_url': downloadUrl});

      // Yerel state'i güncelle
      await _loadTeamData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Takım logosu güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Logo yükleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Logo yüklenemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// Logoyu kaldır
  Future<void> _removeLogo() async {
    try {
      setState(() => _isLoading = true);

      // Firestore'dan kaldır
      await _firestore
          .collection('teams')
          .doc(_currentTeam!.teamId)
          .update({'logo_url': null});

      // Storage'dan sil (varsa)
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('team_logos')
            .child('${_currentTeam!.teamId}.jpg');
        await ref.delete();
      } catch (_) {
        // Dosya yoksa sessizce geç
      }

      await _loadTeamData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logo kaldırıldı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Logo kaldırma hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadTeamData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Takımım',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _hasTeam ? 'Takımınla yarış ve umut ol!' : 'Takım kur veya katıl',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 24),

              if (_hasTeam && _currentTeam != null)
                _buildTeamView()
              else
                _buildNoTeamView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamView() {
    return Column(
      children: [
        // Takım Bilgi Kartı
        _buildTeamInfoCard(),
        const SizedBox(height: 20),

        // Lider için: Üye Ekle butonu
        if (_isLeader) ...[
          _buildLeaderActions(),
          const SizedBox(height: 20),
        ],

        // Üye Listesi Başlığı
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Takım Üyeleri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_teamMembers.length} üye',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Üye Listesi
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _teamMembers.length,
          itemBuilder: (context, index) {
            return _buildMemberCard(_teamMembers[index], index + 1);
          },
        ),

        const SizedBox(height: 20),

        // Takımdan Ayrıl
        if (!_isLeader)
          OutlinedButton.icon(
            onPressed: _showLeaveTeamDialog,
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            label: const Text('Takımdan Ayrıl', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo ve isim
          Row(
            children: [
              // Takım logosu - lider için tıklanabilir
              GestureDetector(
                onTap: _isLeader ? _showLogoOptions : null,
                child: Stack(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        image: _currentTeam!.logoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_currentTeam!.logoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _currentTeam!.logoUrl == null
                          ? Center(
                              child: Text(
                                _currentTeam!.name.isNotEmpty 
                                    ? _currentTeam!.name[0].toUpperCase() 
                                    : 'T',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            )
                          : null,
                    ),
                    // Lider için düzenleme ikonu
                    if (_isLeader)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentTeam!.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_isLeader)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '👑 Lider',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Referans Kodu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.share, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                const Text('Referans Kodu: ', style: TextStyle(color: Colors.white70)),
                Text(
                  _currentTeam!.referralCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _currentTeam!.referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Kod kopyalandı: ${_currentTeam!.referralCode}'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // İstatistikler
          Row(
            children: [
              Expanded(child: _buildTeamStat('Üyeler', '${_currentTeam!.membersCount}', Icons.people)),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(child: _buildTeamStat('Toplam Hope', '${_currentTeam!.totalTeamHope.toStringAsFixed(0)}', Icons.favorite)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildLeaderActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.amber[700]),
              const SizedBox(width: 8),
              Text(
                'Lider Yetkileri',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[800]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showInviteUserDialog,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Üye Davet Et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, int rank) {
    bool isLeader = member['isLeader'] ?? false;
    bool isCurrentUser = member['uid'] == _auth.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser ? Colors.blue[200]! : Colors.grey[200]!,
        ),
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
          // Sıra
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isLeader ? Colors.amber : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isLeader
                  ? const Text('👑', style: TextStyle(fontSize: 14))
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.purple[100],
            child: Text(
              (member['name'] as String).isNotEmpty 
                  ? (member['name'] as String)[0].toUpperCase() 
                  : 'U',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple[700],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // İsim ve bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (isCurrentUser)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Sen',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Bugün: ${member['daily_steps']} adım',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),

          // Toplam Hope
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(member['total_hope'] as num).toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                ),
              ),
              Text(
                'Hope',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoTeamView() {
    return Column(
      children: [
        // Takım Kur
        _buildActionCard(
          icon: Icons.add_circle_outline,
          title: 'Takım Kur',
          subtitle: 'Yeni bir takım oluştur ve lider ol',
          color: Colors.green,
          onTap: _showCreateTeamDialog,
        ),

        const SizedBox(height: 16),

        // Takıma Katıl
        _buildActionCard(
          icon: Icons.group_add,
          title: 'Takıma Katıl',
          subtitle: 'Referans kodu ile mevcut takıma katıl',
          color: Colors.blue,
          onTap: _showJoinTeamDialog,
        ),

        const SizedBox(height: 24),

        // Bilgi
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Column(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber[700], size: 48),
              const SizedBox(height: 12),
              const Text(
                'Takımlar Neden Önemli?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '• Takım arkadaşlarınla yarış\n• Birlikte daha çok Hope kazan\n• Takım sıralamasında yüksel\n• Sosyal motivasyon ile daha çok adım at',
                style: TextStyle(color: Colors.grey[700], height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ===================== DIALOG'LAR =====================

  void _showCreateTeamDialog() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Takım Kur'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Takım Adı',
                hintText: 'Örn: Umut Yıldızları',
                prefixIcon: const Icon(Icons.group),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Benzersiz bir referans kodu otomatik oluşturulacak.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _createTeam(nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _showJoinTeamDialog() {
    final codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.group_add, color: Colors.blue),
            SizedBox(width: 8),
            Text('Takıma Katıl'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Referans Kodu',
                hintText: 'Örn: ABC123',
                prefixIcon: const Icon(Icons.vpn_key),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Takım liderinden aldığınız 6 haneli kodu girin.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _joinTeam(codeController.text.trim().toUpperCase());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );
  }

  void _showInviteUserDialog() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue),
              SizedBox(width: 8),
              Text('Üye Davet Et'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'İsim veya Nickname Ara',
                    hintText: 'Örn: Ahmet Yılmaz',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        if (searchController.text.trim().isEmpty) return;
                        
                        setDialogState(() => isSearching = true);
                        
                        final results = await _searchUsers(searchController.text.trim());
                        
                        setDialogState(() {
                          searchResults = results;
                          isSearching = false;
                        });
                      },
                    ),
                  ),
                  onSubmitted: (value) async {
                    if (value.trim().isEmpty) return;
                    
                    setDialogState(() => isSearching = true);
                    
                    final results = await _searchUsers(value.trim());
                    
                    setDialogState(() {
                      searchResults = results;
                      isSearching = false;
                    });
                  },
                ),
                const SizedBox(height: 16),

                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  )
                else if (searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'İsim veya nickname ile kullanıcı arayın',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                else
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final user = searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple[100],
                            child: Text(
                              (user['name'] as String)[0].toUpperCase(),
                              style: TextStyle(color: Colors.purple[700]),
                            ),
                          ),
                          title: Text(user['name']),
                          subtitle: Text(
                            user['hasTeam'] ? 'Başka takımda' : 'Takımsız',
                            style: TextStyle(
                              color: user['hasTeam'] ? Colors.orange : Colors.green,
                              fontSize: 12,
                            ),
                          ),
                          trailing: user['hasTeam']
                              ? null
                              : ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _sendInvite(user['uid'], user['name']);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  child: const Text('Davet Et', style: TextStyle(fontSize: 12)),
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveTeamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Takımdan Ayrıl'),
        content: const Text('Takımdan ayrılmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveTeam();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
  }

  // ===================== FONKSİYONLAR =====================

  Future<void> _createTeam(String name) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      String referralCode = _generateReferralCode();

      final teamRef = await _firestore.collection('teams').add({
        'name': name,
        'logo_url': null,
        'referral_code': referralCode,
        'leader_uid': uid,
        'members_count': 1,
        'total_team_hope': 0.0,
        'created_at': Timestamp.now(),
        'member_ids': [uid],
      });

      await teamRef.collection('team_members').doc(uid).set({
        'team_id': teamRef.id,
        'user_id': uid,
        'member_status': 'active',
        'join_date': Timestamp.now(),
        'member_total_hope': 0.0,
        'member_daily_steps': 0,
      });

      await _firestore.collection('users').doc(uid).update({
        'current_team_id': teamRef.id,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Takım oluşturuldu! Kod: $referralCode'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadTeamData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _joinTeam(String code) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final teamQuery = await _firestore
          .collection('teams')
          .where('referral_code', isEqualTo: code)
          .limit(1)
          .get();

      if (teamQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takım bulunamadı!'), backgroundColor: Colors.red),
        );
        return;
      }

      final teamDoc = teamQuery.docs.first;
      final teamId = teamDoc.id;

      await _firestore.collection('teams').doc(teamId).collection('team_members').doc(uid).set({
        'team_id': teamId,
        'user_id': uid,
        'member_status': 'active',
        'join_date': Timestamp.now(),
        'member_total_hope': 0.0,
        'member_daily_steps': 0,
      });

      await _firestore.collection('teams').doc(teamId).update({
        'members_count': FieldValue.increment(1),
        'member_ids': FieldValue.arrayUnion([uid]),
      });

      await _firestore.collection('users').doc(uid).update({
        'current_team_id': teamId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Takıma katıldınız!'), backgroundColor: Colors.green),
      );

      await _loadTeamData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('full_name', isGreaterThanOrEqualTo: query)
          .where('full_name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': data['full_name'] ?? 'Kullanıcı',
          'hasTeam': data['current_team_id'] != null,
        };
      }).where((user) => user['uid'] != _auth.currentUser?.uid).toList();
    } catch (e) {
      print('Kullanıcı arama hatası: $e');
      return [];
    }
  }

  Future<void> _sendInvite(String targetUid, String targetName) async {
    try {
      await _firestore.collection('notifications').add({
        'receiver_uid': targetUid,
        'sender_team_id': _currentTeam!.teamId,
        'team_name': _currentTeam!.name,
        'type': 'team_invite',
        'status': 'pending',
        'created_at': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📨 $targetName\'e davet gönderildi!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _leaveTeam() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _currentTeam == null) return;

    try {
      final batch = _firestore.batch();

      batch.delete(
        _firestore.collection('teams').doc(_currentTeam!.teamId).collection('team_members').doc(uid),
      );

      batch.update(
        _firestore.collection('teams').doc(_currentTeam!.teamId),
        {
          'members_count': FieldValue.increment(-1),
          'member_ids': FieldValue.arrayRemove([uid]),
        },
      );

      batch.update(
        _firestore.collection('users').doc(uid),
        {'current_team_id': null},
      );

      await batch.commit();

      setState(() {
        _hasTeam = false;
        _currentTeam = null;
        _teamMembers = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takımdan ayrıldınız')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _generateReferralCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (i) => chars[(random + i * 7) % chars.length]).join();
  }
}
