import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'dart:math' show cos, sin, Random;
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/social_share_service.dart';
import '../../models/user_model.dart';
import '../../models/charity_model.dart';
import '../../providers/language_provider.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../services/interstitial_ad_service.dart';

/// Bağış Sayfası - Vakıf Kartları
class CharityScreen extends StatefulWidget {
  const CharityScreen({Key? key}) : super(key: key);

  @override
  State<CharityScreen> createState() => _CharityScreenState();
}

class _CharityScreenState extends State<CharityScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserModel? _currentUser;
  bool _isLoading = true;
  String _searchQuery = '';
  int _selectedTab = 0; // 0: Vakıflar, 1: Topluluklar, 2: Bireysel

  // Firestore'dan çekilen listeler
  List<CharityModel> _charities = [];
  List<CharityModel> _communities = [];
  List<CharityModel> _individuals = [];

  // 🔄 Real-time user stream
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupUserStream(); // Real-time kullanıcı dinleyicisi
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  /// 🔄 Kullanıcı verilerini real-time dinle
  void _setupUserStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _userSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists) {
        setState(() {
          _currentUser = UserModel.fromMap(snapshot.data()!, uid);
        });
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Kullanıcı verisini yükle
      final user = await _authService.getCurrentUser();
      
      // Firestore'dan tüm aktif vakıf/topluluk/bireyleri çek
      final snapshot = await _firestore
          .collection('charities')
          .where('is_active', isEqualTo: true)
          .get();
      
      final allItems = snapshot.docs
          .map((doc) => CharityModel.fromFirestore(doc))
          .toList();
      
      // Türe göre ayır
      final charities = allItems.where((c) => c.type == RecipientType.charity).toList();
      final communities = allItems.where((c) => c.type == RecipientType.community).toList();
      final individuals = allItems.where((c) => c.type == RecipientType.individual).toList();
      
      if (mounted) {
        setState(() {
          _currentUser = user;
          _charities = charities;
          _communities = communities;
          _individuals = individuals;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Veri yükleme hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    
    // Seçili tab'a göre listeyi al
    List<CharityModel> currentList;
    switch (_selectedTab) {
      case 0:
        currentList = _charities;
        break;
      case 1:
        currentList = _communities;
        break;
      case 2:
        currentList = _individuals;
        break;
      default:
        currentList = _charities;
    }
    
    // Arama filtreleme
    final filteredList = currentList.where((item) {
      final name = item.name.toLowerCase();
      final desc = item.description.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || desc.contains(query);
    }).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Text(
                lang.beHope,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                lang.isTurkish ? 'Hope Bakiyelerin Umut Olsun' : 'Let Your Hope Balance Become Hope',
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),

              const SizedBox(height: 20),

              // Bakiye Kartı
              _buildBalanceCard(),

              const SizedBox(height: 24),

              // Arama Kutusu
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: _selectedTab == 0 
                        ? lang.searchCharityHint 
                        : (_selectedTab == 1 
                            ? (lang.isTurkish ? 'Topluluk ara...' : 'Search community...')
                            : (lang.isTurkish ? 'Birey ara...' : 'Search individual...')),
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Başlık - Tab'a göre değişir
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedTab == 0 
                        ? lang.charitiesTitle 
                        : (_selectedTab == 1 
                            ? (lang.isTurkish ? 'Topluluklar' : 'Communities')
                            : (lang.isTurkish ? 'Bireyler' : 'Individuals')),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _selectedTab == 0 
                        ? lang.charitiesCount(filteredList.length)
                        : (_selectedTab == 1 
                            ? (lang.isTurkish ? '${filteredList.length} topluluk' : '${filteredList.length} communities')
                            : (lang.isTurkish ? '${filteredList.length} birey' : '${filteredList.length} individuals')),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // İçerik - Tüm tab'lar için aynı yapı
              if (filteredList.isEmpty)
                _buildEmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    return _buildCharityCardNew(filteredList[index]);
                  },
                ),

              const SizedBox(height: 8),
              const BannerAdWidget(), // Reklam Alanı
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final lang = context.read<LanguageProvider>();
    String title;
    String subtitle;
    Color color;
    String? iconAsset; // PNG icon path
    
    switch (_selectedTab) {
      case 0:
        iconAsset = 'assets/icons/anasayfa.png';
        title = lang.isTurkish ? 'Yakında!' : 'Coming Soon!';
        subtitle = lang.isTurkish 
            ? 'Vakıflar çok yakında burada olacak.\nUmut olmak için bizi takip edin!' 
            : 'Charities will be here very soon.\nFollow us to become Hope!';
        color = const Color(0xFF6EC6B5);
        break;
      case 1:
        iconAsset = 'assets/icons/takım.png';
        title = lang.isTurkish ? 'Yakında!' : 'Coming Soon!';
        subtitle = lang.isTurkish 
            ? 'Topluluklar çok yakında burada olacak.\nUmut olmak için bizi takip edin!' 
            : 'Communities will be here very soon.\nFollow us to become Hope!';
        color = const Color(0xFFE07A5F);
        break;
      case 2:
        iconAsset = 'assets/icons/Profil.png';
        title = lang.isTurkish ? 'Yakında!' : 'Coming Soon!';
        subtitle = lang.isTurkish 
            ? 'Bireyler çok yakında burada olacak.\nUmut olmak için bizi takip edin!' 
            : 'Individuals will be here very soon.\nFollow us to become Hope!';
        color = const Color(0xFFF2C94C);
        break;
      default:
        iconAsset = null;
        title = lang.isTurkish ? 'Yakında!' : 'Coming Soon!';
        subtitle = '';
        color = Colors.grey;
    }
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: iconAsset != null 
                  ? Image.asset(iconAsset, width: 64, height: 64)
                  : Icon(Icons.search_off, size: 64, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_active_outlined, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(
                    lang.isTurkish ? 'Bildirimlerini Açık Tut' : 'Keep Notifications On',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final lang = context.read<LanguageProvider>();
    double balance = _currentUser?.walletBalanceHope ?? 0;
    bool canDonate = balance >= 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6EC6B5), // Yeşil
            Color(0xFFE07A5F), // Turkuaz
            Color(0xFFF2C94C), // Mor
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE07A5F).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bakiye Label
          Text(
            lang.hopeBalanceLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          // Bakiye + hp logosu
          Row(
            children: [
              Text(
                balance.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Image.asset('assets/hp.png', width: 36, height: 36),
            ],
          ),
          const SizedBox(height: 12),
          // Tab butonları - ayrı satırda
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Vakıflar butonu
                  GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        lang.isTurkish ? 'Vakıflar' : 'Charities',
                        style: TextStyle(
                          color: _selectedTab == 0 ? const Color(0xFF6EC6B5) : Colors.white70,
                          fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  // Topluluklar butonu
                  GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        lang.isTurkish ? 'Topluluklar' : 'Communities',
                        style: TextStyle(
                          color: _selectedTab == 1 ? const Color(0xFFE07A5F) : Colors.white70,
                          fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  // Bireysel butonu
                  GestureDetector(
                    onTap: () => setState(() => _selectedTab = 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedTab == 2 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        lang.isTurkish ? 'Bireysel' : 'Individual',
                        style: TextStyle(
                          color: _selectedTab == 2 ? const Color(0xFFF2C94C) : Colors.white70,
                          fontWeight: _selectedTab == 2 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    canDonate
                        ? lang.readyToBeHope
                        : lang.needMoreHopeForDonation,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Yeni CharityModel için kart widget'ı (Firestore'dan gelen veriler için)
  Widget _buildCharityCardNew(CharityModel charity) {
    final lang = context.read<LanguageProvider>();
    Color cardColor = _getColorForType(charity.type);
    
    return GestureDetector(
      onTap: () => _showCharityDetailsNew(charity),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Üst kısım - Gradient bant
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF6EC6B5),
                    Color(0xFFE07A5F),
                    Color(0xFFF2C94C),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Logo/Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: charity.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              charity.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                _getIconForType(charity.type),
                                color: cardColor,
                                size: 24,
                              ),
                            ),
                          )
                        : Icon(
                            _getIconForType(charity.type),
                            color: cardColor,
                            size: 24,
                          ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Bilgiler
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                charity.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (charity.isVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified, color: Colors.blue, size: 16),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          charity.category != null 
                              ? CharityCategory.values
                                  .firstWhere((c) => c.value == charity.category, orElse: () => CharityCategory.humanitarian)
                                  .displayName
                              : 'Kategori belirtilmemiş',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Umut Ol butonu - Sağ tarafta
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF6EC6B5),
                          Color(0xFFE07A5F),
                          Color(0xFFF2C94C),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _handleDonationNew(charity),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/icons/umut ol buton .png', width: 20, height: 20, fit: BoxFit.contain),
                              const SizedBox(width: 6),
                              Text(
                                lang.beHopeButton,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForType(RecipientType type) {
    switch (type) {
      case RecipientType.charity:
        return const Color(0xFF6EC6B5);
      case RecipientType.community:
        return const Color(0xFFE07A5F);
      case RecipientType.individual:
        return const Color(0xFFF2C94C);
    }
  }

  IconData _getIconForType(RecipientType type) {
    switch (type) {
      case RecipientType.charity:
        return Icons.business;
      case RecipientType.community:
        return Icons.groups;
      case RecipientType.individual:
        return Icons.person;
    }
  }

  /// Yeni CharityModel için detay sayfası
  void _showCharityDetailsNew(CharityModel charity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharityDetailPageNew(
          charity: charity,
          currentUser: _currentUser,
          onDonate: () => _handleDonationNew(charity),
        ),
      ),
    );
  }

  Future<void> _handleDonationNew(CharityModel charity) async {
    double balance = _currentUser?.walletBalanceHope ?? 0;

    // Bakiye kontrolü - 10 Hope'tan az ise uyarı (minimum bağış 10 Hope)
    if (balance < 10) {
      _showInsufficientBalanceDialog();
      return;
    }

    // Bağış miktarı seç
    final amount = await _showDonationAmountDialog(balance);
    if (amount == null || amount <= 0) return;

    // Gerçek Interstitial reklam göster ve sonrasında bağışı işle
    await InterstitialAdService.instance.showAd(
      context: 'donation',
      onAdComplete: () async {
        // Bağışı gerçekleştir
        await _processDonationNew(charity, amount);
      },
    );
  }

  Future<void> _processDonationNew(CharityModel charity, double amount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      // 🔍 İlk bağış kontrolü - Bu kullanıcının bu vakfa ilk bağışı mı?
      final existingDonations = await firestore
          .collection('activity_logs')
          .where('user_id', isEqualTo: uid)
          .where('charity_id', isEqualTo: charity.id)
          .where('activity_type', isEqualTo: 'donation')
          .limit(1)
          .get();
      final isFirstDonation = existingDonations.docs.isEmpty;

      // 1. Kullanıcı bakiyesini düş
      batch.update(
        firestore.collection('users').doc(uid),
        {'wallet_balance_hope': FieldValue.increment(-amount)},
      );

      // 2. Global activity log ekle
      final logRef = firestore.collection('activity_logs').doc();
      final now = DateTime.now();
      final donationMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      batch.set(logRef, {
        'user_id': uid,
        'user_name': _currentUser?.fullName ?? 'Anonim',
        'activity_type': 'donation',
        'action_type': 'donation',
        'recipient_id': charity.id,
        'recipient_name': charity.name,
        'charity_id': charity.id,
        'charity_name': charity.name,
        'charity_logo_url': charity.imageUrl, // Vakıf logosu
        'recipient_type': charity.type.value,
        'amount': amount,
        'hope_amount': amount,
        'donation_month': donationMonth, // Hangi ayın bağışı
        'donation_status': 'pending', // Beklemede - ay sonunda hesaplanacak
        'created_at': Timestamp.now(),
        'timestamp': Timestamp.now(),
      });
      
      // 3. User subcollection activity log ekle (rozet hesaplama için)
      final userLogRef = firestore.collection('users').doc(uid).collection('activity_logs').doc();
      batch.set(userLogRef, {
        'user_id': uid,
        'activity_type': 'donation',
        'action_type': 'donation',
        'target_name': charity.name,
        'charity_name': charity.name,
        'charity_id': charity.id,
        'charity_logo_url': charity.imageUrl, // Vakıf logosu
        'recipient_id': charity.id,
        'recipient_type': charity.type.value,
        'amount': amount,
        'hope_amount': amount,
        'created_at': Timestamp.now(),
        'timestamp': Timestamp.now(),
      });

      // 4. Charity'nin toplam bağışını güncelle (donor_count sadece ilk bağışta artar)
      batch.update(
        firestore.collection('charities').doc(charity.id),
        {
          'collected_amount': FieldValue.increment(amount),
          if (isFirstDonation) 'donor_count': FieldValue.increment(1),
        },
      );

      // 5. Takıma bağışı ekle (varsa)
      if (_currentUser?.currentTeamId != null) {
        final teamMemberRef = firestore
            .collection('teams')
            .doc(_currentUser!.currentTeamId)
            .collection('team_members')
            .doc(uid);

        batch.update(teamMemberRef, {
          'member_total_hope': FieldValue.increment(amount),
        });

        // Takım toplam hope'unu güncelle
        batch.update(
          firestore.collection('teams').doc(_currentUser!.currentTeamId),
          {'total_team_hope': FieldValue.increment(amount)},
        );
      }

      await batch.commit();
      
      // 📊 Kullanıcının toplam bağış istatistiğini güncelle
      await firestore.collection('users').doc(uid).update({
        'lifetime_donated_hope': FieldValue.increment(amount),
        'total_donation_count': FieldValue.increment(1),
      });
      
      // 🎖️ Lifetime bağışı güncelle ve rozet kontrol et
      await BadgeService().updateLifetimeDonations(amount);

      // Kullanıcı ve vakıf/topluluk verilerini yenile
      await _loadData();

      // Başarı mesajı
      if (mounted) {
        await _showSuccessDialog(charity.name, amount);
      }
      
      // Rozet kontrolü
      if (mounted) {
        await _checkNewBadgesAfterDonation();
      }
    } catch (e) {
      if (mounted) {
        final lang = context.read<LanguageProvider>();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
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
                onPressed: () => Navigator.pop(context),
                child: Text(lang.ok),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showInsufficientBalanceDialog() {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            'assets/icons/yonca.png',
            width: 48,
            height: 48,
          ),
        ),
        title: Text(lang.walkMoreTitle),
        content: Text(
          lang.walkMoreDesc,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.isTurkish ? 'Tamam' : 'OK'),
          ),
        ],
      ),
    );
  }

  Future<double?> _showDonationAmountDialog(double maxAmount) async {
    double selectedAmount = 10;
    final lang = context.read<LanguageProvider>();
    
    return showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(lang.donationAmountTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.currentBalanceMsg(maxAmount),
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              
              // Hazır miktarlar
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [10, 20, 30, 40, 50, 100].map((amount) {
                  bool isSelected = selectedAmount == amount.toDouble();
                  bool isAvailable = amount <= maxAmount;
                  
                  return ChoiceChip(
                    label: Text('$amount hp'),
                    selected: isSelected,
                    onSelected: isAvailable 
                        ? (selected) {
                            if (selected) {
                              setDialogState(() => selectedAmount = amount.toDouble());
                            }
                          }
                        : null,
                    selectedColor: const Color(0xFFE8F7F5),
                    disabledColor: Colors.grey[200],
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Seçilen miktar gösterimi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/hp.png', width: 24, height: 24),
                    const SizedBox(width: 8),
                    Text(
                      lang.hopeWillBeDonated(selectedAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE07A5F),
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
              child: Text(lang.cancel),
            ),
            ElevatedButton(
              onPressed: selectedAmount <= maxAmount 
                  ? () => Navigator.pop(context, selectedAmount)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE07A5F),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(selectedAmount <= maxAmount 
                  ? lang.continueBtn 
                  : lang.isTurkish ? 'Yetersiz Bakiye' : 'Insufficient Balance'),
            ),
          ],
        ),
      ),
    );
  }

  /// Bağış sonrası rozet kontrolü
  Future<void> _checkNewBadgesAfterDonation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final badgeService = BadgeService();
    final newBadges = await badgeService.getNewBadges(uid);
    
    if (newBadges.isEmpty) return;
    
    // Her yeni rozet için sırayla dialog göster
    for (int i = 0; i < newBadges.length; i++) {
      final badge = newBadges[i];
      if (!mounted) return;
      
      // Dialog'un kapanmasını bekle
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _buildBadgeDialog(dialogContext, badge),
      );
      
      await badgeService.markBadgeAsSeen(uid, badge.id);
      
      // Birden fazla rozet varsa aralarında kısa bekleme
      if (i < newBadges.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }
  
  /// Rozet kazanıldı dialog'u
  Widget _buildBadgeDialog(BuildContext dialogContext, dynamic badge) {
    final lang = context.read<LanguageProvider>();
    final badgeName = lang.isTurkish ? _getBadgeNameTr(badge.id) : _getBadgeNameEn(badge.id);
    final badgeDescription = lang.isTurkish ? _getBadgeDescriptionTr(badge.id) : _getBadgeDescriptionEn(badge.id);
    final congratsMessage = lang.isTurkish ? _getBadgeCongratulationMessage(badge.id) : _getBadgeCongratulationMessageEn(badge.id);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Rozet görseli (PNG)
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(badge.gradientStart).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: badge.imagePath != null
                ? Image.asset(
                    badge.imagePath!,
                    fit: BoxFit.contain,
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(badge.gradientStart), Color(badge.gradientEnd)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(badge.icon, style: const TextStyle(fontSize: 45)),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Color(badge.gradientStart), Color(badge.gradientEnd)],
            ).createShader(bounds),
            child: Text(
              lang.isTurkish ? 'Tebrikler!' : 'Congratulations!',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Rozet ismi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(badge.gradientStart).withOpacity(0.15),
                  Color(badge.gradientEnd).withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Color(badge.gradientStart).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  lang.isTurkish ? '$badgeName Rozetiniz Açıldı!' : '$badgeName Badge Unlocked!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(badge.gradientStart),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badgeDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tebrik mesajı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              congratsMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Center(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(badge.gradientStart), Color(badge.gradientEnd)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lang.isTurkish ? 'Harika! ' : 'Awesome! ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Image.asset('assets/icons/yonca.png', width: 20, height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// Rozet açıklaması (gereksinim)
  String _getBadgeDescriptionTr(String badgeId) {
    final descriptions = {
      // Adım Rozetleri
      'steps_10k': '10.000 Adım Dönüştürüldü',
      'steps_100k': '100.000 Adım Dönüştürüldü',
      'steps_1m': '1 Milyon Adım Dönüştürüldü',
      'steps_10m': '10 Milyon Adım Dönüştürüldü',
      'steps_100m': '100 Milyon Adım Dönüştürüldü',
      'steps_1b': '1 Milyar Adım Dönüştürüldü',
      // Bağış Rozetleri
      'donation_10': '10 Hope Bağışlandı',
      'donation_100': '100 Hope Bağışlandı',
      'donation_1k': '1.000 Hope Bağışlandı',
      'donation_10k': '10.000 Hope Bağışlandı',
      'donation_100k': '100.000 Hope Bağışlandı',
      'donation_1m': '1 Milyon Hope Bağışlandı',
      // Aktivite Rozetleri
      'streak_first': 'İlk Giriş Yapıldı',
      'streak_7': '7 Gün Seri',
      'streak_30': '30 Gün Seri',
      'streak_90': '90 Gün Seri',
      'streak_180': '180 Gün Seri',
      'streak_365': '365 Gün Seri',
    };
    return descriptions[badgeId] ?? badgeId;
  }
  
  /// Tebrik mesajı
  String _getBadgeCongratulationMessage(String badgeId) {
    final messages = {
      // Adım Rozetleri
      'steps_10k': 'İlk adımını attın! 10.000 adım harika bir başarı! 👟',
      'steps_100k': 'Yürüyüşçü unvanını hak ettin! Adımların umuda dönüşüyor! 🚶',
      'steps_1m': 'Gezgin oldun! 1 milyon adım inanılmaz bir başarı! 🗺️',
      'steps_10m': 'Koşucu seviyesine ulaştın! Azmin örnek olsun! 🏃',
      'steps_100m': 'Maraton unvanı senin! 100 milyon adım efsanevi! 🏅',
      'steps_1b': 'Efsane oldun! 1 milyar adım... Sen bir kahramansın! 🌟',
      // Bağış Rozetleri
      'donation_10': 'İlk umut tohumunu ektin! 10 Hope ile başladın! 🌱',
      'donation_100': 'Yardımsever kalbinle 100 Hope bağışladın! Teşekkürler! 💚',
      'donation_1k': 'Cömert kalbin parlıyor! 1.000 Hope ile umut oldun! 💜',
      'donation_10k': 'Umut Elçisi unvanını kazandın! 10.000 Hope muhteşem! 🕊️',
      'donation_100k': 'Umut Kahramanısın! 100.000 Hope ile hayatlar değiştirdin! 🦸',
      'donation_1m': 'Umut Tanrısı! 1 milyon Hope... Sen bir efsanesin! 👑',
      // Aktivite Rozetleri
      'streak_first': 'Hoş geldin! İlk adımını attın, yolculuk başlıyor! 🎉',
      'streak_7': 'Kararlılığın ortaya çıkıyor! 7 gün üst üste, devam et! 💪',
      'streak_30': 'Sadık bir umut taşıyıcısısın! 30 günlük seri muhteşem! 🌟',
      'streak_90': 'Alışkanlık ustası oldun! 90 gün harika! 🔥',
      'streak_180': 'Adanmışlığın takdire değer! Yarım yıl boyunca buradaydın! 💎',
      'streak_365': 'Bağlılık şampiyonu! Tam bir yıl! Sen gerçek bir kahramansın! 👑',
    };
    return messages[badgeId] ?? 'Harika bir rozet kazandın!';
  }
  
  /// Rozet adını Türkçe olarak al
  String _getBadgeNameTr(String badgeId) {
    final names = {
      // Adım Rozetleri
      'steps_10k': 'İlk Adım',
      'steps_100k': 'Yürüyüşçü',
      'steps_1m': 'Gezgin',
      'steps_10m': 'Koşucu',
      'steps_100m': 'Maraton',
      'steps_1b': 'Efsane',
      // Bağış Rozetleri
      'donation_10': 'Umut Tohumu',
      'donation_100': 'Yardımsever',
      'donation_1k': 'Cömert Kalp',
      'donation_10k': 'Umut Elçisi',
      'donation_100k': 'Umut Kahramanı',
      'donation_1m': 'Umut Tanrısı',
      // Aktivite Rozetleri
      'streak_first': 'Hoşgeldin',
      'streak_7': 'Kararlı',
      'streak_30': 'Sadık',
      'streak_90': 'Alışkanlık',
      'streak_180': 'Adanmış',
      'streak_365': 'Bağlılık',
    };
    return names[badgeId] ?? badgeId;
  }

  /// Rozet adını İngilizce olarak al
  String _getBadgeNameEn(String badgeId) {
    final names = {
      // Step Badges
      'steps_10k': 'First Step',
      'steps_100k': 'Walker',
      'steps_1m': 'Explorer',
      'steps_10m': 'Runner',
      'steps_100m': 'Marathon',
      'steps_1b': 'Legend',
      // Donation Badges
      'donation_10': 'Hope Seed',
      'donation_100': 'Philanthropist',
      'donation_1k': 'Generous Heart',
      'donation_10k': 'Hope Ambassador',
      'donation_100k': 'Hope Hero',
      'donation_1m': 'Hope Legend',
      // Activity Badges
      'streak_first': 'Welcome',
      'streak_7': 'Determined',
      'streak_30': 'Loyal',
      'streak_90': 'Habitual',
      'streak_180': 'Devoted',
      'streak_365': 'Committed',
    };
    return names[badgeId] ?? badgeId;
  }

  /// Rozet açıklaması İngilizce
  String _getBadgeDescriptionEn(String badgeId) {
    final descriptions = {
      // Step Badges
      'steps_10k': '10,000 Steps Converted',
      'steps_100k': '100,000 Steps Converted',
      'steps_1m': '1 Million Steps Converted',
      'steps_10m': '10 Million Steps Converted',
      'steps_100m': '100 Million Steps Converted',
      'steps_1b': '1 Billion Steps Converted',
      // Donation Badges
      'donation_10': '10 Hope Donated',
      'donation_100': '100 Hope Donated',
      'donation_1k': '1,000 Hope Donated',
      'donation_10k': '10,000 Hope Donated',
      'donation_100k': '100,000 Hope Donated',
      'donation_1m': '1 Million Hope Donated',
      // Activity Badges
      'streak_first': 'First Login',
      'streak_7': '7 Day Streak',
      'streak_30': '30 Day Streak',
      'streak_90': '90 Day Streak',
      'streak_180': '180 Day Streak',
      'streak_365': '365 Day Streak',
    };
    return descriptions[badgeId] ?? badgeId;
  }

  /// Tebrik mesajı İngilizce
  String _getBadgeCongratulationMessageEn(String badgeId) {
    final messages = {
      // Step Badges
      'steps_10k': 'You took your first step! 10,000 steps is a great achievement! 👟',
      'steps_100k': 'You earned the Walker title! Your steps are turning into hope! 🚶',
      'steps_1m': 'You became an Explorer! 1 million steps is incredible! 🗺️',
      'steps_10m': 'You reached Runner level! Your perseverance is inspiring! 🏃',
      'steps_100m': 'Marathon title is yours! 100 million steps is legendary! 🏅',
      'steps_1b': 'You became a Legend! 1 billion steps... You are a hero! 🌟',
      // Donation Badges
      'donation_10': 'You planted the first seed of hope! Started with 10 Hope! 🌱',
      'donation_100': 'With your generous heart, you donated 100 Hope! Thank you! 💚',
      'donation_1k': 'Your generous heart shines! You became hope with 1,000 Hope! 💜',
      'donation_10k': 'You earned the Hope Ambassador title! 10,000 Hope is amazing! 🕊️',
      'donation_100k': 'You are a Hope Hero! Changed lives with 100,000 Hope! 🦸',
      'donation_1m': 'Hope Legend! 1 million Hope... You are a legend! 👑',
      // Activity Badges
      'streak_first': 'Welcome! You took your first step, the journey begins! 🎉',
      'streak_7': 'Your determination shows! 7 days in a row, keep going! 💪',
      'streak_30': 'You are a loyal hope carrier! 30 day streak is awesome! 🌟',
      'streak_90': 'You became a habit master! 90 days is amazing! 🔥',
      'streak_180': 'Your dedication is admirable! You were here for half a year! 💎',
      'streak_365': 'Commitment champion! A full year! You are a true hero! 👑',
    };
    return messages[badgeId] ?? 'You earned an amazing badge!';
  }

  Future<void> _showSuccessDialog(String charityName, double amount) async {
    final lang = context.read<LanguageProvider>();
    final GlobalKey shareImageKey = GlobalKey();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Ana içerik
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Paylaşılacak görsel alanı
                  RepaintBoundary(
                    key: shareImageKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Profil resmi
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Parıltı efekti
                                    ...List.generate(8, (index) {
                                      final angle = index * (3.14159 / 4);
                                      return Transform.translate(
                                        offset: Offset(
                                          50 * value * cos(angle),
                                          50 * value * sin(angle),
                                        ),
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFFF2C94C),
                                                const Color(0xFFE07A5F),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      );
                                    }),
                                    // Profil resmi
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF6EC6B5), Color(0xFFE07A5F)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE07A5F).withOpacity(0.4),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(50),
                                        child: _currentUser?.profileImageUrl != null && _currentUser!.profileImageUrl!.isNotEmpty
                                            ? Image.network(
                                                _currentUser!.profileImageUrl!,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    color: const Color(0xFFE8F7F5),
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 50,
                                                      color: Color(0xFFE07A5F),
                                                    ),
                                                  );
                                                },
                                              )
                                            : Container(
                                                color: const Color(0xFFE8F7F5),
                                                child: const Icon(
                                                  Icons.person,
                                                  size: 50,
                                                  color: Color(0xFFE07A5F),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Tebrikler yazısı (emojisiz)
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
                            ).createShader(bounds),
                            child: Text(
                              lang.isTurkish ? 'Tebrikler!' : 'Congratulations!',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Kullanıcı adı
                          Text(
                            _currentUser?.fullName ?? (lang.isTurkish ? 'Kullanıcı' : 'User'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Umut Oldunuz (emojisiz)
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
                            ).createShader(bounds),
                            child: Text(
                              lang.youBecameHope,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Vakıf adı
                          Text(
                            charityName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Bağış miktarı
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [const Color(0xFFE8F7F5), const Color(0xFFFFF0ED)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/hp.png', width: 24, height: 24),
                                const SizedBox(width: 8),
                                Text(
                                  '${amount.toStringAsFixed(0)} Hope',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFE07A5F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lang.isTurkish ? 'Bir Adım Umut' : 'OneHopeStep',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.remainingBalance(_currentUser?.walletBalanceHope ?? 0),
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Paylaşım butonları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildShareButton(
                        icon: FontAwesomeIcons.whatsapp,
                        color: const Color(0xFF25D366),
                    onTap: () async {
                      final imageData = await SocialShareService().captureWidget(shareImageKey);
                      await SocialShareService().shareToWhatsApp(imageData: imageData);
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildShareButton(
                    icon: FontAwesomeIcons.instagram,
                    color: const Color(0xFFE4405F),
                    onTap: () async {
                      final imageData = await SocialShareService().captureWidget(shareImageKey);
                      await SocialShareService().shareToInstagram(imageData: imageData);
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildShareButton(
                    icon: FontAwesomeIcons.facebookF,
                    color: const Color(0xFF1877F2),
                    onTap: () async {
                      final imageData = await SocialShareService().captureWidget(shareImageKey);
                      await SocialShareService().shareToFacebook(imageData: imageData);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Buton
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE07A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lang.awesome,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.asset('assets/icons/yonca.png', width: 20, height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Sol konfeti animasyonu
        Positioned(
          left: -50,
          top: -50,
          bottom: -50,
          child: _ConfettiAnimation(isLeft: true),
        ),
        // Sağ konfeti animasyonu
        Positioned(
          right: -50,
          top: -50,
          bottom: -50,
          child: _ConfettiAnimation(isLeft: false),
        ),
          ],
        ),
      ),
    );
  }

  /// Paylaşım butonu oluştur
  Widget _buildShareButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: FaIcon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

/// Tam ekran konfeti animasyonu widget'ı
class _ConfettiAnimation extends StatefulWidget {
  final bool isLeft;
  const _ConfettiAnimation({required this.isLeft});

  @override
  State<_ConfettiAnimation> createState() => _ConfettiAnimationState();
}

class _ConfettiAnimationState extends State<_ConfettiAnimation>
    with TickerProviderStateMixin {
  late List<_ConfettiPiece> _confettiPieces;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    // Çok daha fazla konfeti parçası oluştur - her yerden gelsin
    final random = Random();
    _confettiPieces = List.generate(50, (index) {
      // Farklı yönlerden gelen konfetiler
      final direction = index % 4; // 0: yukarı, 1: aşağı, 2: sol, 3: sağ
      double startX, startY, endX, endY;
      
      if (widget.isLeft) {
        switch (direction) {
          case 0: // Yukarıdan
            startX = random.nextDouble() * 150 - 50;
            startY = -50;
            endX = startX + (random.nextDouble() * 100 - 50);
            endY = random.nextDouble() * 500 + 200;
            break;
          case 1: // Aşağıdan
            startX = random.nextDouble() * 150 - 50;
            startY = 600;
            endX = startX + (random.nextDouble() * 100 - 50);
            endY = random.nextDouble() * 300;
            break;
          case 2: // Soldan
            startX = -80;
            startY = random.nextDouble() * 400;
            endX = random.nextDouble() * 200 + 50;
            endY = startY + (random.nextDouble() * 200 - 100);
            break;
          default: // Ortadan dağılan
            startX = random.nextDouble() * 100;
            startY = random.nextDouble() * 200 + 100;
            endX = startX + (random.nextDouble() * 150 - 75);
            endY = startY + (random.nextDouble() * 300);
        }
      } else {
        switch (direction) {
          case 0: // Yukarıdan
            startX = random.nextDouble() * 150 - 100;
            startY = -50;
            endX = startX + (random.nextDouble() * 100 - 50);
            endY = random.nextDouble() * 500 + 200;
            break;
          case 1: // Aşağıdan
            startX = random.nextDouble() * 150 - 100;
            startY = 600;
            endX = startX + (random.nextDouble() * 100 - 50);
            endY = random.nextDouble() * 300;
            break;
          case 2: // Sağdan
            startX = 80;
            startY = random.nextDouble() * 400;
            endX = -(random.nextDouble() * 200 + 50);
            endY = startY + (random.nextDouble() * 200 - 100);
            break;
          default: // Ortadan dağılan
            startX = -(random.nextDouble() * 100);
            startY = random.nextDouble() * 200 + 100;
            endX = startX - (random.nextDouble() * 150 - 75);
            endY = startY + (random.nextDouble() * 300);
        }
      }
      
      return _ConfettiPiece(
        color: [
          const Color(0xFF6EC6B5),
          const Color(0xFF6EC6B5).withOpacity(0.7),
          const Color(0xFFE07A5F),
          const Color(0xFFE07A5F).withOpacity(0.7),
          const Color(0xFFF2C94C),
          const Color(0xFFF2C94C).withOpacity(0.7),
          const Color(0xFFE8F7F5),
          Colors.orange,
          Colors.orange.shade300,
          Colors.green,
          Colors.green.shade300,
          Colors.red,
          Colors.red.shade300,
          Colors.yellow,
          Colors.white,
          Colors.white70,
        ][random.nextInt(16)],
        startX: startX,
        startY: startY,
        endX: endX,
        endY: endY,
        rotation: random.nextDouble() * 1080,
        size: random.nextDouble() * 10 + 5,
        delay: random.nextDouble() * 0.4,
        shape: random.nextInt(3), // 0: dikdörtgen, 1: kare, 2: daire
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 150,
          height: 600,
          child: Stack(
            clipBehavior: Clip.none,
            children: _confettiPieces.map((piece) {
              final progress = (_controller.value - piece.delay).clamp(0.0, 1.0) / (1.0 - piece.delay);
              if (progress <= 0) return const SizedBox();

              final curvedProgress = Curves.easeOut.transform(progress);
              final x = piece.startX + (piece.endX - piece.startX) * curvedProgress;
              final y = piece.startY + (piece.endY - piece.startY) * curvedProgress;
              // Daha şeffaf konfetiler (0.5 başlangıç, zamanla daha şeffaf)
              final opacity = (0.5 - progress * 0.4).clamp(0.0, 0.5);

              Widget confettiWidget;
              if (piece.shape == 2) {
                // Daire
                confettiWidget = Container(
                  width: piece.size,
                  height: piece.size,
                  decoration: BoxDecoration(
                    color: piece.color.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                );
              } else if (piece.shape == 1) {
                // Kare
                confettiWidget = Container(
                  width: piece.size,
                  height: piece.size,
                  decoration: BoxDecoration(
                    color: piece.color.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              } else {
                // Dikdörtgen (şerit)
                confettiWidget = Container(
                  width: piece.size,
                  height: piece.size * 0.4,
                  decoration: BoxDecoration(
                    color: piece.color.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }

              return Positioned(
                left: widget.isLeft ? x + 75 : null,
                right: widget.isLeft ? null : -x + 75,
                top: y,
                child: Transform.rotate(
                  angle: piece.rotation * progress * 3.14159 / 180,
                  child: Opacity(
                    opacity: opacity,
                    child: confettiWidget,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ConfettiPiece {
  final Color color;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double rotation;
  final double size;
  final double delay;
  final int shape;

  _ConfettiPiece({
    required this.color,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.rotation,
    required this.size,
    required this.delay,
    required this.shape,
  });
}

/// Bağış öncesi reklam dialog
class DonationAdDialog extends StatefulWidget {
  const DonationAdDialog({Key? key}) : super(key: key);

  @override
  State<DonationAdDialog> createState() => _DonationAdDialogState();
}

class _DonationAdDialogState extends State<DonationAdDialog> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        Navigator.pop(context, true);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.donationAdTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_countdown',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium, size: 48, color: Colors.green[600]),
                    const SizedBox(height: 12),
                    Text(
                      lang.watchAdSupportDonation,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: (5 - _countdown) / 5,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(Colors.green[600]),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text(
              lang.adClosingIn(_countdown),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vakıf Detay Sayfası - Aktivite Geçmişi, Sıralama ve Yorumlar
class CharityDetailPage extends StatefulWidget {
  final Map<String, dynamic> charity;
  final UserModel? currentUser;
  final VoidCallback onDonate;
  
  const CharityDetailPage({
    Key? key,
    required this.charity,
    required this.currentUser,
    required this.onDonate,
  }) : super(key: key);

  @override
  State<CharityDetailPage> createState() => _CharityDetailPageState();
}

class _CharityDetailPageState extends State<CharityDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _totalDonationAmount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTotalDonation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTotalDonation() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'donation')
          .where('charity_id', isEqualTo: widget.charity['id'])
          .get();
      
      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['amount'] as num?)?.toDouble() ?? 0;
      }
      
      if (mounted) {
        setState(() {
          _totalDonationAmount = total;
        });
      }
    } catch (e) {
      debugPrint('Toplam bağış yüklenirken hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color cardColor = widget.charity['color'] as Color;
    final lang = context.read<LanguageProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.charity['name']),
        backgroundColor: cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Üst bilgi alanı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    widget.charity['icon'] as IconData,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    String desc;
                    switch (widget.charity['descKey']) {
                      case 'tema': desc = lang.temaDesc; break;
                      case 'losev': desc = lang.losevDesc; break;
                      case 'tegv': desc = lang.tegvDesc; break;
                      case 'kizilay': desc = lang.kizilayDesc; break;
                      case 'darussafaka': desc = lang.darussafakaDesc; break;
                      case 'koruncuk': desc = lang.koruncukDesc; break;
                      default: desc = '';
                    }
                    return Text(
                      desc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Umut Ol butonu - Şeffaf arka plan, gradient çerçeve
                CustomPaint(
                  painter: GradientBorderPainter(
                    borderRadius: 16,
                    strokeWidth: 3,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6EC6B5), // Yeşil
                        Color(0xFFE07A5F), // Turkuaz
                        Color(0xFFF2C94C), // Mor
                      ],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onDonate();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/icons/umut ol buton .png', width: 32, height: 32, fit: BoxFit.contain),
                                const SizedBox(width: 8),
                                Text(lang.beHopeButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${lang.totalDonated}: ${_totalDonationAmount.toStringAsFixed(0)} Hope',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: lang.donationHistory),
                Tab(text: lang.rankingTab),
                Tab(text: lang.commentsTab),
              ],
            ),
          ),

          // Tab içerikleri
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Bağış Geçmişi
                _buildDonationHistoryTab(cardColor),
                // 2. Sıralama
                _buildRankingTab(cardColor),
                // 3. Yorumlar
                _buildCommentsTab(cardColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bağış Geçmişi Tab
  Widget _buildDonationHistoryTab(Color cardColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'donation')
          .where('charity_id', isEqualTo: widget.charity['id'])
          .snapshots(),
      builder: (context, snapshot) {
        final lang = context.read<LanguageProvider>();
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Hata: ${snapshot.error}', style: TextStyle(color: Colors.grey[600])),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  lang.noDonationsYetCharity,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.beFirstHope,
                  style: TextStyle(color: cardColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        // Client-side sıralama
        final donations = snapshot.data!.docs.toList();
        donations.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['created_at'] ?? aData['timestamp']) as Timestamp?;
          final bTime = (bData['created_at'] ?? bData['timestamp']) as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: donations.length,
          itemBuilder: (context, index) {
            final donation = donations[index].data() as Map<String, dynamic>;
            return _buildDonationItem(context, donation, cardColor);
          },
        );
      },
    );
  }

  // Sıralama Tab - En çok bağış yapanlar
  Widget _buildRankingTab(Color cardColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activity_logs')
          .where('activity_type', isEqualTo: 'donation')
          .where('charity_id', isEqualTo: widget.charity['id'])
          .snapshots(),
      builder: (context, snapshot) {
        final lang = context.read<LanguageProvider>();
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  lang.noRankingsYet,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        // Kullanıcı bazlı toplam bağışları hesapla
        final Map<String, double> userDonations = {};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final userId = data['user_id'] as String? ?? '';
          final amount = (data['amount'] as num?)?.toDouble() ?? 0;
          if (userId.isNotEmpty) {
            userDonations[userId] = (userDonations[userId] ?? 0) + amount;
          }
        }

        // Sırala ve en fazla 10 kişi al
        final sortedUsers = userDonations.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topUsers = sortedUsers.take(10).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: topUsers.length,
          itemBuilder: (context, index) {
            final userId = topUsers[index].key;
            final totalAmount = topUsers[index].value;
            return _buildRankingItem(context, userId, totalAmount, index + 1, cardColor);
          },
        );
      },
    );
  }

  Widget _buildRankingItem(BuildContext context, String userId, double totalAmount, int rank, Color color) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        final lang = context.read<LanguageProvider>();
        
        String userName = lang.user;
        String? photoUrl;
        
        if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null) {
            final fullName = userData['full_name'] as String? ?? lang.user;
            userName = UserModel.maskName(fullName); // İsim maskeleme
            photoUrl = userData['profile_image_url'] as String?;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: rank <= 3 ? _getRankColor(rank).withOpacity(0.3) : Colors.grey[200]!,
              width: rank <= 3 ? 2 : 1,
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
              // Sıralama (madalya veya sayı)
              if (rank <= 3)
                _buildMedal(rank)
              else
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$rank',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              const SizedBox(width: 12),
              // Profil fotoğrafı
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.1),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Icon(Icons.person, color: color, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              // İsim
              Expanded(
                child: Text(
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              // Toplam bağış
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${totalAmount.toStringAsFixed(0)} H',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMedal(int rank) {
    final color = _getRankColor(rank);
    final icon = rank == 1 
        ? Icons.workspace_premium 
        : rank == 2 
            ? Icons.workspace_premium 
            : Icons.workspace_premium;
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.8), color],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFF2C94C); // Altın
      case 2: return const Color(0xFFC0C0C0); // Gümüş
      case 3: return const Color(0xFFCD7F32); // Bronz
      default: return Colors.grey;
    }
  }

  // Yorumlar Tab
  Widget _buildCommentsTab(Color cardColor) {
    final lang = context.read<LanguageProvider>();
    
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('charity_comments')
                .where('charity_id', isEqualTo: widget.charity['id'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Hata: ${snapshot.error}', style: TextStyle(color: Colors.grey[600])),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        lang.noCommentsYet,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.beFirstToComment,
                        style: TextStyle(color: cardColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              // Client-side sıralama
              final comments = snapshot.data!.docs.toList();
              comments.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['created_at'] as Timestamp?;
                final bTime = bData['created_at'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime);
              });
              
              // Max 10 yorum göster
              final displayComments = comments.take(10).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: displayComments.length,
                itemBuilder: (context, index) {
                  final comment = displayComments[index].data() as Map<String, dynamic>;
                  return _buildCommentItem(context, comment, cardColor);
                },
              );
            },
          ),
        ),
        // Yorumunuzu Yazın butonu
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCommentDialog(cardColor),
              icon: const Icon(Icons.edit),
              label: Text(lang.writeYourComment),
              style: ElevatedButton.styleFrom(
                backgroundColor: cardColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentItem(BuildContext context, Map<String, dynamic> comment, Color color) {
    final userId = comment['user_id'] as String? ?? '';
    final commentText = comment['comment'] as String? ?? '';
    final timestamp = comment['created_at'] as Timestamp?;
    final dateStr = timestamp != null 
        ? DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate())
        : '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        final lang = context.read<LanguageProvider>();
        
        String userName = lang.user;
        String? photoUrl;
        
        if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null) {
            final fullName = userData['full_name'] as String? ?? lang.user;
            userName = UserModel.maskName(fullName); // İsim maskeleme
            photoUrl = userData['profile_image_url'] as String?;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profil fotoğrafı (yuvarlak)
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.1),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Icon(Icons.person, color: color, size: 28)
                    : null,
              ),
              const SizedBox(width: 12),
              // Sağ taraf - İsim, yorum, tarih
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      commentText,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCommentDialog(Color color) {
    final TextEditingController commentController = TextEditingController();
    final lang = context.read<LanguageProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(lang.writeYourComment),
        content: TextField(
          controller: commentController,
          maxLines: 4,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: lang.commentHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (commentController.text.trim().isEmpty) return;
              
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId == null) return;

              // Dialog'u kapat
              Navigator.pop(context);

              try {
                // Yorumu ekle
                await FirebaseFirestore.instance.collection('charity_comments').add({
                  'charity_id': widget.charity['id'],
                  'user_id': userId,
                  'comment': commentController.text.trim(),
                  'created_at': Timestamp.now(),
                });

                // 10'dan fazla yorum varsa en eskisini sil
                final comments = await FirebaseFirestore.instance
                    .collection('charity_comments')
                    .where('charity_id', isEqualTo: widget.charity['id'])
                    .get();

                if (comments.docs.length > 10) {
                  // Sırala ve en eskileri bul
                  final sortedDocs = comments.docs.toList();
                  sortedDocs.sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();
                    final aTime = aData['created_at'] as Timestamp?;
                    final bTime = bData['created_at'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });
                  
                  // En eski yorumları sil
                  for (int i = 10; i < sortedDocs.length; i++) {
                    await sortedDocs[i].reference.delete();
                  }
                }

                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      icon: Icon(Icons.check_circle, color: Colors.green, size: 48),
                      title: Text(lang.isTurkish ? 'Başarılı' : 'Success'),
                      content: Text(lang.commentSent),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(lang.ok),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Yorum gönderme hatası: $e');
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
                      content: Text('${lang.commentError}: $e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(lang.ok),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(lang.send),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationItem(BuildContext context, Map<String, dynamic> donation, Color color) {
    final timestamp = (donation['created_at'] ?? donation['timestamp']) as Timestamp?;
    final dateStr = timestamp != null 
        ? DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate())
        : '';
    final amount = (donation['amount'] as num?)?.toStringAsFixed(1) ?? '0';
    final donorId = donation['user_id'] as String? ?? '';

    // Boş ID kontrolü
    if (donorId.isEmpty) {
      final lang = context.read<LanguageProvider>();
      return _buildDonationCard(lang.anonymous, dateStr, amount, color, null);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(donorId).get(),
      builder: (context, userSnapshot) {
        final lang = context.read<LanguageProvider>();
        // Loading state
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildDonationCard(lang.loadingText, dateStr, amount, color, null);
        }

        // Hata kontrolü
        if (userSnapshot.hasError) {
          return _buildDonationCard(lang.user, dateStr, amount, color, null);
        }
        
        String donorName = lang.user;
        
        if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          
          if (userData != null) {
            // Önce full_name dene
            String? fullName = userData['full_name'] as String?;
            
            // full_name yoksa veya boşsa email'den isim çıkar
            if (fullName == null || fullName.isEmpty) {
              final email = userData['email'] as String?;
              if (email != null && email.contains('@')) {
                // email'den @ öncesini al ve ilk harfi büyük yap
                final emailName = email.split('@').first;
                donorName = '${emailName[0].toUpperCase()}${emailName.substring(1)}';
                // Çok uzunsa kısalt
                if (donorName.length > 15) {
                  donorName = '${donorName.substring(0, 12)}...';
                }
              }
            } else {
              // İsmi maskele (Se** Se** Ka** formatı)
              donorName = UserModel.maskName(fullName);
            }
          }
        }

        // Profil fotoğrafı ile birlikte kart oluştur
        String? photoUrl;
        if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          photoUrl = userData?['profile_image_url'] as String?;
        }
        
        return _buildDonationCard(donorName, dateStr, amount, color, photoUrl);
      },
    );
  }

  Widget _buildDonationCard(String donorName, String dateStr, String amount, Color color, String? photoUrl) {
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
          // Profil fotoğrafı (bagis.png yerine)
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.1),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(
                    donorName.isNotEmpty ? donorName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donorName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$amount H',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient çerçeve çizen CustomPainter
/// Sadece border çizer, arka plan şeffaf kalır
class GradientBorderPainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;
  final Gradient gradient;

  GradientBorderPainter({
    required this.borderRadius,
    required this.strokeWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CharityModel için yeni detay sayfası (Firestore'dan gelen veriler için)
class CharityDetailPageNew extends StatefulWidget {
  final CharityModel charity;
  final UserModel? currentUser;
  final VoidCallback onDonate;
  
  const CharityDetailPageNew({
    Key? key,
    required this.charity,
    required this.currentUser,
    required this.onDonate,
  }) : super(key: key);

  @override
  State<CharityDetailPageNew> createState() => _CharityDetailPageNewState();
}

class _CharityDetailPageNewState extends State<CharityDetailPageNew> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  
  // Gradient renkleri - 4 tab için
  static const List<Color> _tabColors = [
    Color(0xFF6EC6B5),  // Açıklama - Yeşil/Turkuaz
    Color(0xFF8DB89A),  // Hareketler - Yeşil-Turuncu arası
    Color(0xFFE07A5F),  // Sıralama - Turuncu/Mercan
    Color(0xFFF2C94C),  // Yorumlar - Sarı
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color get _cardColor {
    switch (widget.charity.type) {
      case RecipientType.charity:
        return const Color(0xFF6EC6B5);
      case RecipientType.community:
        return const Color(0xFFE07A5F);
      case RecipientType.individual:
        return const Color(0xFFF2C94C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Logo - AppBar'da küçük göster
            if (widget.charity.imageUrl != null && widget.charity.imageUrl!.isNotEmpty)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.charity.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      _getIconForType(widget.charity.type),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Text(
                widget.charity.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Banner/Kapak Fotoğrafı Alanı
          Container(
            width: double.infinity,
            height: widget.charity.bannerUrl != null && widget.charity.bannerUrl!.isNotEmpty ? 180 : 100,
            decoration: BoxDecoration(
              color: _cardColor,
              image: widget.charity.bannerUrl != null && widget.charity.bannerUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(widget.charity.bannerUrl!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.2),
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            child: Stack(
              children: [
                // Progress ve toplam bilgisi
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Column(
                    children: [
                      if (widget.charity.targetAmount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${widget.charity.collectedAmount.toStringAsFixed(0)} Hope',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Hedef: ${widget.charity.targetAmount.toStringAsFixed(0)} Hope',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (widget.charity.collectedAmount / widget.charity.targetAmount).clamp(0.0, 1.0),
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Umut Ol Butonu - Yatay tam genişlik
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF6EC6B5),
                    Color(0xFFE07A5F),
                    Color(0xFFF2C94C),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE07A5F).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDonate();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/icons/umut ol buton .png', width: 28, height: 28, fit: BoxFit.contain),
                        const SizedBox(width: 10),
                        Text(lang.beHopeButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Tab Bar - Gradient renkli
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _tabColors[_currentTabIndex],
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs: [
                Tab(text: lang.isTurkish ? 'Açıklama' : 'About'),
                Tab(text: lang.donationHistory),
                Tab(text: lang.rankingTab),
                Tab(text: lang.commentsTab),
              ],
            ),
          ),

          // Tab içerikleri
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDescriptionTab(),
                _buildDonationHistoryTab(),
                _buildRankingTab(),
                _buildCommentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Açıklama tab'ı - yeni eklenen
  Widget _buildDescriptionTab() {
    final lang = context.read<LanguageProvider>();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Açıklama
          Text(
            lang.isTurkish ? 'Hakkında' : 'About',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.charity.description,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 15,
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // İletişim bilgileri
          if (widget.charity.contactEmail != null || 
              widget.charity.contactPhone != null || 
              widget.charity.website != null) ...[
            Text(
              lang.isTurkish ? 'İletişim' : 'Contact',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            if (widget.charity.contactEmail != null)
              _buildContactRow(Icons.email, widget.charity.contactEmail!),
            if (widget.charity.contactPhone != null)
              _buildContactRow(Icons.phone, widget.charity.contactPhone!),
            if (widget.charity.website != null)
              _buildContactRow(Icons.language, widget.charity.website!),
          ],
          
          const SizedBox(height: 24),
          
          // İstatistikler
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    Icons.people,
                    '${widget.charity.donorCount}',
                    lang.isTurkish ? 'Bağışçı' : 'Donors',
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: _buildStatItem(
                    Icons.favorite,
                    '${widget.charity.collectedAmount.toStringAsFixed(0)}',
                    'Hope',
                  ),
                ),
                if (widget.charity.targetAmount > 0) ...[
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Expanded(
                    child: _buildStatItem(
                      Icons.flag,
                      '%${((widget.charity.collectedAmount / widget.charity.targetAmount) * 100).toStringAsFixed(0)}',
                      lang.isTurkish ? 'Tamamlandı' : 'Completed',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'education':
        return context.read<LanguageProvider>().isTurkish ? 'Eğitim' : 'Education';
      case 'health':
        return context.read<LanguageProvider>().isTurkish ? 'Sağlık' : 'Health';
      case 'animals':
        return context.read<LanguageProvider>().isTurkish ? 'Hayvanlar' : 'Animals';
      case 'environment':
        return context.read<LanguageProvider>().isTurkish ? 'Çevre' : 'Environment';
      case 'humanitarian':
        return context.read<LanguageProvider>().isTurkish ? 'İnsani Yardım' : 'Humanitarian';
      case 'accessibility':
        return context.read<LanguageProvider>().isTurkish ? 'Erişilebilirlik' : 'Accessibility';
      default:
        return category;
    }
  }
  
  Widget _buildContactRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _cardColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: _cardColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: _cardColor, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
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

  IconData _getIconForType(RecipientType type) {
    switch (type) {
      case RecipientType.charity:
        return Icons.business;
      case RecipientType.community:
        return Icons.groups;
      case RecipientType.individual:
        return Icons.person;
    }
  }

  Widget _buildDonationHistoryTab() {
    // Hem yeni format (activity_type) hem eski format (action_type) destekle
    // Firestore OR query desteklemediği için iki ayrı stream kullanıyoruz
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _getCombinedDonationStream(),
      builder: (context, snapshot) {
        final lang = context.read<LanguageProvider>();
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  lang.noDonationsYetCharity,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final data = snapshot.data![index].data() as Map<String, dynamic>;
            return _buildDonationItem(data);
          },
        );
      },
    );
  }
  
  Stream<List<QueryDocumentSnapshot>> _getCombinedDonationStream() {
    final charityId = widget.charity.id;
    
    // İki farklı sorguyu birleştir
    final stream1 = FirebaseFirestore.instance
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation')
        .where('recipient_id', isEqualTo: charityId)
        .snapshots();
    
    final stream2 = FirebaseFirestore.instance
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation')
        .where('charity_id', isEqualTo: charityId)
        .snapshots();
    
    final stream3 = FirebaseFirestore.instance
        .collection('activity_logs')
        .where('action_type', isEqualTo: 'donation')
        .where('recipient_id', isEqualTo: charityId)
        .snapshots();
    
    // Stream'leri birleştir
    return stream1.asyncMap((snap1) async {
      final snap2 = await stream2.first;
      final snap3 = await stream3.first;
      
      final allDocs = <String, QueryDocumentSnapshot>{};
      for (var doc in snap1.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in snap2.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in snap3.docs) {
        allDocs[doc.id] = doc;
      }
      
      // Tarihe göre sırala
      final sorted = allDocs.values.toList();
      sorted.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aTime = (aData['created_at'] ?? aData['timestamp']) as Timestamp?;
        final bTime = (bData['created_at'] ?? bData['timestamp']) as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      
      return sorted.take(50).toList();
    });
  }

  Widget _buildDonationItem(Map<String, dynamic> data) {
    final userId = data['user_id'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final timestamp = (data['created_at'] ?? data['timestamp']) as Timestamp?;
    final dateStr = timestamp != null 
        ? DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate())
        : '';

    // Güncel ismi users collection'dan çek
    return FutureBuilder<DocumentSnapshot>(
      future: userId.isNotEmpty 
          ? FirebaseFirestore.instance.collection('users').doc(userId).get()
          : Future.value(null),
      builder: (context, snapshot) {
        String userName = data['user_name'] as String? ?? 'Anonim';
        
        // Güncel ismi al
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          userName = userData?['full_name'] ?? userName;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 5,
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _cardColor.withOpacity(0.1),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _cardColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      UserModel.maskName(userName),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _cardColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${amount.toStringAsFixed(0)} H',
                  style: TextStyle(
                    color: _cardColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<List<QueryDocumentSnapshot>> _getCombinedDonationsForRanking() async {
    final charityId = widget.charity.id;
    
    final snap1 = await FirebaseFirestore.instance
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation')
        .where('recipient_id', isEqualTo: charityId)
        .get();
    
    final snap2 = await FirebaseFirestore.instance
        .collection('activity_logs')
        .where('activity_type', isEqualTo: 'donation')
        .where('charity_id', isEqualTo: charityId)
        .get();
    
    final snap3 = await FirebaseFirestore.instance
        .collection('activity_logs')
        .where('action_type', isEqualTo: 'donation')
        .where('recipient_id', isEqualTo: charityId)
        .get();
    
    final allDocs = <String, QueryDocumentSnapshot>{};
    for (var doc in snap1.docs) {
      allDocs[doc.id] = doc;
    }
    for (var doc in snap2.docs) {
      allDocs[doc.id] = doc;
    }
    for (var doc in snap3.docs) {
      allDocs[doc.id] = doc;
    }
    
    return allDocs.values.toList();
  }

  Widget _buildRankingTab() {
    final lang = context.read<LanguageProvider>();
    
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _getCombinedDonationsForRanking(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  lang.noRankingsYet,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        // Kullanıcı bazlı toplam
        final Map<String, double> userDonations = {};
        
        for (var doc in snapshot.data!) {
          final data = doc.data() as Map<String, dynamic>;
          final userId = data['user_id'] as String? ?? '';
          final amount = (data['amount'] as num?)?.toDouble() ?? 0;
          
          if (userId.isNotEmpty) {
            userDonations[userId] = (userDonations[userId] ?? 0) + amount;
          }
        }

        final sortedUsers = userDonations.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topUsers = sortedUsers.take(10).toList();

        // Güncel kullanıcı isimlerini toplu olarak çek
        return FutureBuilder<Map<String, String>>(
          future: _fetchUserNames(topUsers.map((e) => e.key).toList()),
          builder: (context, namesSnapshot) {
            final userNames = namesSnapshot.data ?? {};

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: topUsers.length,
              itemBuilder: (context, index) {
                final userId = topUsers[index].key;
                final totalAmount = topUsers[index].value;
                final userName = userNames[userId] ?? 'Anonim';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: index < 3 ? _getRankColor(index + 1).withOpacity(0.3) : Colors.grey[200]!,
                      width: index < 3 ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Sıra
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: index < 3 ? _getRankColor(index + 1) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: index < 3
                              ? const Icon(Icons.workspace_premium, color: Colors.white, size: 20)
                              : Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          UserModel.maskName(userName),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _cardColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${totalAmount.toStringAsFixed(0)} H',
                          style: TextStyle(color: _cardColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Kullanıcı ID'lerinden güncel isimleri toplu olarak çeker
  Future<Map<String, String>> _fetchUserNames(List<String> userIds) async {
    final Map<String, String> names = {};
    if (userIds.isEmpty) return names;
    
    // Firestore'da whereIn max 10 eleman alır, zaten 10 ile sınırladık
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds)
        .get();
    
    for (var doc in snapshot.docs) {
      names[doc.id] = doc.data()['full_name'] ?? 'Anonim';
    }
    
    return names;
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFF2C94C);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      default: return Colors.grey;
    }
  }

  Widget _buildCommentsTab() {
    final lang = context.read<LanguageProvider>();
    
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('charity_comments')
                .where('charity_id', isEqualTo: widget.charity.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        lang.noCommentsYet,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.beFirstToComment,
                        style: TextStyle(color: _cardColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              // Client-side sıralama
              final comments = snapshot.data!.docs.toList();
              comments.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['created_at'] as Timestamp?;
                final bTime = bData['created_at'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime);
              });
              
              final displayComments = comments.take(10).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: displayComments.length,
                itemBuilder: (context, index) {
                  final comment = displayComments[index].data() as Map<String, dynamic>;
                  return _buildCommentItemNew(comment);
                },
              );
            },
          ),
        ),
        // Yorum yaz butonu
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCommentDialogNew(),
              icon: const Icon(Icons.edit),
              label: Text(lang.writeYourComment),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cardColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentItemNew(Map<String, dynamic> comment) {
    final userId = comment['user_id'] as String? ?? '';
    final commentText = comment['comment'] as String? ?? '';
    final timestamp = comment['created_at'] as Timestamp?;
    final dateStr = timestamp != null 
        ? DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate())
        : '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        String userName = 'Anonim';
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          userName = userData['display_name'] ?? userData['full_name'] ?? 'Anonim';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _cardColor.withOpacity(0.1),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                      style: TextStyle(fontWeight: FontWeight.bold, color: _cardColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          UserModel.maskName(userName),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                commentText,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCommentDialogNew() {
    final commentController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    final lang = context.read<LanguageProvider>();
    
    if (user == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              Text(lang.isTurkish ? 'Uyarı' : 'Warning'),
            ],
          ),
          content: Text(lang.pleaseLogin),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.ok),
            ),
          ],
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.writeYourComment,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: lang.commentHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final text = commentController.text.trim();
                  if (text.isEmpty) return;
                  
                  try {
                    await FirebaseFirestore.instance.collection('charity_comments').add({
                      'charity_id': widget.charity.id,
                      'user_id': user.uid,
                      'comment': text,
                      'created_at': Timestamp.now(),
                    });
                    
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        icon: Icon(Icons.check_circle, color: Colors.green, size: 48),
                        title: Text(lang.isTurkish ? 'Başarılı' : 'Success'),
                        content: Text(lang.commentAdded),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(lang.ok),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
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
                        content: Text('$e'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(lang.ok),
                          ),
                        ],
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cardColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(lang.send, style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}