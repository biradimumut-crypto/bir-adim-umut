import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../providers/language_provider.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../services/local_notification_service.dart';

/// Leaderboard Ekranı - 3 Tab: Adım Şampiyonları, Umut Olanlar, Takımlar
/// Her kategoride sadece ilk 3 gösterilir (Altın, Gümüş, Bronz)
/// Tüm sıralamalar AYLIK ve DİNAMİK - her ay başında sıfırlanır
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Veriler
  List<Map<String, dynamic>> _converters = [];
  List<Map<String, dynamic>> _donators = [];
  List<Map<String, dynamic>> _teams = [];
  
  bool _isLoadingConverters = true;
  bool _isLoadingDonators = true;
  bool _isLoadingTeams = true;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
    
    // Her 30 saniyede bir yenile (dinamik güncelleme)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadAllData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Uygulama arka plandan döndüğünde otomatik yenile
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 LeaderboardScreen resumed - refreshing data...');
      _loadAllData();
    }
  }

  /// Tüm verileri yükle
  Future<void> _loadAllData() async {
    await Future.wait([
      _loadConverters(),
      _loadDonators(),
      _loadTeams(),
    ]);
  }

  /// İsmi maskele: "Ahmet Yılmaz" -> "Ah*** Yı****"
  String _maskName(String name) {
    if (name.isEmpty) return '***';
    
    final parts = name.split(' ');
    return parts.map((part) {
      if (part.length <= 2) return part;
      return '${part.substring(0, 2)}${'*' * (part.length - 2)}';
    }).join(' ');
  }

  /// Bu ayın başlangıç tarihini al
  DateTime _getMonthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Tab 1: Adım Şampiyonları - Bu ay en çok GERÇEK adım dönüştürenler
  /// Sadece: step_conversion, step_conversion_2x, carryover_conversion
  /// Dahil DEĞİL: bonus_conversion (referral), reward_ad_bonus, leaderboard_bonus
  Future<void> _loadConverters() async {
    if (!mounted) return;
    setState(() => _isLoadingConverters = true);

    try {
      final monthStart = _getMonthStart();
      
      // Sadece gerçek adım dönüşümlerini say (bonus hariç)
      final validActivityTypes = [
        'step_conversion',      // Günlük adım dönüşümü
        'step_conversion_2x',   // Progress bar 2x bonus
        'carryover_conversion', // Taşınan adım dönüşümü
      ];
      
      // Kullanıcı başına toplam adım hesapla
      final Map<String, int> userSteps = {};
      
      for (final activityType in validActivityTypes) {
        final logsSnapshot = await _firestore
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
          
          final uid = data['user_id'] ?? '';
          final steps = (data['steps_converted'] ?? 0) as int;
          
          if (uid.isNotEmpty && steps > 0) {
            userSteps[uid] = (userSteps[uid] ?? 0) + steps;
          }
        }
      }
      
      // Kullanıcı isimlerini al
      List<Map<String, dynamic>> userStepsList = [];
      
      for (var entry in userSteps.entries) {
        final uid = entry.key;
        final steps = entry.value;
        
        String userName = 'Kullanıcı';
        String? photoUrl;
        try {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (userDoc.exists) {
            userName = userDoc.data()?['full_name'] ?? 'Kullanıcı';
            photoUrl = userDoc.data()?['profile_image_url'];
          }
        } catch (_) {}
        
        userStepsList.add({
          'uid': uid,
          'name': userName,
          'value': steps,
          'photoUrl': photoUrl,
        });
      }
      
      // Sırala ve ilk 3'ü al
      userStepsList.sort((a, b) => (b['value'] as int).compareTo(a['value'] as int));
      
      // Kullanıcının sıralamasını kontrol et ve bildirim gönder
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null) {
        await _checkStepRankingNotification(userStepsList, currentUid);
      }
      
      if (mounted) {
        setState(() {
          _converters = userStepsList.take(3).toList();
          _isLoadingConverters = false;
        });
      }
    } catch (e) {
      print('Adım şampiyonları yükleme hatası: $e');
      if (mounted) {
        setState(() => _isLoadingConverters = false);
      }
    }
  }

  /// Tab 2: Umut Olanlar - Bu ay en çok bağış yapanlar
  Future<void> _loadDonators() async {
    if (!mounted) return;
    setState(() => _isLoadingDonators = true);

    try {
      final monthStart = _getMonthStart();
      
      // Eski ve yeni formatları destekle
      final logsSnapshot1 = await _firestore
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'donation')
          .get();
      
      final logsSnapshot2 = await _firestore
          .collection('activity_logs')
          .where('action_type', isEqualTo: 'donation')
          .get();
      
      // Birleştir ve duplicate kaldır
      final allDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (var doc in logsSnapshot1.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in logsSnapshot2.docs) {
        allDocs[doc.id] = doc;
      }

      // Kullanıcı başına toplam bağış hesapla
      final Map<String, double> userDonations = {};

      for (var doc in allDocs.values) {
        final data = doc.data();
        
        // Tarih kontrolü - bu ay mı?
        DateTime? logDate;
        if (data['created_at'] != null) {
          logDate = (data['created_at'] as Timestamp).toDate();
        } else if (data['timestamp'] != null) {
          logDate = (data['timestamp'] as Timestamp).toDate();
        }
        
        if (logDate == null || logDate.isBefore(monthStart)) continue;
        
        final uid = data['user_id'] ?? '';
        // Hem amount hem hope_amount kontrol et
        final amount = (data['amount'] ?? data['hope_amount'] ?? 0).toDouble();

        if (uid.isNotEmpty) {
          userDonations[uid] = (userDonations[uid] ?? 0) + amount;
        }
      }

      // Kullanıcı isimlerini al
      List<Map<String, dynamic>> donatorsList = [];
      
      for (var entry in userDonations.entries) {
        final uid = entry.key;
        final amount = entry.value;
        
        // Kullanıcı adını ve fotoğrafını Firestore'dan al
        String userName = 'Kullanıcı';
        String? photoUrl;
        try {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (userDoc.exists) {
            userName = userDoc.data()?['full_name'] ?? 'Kullanıcı';
            photoUrl = userDoc.data()?['profile_image_url'];
          }
        } catch (_) {}
        
        donatorsList.add({
          'uid': uid,
          'name': userName,
          'value': amount,
          'photoUrl': photoUrl,
        });
      }

      // Sırala - eşit puanlarda UID'ye göre sırala (tutarlılık için)
      donatorsList.sort((a, b) {
        final valueDiff = (b['value'] as double).compareTo(a['value'] as double);
        if (valueDiff != 0) return valueDiff;
        return (a['uid'] as String).compareTo(b['uid'] as String);
      });
      
      // Kullanıcının sıralamasını kontrol et ve bildirim gönder
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null) {
        await _checkDonationRankingNotification(donatorsList, currentUid);
      }
      
      if (mounted) {
        setState(() {
          _donators = donatorsList.take(3).toList();
          _isLoadingDonators = false;
        });
      }
    } catch (e) {
      print('Umut olanlar yükleme hatası: $e');
      if (mounted) {
        setState(() => _isLoadingDonators = false);
      }
    }
  }

  /// Tab 3: Takımlar - Bu ayın en çok Hope toplayan takımları
  Future<void> _loadTeams() async {
    if (!mounted) return;
    setState(() => _isLoadingTeams = true);

    try {
      final monthStart = _getMonthStart();
      
      // Bu ayki bağışları takım bazında hesapla
      final logsSnapshot = await _firestore
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'donation')
          .get();

      // Kullanıcının takımını bul ve takım bazında toplam hesapla
      final Map<String, double> teamDonations = {};
      final Map<String, String> teamNames = {};
      final Map<String, int> teamMemberCounts = {};
      final Map<String, String?> teamPhotos = {};

      for (var doc in logsSnapshot.docs) {
        final data = doc.data();
        
        // Tarih kontrolü
        DateTime? logDate;
        if (data['created_at'] != null) {
          logDate = (data['created_at'] as Timestamp).toDate();
        } else if (data['timestamp'] != null) {
          logDate = (data['timestamp'] as Timestamp).toDate();
        }
        
        if (logDate == null || logDate.isBefore(monthStart)) continue;
        
        final uid = data['user_id'] ?? '';
        final amount = (data['amount'] ?? 0).toDouble();

        if (uid.isEmpty) continue;

        // Kullanıcının takımını bul
        try {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (userDoc.exists) {
            final teamId = userDoc.data()?['current_team_id'];
            if (teamId != null && teamId.isNotEmpty) {
              teamDonations[teamId] = (teamDonations[teamId] ?? 0) + amount;
              
              // Takım bilgilerini al (henüz almadıysa)
              if (!teamNames.containsKey(teamId)) {
                final teamDoc = await _firestore.collection('teams').doc(teamId).get();
                if (teamDoc.exists) {
                  teamNames[teamId] = teamDoc.data()?['name'] ?? 'Takım';
                  teamMemberCounts[teamId] = teamDoc.data()?['members_count'] ?? 0;
                  teamPhotos[teamId] = teamDoc.data()?['logo_url'];
                }
              }
            }
          }
        } catch (_) {}
      }

      // Listeye dönüştür
      List<Map<String, dynamic>> teamsList = [];
      
      for (var entry in teamDonations.entries) {
        teamsList.add({
          'uid': entry.key,
          'name': teamNames[entry.key] ?? 'Takım',
          'value': entry.value,
          'membersCount': teamMemberCounts[entry.key] ?? 0,
          'photoUrl': teamPhotos[entry.key],
        });
      }

      // Sırala ve ilk 3'ü al
      teamsList.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
      
      // Kullanıcının takımının sıralamasını kontrol et ve bildirim gönder
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null) {
        await _checkTeamRankingNotification(teamsList, currentUid);
      }
      
      if (mounted) {
        setState(() {
          _teams = teamsList.take(3).toList();
          _isLoadingTeams = false;
        });
      }
    } catch (e) {
      print('Takımlar yükleme hatası: $e');
      if (mounted) {
        setState(() => _isLoadingTeams = false);
      }
    }
  }
  
  /// Adım sıralaması bildirimi kontrol
  Future<void> _checkStepRankingNotification(List<Map<String, dynamic>> rankings, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final notificationService = LocalNotificationService();
    
    // İlk 3'te mi?
    final userRank = rankings.indexWhere((r) => r['uid'] == uid);
    if (userRank >= 0 && userRank < 3) {
      final notifKey = 'step_rank_notif_${userRank + 1}_$today';
      final alreadySent = prefs.getBool(notifKey) ?? false;
      
      if (!alreadySent) {
        await notificationService.showStepRankingNotification(userRank + 1);
        await prefs.setBool(notifKey, true);
      }
    }
  }
  
  /// Bağış sıralaması bildirimi kontrol
  Future<void> _checkDonationRankingNotification(List<Map<String, dynamic>> rankings, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final notificationService = LocalNotificationService();
    
    final userRank = rankings.indexWhere((r) => r['uid'] == uid);
    if (userRank >= 0 && userRank < 3) {
      final notifKey = 'donation_rank_notif_${userRank + 1}_$today';
      final alreadySent = prefs.getBool(notifKey) ?? false;
      
      if (!alreadySent) {
        await notificationService.showDonationRankingNotification(userRank + 1);
        await prefs.setBool(notifKey, true);
      }
    }
  }
  
  /// Takım sıralaması bildirimi kontrol
  Future<void> _checkTeamRankingNotification(List<Map<String, dynamic>> teamRankings, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final notificationService = LocalNotificationService();
    
    // Kullanıcının takımını bul
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final teamId = userDoc.data()?['current_team_id'];
      
      if (teamId == null || teamId.isEmpty) return;
      
      final teamRank = teamRankings.indexWhere((t) => t['uid'] == teamId);
      if (teamRank >= 0 && teamRank < 3) {
        final teamName = teamRankings[teamRank]['name'] ?? 'Takımın';
        final notifKey = 'team_rank_notif_${teamRank + 1}_$today';
        final alreadySent = prefs.getBool(notifKey) ?? false;
        
        if (!alreadySent) {
          await notificationService.showTeamRankingNotification(teamName, teamRank + 1);
          await prefs.setBool(notifKey, true);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadAllData,
        child: Column(
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.leaderboardScreenTitle,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.thisMonthsBest,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                labelColor: const Color(0xFFE07A5F),
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                tabs: [
                  Tab(text: lang.stepChampionsTab),
                  Tab(text: lang.hopeHeroesTab),
                  Tab(text: lang.teamsTab),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildConvertersTab(),
                  _buildDonatorsTab(),
                  _buildTeamsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 1: Adım Şampiyonları
  Widget _buildConvertersTab() {
    final lang = context.read<LanguageProvider>();
    if (_isLoadingConverters) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_converters.isEmpty) {
      return _buildEmptyState(lang.noConvertersYet);
    }

    return _buildPodiumView(
      users: _converters,
      valueLabel: lang.stepsLabel,
      color: const Color(0xFF6EC6B5),
      icon: Icons.directions_walk,
    );
  }

  /// Tab 2: Umut Olanlar
  Widget _buildDonatorsTab() {
    final lang = context.read<LanguageProvider>();
    if (_isLoadingDonators) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_donators.isEmpty) {
      return _buildEmptyState(lang.noDonationsYet);
    }

    return _buildPodiumView(
      users: _donators,
      valueLabel: 'Hope',
      color: const Color(0xFFE07A5F),
      icon: Icons.favorite,
    );
  }

  /// Tab 3: Takımlar
  Widget _buildTeamsTab() {
    final lang = context.read<LanguageProvider>();
    if (_isLoadingTeams) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_teams.isEmpty) {
      return _buildEmptyState(lang.noTeamDonationsYet);
    }

    return _buildTeamPodiumView(_teams);
  }

  /// Podyum görünümü - 3 kişilik
  Widget _buildPodiumView({
    required List<Map<String, dynamic>> users,
    required String valueLabel,
    required Color color,
    required IconData icon,
  }) {
    final lang = context.read<LanguageProvider>();
    final currentUid = _auth.currentUser?.uid;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Podyum
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2. Sıra (Gümüş)
              if (users.length >= 2)
                _buildPodiumItem(
                  rank: 2,
                  name: _maskName(users[1]['name']),
                  value: _formatValue(users[1]['value']),
                  valueLabel: valueLabel,
                  color: Colors.grey[400]!,
                  height: 100,
                  icon: icon,
                  isCurrentUser: users[1]['uid'] == currentUid,
                  photoUrl: users[1]['photoUrl'],
                )
              else
                _buildEmptyPodiumItem(rank: 2, height: 100),
              
              const SizedBox(width: 8),
              
              // 1. Sıra (Altın)
              if (users.isNotEmpty)
                _buildPodiumItem(
                  rank: 1,
                  name: _maskName(users[0]['name']),
                  value: _formatValue(users[0]['value']),
                  valueLabel: valueLabel,
                  color: const Color(0xFFF2C94C),
                  height: 130,
                  icon: icon,
                  isCurrentUser: users[0]['uid'] == currentUid,
                  photoUrl: users[0]['photoUrl'],
                )
              else
                _buildEmptyPodiumItem(rank: 1, height: 130),
              
              const SizedBox(width: 8),
              
              // 3. Sıra (Bronz)
              if (users.length >= 3)
                _buildPodiumItem(
                  rank: 3,
                  name: _maskName(users[2]['name']),
                  value: _formatValue(users[2]['value']),
                  valueLabel: valueLabel,
                  color: Colors.brown[400]!,
                  height: 80,
                  icon: icon,
                  isCurrentUser: users[2]['uid'] == currentUid,
                  photoUrl: users[2]['photoUrl'],
                )
              else
                _buildEmptyPodiumItem(rank: 3, height: 80),
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Ay bilgisi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _getCurrentMonthName(lang),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Açıklama
          Text(
            lang.rankingResetsMonthly,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          
          const SizedBox(height: 16),
          const BannerAdWidget(), // Reklam Alanı
        ],
      ),
    );
  }

  /// Takım podyum görünümü
  Widget _buildTeamPodiumView(List<Map<String, dynamic>> teams) {
    final lang = context.read<LanguageProvider>();
    return FutureBuilder<String?>(
      future: _getCurrentUserTeamId(),
      builder: (context, snapshot) {
        final currentTeamId = snapshot.data;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Podyum
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 2. Sıra
                  if (teams.length >= 2)
                    _buildTeamPodiumItem(
                      rank: 2,
                      name: teams[1]['name'],
                      value: (teams[1]['value'] as num).toDouble(),
                      membersCount: teams[1]['membersCount'] ?? 0,
                      color: Colors.grey[400]!,
                      height: 100,
                      isCurrentTeam: teams[1]['uid'] == currentTeamId,
                      photoUrl: teams[1]['photoUrl'],
                    )
                  else
                    _buildEmptyPodiumItem(rank: 2, height: 100),
                  
                  const SizedBox(width: 8),
                  
                  // 1. Sıra
                  if (teams.isNotEmpty)
                    _buildTeamPodiumItem(
                      rank: 1,
                      name: teams[0]['name'],
                      value: (teams[0]['value'] as num).toDouble(),
                      membersCount: teams[0]['membersCount'] ?? 0,
                      color: const Color(0xFFF2C94C),
                      height: 130,
                      isCurrentTeam: teams[0]['uid'] == currentTeamId,
                      photoUrl: teams[0]['photoUrl'],
                    )
                  else
                    _buildEmptyPodiumItem(rank: 1, height: 130),
                  
                  const SizedBox(width: 8),
                  
                  // 3. Sıra
                  if (teams.length >= 3)
                    _buildTeamPodiumItem(
                      rank: 3,
                      name: teams[2]['name'],
                      value: (teams[2]['value'] as num).toDouble(),
                      membersCount: teams[2]['membersCount'] ?? 0,
                      color: Colors.brown[400]!,
                      height: 80,
                      isCurrentTeam: teams[2]['uid'] == currentTeamId,
                      photoUrl: teams[2]['photoUrl'],
                    )
                  else
                    _buildEmptyPodiumItem(rank: 3, height: 80),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Ay bilgisi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      _getCurrentMonthName(lang),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Açıklama
              Text(
                lang.rankingResetsMonthly,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              
              const SizedBox(height: 16),
              const BannerAdWidget(), // Reklam Alanı
            ],
          ),
        );
      },
    );
  }

  Future<String?> _getCurrentUserTeamId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['current_team_id'];
    } catch (_) {
      return null;
    }
  }

  /// Podyum item widget'ı
  Widget _buildPodiumItem({
    required int rank,
    required String name,
    required String value,
    required String valueLabel,
    required Color color,
    required double height,
    required IconData icon,
    required bool isCurrentUser,
    String? photoUrl,
  }) {
    final medals = ['🥇', '🥈', '🥉'];
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Madalya
        Text(
          medals[rank - 1],
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 4),
        
        // Avatar - Profil fotoğrafı ile
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrentUser ? const Color(0xFF6EC6B5) : color,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: rank == 1 ? 30 : 24,
            backgroundColor: color.withOpacity(0.2),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Icon(
                    Icons.person,
                    size: rank == 1 ? 30 : 24,
                    color: color,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 4),
        
        // İsim
        SizedBox(
          width: 90,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: rank == 1 ? 11 : 10,
              color: isCurrentUser ? const Color(0xFFE07A5F) : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        if (isCurrentUser)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF6EC6B5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Builder(
              builder: (context) {
                final lang = context.read<LanguageProvider>();
                return Text(
                  lang.youIndicator,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        
        const SizedBox(height: 4),
        
        // Podyum kutusu
        Container(
          width: 90,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Takım podyum item
  Widget _buildTeamPodiumItem({
    required int rank,
    required String name,
    required double value,
    required int membersCount,
    required Color color,
    required double height,
    required bool isCurrentTeam,
    String? photoUrl,
  }) {
    final medals = ['🥇', '🥈', '🥉'];
    
    return Column(
      children: [
        // Madalya
        Text(
          medals[rank - 1],
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 4),
        
        // Logo - Takım fotoğrafı ile
        Container(
          width: rank == 1 ? 60 : 50,
          height: rank == 1 ? 60 : 50,
          decoration: BoxDecoration(
            gradient: photoUrl == null 
                ? LinearGradient(
                    colors: [const Color(0xFF6EC6B5), const Color(0xFFE07A5F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrentTeam ? Colors.green : color,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            image: photoUrl != null 
                ? DecorationImage(
                    image: NetworkImage(photoUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: photoUrl == null 
              ? Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'T',
                    style: TextStyle(
                      fontSize: rank == 1 ? 28 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 4),
        
        // Takım ismi
        SizedBox(
          width: 90,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: rank == 1 ? 12 : 10,
              color: isCurrentTeam ? Colors.green[700] : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        if (isCurrentTeam)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Builder(
              builder: (context) {
                final lang = context.read<LanguageProvider>();
                return Text(
                  lang.yourTeamIndicator,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        
        const SizedBox(height: 4),
        
        // Podyum kutusu
        Container(
          width: 90,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: Colors.white, size: 18),
                Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Hope',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 9,
                  ),
                ),
                Builder(
                  builder: (context) {
                    final lang = context.read<LanguageProvider>();
                    return Text(
                      lang.membersUnit(membersCount),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 8,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Boş podyum item
  Widget _buildEmptyPodiumItem({required int rank, required double height}) {
    final medals = ['🥇', '🥈', '🥉'];
    
    return Column(
      children: [
        Text(
          medals[rank - 1],
          style: TextStyle(fontSize: 32, color: Colors.grey[300]),
        ),
        const SizedBox(height: 8),
        CircleAvatar(
          radius: rank == 1 ? 35 : 28,
          backgroundColor: Colors.grey[200],
          child: Icon(
            Icons.person_outline,
            size: rank == 1 ? 35 : 28,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 100,
          child: Builder(
            builder: (context) {
              final lang = context.read<LanguageProvider>();
              return Text(
                lang.emptyPodium,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: rank == 1 ? 13 : 11,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 100,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Center(
            child: Text(
              '?',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Değeri formatla
  String _formatValue(dynamic value) {
    if (value is int) {
      if (value >= 1000) {
        return '${(value / 1000).toStringAsFixed(1)}K';
      }
      return value.toString();
    }
    if (value is double) {
      return value.toStringAsFixed(1);
    }
    return value.toString();
  }

  /// Mevcut ayın adını al
  String _getCurrentMonthName(LanguageProvider lang) {
    final now = DateTime.now();
    return '${lang.getMonthName(now.month)} ${now.year}';
  }

  Widget _buildEmptyState(String message) {
    final lang = context.read<LanguageProvider>();
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                lang.beTheFirst,
                style: TextStyle(
                  color: const Color(0xFF6EC6B5),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              // Ay bilgisi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      _getCurrentMonthName(lang),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
