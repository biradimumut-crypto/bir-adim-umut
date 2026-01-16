import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/user_model.dart';
import '../../widgets/admin/admin_data_table.dart';

/// Kullanıcı yönetimi ekranı
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<UserModel> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = _searchQuery.isEmpty
          ? await _adminService.getAllUsers()
          : await _adminService.searchUsers(_searchQuery);
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query);
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header - Mobil uyumlu
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kullanıcı Yönetimi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Tüm kullanıcıları görüntüle ve yönet',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
        
        // Arama Barı
        AdminSearchBar(
          controller: _searchController,
          hintText: 'İsim veya email ile ara...',
          onChanged: _onSearch,
          onClear: () => _onSearch(''),
        ),
        
        // Kullanıcı Listesi
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Kullanıcı bulunamadı', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return _buildUserCard(user);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(UserModel user) {
    final isBanned = user.isBanned;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst kısım - Avatar ve bilgiler
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    backgroundImage: user.profileImageUrl != null
                        ? NetworkImage(user.profileImageUrl!)
                        : null,
                    child: user.profileImageUrl == null
                        ? Text(
                            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  
                  // Kullanıcı Bilgileri
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isBanned) ...[
                              const SizedBox(width: 8),
                              StatusBadge.banned(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Aksiyon Butonları
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showUserDetails(user),
                        icon: const Icon(Icons.visibility, size: 20),
                        tooltip: 'Detayları Gör',
                        color: Colors.blue,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        onPressed: () => _showEditBalanceDialog(user),
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Bakiye Düzenle',
                        color: Colors.orange,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        onPressed: () => isBanned
                            ? _unbanUser(user)
                            : _showBanDialog(user),
                        icon: Icon(isBanned ? Icons.lock_open : Icons.block, size: 20),
                        tooltip: isBanned ? 'Banı Kaldır' : 'Banla',
                        color: isBanned ? Colors.green : Colors.red,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        onPressed: () => _showDeleteConfirmDialog(user),
                        icon: const Icon(Icons.delete_forever, size: 20),
                        tooltip: 'Kullanıcıyı Sil',
                        color: Colors.red.shade900,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Alt kısım - Info chips (Wrap ile sarmalayarak overflow önleme)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildInfoChip(
                    Icons.account_balance_wallet,
                    '${user.walletBalanceHope.toStringAsFixed(1)} H',
                    Colors.amber,
                  ),
                  _buildInfoChip(
                    Icons.people,
                    '${user.referralCount} davet',
                    Colors.blue,
                  ),
                  _buildInfoChip(
                    Icons.calendar_today,
                    _formatDate(user.createdAt),
                    Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: user.profileImageUrl != null
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? Text(user.fullName[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(user.fullName)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('UID', user.uid),
                _buildDetailRow('Email', user.email),
                _buildDetailRow('Nickname', user.nickname ?? '-'),
                _buildDetailRow('Bakiye', '${user.walletBalanceHope.toStringAsFixed(2)} Hope'),
                _buildDetailRow('Takım ID', user.currentTeamId ?? 'Takımsız'),
                _buildDetailRow('Referral Kodu', user.personalReferralCode ?? '-'),
                _buildDetailRow('Davet Eden', user.referredBy ?? '-'),
                _buildDetailRow('Davet Sayısı', '${user.referralCount}'),
                _buildDetailRow('Bonus Adım', '${user.referralBonusSteps}'),
                _buildDetailRow('Tema', user.themePreference),
                _buildDetailRow('Kayıt Tarihi', _formatDateTime(user.createdAt)),
                _buildDetailRow('Son Sync', 
                    user.lastStepSyncTime != null 
                        ? _formatDateTime(user.lastStepSyncTime!) 
                        : '-'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  void _showBanDialog(UserModel user) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Banla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${user.fullName} kullanıcısını banlamak istediğinize emin misiniz?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Ban Sebebi',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              Navigator.pop(context);
              await _adminService.banUser(user.uid, reasonController.text);
              _loadUsers();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcı banlandı'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Banla'),
          ),
        ],
      ),
    );
  }

  void _unbanUser(UserModel user) async {
    await _adminService.unbanUser(user.uid);
    _loadUsers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ban kaldırıldı'), backgroundColor: Colors.green),
      );
    }
  }

  void _showDeleteConfirmDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 8),
            const Text('Kullanıcıyı Sil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.fullName} kullanıcısını silmek istediğinize emin misiniz?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '⚠️ Bu işlem geri alınamaz!',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  SizedBox(height: 8),
                  Text('Silinecek veriler:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('• Kullanıcı profili'),
                  Text('• Tüm Hope bakiyesi'),
                  Text('• Adım geçmişi'),
                  Text('• Aktivite logları'),
                  Text('• Rozetler'),
                  Text('• Yorumlar'),
                  Text('• Takım üyeliği'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteUser(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kalıcı Olarak Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserModel user) async {
    try {
      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      await _adminService.deleteUser(user.uid, user.fullName);
      
      // Loading kapat
      if (mounted) Navigator.pop(context);
      
      _loadUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} silindi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Loading kapat
      if (mounted) Navigator.pop(context);
      
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

  void _showEditBalanceDialog(UserModel user) {
    final balanceController = TextEditingController(
      text: user.walletBalanceHope.toString(),
    );
    final reasonController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Context'i önceden kaydet
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bakiye Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: balanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Yeni Bakiye (Hope)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Değişiklik Sebebi',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBalance = double.tryParse(balanceController.text);
              if (newBalance != null) {
                Navigator.pop(dialogContext);
                try {
                  await _adminService.updateUserBalance(
                    user.uid,
                    newBalance,
                    reasonController.text,
                  );
                  _loadUsers();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Bakiye güncellendi')),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
