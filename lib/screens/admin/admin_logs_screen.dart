import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

/// Admin işlem logları ekranı
class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  final AdminService _adminService = AdminService();
  
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _adminService.getAdminLogs();
      if (mounted) {
        setState(() {
          _logs = logs;
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
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin İşlem Logları',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Son ${_logs.length} işlem',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadLogs,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Yenile', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
        ),
        
        // Log Listesi
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Henüz işlem kaydı yok', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return _buildLogCard(log);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final action = log['action'] ?? 'unknown';
    final timestamp = log['timestamp']?.toDate() ?? DateTime.now();
    final adminUid = log['admin_uid'] ?? '-';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getActionColor(action).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getActionIcon(action),
            color: _getActionColor(action),
            size: 20,
          ),
        ),
        title: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _getActionTitle(action),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getActionColor(action).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                action,
                style: TextStyle(
                  fontSize: 9,
                  color: _getActionColor(action),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            _buildLogDetails(log),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(timestamp),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          adminUid,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, size: 20),
          onPressed: () => _showLogDetails(log),
        ),
      ),
    );
  }

  Widget _buildLogDetails(Map<String, dynamic> log) {
    final action = log['action'] ?? '';
    
    switch (action) {
      case 'ban_user':
        return Text('Kullanıcı: ${log['target_uid'] ?? '-'}\nSebep: ${log['reason'] ?? '-'}');
      case 'unban_user':
        return Text('Kullanıcı: ${log['target_uid'] ?? '-'}');
      case 'update_balance':
        return Text(
          'Kullanıcı: ${log['target_uid'] ?? '-'}\n'
          '${log['old_balance']?.toStringAsFixed(2) ?? '0'} H → ${log['new_balance']?.toStringAsFixed(2) ?? '0'} H',
        );
      case 'delete_team':
        return Text('Takım: ${log['target_team_id'] ?? '-'}');
      case 'create_charity':
      case 'update_charity':
      case 'delete_charity':
        return Text('ID: ${log['charity_id'] ?? '-'}\nTür: ${log['charity_type'] ?? '-'}');
      case 'create_badge':
      case 'delete_badge':
        return Text('Rozet: ${log['badge_name'] ?? log['badge_id'] ?? '-'}');
      case 'send_broadcast':
        return Text('Başlık: ${log['title'] ?? '-'}');
      case 'mark_donation_transferred':
        final donationId = log['donation_id'] ?? '-';
        final amount = log['amount']?.toStringAsFixed(1) ?? '0';
        final recipientName = log['recipient_name'] ?? log['recipient_id'] ?? '-';
        return Text('Bağış: $amount H\nAlıcı: $recipientName\nID: ${donationId.toString().substring(0, donationId.toString().length > 8 ? 8 : donationId.toString().length)}...');
      case 'unmark_donation_transferred':
        final donationId2 = log['donation_id'] ?? '-';
        final amount2 = log['amount']?.toStringAsFixed(1) ?? '0';
        final recipientName2 = log['recipient_name'] ?? log['recipient_id'] ?? '-';
        return Text('Bağış: $amount2 H\nAlıcı: $recipientName2\nID: ${donationId2.toString().substring(0, donationId2.toString().length > 8 ? 8 : donationId2.toString().length)}...');
      default:
        return const Text('-');
    }
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Detayları'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: log.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          entry.value?.toString() ?? '-',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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

  Color _getActionColor(String action) {
    switch (action) {
      case 'ban_user':
        return Colors.red;
      case 'unban_user':
        return Colors.green;
      case 'update_balance':
        return Colors.amber;
      case 'delete_team':
      case 'delete_charity':
      case 'delete_badge':
        return Colors.red;
      case 'create_charity':
      case 'create_badge':
        return Colors.green;
      case 'update_charity':
        return Colors.blue;
      case 'send_broadcast':
        return Colors.purple;
      case 'mark_donation_transferred':
        return Colors.green;
      case 'unmark_donation_transferred':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'ban_user':
        return Icons.block;
      case 'unban_user':
        return Icons.lock_open;
      case 'update_balance':
        return Icons.account_balance_wallet;
      case 'delete_team':
        return Icons.group_remove;
      case 'create_charity':
        return Icons.add_business;
      case 'update_charity':
        return Icons.edit;
      case 'delete_charity':
        return Icons.delete;
      case 'create_badge':
        return Icons.emoji_events;
      case 'delete_badge':
        return Icons.remove_circle;
      case 'send_broadcast':
        return Icons.campaign;
      case 'mark_donation_transferred':
        return Icons.check_circle;
      case 'unmark_donation_transferred':
        return Icons.cancel;
      default:
        return Icons.history;
    }
  }

  String _getActionTitle(String action) {
    switch (action) {
      case 'ban_user':
        return 'Kullanıcı Banlandı';
      case 'unban_user':
        return 'Ban Kaldırıldı';
      case 'update_balance':
        return 'Bakiye Güncellendi';
      case 'delete_team':
        return 'Takım Silindi';
      case 'create_charity':
        return 'Bağış Alıcısı Oluşturuldu';
      case 'update_charity':
        return 'Bağış Alıcısı Güncellendi';
      case 'delete_charity':
        return 'Bağış Alıcısı Silindi';
      case 'create_badge':
        return 'Rozet Oluşturuldu';
      case 'delete_badge':
        return 'Rozet Silindi';
      case 'send_broadcast':
        return 'Toplu Bildirim Gönderildi';
      case 'mark_donation_transferred':
        return 'Bağış Aktarıldı';
      case 'unmark_donation_transferred':
        return 'Bağış Aktarımı Geri Alındı';
      default:
        return 'İşlem';
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
