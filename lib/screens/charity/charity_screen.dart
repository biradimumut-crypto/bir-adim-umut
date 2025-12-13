import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

/// Bağış Sayfası - Vakıf Kartları
class CharityScreen extends StatefulWidget {
  const CharityScreen({Key? key}) : super(key: key);

  @override
  State<CharityScreen> createState() => _CharityScreenState();
}

class _CharityScreenState extends State<CharityScreen> {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;
  String _searchQuery = '';

  // Vakıflar listesi
  final List<Map<String, dynamic>> _charities = [
    {
      'id': 'tema',
      'name': 'TEMA Vakfı',
      'description': 'Türkiye\'nin doğal varlıklarını koruma vakfı',
      'icon': Icons.eco,
      'color': Colors.green,
      'image': 'assets/tema.png',
    },
    {
      'id': 'losev',
      'name': 'LÖSEV',
      'description': 'Lösemili Çocuklar Sağlık ve Eğitim Vakfı',
      'icon': Icons.favorite,
      'color': Colors.red,
      'image': 'assets/losev.png',
    },
    {
      'id': 'tegv',
      'name': 'TEGV',
      'description': 'Türkiye Eğitim Gönüllüleri Vakfı',
      'icon': Icons.school,
      'color': Colors.blue,
      'image': 'assets/tegv.png',
    },
    {
      'id': 'kizilay',
      'name': 'Türk Kızılay',
      'description': 'İnsani yardım ve kan bağışı kuruluşu',
      'icon': Icons.local_hospital,
      'color': Colors.red[700],
      'image': 'assets/kizilay.png',
    },
    {
      'id': 'darussafaka',
      'name': 'Darüşşafaka',
      'description': 'Yetim ve yoksul çocukların eğitim vakfı',
      'icon': Icons.menu_book,
      'color': Colors.indigo,
      'image': 'assets/darussafaka.png',
    },
    {
      'id': 'koruncuk',
      'name': 'Koruncuk Vakfı',
      'description': 'Korunmaya muhtaç çocuklar için destek',
      'icon': Icons.child_care,
      'color': Colors.orange,
      'image': 'assets/koruncuk.png',
    },
  ];

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

  @override
  Widget build(BuildContext context) {
    // Arama filtreleme
    final filteredCharities = _charities.where((charity) {
      final name = charity['name'].toString().toLowerCase();
      final desc = charity['description'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || desc.contains(query);
    }).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              const Text(
                'Bağış Yap',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Hope puanlarınla vakıflara destek ol!',
                style: TextStyle(color: Colors.grey[600]),
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
                    hintText: 'Vakıf ara...',
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

              // Vakıflar Başlığı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vakıflar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${filteredCharities.length} vakıf',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Vakıf Kartları
              if (filteredCharities.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'Vakıf bulunamadı',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredCharities.length,
                  itemBuilder: (context, index) {
                    return _buildCharityCard(filteredCharities[index]);
                  },
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    double balance = _currentUser?.walletBalanceHope ?? 0;
    bool canDonate = balance >= 5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canDonate 
              ? [Colors.green[500]!, Colors.green[700]!]
              : [Colors.grey[400]!, Colors.grey[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (canDonate ? Colors.green : Colors.grey).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hope Bakiyen',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${balance.toStringAsFixed(2)} H',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  canDonate ? Icons.volunteer_activism : Icons.lock_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
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
                Icon(
                  canDonate ? Icons.check_circle : Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    canDonate
                        ? 'Umut olmaya hazırsın! Bir vakıf seç.'
                        : 'Umut olmak için en az 5 Hope gerekli. Biraz daha adım at!',
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

  Widget _buildCharityCard(Map<String, dynamic> charity) {
    Color cardColor = charity['color'] as Color;
    
    return GestureDetector(
      onTap: () => _showCharityDetails(charity),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Üst kısım - Renkli bant
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Logo/Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    charity['icon'] as IconData,
                    color: cardColor,
                    size: 30,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        charity['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        charity['description'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bağış butonu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleDonation(charity),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cardColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volunteer_activism, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'UMUT OL',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  /// Vakıf detay sayfasını göster
  void _showCharityDetails(Map<String, dynamic> charity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharityDetailPage(
          charity: charity,
          currentUser: _currentUser,
          onDonate: () => _handleDonation(charity),
        ),
      ),
    );
  }

  Future<void> _handleDonation(Map<String, dynamic> charity) async {
    double balance = _currentUser?.walletBalanceHope ?? 0;

    // Bakiye kontrolü - 5 Hope'tan az ise uyarı
    if (balance < 5) {
      _showInsufficientBalanceDialog();
      return;
    }

    // Bağış miktarı seç
    final amount = await _showDonationAmountDialog(balance);
    if (amount == null || amount <= 0) return;

    // Reklam göster
    final adWatched = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DonationAdDialog(),
    );

    if (adWatched != true) return;

    // Bağışı gerçekleştir
    await _processDonation(charity, amount);
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.directions_walk, color: Colors.orange[700], size: 32),
        ),
        title: const Text('Biraz Daha Adım At!'),
        content: const Text(
          'Umut olmak için en az 5 Hope bakiyen olmalı.\n\nAdımlarını dönüştürerek Hope kazanabilirsin!',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<double?> _showDonationAmountDialog(double maxAmount) async {
    double selectedAmount = 5;
    
    return showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Bağış Miktarı'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mevcut bakiye: ${maxAmount.toStringAsFixed(2)} Hope',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              
              // Hazır miktarlar
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [5, 10, 20, 50].map((amount) {
                  bool isSelected = selectedAmount == amount.toDouble();
                  bool isAvailable = amount <= maxAmount;
                  
                  return ChoiceChip(
                    label: Text('$amount H'),
                    selected: isSelected,
                    onSelected: isAvailable 
                        ? (selected) {
                            if (selected) {
                              setDialogState(() => selectedAmount = amount.toDouble());
                            }
                          }
                        : null,
                    selectedColor: Colors.purple[100],
                    disabledColor: Colors.grey[200],
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Seçilen miktar gösterimi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      '${selectedAmount.toStringAsFixed(0)} Hope bağışlanacak',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
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
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedAmount),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Devam Et'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processDonation(Map<String, dynamic> charity, double amount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      // 1. Kullanıcı bakiyesini düş
      batch.update(
        firestore.collection('users').doc(uid),
        {'wallet_balance_hope': FieldValue.increment(-amount)},
      );

      // 2. Activity log ekle
      final logRef = firestore.collection('activity_logs').doc();
      batch.set(logRef, {
        'user_id': uid,
        'activity_type': 'donation',
        'charity_name': charity['name'],
        'charity_id': charity['id'],
        'amount': amount,
        'created_at': Timestamp.now(),
      });

      // 3. Takıma bağışı ekle (varsa)
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

      // Kullanıcı verisini yenile
      await _loadUserData();

      // Başarı mesajı
      if (mounted) {
        _showSuccessDialog(charity['name'], amount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog(String charityName, double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: Colors.green[700], size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tebrikler! 🎉',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '$charityName için\nUMUT OLDUNUZ!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Bağışlanan: ${amount.toStringAsFixed(0)} Hope',
                style: TextStyle(
                  color: Colors.purple[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kalan bakiye: ${(_currentUser?.walletBalanceHope ?? 0).toStringAsFixed(2)} Hope',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Harika!'),
            ),
          ),
        ],
      ),
    );
  }
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
                const Text(
                  'Bağış Reklamı',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                    Icon(Icons.volunteer_activism, size: 48, color: Colors.green[600]),
                    const SizedBox(height: 12),
                    Text(
                      'Reklam izleyerek\nbağışı destekle!',
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
              'Bağış $_countdown saniye sonra tamamlanacak...',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vakıf Detay Sayfası - Aktivite Geçmişi
class CharityDetailPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final Color cardColor = charity['color'] as Color;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(charity['name']),
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
                    charity['icon'] as IconData,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  charity['description'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onDonate();
                  },
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('UMUT OL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: cardColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // Bağış geçmişi başlığı
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.grey[700]),
                const SizedBox(width: 8),
                const Text(
                  'Bağış Geçmişi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Bağış listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activity_logs')
                  .where('activity_type', isEqualTo: 'donation')
                  .where('charity_id', isEqualTo: charity['id'])
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
                        Icon(Icons.volunteer_activism, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz bağış yapılmamış',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'İlk umut sen ol!',
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
                    return _buildDonationItem(donation, cardColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationItem(Map<String, dynamic> donation, Color color) {
    final timestamp = (donation['created_at'] ?? donation['timestamp']) as Timestamp?;
    final dateStr = timestamp != null 
        ? DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate())
        : '';
    final amount = (donation['amount'] as num?)?.toStringAsFixed(1) ?? '0';
    final donorId = donation['user_id'] as String? ?? '';

    // Boş ID kontrolü
    if (donorId.isEmpty) {
      return _buildDonationCard('Anonim', dateStr, amount, color);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(donorId).get(),
      builder: (context, userSnapshot) {
        // Loading state
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildDonationCard('Yükleniyor...', dateStr, amount, color);
        }

        // Hata kontrolü
        if (userSnapshot.hasError) {
          return _buildDonationCard('Kullanıcı', dateStr, amount, color);
        }
        
        String donorName = 'Kullanıcı';
        
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
              // İsmi maskele (örn: Sercan K.)
              final parts = fullName.trim().split(' ');
              if (parts.length > 1) {
                donorName = '${parts.first} ${parts.last[0]}.';
              } else {
                donorName = parts.first;
              }
            }
          }
        }

        return _buildDonationCard(donorName, dateStr, amount, color);
      },
    );
  }

  Widget _buildDonationCard(String donorName, String dateStr, String amount, Color color) {
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
            child: Icon(Icons.favorite, color: color, size: 24),
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
