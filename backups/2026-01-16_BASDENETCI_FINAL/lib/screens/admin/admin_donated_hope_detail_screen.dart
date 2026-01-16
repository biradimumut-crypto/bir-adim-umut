import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/admin_dashboard_stats.dart';

/// Bağışlanan Hope Detay Sayfası
/// Kurum bazlı breakdown + tarih filtresi
class AdminDonatedHopeDetailScreen extends StatefulWidget {
  const AdminDonatedHopeDetailScreen({super.key});

  @override
  State<AdminDonatedHopeDetailScreen> createState() => _AdminDonatedHopeDetailScreenState();
}

class _AdminDonatedHopeDetailScreenState extends State<AdminDonatedHopeDetailScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  DonatedHopeAnalytics? _analytics;
  
  // Tarih filtresi
  DateFilterType _filterType = DateFilterType.daily;
  DateTime _selectedDate = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      DateTime? startDate;
      DateTime? endDate;
      
      switch (_filterType) {
        case DateFilterType.daily:
          // Kümülatif - tarih filtresi yok
          startDate = null;
          endDate = null;
          break;
        case DateFilterType.monthly:
          startDate = DateTime(_selectedYear, _selectedMonth, 1);
          endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
          break;
        case DateFilterType.custom:
          startDate = _customStartDate;
          endDate = _customEndDate;
          break;
      }
      
      final analytics = await _adminService.getDonatedHopeAnalytics(
        startDate: startDate,
        endDate: endDate,
      );
      
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Veri yükleme hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: const Text('Bağışlanan Hope Detayları'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarih Filtresi
                  _buildDateFilter(),
                  
                  const SizedBox(height: 20),
                  
                  // Toplam Kart
                  _buildTotalCard(),
                  
                  const SizedBox(height: 20),
                  
                  // Kurum Bazlı Breakdown
                  const Text(
                    'Kurum Dağılımı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (_analytics?.charityBreakdown.isEmpty ?? true)
                    _buildEmptyState()
                  else
                    ..._buildCharityCards(),
                ],
              ),
            ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tarih Filtresi',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              _buildFilterChip('Tümü', DateFilterType.daily, isAll: true),
              const SizedBox(width: 8),
              _buildFilterChip('Aylık', DateFilterType.monthly),
              const SizedBox(width: 8),
              _buildFilterChip('Özel', DateFilterType.custom),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (_filterType == DateFilterType.monthly)
            _buildMonthSelector(),
          
          if (_filterType == DateFilterType.custom)
            _buildCustomDateSelector(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, DateFilterType type, {bool isAll = false}) {
    final isSelected = isAll 
        ? _filterType == DateFilterType.daily 
        : _filterType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = isAll ? DateFilterType.daily : type;
        });
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() => _selectedYear--);
                _loadData();
              },
            ),
            Text(
              '$_selectedYear',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _selectedYear < DateTime.now().year ? () {
                setState(() => _selectedYear++);
                _loadData();
              } : null,
            ),
          ],
        ),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(12, (index) {
            final month = index + 1;
            final isSelected = month == _selectedMonth;
            final isFuture = _selectedYear == DateTime.now().year && 
                            month > DateTime.now().month;
            
            return GestureDetector(
              onTap: isFuture ? null : () {
                setState(() => _selectedMonth = month);
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? const Color(0xFF9B59B6)
                      : (isFuture ? Colors.grey[100] : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  months[index],
                  style: TextStyle(
                    color: isSelected 
                        ? Colors.white 
                        : (isFuture ? Colors.grey[400] : Colors.grey[700]),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCustomDateSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _customStartDate ?? DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _customStartDate = date);
                if (_customEndDate != null) _loadData();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _customStartDate != null
                        ? '${_customStartDate!.day}/${_customStartDate!.month}/${_customStartDate!.year}'
                        : 'Başlangıç',
                    style: TextStyle(
                      color: _customStartDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('-'),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _customEndDate ?? DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _customEndDate = date);
                if (_customStartDate != null) _loadData();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _customEndDate != null
                        ? '${_customEndDate!.day}/${_customEndDate!.month}/${_customEndDate!.year}'
                        : 'Bitiş',
                    style: TextStyle(
                      color: _customEndDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalCard() {
    final total = _analytics?.totalDonatedHope ?? 0;
    final count = _analytics?.totalDonationCount ?? 0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B59B6).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.volunteer_activism_rounded,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            '${total.toStringAsFixed(1)} H',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _filterType == DateFilterType.daily
                ? 'Toplam Bağışlanan Hope (Kümülatif)'
                : 'Seçili Dönemde Bağışlanan Hope',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count bağış işlemi',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Bu dönemde bağış yapılmamış',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCharityCards() {
    final charities = _analytics?.charityBreakdown.values.toList() ?? [];
    final total = _analytics?.totalDonatedHope ?? 1;
    
    // Hope miktarına göre sırala
    charities.sort((a, b) => b.totalHope.compareTo(a.totalHope));
    
    final colors = [
      const Color(0xFF9B59B6),
      const Color(0xFFE74C3C),
      const Color(0xFF3498DB),
      const Color(0xFF2ECC71),
      const Color(0xFFF39C12),
      const Color(0xFF1ABC9C),
    ];
    
    return charities.asMap().entries.map((entry) {
      final index = entry.key;
      final charity = entry.value;
      final color = colors[index % colors.length];
      final percentage = total > 0 ? (charity.totalHope / total * 100) : 0;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Logo/Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: charity.charityLogoUrl != null && charity.charityLogoUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        charity.charityLogoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.business_rounded,
                          color: color,
                          size: 24,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.business_rounded,
                      color: color,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    charity.charityName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${charity.donationCount} bağış',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${charity.totalHope.toStringAsFixed(1)} H',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                Text(
                  '%${percentage.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }
}
