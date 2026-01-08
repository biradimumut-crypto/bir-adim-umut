import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../models/team_model.dart';
import '../../widgets/admin/admin_data_table.dart';

/// Takım yönetimi ekranı
class AdminTeamsScreen extends StatefulWidget {
  const AdminTeamsScreen({super.key});

  @override
  State<AdminTeamsScreen> createState() => _AdminTeamsScreenState();
}

class _AdminTeamsScreenState extends State<AdminTeamsScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  
  List<TeamModel> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    try {
      final teams = await _adminService.getAllTeams();
      if (mounted) {
        setState(() {
          _teams = teams;
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
                'Takım Yönetimi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Toplam ${_teams.length} takım',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
        
        // Arama Barı
        AdminSearchBar(
          controller: _searchController,
          hintText: 'Takım adı ile ara...',
          onChanged: (query) {
            setState(() {});
          },
        ),
        
        // Takım Listesi
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _teams.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Takım bulunamadı', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredTeams.length,
                        itemBuilder: (context, index) {
                          final team = _filteredTeams[index];
                          return _buildTeamCard(team);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  List<TeamModel> get _filteredTeams {
    if (_searchController.text.isEmpty) return _teams;
    return _teams.where((team) =>
        team.name.toLowerCase().contains(_searchController.text.toLowerCase())
    ).toList();
  }

  Widget _buildTeamCard(TeamModel team) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTeamDetails(team),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst kısım
              Row(
                children: [
                  // Takım Avatarı
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: team.logoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(team.logoUrl!, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.groups, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  
                  // Takım Bilgileri
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                team.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                team.referralCode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Aksiyon Butonları
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showTeamDetails(team),
                        icon: const Icon(Icons.visibility, size: 20),
                        tooltip: 'Detayları Gör',
                        color: Colors.blue,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        onPressed: () => _showDeleteConfirmation(team),
                        icon: const Icon(Icons.delete, size: 20),
                        tooltip: 'Takımı Sil',
                        color: Colors.red,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Alt kısım - Info chips
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildInfoChip(
                    Icons.people,
                    '${team.membersCount} üye',
                    Colors.blue,
                  ),
                  _buildInfoChip(
                    Icons.paid,
                    '${team.totalTeamHope.toStringAsFixed(0)} H',
                    Colors.amber,
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

  void _showTeamDetails(TeamModel team) async {
    // Üyelerin username'lerini çek
    final Map<String, String> memberNames = {};
    
    for (var uid in team.memberIds) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          memberNames[uid] = userData?['full_name'] ?? 
                             userData?['display_name'] ?? 
                             userData?['user_name'] ?? 
                             'Anonim';
        } else {
          memberNames[uid] = 'Kullanıcı bulunamadı';
        }
      } catch (e) {
        memberNames[uid] = 'Yüklenemedi';
      }
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.groups, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                team.name,
                style: const TextStyle(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Takım ID', team.teamId),
                _buildDetailRow('Referral Kodu', team.referralCode),
                _buildDetailRow('Lider UID', team.leaderUid),
                _buildDetailRow('Üye Sayısı', '${team.membersCount}'),
                _buildDetailRow('Toplam Hope', '${team.totalTeamHope.toStringAsFixed(2)} Hope'),
                _buildDetailRow('Kuruluş Tarihi', _formatDateTime(team.createdAt)),
                const Divider(),
                const Text(
                  'Üyeler:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...team.memberIds.map((uid) {
                  final userName = memberNames[uid] ?? 'Yükleniyor...';
                  final isLeader = uid == team.leaderUid;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      onTap: () {
                        // UID'yi göster
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(userName),
                            content: SelectableText('UID: $uid'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Tamam'),
                              ),
                            ],
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLeader ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isLeader ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isLeader)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Lider',
                                  style: TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                            const SizedBox(width: 4),
                            const Icon(Icons.touch_app, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
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

  void _showDeleteConfirmation(TeamModel team) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Takımı Sil'),
        content: Text(
          '"${team.name}" takımını silmek istediğinize emin misiniz?\n\n'
          'Bu işlem geri alınamaz ve ${team.membersCount} üye takımsız kalacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _adminService.deleteTeam(team.teamId);
              _loadTeams();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Takım silindi'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  /// Tam sayı formatla - binlik ayırıcı ile
  String _formatNumber(int number) {
    if (number >= 1000) {
      String result = '';
      String numStr = number.toString();
      int count = 0;
      for (int i = numStr.length - 1; i >= 0; i--) {
        count++;
        result = numStr[i] + result;
        if (count % 3 == 0 && i > 0) {
          result = '.' + result;
        }
      }
      return result;
    }
    return number.toString();
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
