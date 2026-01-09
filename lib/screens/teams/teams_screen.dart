import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../models/team_model.dart';
import '../../providers/language_provider.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/success_dialog.dart';
import '../../services/interstitial_ad_service.dart';

/// Takım Ekranı - Detaylı üye görünümü, lider yetkileri, davet sistemi
class TeamsScreen extends StatefulWidget {
  const TeamsScreen({Key? key}) : super(key: key);

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  TeamModel? _currentTeam;
  bool _isLoading = true;
  bool _hasTeam = false;
  bool _isLeader = false;
  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _pendingInvites = []; // Bekleyen davetler
  List<Map<String, dynamic>> _joinRequests = []; // Takıma katılma istekleri (lider için)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTeamData();
    _loadPendingInvites(); // Davetleri yükle
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
      debugPrint('📱 TeamsScreen resumed - refreshing data...');
      _loadTeamData();
      _loadPendingInvites();
    }
  }

  /// Bekleyen takım davetlerini yükle
  Future<void> _loadPendingInvites() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final invitesSnapshot = await _firestore
          .collection('notifications')
          .where('receiver_uid', isEqualTo: uid)
          .where('type', isEqualTo: 'team_invite')
          .where('status', isEqualTo: 'pending')
          .get();

      List<Map<String, dynamic>> invites = [];
      for (var doc in invitesSnapshot.docs) {
        final data = doc.data();
        
        // Gönderen kullanıcının ismini al (eğer sender_name yoksa)
        String senderName = data['sender_name'] ?? '';
        if (senderName.isEmpty && data['sender_uid'] != null) {
          try {
            final senderDoc = await _firestore.collection('users').doc(data['sender_uid']).get();
            senderName = senderDoc.data()?['full_name'] ?? 'Takım Lideri';
          } catch (_) {
            senderName = 'Takım Lideri';
          }
        }
        if (senderName.isEmpty) senderName = 'Takım Lideri';
        
        invites.add({
          'notificationId': doc.id,
          'teamId': data['sender_team_id'],
          'teamName': data['team_name'] ?? 'Bilinmeyen Takım',
          'senderName': senderName,
          'createdAt': (data['created_at'] as Timestamp?)?.toDate(),
        });
      }

      if (mounted) {
        setState(() {
          _pendingInvites = invites;
        });
      }
    } catch (e) {
      print('Davetler yükleme hatası: $e');
    }
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
              'profileImageUrl': userDoc.data()?['profile_image_url'],
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
          
          // Lider ise katılma isteklerini yükle
          if (team.leaderUid == uid) {
            await _loadJoinRequests();
          }
        }
      }
    } catch (e) {
      print('Takım yükleme hatası: $e');
    }

    setState(() => _isLoading = false);
  }

  /// Takıma katılma isteklerini yükle (sadece lider için)
  Future<void> _loadJoinRequests() async {
    final uid = _auth.currentUser?.uid;
    final teamId = _currentTeam?.teamId;
    if (uid == null || teamId == null) return;

    try {
      final requestsSnapshot = await _firestore
          .collection('notifications')
          .where('receiver_uid', isEqualTo: uid)
          .where('sender_team_id', isEqualTo: teamId)
          .where('type', isEqualTo: 'join_request')
          .where('status', isEqualTo: 'pending')
          .get();

      List<Map<String, dynamic>> requests = [];
      for (var doc in requestsSnapshot.docs) {
        final data = doc.data();
        requests.add({
          'notificationId': doc.id,
          'senderUid': data['sender_uid'],
          'senderName': data['sender_name'] ?? 'Kullanıcı',
          'senderPhoto': data['sender_photo'],
          'teamId': data['sender_team_id'],
          'createdAt': (data['created_at'] as Timestamp?)?.toDate(),
        });
      }

      if (mounted) {
        setState(() {
          _joinRequests = requests;
        });
      }
    } catch (e) {
      print('Katılma istekleri yükleme hatası: $e');
    }
  }

  /// Tüm üyelerin toplam Hope değerini hesapla
  /// Firestore'daki total_team_hope yerine gerçek verilerden hesap
  double _calculateTotalHope() {
    double total = 0.0;
    for (var member in _teamMembers) {
      total += (member['total_hope'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  /// Logo seçeneklerini göster (lider için)
  void _showLogoOptions() {
    final lang = context.read<LanguageProvider>();
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
              Text(
                lang.teamLogo,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library, color: const Color(0xFF6EC6B5)),
                ),
                title: Text(lang.chooseFromGalleryOption),
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
                title: Text(lang.takePhotoOption),
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
                  title: Text(lang.removeLogo),
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
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.logoUpdated),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Logo yükleme hatası: $e');
      if (mounted) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.logoUploadFailed}: $e'),
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
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.logoRemoved),
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
    final lang = context.read<LanguageProvider>();
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadTeamData();
          await _loadPendingInvites();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.myTeamTitle,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _hasTeam ? lang.competeWithTeam : lang.createOrJoinTeam,
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 24),

              // Bekleyen Davetler
              if (_pendingInvites.isNotEmpty) ...[
                _buildPendingInvitesSection(),
                const SizedBox(height: 24),
              ],

              if (_hasTeam && _currentTeam != null)
                _buildTeamView()
              else
                _buildNoTeamView(),
              
              const SizedBox(height: 8),
              const BannerAdWidget(), // Reklam Alanı
            ],
          ),
        ),
      ),
    );
  }

  /// Bekleyen davetler bölümü
  Widget _buildPendingInvitesSection() {
    final lang = context.read<LanguageProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mail, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text(
              lang.isTurkish ? 'Bekleyen Davetler' : 'Pending Invites',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_pendingInvites.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_pendingInvites.map((invite) => _buildInviteCard(invite)).toList()),
      ],
    );
  }

  /// Davet kartı
  Widget _buildInviteCard(Map<String, dynamic> invite) {
    final lang = context.read<LanguageProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFFF0ED), const Color(0xFFFFF9E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE07A5F).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Takım ikonu
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF2C94C), Color(0xFF6EC6B5)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          
          // Davet bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite['teamName'] ?? 'Takım',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lang.isTurkish 
                      ? '${invite['senderName']} sizi takıma davet etti'
                      : '${invite['senderName']} invited you to the team',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          // Kabul/Reddet butonları
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reddet
              IconButton(
                onPressed: () => _rejectInvite(invite),
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: lang.reject,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                ),
              ),
              const SizedBox(width: 8),
              // Kabul et
              IconButton(
                onPressed: () => _acceptInvite(invite),
                icon: const Icon(Icons.check, color: Colors.green),
                tooltip: lang.accept,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Daveti kabul et
  Future<void> _acceptInvite(Map<String, dynamic> invite) async {
    final lang = context.read<LanguageProvider>();
    final uid = _auth.currentUser?.uid;
    
    if (uid == null) return;
    
    // Zaten takımda mıyız kontrol et
    if (_hasTeam) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.isTurkish 
              ? 'Zaten bir takımdasınız. Önce mevcut takımınızdan ayrılmalısınız.'
              : 'You are already in a team. Leave your current team first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final teamId = invite['teamId'];
      final notificationId = invite['notificationId'];
      
      final batch = _firestore.batch();
      
      // 1. Kullanıcının current_team_id'sini güncelle
      batch.update(_firestore.collection('users').doc(uid), {
        'current_team_id': teamId,
      });
      
      // 2. team_members'a ekle
      batch.set(
        _firestore.collection('teams').doc(teamId).collection('team_members').doc(uid),
        {
          'team_id': teamId,
          'user_id': uid,
          'member_status': 'active',
          'join_date': Timestamp.now(),
          'member_total_hope': 0.0,
          'member_daily_steps': 0,
        },
      );
      
      // 3. Takım üye sayısını artır
      batch.update(_firestore.collection('teams').doc(teamId), {
        'member_count': FieldValue.increment(1),
      });
      
      // 4. Notification'ı accepted olarak güncelle
      batch.update(_firestore.collection('notifications').doc(notificationId), {
        'status': 'accepted',
        'responded_at': Timestamp.now(),
      });
      
      await batch.commit();

      // Verileri yeniden yükle
      await _loadTeamData();
      await _loadPendingInvites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? '✅ ${invite['teamName']} takımına katıldınız!'
                : '✅ Joined ${invite['teamName']}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Davet kabul hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? 'Davet kabul edilemedi: $e'
                : 'Could not accept invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// Daveti reddet
  Future<void> _rejectInvite(Map<String, dynamic> invite) async {
    final lang = context.read<LanguageProvider>();

    // Onay dialog'u
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.isTurkish ? 'Daveti Reddet' : 'Reject Invite'),
        content: Text(lang.isTurkish 
            ? '${invite['teamName']} takımının davetini reddetmek istediğinize emin misiniz?'
            : 'Are you sure you want to reject the invite from ${invite['teamName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lang.reject),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Notification'ı rejected olarak güncelle
      await _firestore.collection('notifications').doc(invite['notificationId']).update({
        'status': 'rejected',
        'responded_at': Timestamp.now(),
      });

      // Davetleri yeniden yükle
      await _loadPendingInvites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? 'Davet reddedildi'
                : 'Invite rejected'),
            backgroundColor: Colors.grey,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Davet reddetme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? 'Davet reddedilemedi: $e'
                : 'Could not reject invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTeamView() {
    final lang = context.read<LanguageProvider>();
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
            Text(
              lang.teamMembersTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              lang.membersCount(_teamMembers.length),
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
            label: Text(lang.leaveTeamTitle, style: const TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamInfoCard() {
    final lang = context.read<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2C94C), Color(0xFFE07A5F), Color(0xFF6EC6B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF2C94C).withOpacity(0.3),
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
                                  color: Color(0xFFF2C94C),
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
                            color: const Color(0xFFF2C94C),
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
                          color: const Color(0xFFF2C94C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          lang.leader,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          
          // Takım Bonus Adımları Bölümü
          _buildTeamBonusSection(),

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
                Text(lang.referralCodeLabel, style: const TextStyle(color: Colors.white70)),
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
                        content: Text(lang.codeCopiedMsg(_currentTeam!.referralCode)),
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

          // İstatistikler - Gerçek verilerden hesapla (tutarsızlık düzeltmesi)
          Row(
            children: [
              // Üye sayısı: Gerçek üye listesinden al
              Expanded(child: _buildTeamStatWithImage(lang.membersLabel, '${_teamMembers.length}', 'assets/icons/takım.png')),
              Container(width: 1, height: 40, color: Colors.white24),
              // Toplam Hope: Üyelerin member_total_hope toplamından hesapla
              Expanded(child: _buildTeamStatWithImage(lang.totalHopeLabel, '${_calculateTotalHope().toStringAsFixed(0)}', 'assets/hp.png')),
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

  Widget _buildTeamStatWithImage(String label, String value, String imagePath) {
    return Column(
      children: [
        Image.asset(imagePath, width: 24, height: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
  
  /// Takım Bonus Adımları Bölümü
  Widget _buildTeamBonusSection() {
    final lang = context.read<LanguageProvider>();
    final teamBonusSteps = _currentTeam?.teamBonusSteps ?? 0;
    final teamBonusConverted = _currentTeam?.teamBonusConverted ?? 0;
    final remainingBonus = teamBonusSteps - teamBonusConverted;
    final hasBonus = remainingBonus > 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                lang.isTurkish ? 'Takım Bonus Adımları' : 'Team Bonus Steps',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatNumber(remainingBonus > 0 ? remainingBonus : 0),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            lang.isTurkish ? 'Kullanılabilir Adım' : 'Available Steps',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          // Bilgi mesajı - bonus yoksa nasıl kazanılır
          if (!hasBonus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      lang.isTurkish 
                          ? 'Sıralamada ilk 3\'e girerek veya yeni üye davet ederek bonus kazanın!' 
                          : 'Earn bonus by ranking top 3 or inviting new members!',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          if (hasBonus) ...[
            const SizedBox(height: 4),
            ElevatedButton.icon(
              onPressed: () => _showTeamBonusConvertDialog(remainingBonus),
              icon: const Icon(Icons.sync, size: 20),
              label: Text(lang.isTurkish ? 'Dönüştür' : 'Convert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE07A5F),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang.isTurkish 
                  ? 'Hope kazanımı kendi cüzdanınıza eklenir' 
                  : 'Hope will be added to your wallet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
  
  /// Takım bonus dönüştürme dialogu - showModalBottomSheet kullanarak
  void _showTeamBonusConvertDialog(int availableSteps) {
    final lang = context.read<LanguageProvider>();
    final maxSteps = availableSteps > 2500 ? 2500 : availableSteps;
    final hopeEarned = maxSteps / 100.0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2C94C), Color(0xFFE07A5F)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Başlık
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.card_giftcard, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Text(
                  lang.isTurkish ? 'Takım Bonus' : 'Team Bonus',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Dönüşüm kartları
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Adım
                  Column(
                    children: [
                      Image.asset('assets/badges/adimm.png', width: 40, height: 40),
                      const SizedBox(height: 8),
                      Text(
                        '$maxSteps',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        lang.isTurkish ? 'Adım' : 'Steps',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // Ok
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 32),
                  // Hope
                  Column(
                    children: [
                      Image.asset('assets/hp.png', width: 40, height: 40),
                      const SizedBox(height: 8),
                      Text(
                        hopeEarned.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Hope',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Bilgi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_filled, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    lang.isTurkish 
                        ? 'Reklam izleyerek dönüştür' 
                        : 'Watch ad to convert',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Butonlar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(lang.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _convertTeamBonusDirectly(maxSteps);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: Text(lang.isTurkish ? 'İzle & Dönüştür' : 'Watch & Convert'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFE07A5F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Alt bilgi
            Text(
              lang.isTurkish 
                  ? 'Hope kazanımı kendi cüzdanınıza eklenir'
                  : 'Hope will be added to your wallet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  /// Takım bonus dönüştürme işlemi - direkt reklam göster (çift dialog yok)
  Future<void> _convertTeamBonusDirectly(int steps) async {
    final lang = context.read<LanguageProvider>();
    final uid = _auth.currentUser?.uid;
    if (uid == null || _currentTeam == null) return;
    
    // InterstitialAdService kullanarak direk reklam göster
    await InterstitialAdService.instance.showAd(
      context: 'team_bonus_conversion',
      onAdComplete: () async {
        // Dönüştürme işlemi
        try {
          final hopeEarned = steps / 100.0; // 100 adım = 1 Hope
          
          final batch = _firestore.batch();
          
          // Takım bonus'unu düş
          final teamRef = _firestore.collection('teams').doc(_currentTeam!.teamId);
          batch.update(teamRef, {
            'team_bonus_converted': FieldValue.increment(steps),
          });
          
          // Kullanıcının cüzdanına Hope ekle
          final userRef = _firestore.collection('users').doc(uid);
          batch.update(userRef, {
            'wallet_balance_hope': FieldValue.increment(hopeEarned),
            'lifetime_converted_steps': FieldValue.increment(steps),
            'lifetime_earned_hope': FieldValue.increment(hopeEarned),
          });

          // Activity log ekle
          final logRef = _firestore.collection('activity_logs').doc();
          batch.set(logRef, {
            'user_id': uid,
            'team_id': _currentTeam!.teamId,
            'activity_type': 'team_bonus_conversion',
            'steps_converted': steps,
            'hope_earned': hopeEarned,
            'is_team_bonus': true,
            'created_at': FieldValue.serverTimestamp(),
          });

          await batch.commit();
          
          // Başarı dialogu göster (konfetili)
          if (mounted) {
            await showSuccessDialog(
              context: context,
              title: lang.isTurkish ? 'Tebrikler!' : 'Congratulations!',
              message: '+${hopeEarned.toStringAsFixed(0)} Hope',
              subtitle: lang.isTurkish 
                  ? 'Takım bonusundan $steps adım dönüştürdünüz!'
                  : 'You converted $steps steps from team bonus!',
              imagePath: 'assets/hp.png',
              gradientColors: [const Color(0xFFF2C94C), const Color(0xFFE07A5F)],
              buttonText: lang.isTurkish ? 'Muhteşem!' : 'Awesome!',
            );
          }
          
          // Verileri yenile
          await _loadTeamData();
        } catch (e) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(lang.isTurkish ? 'Hata' : 'Error'),
                content: Text(lang.isTurkish ? 'Dönüştürme hatası: $e' : 'Conversion error: $e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(lang.ok),
                  ),
                ],
              ),
            );
          }
        }
      },
    );
  }
  
  /// Eski _convertTeamBonus (artık kullanılmıyor, backward compatibility için)
  Future<void> _convertTeamBonus(int steps) async {
    await _convertTeamBonusDirectly(steps);
  }
  
  /// Rewarded ad göster (artık kullanılmıyor - InterstitialAdService'e geçildi)
  Future<bool> _showRewardedAd() async {
    // InterstitialAdService kullanılıyor, bu fonksiyon artık çağrılmayacak
    return true;
  }
  
  /// Sayı formatlama
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildLeaderActions() {
    final lang = context.read<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2C94C).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: const Color(0xFFF2C94C)),
              const SizedBox(width: 8),
              Text(
                lang.leaderPrivileges,
                style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFFE07A5F)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Üye Davet Et butonu
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF2C94C), Color(0xFFE07A5F), Color(0xFF6EC6B5)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _showInviteUserDialog,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(lang.inviteMember),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Katılma İstekleri butonu
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showJoinRequestsDialog,
                    icon: const Icon(Icons.group_add, size: 18),
                    label: Text(lang.isTurkish ? 'İstekler' : 'Requests'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE07A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // Badge
                  if (_joinRequests.isNotEmpty)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_joinRequests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Katılma istekleri dialog'u
  void _showJoinRequestsDialog() {
    final lang = context.read<LanguageProvider>();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.group_add, color: Color(0xFFF2C94C)),
              const SizedBox(width: 8),
              Text(lang.isTurkish ? 'Katılma İstekleri' : 'Join Requests'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_joinRequests.length}',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: _joinRequests.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          lang.isTurkish 
                              ? 'Bekleyen katılma isteği yok' 
                              : 'No pending join requests',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    height: 300,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _joinRequests.length,
                      itemBuilder: (context, index) {
                        final request = _joinRequests[index];
                        return _buildJoinRequestCard(request, setDialogState);
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.close),
            ),
          ],
        ),
      ),
    );
  }

  /// Katılma isteği kartı
  Widget _buildJoinRequestCard(Map<String, dynamic> request, StateSetter setDialogState) {
    final name = request['senderName'] ?? 'Kullanıcı';
    final photo = request['senderPhoto'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Profil fotoğrafı
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE8F7F5),
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE07A5F),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // İsim
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (request['createdAt'] != null)
                  Text(
                    _formatDate(request['createdAt']),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ),
          
          // Kabul/Reddet butonları
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reddet
              IconButton(
                onPressed: () => _rejectJoinRequest(request, setDialogState),
                icon: const Icon(Icons.close, color: Colors.red),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                ),
              ),
              const SizedBox(width: 8),
              // Kabul et
              IconButton(
                onPressed: () => _acceptJoinRequest(request, setDialogState),
                icon: const Icon(Icons.check, color: Colors.green),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tarih formatla
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else {
      return '${diff.inDays} gün önce';
    }
  }

  /// Katılma isteğini kabul et
  Future<void> _acceptJoinRequest(Map<String, dynamic> request, StateSetter setDialogState) async {
    final lang = context.read<LanguageProvider>();
    final senderUid = request['senderUid'];
    final teamId = _currentTeam?.teamId;
    final notificationId = request['notificationId'];
    
    if (senderUid == null || teamId == null) return;
    
    try {
      final batch = _firestore.batch();
      
      // 1. Kullanıcının current_team_id'sini güncelle
      batch.update(_firestore.collection('users').doc(senderUid), {
        'current_team_id': teamId,
      });
      
      // 2. team_members'a ekle
      batch.set(
        _firestore.collection('teams').doc(teamId).collection('team_members').doc(senderUid),
        {
          'team_id': teamId,
          'user_id': senderUid,
          'member_status': 'active',
          'join_date': Timestamp.now(),
          'member_total_hope': 0.0,
          'member_daily_steps': 0,
        },
      );
      
      // 3. Takım üye sayısını artır
      batch.update(_firestore.collection('teams').doc(teamId), {
        'members_count': FieldValue.increment(1),
      });
      
      // 4. Notification'ı accepted olarak güncelle
      batch.update(_firestore.collection('notifications').doc(notificationId), {
        'status': 'accepted',
        'responded_at': Timestamp.now(),
      });
      
      await batch.commit();
      
      // State'i güncelle
      setDialogState(() {
        _joinRequests.removeWhere((r) => r['notificationId'] == notificationId);
      });
      
      setState(() {
        _joinRequests.removeWhere((r) => r['notificationId'] == notificationId);
      });
      
      // Takım verilerini yeniden yükle
      await _loadTeamData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? '✅ ${request['senderName']} takıma katıldı!' 
                : '✅ ${request['senderName']} joined the team!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Katılma isteği kabul hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? 'İstek kabul edilemedi: $e' 
                : 'Could not accept request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Katılma isteğini reddet
  Future<void> _rejectJoinRequest(Map<String, dynamic> request, StateSetter setDialogState) async {
    final lang = context.read<LanguageProvider>();
    final notificationId = request['notificationId'];
    
    try {
      // Notification'ı rejected olarak güncelle
      await _firestore.collection('notifications').doc(notificationId).update({
        'status': 'rejected',
        'responded_at': Timestamp.now(),
      });
      
      // State'i güncelle
      setDialogState(() {
        _joinRequests.removeWhere((r) => r['notificationId'] == notificationId);
      });
      
      setState(() {
        _joinRequests.removeWhere((r) => r['notificationId'] == notificationId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? 'İstek reddedildi' 
                : 'Request rejected'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      print('Katılma isteği reddetme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? 'İstek reddedilemedi: $e' 
                : 'Could not reject request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMemberCard(Map<String, dynamic> member, int rank) {
    final lang = context.read<LanguageProvider>();
    bool isLeader = member['isLeader'] ?? false;
    bool isCurrentUser = member['uid'] == _auth.currentUser?.uid;
    
    // Lider, kendisi olmayan ve lider olmayan üyeleri çıkarabilir
    bool canKick = _isLeader && !isCurrentUser && !isLeader;

    return InkWell(
      onTap: canKick ? () => _showKickMemberDialog(member) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFF2C94C), // Mor
              Color(0xFFE07A5F), // İndigo
              Color(0xFF6EC6B5), // Pembe
            ],
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(top: 3), // Üst çerçeve kalınlığı
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrentUser ? const Color(0xFFF3E8FF) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              topRight: Radius.circular(13),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              // Sıra
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isLeader ? const Color(0xFFF2C94C) : Colors.grey[200],
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

              // Avatar - Profil fotoğrafı ile
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE8F7F5),
                backgroundImage: member['profileImageUrl'] != null 
                    ? NetworkImage(member['profileImageUrl']) 
                    : null,
                child: member['profileImageUrl'] == null 
                    ? Text(
                        (member['name'] as String).isNotEmpty 
                            ? (member['name'] as String)[0].toUpperCase() 
                            : 'U',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE07A5F),
                        ),
                      )
                    : null,
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
                          color: const Color(0xFFF2C94C),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lang.youLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                  ],
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
                  color: const Color(0xFFE07A5F),
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
        ),
      ),
    );
  }

  /// Üyeyi takımdan çıkarma dialog'u
  void _showKickMemberDialog(Map<String, dynamic> member) {
    final lang = context.read<LanguageProvider>();
    final memberName = member['name'] ?? 'Üye';
    final teamName = _currentTeam?.name ?? 'Takım';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.person_remove, color: Colors.red[400]),
            const SizedBox(width: 12),
            Text(lang.isTurkish ? 'Üyeyi Çıkar' : 'Remove Member'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            children: [
              TextSpan(
                text: memberName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: lang.isTurkish 
                    ? ' kişisini ' 
                    : ' from ',
              ),
              TextSpan(
                text: teamName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: lang.isTurkish 
                    ? ' takımından çıkarmak istediğinize emin misiniz?' 
                    : ' team. Are you sure?',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _kickMember(member);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lang.isTurkish ? 'Çıkar' : 'Remove'),
          ),
        ],
      ),
    );
  }

  /// Üyeyi takımdan çıkar
  Future<void> _kickMember(Map<String, dynamic> member) async {
    final lang = context.read<LanguageProvider>();
    final memberUid = member['uid'];
    final teamId = _currentTeam?.teamId;
    
    if (memberUid == null || teamId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final batch = _firestore.batch();
      
      // 1. team_members'dan sil
      batch.delete(
        _firestore.collection('teams').doc(teamId).collection('team_members').doc(memberUid),
      );
      
      // 2. Kullanıcının current_team_id'sini null yap
      batch.update(_firestore.collection('users').doc(memberUid), {
        'current_team_id': null,
      });
      
      // 3. Takım üye sayısını azalt
      batch.update(_firestore.collection('teams').doc(teamId), {
        'members_count': FieldValue.increment(-1),
      });
      
      await batch.commit();
      
      // Verileri yeniden yükle
      await _loadTeamData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? '${member['name']} takımdan çıkarıldı' 
                : '${member['name']} removed from team'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Üye çıkarma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? 'Üye çıkarılamadı: $e' 
                : 'Could not remove member: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildNoTeamView() {
    final lang = context.read<LanguageProvider>();
    return Column(
      children: [
        // Bekleyen Davetler (varsa)
        if (_pendingInvites.isNotEmpty) ...[
          _buildPendingInvitesSection(),
          const SizedBox(height: 24),
        ],
        
        // Takım Kur
        _buildActionCard(
          icon: Icons.add_circle_outline,
          title: lang.createTeamOption,
          subtitle: lang.createTeamDesc,
          color: Colors.green,
          onTap: _showCreateTeamDialog,
        ),

        const SizedBox(height: 16),

        // Takıma Katıl
        _buildActionCard(
          icon: Icons.group_add,
          title: lang.joinTeamOption,
          subtitle: lang.joinTeamDesc,
          color: const Color(0xFFF2C94C),
          onTap: _showJoinTeamDialog,
        ),

        const SizedBox(height: 24),

        // Bilgi
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF2C94C).withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(Icons.emoji_events, color: const Color(0xFFF2C94C), size: 48),
              const SizedBox(height: 12),
              Text(
                lang.whyTeamsImportant,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                lang.teamBenefits,
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
    final lang = context.read<LanguageProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.add_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(lang.createTeamOption),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: lang.teamNameLabel,
                hintText: lang.teamNameHint,
                prefixIcon: const Icon(Icons.group),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              lang.referralCodeAutoGen,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _createTeam(nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(lang.create),
          ),
        ],
      ),
    );
  }

  void _showJoinTeamDialog() {
    final codeController = TextEditingController();
    final lang = context.read<LanguageProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.group_add, color: Color(0xFFF2C94C)),
            const SizedBox(width: 8),
            Text(lang.joinTeamOption),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: lang.referralCodeInput,
                hintText: lang.referralCodeHint,
                prefixIcon: const Icon(Icons.vpn_key),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              lang.referralCodeInfo,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _joinTeam(codeController.text.trim().toUpperCase());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2C94C)),
            child: Text(lang.join),
          ),
        ],
      ),
    );
  }

  void _showInviteUserDialog() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    final lang = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.person_add, color: Color(0xFFF2C94C)),
              const SizedBox(width: 8),
              Text(lang.inviteMember),
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
                    labelText: lang.searchNameOrNickname,
                    hintText: lang.searchNameHint,
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
                      lang.searchForUsers,
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
                            backgroundColor: const Color(0xFFE8F7F5),
                            backgroundImage: user['profileImageUrl'] != null 
                                ? NetworkImage(user['profileImageUrl']) 
                                : null,
                            child: user['profileImageUrl'] == null 
                                ? Text(
                                    (user['name'] as String)[0].toUpperCase(),
                                    style: TextStyle(color: const Color(0xFFE07A5F)),
                                  )
                                : null,
                          ),
                          title: Text(user['name']),
                          subtitle: Text(
                            user['hasTeam'] ? lang.inAnotherTeam : lang.noTeamStatus,
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
                                    backgroundColor: const Color(0xFFF2C94C),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  child: Text(lang.inviteBtn, style: const TextStyle(fontSize: 12)),
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
              child: Text(lang.close),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveTeamDialog() {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.leaveTeamTitle),
        content: Text(lang.leaveTeamConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveTeam();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lang.leave),
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

      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.teamCreatedMsg(referralCode)),
          backgroundColor: Colors.green,
        ),
      );

      await _loadTeamData();
    } catch (e) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.errorMsg(e.toString())), backgroundColor: Colors.red),
      );
    }
  }

  /// Referans kodu ile takıma katılma isteği gönder
  Future<void> _joinTeam(String code) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Takımı bul
      final teamQuery = await _firestore
          .collection('teams')
          .where('referral_code', isEqualTo: code)
          .limit(1)
          .get();

      if (teamQuery.docs.isEmpty) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.teamNotFoundError), backgroundColor: Colors.red),
        );
        return;
      }

      final teamDoc = teamQuery.docs.first;
      final teamId = teamDoc.id;
      final teamData = teamDoc.data();
      final teamName = teamData['name'] ?? 'Takım';
      final leaderUid = teamData['leader_uid'];
      
      // Kullanıcı bilgilerini al
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      final userName = userData?['full_name'] ?? 'Kullanıcı';
      final userPhoto = userData?['profile_image_url'];
      
      // Zaten bekleyen istek var mı kontrol et
      final existingRequest = await _firestore
          .collection('notifications')
          .where('sender_uid', isEqualTo: uid)
          .where('sender_team_id', isEqualTo: teamId)
          .where('type', isEqualTo: 'join_request')
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      
      if (existingRequest.docs.isNotEmpty) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isTurkish 
                ? 'Bu takıma zaten katılma isteği gönderdiniz' 
                : 'You already sent a join request to this team'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Katılma isteği oluştur
      await _firestore.collection('notifications').add({
        'type': 'join_request',
        'status': 'pending',
        'sender_uid': uid,
        'sender_name': userName,
        'sender_photo': userPhoto,
        'receiver_uid': leaderUid, // Takım liderine gönder
        'sender_team_id': teamId,
        'team_name': teamName,
        'created_at': Timestamp.now(),
      });

      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.isTurkish 
              ? '✅ $teamName takımına katılma isteği gönderildi' 
              : '✅ Join request sent to $teamName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.errorMsg(e.toString())), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    try {
      // Lowercase ile arama yap (case-insensitive)
      final searchQuery = query.toLowerCase();
      final snapshot = await _firestore
          .collection('users')
          .where('full_name_lowercase', isGreaterThanOrEqualTo: searchQuery)
          .where('full_name_lowercase', isLessThanOrEqualTo: '$searchQuery\uf8ff')
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': data['full_name'] ?? context.read<LanguageProvider>().userLabel,
          'hasTeam': data['current_team_id'] != null,
          'profileImageUrl': data['profile_image_url'],
        };
      }).where((user) => user['uid'] != _auth.currentUser?.uid).toList();
    } catch (e) {
      print('Kullanıcı arama hatası: $e');
      return [];
    }
  }

  Future<void> _sendInvite(String targetUid, String targetName) async {
    try {
      // Gönderen kullanıcının ismini al
      final senderDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      final senderName = senderDoc.data()?['full_name'] ?? 'Bilinmeyen';
      
      await _firestore.collection('notifications').add({
        'receiver_uid': targetUid,
        'sender_uid': _auth.currentUser!.uid,
        'sender_name': senderName,
        'sender_team_id': _currentTeam!.teamId,
        'team_name': _currentTeam!.name,
        'type': 'team_invite',
        'status': 'pending',
        'created_at': Timestamp.now(),
      });

      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.inviteSentTo(targetName)),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.errorMsg(e.toString())), backgroundColor: Colors.red),
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

      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.youLeftTeam)),
      );
    } catch (e) {
      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.errorMsg(e.toString())), backgroundColor: Colors.red),
      );
    }
  }

  String _generateReferralCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (i) => chars[(random + i * 7) % chars.length]).join();
  }
}
