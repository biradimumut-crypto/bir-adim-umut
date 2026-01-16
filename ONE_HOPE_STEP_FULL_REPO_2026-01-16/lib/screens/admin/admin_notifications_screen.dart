import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';

/// Bildirim yönetimi ekranı - Yinelemeli bildirim + Geçmiş panel
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  
  late TabController _tabController;
  
  bool _isSending = false;
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  
  // Yineleme ayarları
  bool _isRepeating = false;
  String _repeatType = 'daily'; // daily, weekly, monthly
  List<int> _selectedWeekDays = []; // Haftalık için: 1=Pzt, 7=Paz
  int _selectedMonthDay = 1; // Aylık için: 1-31
  
  // Bildirim geçmişi
  List<Map<String, dynamic>> _notificationHistory = [];
  List<Map<String, dynamic>> _scheduledNotifications = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotificationHistory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      // Gönderilmiş bildirimler
      final sentSnapshot = await _firestore
          .collection('broadcast_notifications')
          .orderBy('sent_at', descending: true)
          .limit(50)
          .get();
      
      // Zamanlanmış bildirimler
      final scheduledSnapshot = await _firestore
          .collection('scheduled_notifications')
          .orderBy('scheduled_time', descending: false)
          .get();
      
      if (mounted) {
        setState(() {
          _notificationHistory = sentSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          
          _scheduledNotifications = scheduledSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
      });
    }
  }

  String _formatScheduledDateTime() {
    if (_scheduledDate == null || _scheduledTime == null) return 'Tarih ve saat seçin';
    
    final dateStr = DateFormat('d MMMM yyyy', 'tr_TR').format(_scheduledDate!);
    final timeStr = '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}';
    return '$dateStr - $timeStr';
  }

  String _getRepeatTypeText() {
    switch (_repeatType) {
      case 'daily':
        return 'Her gün';
      case 'weekly':
        if (_selectedWeekDays.isEmpty) return 'Haftalık (gün seçin)';
        final dayNames = _selectedWeekDays.map((d) => _getWeekDayName(d)).join(', ');
        return 'Her hafta: $dayNames';
      case 'monthly':
        return 'Her ayın $_selectedMonthDay. günü';
      default:
        return 'Bilinmiyor';
    }
  }

  String _getWeekDayName(int day) {
    const days = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[day];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header - Mobil uyumlu
        Container(
          padding: const EdgeInsets.all(16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bildirim Yönetimi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Tüm kullanıcılara toplu bildirim gönder',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        
        // Tab Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[700],
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Yeni'),
              Tab(text: 'Zamanlanmış'),
              Tab(text: 'Geçmiş'),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNewNotificationTab(),
              _buildScheduledTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== YENİ BİLDİRİM TAB ====================
  Widget _buildNewNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bildirim Formu
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Bildirim Başlığı *',
                      hintText: 'Örn: Yeni Kampanya! 🎉',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // İçerik
                  TextField(
                    controller: _bodyController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bildirim İçeriği *',
                      hintText: 'Bildirim mesajınızı yazın...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Görsel URL
                  TextField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Görsel URL (Opsiyonel)',
                      hintText: 'https://example.com/image.jpg',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.image, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Zamanlanmış Bildirim
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Zamanla Switch
                  Row(
                    children: [
                      Icon(Icons.schedule, color: _isScheduled ? Colors.orange : Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Zamanlanmış Bildirim', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      Switch(
                        value: _isScheduled,
                        onChanged: (value) {
                          setState(() {
                            _isScheduled = value;
                            if (!value) {
                              _scheduledDate = null;
                              _scheduledTime = null;
                              _isRepeating = false;
                            }
                          });
                        },
                        activeColor: Colors.orange,
                      ),
                    ],
                  ),
                  
                  if (_isScheduled) ...[
                    const Divider(),
                    
                    // Tarih ve Saat Seçici
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _scheduledDate != null
                                          ? DateFormat('d MMM', 'tr_TR').format(_scheduledDate!)
                                          : 'Tarih',
                                      style: TextStyle(fontSize: 12, color: _scheduledDate != null ? Colors.black : Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: _selectTime,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Text(
                                    _scheduledTime != null
                                        ? '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'
                                        : 'Saat',
                                    style: TextStyle(fontSize: 12, color: _scheduledTime != null ? Colors.black : Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Yineleme Ayarı
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isRepeating ? Colors.purple.withOpacity(0.1) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _isRepeating ? Colors.purple.withOpacity(0.3) : Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.repeat, color: _isRepeating ? Colors.purple : Colors.grey, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Yinele', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                              ),
                              Switch(
                                value: _isRepeating,
                                onChanged: (value) => setState(() => _isRepeating = value),
                                activeColor: Colors.purple,
                              ),
                            ],
                          ),
                          
                          if (_isRepeating) ...[
                            const Divider(),
                            
                            // Yineleme Tipi
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildRepeatTypeChip('daily', 'Her Gün', Icons.today),
                                _buildRepeatTypeChip('weekly', 'Haftalık', Icons.view_week),
                                _buildRepeatTypeChip('monthly', 'Aylık', Icons.calendar_month),
                              ],
                            ),
                            
                            // Haftalık gün seçimi
                            if (_repeatType == 'weekly') ...[
                              const SizedBox(height: 10),
                              const Text('Günleri seçin:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                children: List.generate(7, (index) {
                                  final day = index + 1;
                                  final isSelected = _selectedWeekDays.contains(day);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedWeekDays.remove(day);
                                        } else {
                                          _selectedWeekDays.add(day);
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 36,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.purple : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getWeekDayName(day),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSelected ? Colors.white : Colors.black,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                            
                            // Aylık gün seçimi
                            if (_repeatType == 'monthly') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Text('Her ayın ', style: TextStyle(fontSize: 12)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.purple),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: DropdownButton<int>(
                                      value: _selectedMonthDay,
                                      isDense: true,
                                      underline: const SizedBox(),
                                      items: List.generate(28, (i) => DropdownMenuItem(
                                        value: i + 1,
                                        child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                                      )),
                                      onChanged: (value) => setState(() => _selectedMonthDay = value!),
                                    ),
                                  ),
                                  const Text('. günü', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ],
                            
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 14, color: Colors.purple),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _getRepeatTypeText(),
                                      style: const TextStyle(fontSize: 11, color: Colors.purple),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Hızlı Şablonlar
          const Text('Hızlı Şablonlar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTemplateChip('Hatırlatma 👣', 'Adımlarını Unutma!', 'Bugün henüz adım atmadın. Haydi, harekete geç!'),
              _buildTemplateChip('Bağış 💝', 'Umut Ol!', 'Hope puanlarınla bir hayata dokunabilirsin.'),
              _buildTemplateChip('Teşekkür 🙏', 'Teşekkürler!', 'Ailemizin parçası olduğunuz için teşekkürler!'),
              _buildTemplateChip('Kampanya 🎉', 'Özel Kampanya!', 'Sınırlı süreliğine özel kampanyamızı kaçırmayın!'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Gönder Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendNotification,
              icon: _isSending 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isScheduled ? Icons.schedule_send : Icons.send, size: 20),
              label: Text(
                _isSending ? 'Gönderiliyor...' : _isScheduled ? 'Zamanla' : 'Şimdi Gönder',
                style: const TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScheduled ? Colors.orange : Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRepeatTypeChip(String type, String label, IconData icon) {
    final isSelected = _repeatType == type;
    return GestureDetector(
      onTap: () => setState(() => _repeatType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey[700]),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateChip(String label, String title, String body) {
    return ActionChip(
      avatar: const Icon(Icons.flash_on, size: 12),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      onPressed: () {
        setState(() {
          _titleController.text = title;
          _bodyController.text = body;
        });
      },
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ==================== ZAMANLANMIŞ TAB ====================
  Widget _buildScheduledTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final pending = _scheduledNotifications.where((n) => n['status'] == 'pending').toList();
    
    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Zamanlanmış bildirim yok', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadNotificationHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pending.length,
        itemBuilder: (context, index) {
          final notification = pending[index];
          return _buildScheduledCard(notification);
        },
      ),
    );
  }

  Widget _buildScheduledCard(Map<String, dynamic> notification) {
    final scheduledTime = (notification['scheduled_time'] as Timestamp?)?.toDate();
    final repeatType = notification['repeat_type'] as String?;
    final isRepeating = repeatType != null && repeatType != 'none';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.schedule, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title'] ?? 'Başlık yok',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (scheduledTime != null)
                        Text(
                          DateFormat('d MMM yyyy HH:mm', 'tr_TR').format(scheduledTime),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                if (isRepeating)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.repeat, size: 12, color: Colors.purple),
                        const SizedBox(width: 2),
                        Text(
                          _getRepeatLabel(repeatType),
                          style: const TextStyle(fontSize: 10, color: Colors.purple),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notification['body'] ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cancelScheduledNotification(notification['id']),
                  icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                  label: const Text('İptal', style: TextStyle(fontSize: 12, color: Colors.red)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRepeatLabel(String? type) {
    switch (type) {
      case 'daily': return 'Günlük';
      case 'weekly': return 'Haftalık';
      case 'monthly': return 'Aylık';
      default: return '';
    }
  }

  Future<void> _cancelScheduledNotification(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bildirimi İptal Et'),
        content: const Text('Bu zamanlanmış bildirimi iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _firestore.collection('scheduled_notifications').doc(id).update({'status': 'cancelled'});
      _loadNotificationHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim iptal edildi'), backgroundColor: Colors.green),
        );
      }
    }
  }

  // ==================== GEÇMİŞ TAB ====================
  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_notificationHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Henüz bildirim gönderilmemiş', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadNotificationHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notificationHistory.length,
        itemBuilder: (context, index) {
          final notification = _notificationHistory[index];
          return _buildHistoryCard(notification);
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> notification) {
    final sentAt = (notification['sent_at'] as Timestamp?)?.toDate();
    final status = notification['status'] as String? ?? 'sent';
    final isRepeating = notification['repeat_type'] != null && notification['repeat_type'] != 'none';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notification['title'] ?? 'Başlık yok',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isRepeating)
                  const Icon(Icons.repeat, size: 14, color: Colors.purple),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              notification['body'] ?? '',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  sentAt != null ? DateFormat('d MMM yyyy HH:mm', 'tr_TR').format(sentAt) : '-',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(fontSize: 9, color: _getStatusColor(status), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent': return Colors.green;
      case 'fallback_only_inapp': return Colors.orange;
      case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sent': return Icons.check_circle;
      case 'fallback_only_inapp': return Icons.warning;
      case 'failed': return Icons.error;
      default: return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'sent': return 'Gönderildi';
      case 'fallback_only_inapp': return 'Uygulama içi';
      case 'failed': return 'Başarısız';
      default: return status;
    }
  }

  // ==================== GÖNDER ====================
  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve içerik zorunludur'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isScheduled && (_scheduledDate == null || _scheduledTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tarih ve saat seçin'), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isScheduled ? 'Bildirimi Zamanla' : 'Bildirimi Gönder'),
        content: Text(
          _isScheduled
              ? 'Bu bildirim ${_formatScheduledDateTime()} tarihinde gönderilecek.\n${_isRepeating ? '\n🔄 Yineleme: ${_getRepeatTypeText()}' : ''}'
              : 'Bu bildirim ŞİMDİ TÜM kullanıcılara gönderilecektir.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _isScheduled ? Colors.orange : Colors.blue),
            child: Text(_isScheduled ? 'Zamanla' : 'Gönder'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);

    try {
      DateTime? scheduledDateTime;
      if (_isScheduled && _scheduledDate != null && _scheduledTime != null) {
        scheduledDateTime = DateTime(
          _scheduledDate!.year,
          _scheduledDate!.month,
          _scheduledDate!.day,
          _scheduledTime!.hour,
          _scheduledTime!.minute,
        );
      }

      final result = await _adminService.sendBroadcastNotification(
        title: _titleController.text,
        body: _bodyController.text,
        imageUrl: _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
        targetAudience: 'all',
        scheduledTime: scheduledDateTime,
        repeatType: _isRepeating ? _repeatType : null,
        repeatDays: _repeatType == 'weekly' ? _selectedWeekDays : null,
        repeatMonthDay: _repeatType == 'monthly' ? _selectedMonthDay : null,
      );

      if (mounted) {
        final message = result['message'] ?? (_isScheduled ? 'Bildirim zamanlandı!' : 'Bildirim gönderildi!');
        final sentCount = result['sentCount'] ?? 0;
        final isNoToken = message.contains('token bulunamadı');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNoToken 
                ? 'Uyarı: Kayıtlı FCM token yok. Kullanıcılar gerçek cihazda uygulamayı açtığında token kaydedilir.'
                : (sentCount > 0 ? '$sentCount kişiye bildirim gönderildi!' : message)),
            backgroundColor: isNoToken ? Colors.orange : Colors.green,
            duration: Duration(seconds: isNoToken ? 5 : 3),
          ),
        );
        
        _titleController.clear();
        _bodyController.clear();
        _imageUrlController.clear();
        setState(() {
          _isScheduled = false;
          _scheduledDate = null;
          _scheduledTime = null;
          _isRepeating = false;
        });
        
        _loadNotificationHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }
}
