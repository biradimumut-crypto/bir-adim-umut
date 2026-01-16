import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/admin_dashboard_stats.dart';

/// Üretilen Hope Detay Sayfası
/// 5 kaynak bazlı breakdown + tarih filtresi
class AdminProducedHopeDetailScreen extends StatefulWidget {
  const AdminProducedHopeDetailScreen({super.key});

  @override
  State<AdminProducedHopeDetailScreen> createState() => _AdminProducedHopeDetailScreenState();
}

class _AdminProducedHopeDetailScreenState extends State<AdminProducedHopeDetailScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  ProducedHopeAnalytics? _analytics;
  
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
          startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          endDate = startDate.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
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
      
      // Kümülatif toplam için null geç
      final analytics = await _adminService.getProducedHopeAnalytics(
        startDate: _filterType == DateFilterType.daily ? null : startDate,
        endDate: _filterType == DateFilterType.daily ? null : endDate,
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
        title: const Text('Üretilen Hope Detayları'),
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
                  
                  // Kaynak Bazlı Breakdown
                  const Text(
                    'Kaynak Dağılımı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildSourceCard(
                    icon: Icons.directions_walk_rounded,
                    title: 'Günlük Adımlardan',
                    value: _analytics?.hopeFromDailySteps ?? 0,
                    color: const Color(0xFF6EC6B5),
                    description: 'Normal adım dönüşümü (100 adım = 1 Hope)',
                  ),
                  
                  _buildSourceCard(
                    icon: Icons.history_rounded,
                    title: 'Taşınan Adımlardan',
                    value: _analytics?.hopeFromCarryover ?? 0,
                    color: const Color(0xFFE07A5F),
                    description: 'Önceki günlerden kalan adımların dönüşümü',
                  ),
                  
                  _buildSourceCard(
                    icon: Icons.double_arrow_rounded,
                    title: '2x Bonus ile',
                    value: _analytics?.hopeFrom2xBonus ?? 0,
                    color: const Color(0xFFF2C94C),
                    description: 'Progress bar 2x aktifken kazanılan ekstra Hope',
                  ),
                  
                  _buildSourceCard(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Referans Bonusundan',
                    value: _analytics?.hopeFromReferralBonus ?? 0,
                    color: const Color(0xFF9B59B6),
                    description: 'Davet edilen kullanıcılardan gelen bonus',
                  ),
                  
                  _buildSourceCard(
                    icon: Icons.groups_rounded,
                    title: 'Takım Bonusundan',
                    value: _analytics?.hopeFromTeamBonus ?? 0,
                    color: const Color(0xFF3498DB),
                    description: 'Takım bonus adımlarının dönüşümü',
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Pasta Grafiği
                  _buildPieChartSection(),
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
          
          // Filtre Seçenekleri
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
          
          // Aylık seçici
          if (_filterType == DateFilterType.monthly)
            _buildMonthSelector(),
          
          // Özel tarih seçici
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
        // Yıl seçici
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
        
        // Ay seçici
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
                      ? const Color(0xFF6EC6B5)
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
    final total = _analytics?.totalProducedHope ?? 0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6EC6B5), Color(0xFF4AA396)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6EC6B5).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.eco_rounded,
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
                ? 'Toplam Üretilen Hope (Kümülatif)'
                : 'Seçili Dönemde Üretilen Hope',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard({
    required IconData icon,
    required String title,
    required double value,
    required Color color,
    required String description,
  }) {
    final total = _analytics?.totalProducedHope ?? 1;
    final percentage = total > 0 ? (value / total * 100) : 0;
    
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
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
                '${value.toStringAsFixed(1)} H',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
  }

  Widget _buildPieChartSection() {
    final data = _analytics;
    if (data == null) return const SizedBox.shrink();
    
    final sources = [
      {'label': 'Günlük', 'value': data.hopeFromDailySteps, 'color': const Color(0xFF6EC6B5)},
      {'label': 'Taşınan', 'value': data.hopeFromCarryover, 'color': const Color(0xFFE07A5F)},
      {'label': '2x Bonus', 'value': data.hopeFrom2xBonus, 'color': const Color(0xFFF2C94C)},
      {'label': 'Referans', 'value': data.hopeFromReferralBonus, 'color': const Color(0xFF9B59B6)},
      {'label': 'Takım', 'value': data.hopeFromTeamBonus, 'color': const Color(0xFF3498DB)},
    ];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dağılım Özeti',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: sources.map((source) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: source['color'] as Color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${source['label']}: ${(source['value'] as double).toStringAsFixed(1)} H',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
