import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/charity_model.dart';

/// Bağış raporları ekranı - Tamamen scroll edilebilir
class AdminDonationsScreen extends StatefulWidget {
  const AdminDonationsScreen({super.key});

  @override
  State<AdminDonationsScreen> createState() => _AdminDonationsScreenState();
}

class _AdminDonationsScreenState extends State<AdminDonationsScreen> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;
  
  List<DonationRecordModel> _donations = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  RecipientType? _selectedType;
  bool? _transferFilter;
  String _dateRangeType = 'month';
  
  double _totalAmount = 0;
  int _totalDonors = 0;
  Map<String, Map<String, dynamic>> _byRecipient = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDonations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDonations() async {
    setState(() => _isLoading = true);
    try {
      final donations = await _adminService.getMonthlyDonations(
        startDate: _startDate,
        endDate: _endDate,
        recipientType: _selectedType,
      );
      
      double total = 0;
      final Set<String> uniqueDonors = {};
      final Map<String, Map<String, dynamic>> byRecipient = {};
      
      for (var donation in donations) {
        total += donation.amount;
        uniqueDonors.add(donation.donorUid);
        
        if (!byRecipient.containsKey(donation.recipientId)) {
          byRecipient[donation.recipientId] = {
            'id': donation.recipientId,
            'name': donation.recipientName,
            'type': donation.recipientType,
            'amount': 0.0,
            'count': 0,
          };
        }
        byRecipient[donation.recipientId]!['amount'] += donation.amount;
        byRecipient[donation.recipientId]!['count'] += 1;
      }
      
      if (mounted) {
        setState(() {
          _donations = donations;
          _totalAmount = total;
          _totalDonors = uniqueDonors.length;
          _byRecipient = byRecipient;
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

  List<DonationRecordModel> _getFilteredDonations() {
    var filtered = List<DonationRecordModel>.from(_donations);
    if (_selectedType != null) {
      filtered = filtered.where((d) => d.recipientType == _selectedType).toList();
    }
    if (_transferFilter != null) {
      filtered = filtered.where((d) => d.isTransferred == _transferFilter).toList();
    }
    filtered.sort((a, b) => b.donatedAt.compareTo(a.donatedAt));
    return filtered;
  }
  
  double get _transferredAmount => _donations.where((d) => d.isTransferred).fold(0.0, (sum, d) => sum + d.amount);
  double get _pendingAmount => _donations.where((d) => !d.isTransferred).fold(0.0, (sum, d) => sum + d.amount);
  int get _transferredCount => _donations.where((d) => d.isTransferred).length;
  int get _pendingCount => _donations.where((d) => !d.isTransferred).length;
  
  void _setDateRange(String type) {
    final now = DateTime.now();
    setState(() {
      _dateRangeType = type;
      switch (type) {
        case 'today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now;
          break;
        case 'week':
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
      }
    });
    _loadDonations();
  }

  List<Map<String, dynamic>> _getRecipientsByType(RecipientType type) {
    return _byRecipient.values
        .where((r) => r['type'] == type)
        .toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        const Text('Bağış Raporları', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Detaylı bağış geçmişi ve istatistikler', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 16),
        
        // Filtre kartı
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Tarih chip'leri
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip('Bugün', 'today'),
                      const SizedBox(width: 8),
                      _buildChip('Son 7 Gün', 'week'),
                      const SizedBox(width: 8),
                      _buildChip('Bu Ay', 'month'),
                      const SizedBox(width: 8),
                      _buildChip('Özel', 'custom'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Tarih gösterge
                Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: _selectDateRange,
                        child: Text(
                          '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Alıcı türü
                DropdownButtonFormField<RecipientType?>(
                  value: _selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Alıcı Türü',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tümü')),
                    ...RecipientType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedType = v);
                    _loadDonations();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Aktarılan / Bekleyen
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildTransferCard('Aktarılan', _transferredCount, _transferredAmount, Colors.green, Icons.check_circle, _transferFilter == true, () {
                setState(() => _transferFilter = _transferFilter == true ? null : true);
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildTransferCard('Bekleyen', _pendingCount, _pendingAmount, Colors.orange, Icons.pending, _transferFilter == false, () {
                setState(() => _transferFilter = _transferFilter == false ? null : false);
              })),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // İstatistik kartları
        Row(
          children: [
            Expanded(child: _buildStatCard('Toplam Bağış', '${_formatNumber(_totalAmount.toInt())} H', Icons.paid, Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Bağış Sayısı', '${_getFilteredDonations().length}', Icons.receipt_long, Colors.blue)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildStatCard('Bağışçı', '$_totalDonors', Icons.people, Colors.orange)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Ortalama', _donations.isNotEmpty ? '${(_totalAmount / _donations.length).toStringAsFixed(1)} H' : '0 H', Icons.analytics, Colors.purple)),
          ],
        ),
        const SizedBox(height: 16),
        
        // Tab Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Bağış Listesi'),
              Tab(text: 'Alıcı Bazında'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Tab içeriği - sabit yükseklik
        SizedBox(
          height: 500,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDonationsList(),
              _buildRecipientSummary(),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildChip(String label, String type) {
    final isSelected = _dateRangeType == type;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => _setDateRange(type),
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
    );
  }
  
  Widget _buildTransferCard(String title, int count, double amount, Color color, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: isSelected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 18),
                if (isSelected) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Aktif', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            Text('${_formatNumber(amount.toInt())} H', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            Text('$count bağış', style: TextStyle(color: Colors.grey[500], fontSize: 9)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 10), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationsList() {
    final filteredDonations = _getFilteredDonations();
    
    if (filteredDonations.isEmpty) {
      return const Center(child: Text('Bağış bulunamadı', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: filteredDonations.length,
      itemBuilder: (context, index) {
        final donation = filteredDonations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: donation.isTransferred ? Colors.green.withOpacity(0.05) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: donation.isTransferred ? const BorderSide(color: Colors.green) : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getTypeColor(donation.recipientType).withOpacity(0.1),
              child: Icon(_getTypeIcon(donation.recipientType), color: _getTypeColor(donation.recipientType), size: 20),
            ),
            title: Row(
              children: [
                Expanded(child: Text(donation.isAnonymous ? 'Anonim' : donation.donorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                Text('${donation.amount.toStringAsFixed(1)} H', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('→ ${donation.recipientName}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                Row(
                  children: [
                    Text(_formatDateTime(donation.donatedAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    if (donation.isTransferred) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, size: 12, color: Colors.green),
                      const Text(' Aktarıldı', style: TextStyle(fontSize: 11, color: Colors.green)),
                    ],
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(donation.isTransferred ? Icons.check_circle : Icons.check_circle_outline, color: donation.isTransferred ? Colors.green : Colors.grey),
              onPressed: () => _toggleTransfer(donation),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipientSummary() {
    if (_selectedType != null) {
      return _buildTypeSection(_selectedType!);
    }
    
    return ListView(
      children: [
        _buildTypeSection(RecipientType.charity),
        const SizedBox(height: 16),
        _buildTypeSection(RecipientType.community),
        const SizedBox(height: 16),
        _buildTypeSection(RecipientType.individual),
      ],
    );
  }

  Widget _buildTypeSection(RecipientType type) {
    final recipients = _getRecipientsByType(type);
    final color = _getTypeColor(type);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(_getTypeIcon(type), color: color),
              const SizedBox(width: 8),
              Text(type.displayName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              const Spacer(),
              Text('${recipients.length} adet', style: TextStyle(color: color)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (recipients.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('Bağış bulunamadı', style: TextStyle(color: Colors.grey)))
        else
          ...recipients.map((r) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(_getTypeIcon(type), color: color, size: 20)),
              title: Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${r['count']} bağış'),
              trailing: Text('${_formatNumber((r['amount'] as double).toInt())} H', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              onTap: () => _showRecipientDonations(r),
            ),
          )),
      ],
    );
  }

  Future<void> _toggleTransfer(DonationRecordModel donation) async {
    try {
      await _adminService.markDonationAsTransferred(donation.id, !donation.isTransferred);
      await _loadDonations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(donation.isTransferred ? 'Aktarım geri alındı' : 'Aktarıldı işaretlendi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showRecipientDonations(Map<String, dynamic> recipient) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      final donations = await _adminService.getDonationsByRecipientId(recipient['id']);
      if (!mounted) return;
      Navigator.pop(context);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(recipient['name']),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: donations.length,
              itemBuilder: (context, index) {
                final d = donations[index];
                return ListTile(
                  title: Text(d.isAnonymous ? 'Anonim' : d.donorName),
                  subtitle: Text(_formatDateTime(d.donatedAt)),
                  trailing: Text('${d.amount.toStringAsFixed(1)} H', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                );
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _dateRangeType = 'custom';
      });
      _loadDonations();
    }
  }

  Color _getTypeColor(RecipientType type) {
    switch (type) {
      case RecipientType.charity: return Colors.blue;
      case RecipientType.community: return Colors.orange;
      case RecipientType.individual: return Colors.purple;
    }
  }

  IconData _getTypeIcon(RecipientType type) {
    switch (type) {
      case RecipientType.charity: return Icons.business;
      case RecipientType.community: return Icons.groups;
      case RecipientType.individual: return Icons.person;
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      String result = '';
      String numStr = n.toString();
      int count = 0;
      for (int i = numStr.length - 1; i >= 0; i--) {
        count++;
        result = numStr[i] + result;
        if (count % 3 == 0 && i > 0) result = '.' + result;
      }
      return result;
    }
    return n.toString();
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  String _formatDateTime(DateTime d) => '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
