import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/admin_dashboard_stats.dart';

/// Reklam Geliri Detay Sayfası
/// Reklam türü bazlı breakdown + tarih filtresi
class AdminAdRevenueDetailScreen extends StatefulWidget {
  const AdminAdRevenueDetailScreen({super.key});

  @override
  State<AdminAdRevenueDetailScreen> createState() => _AdminAdRevenueDetailScreenState();
}

class _AdminAdRevenueDetailScreenState extends State<AdminAdRevenueDetailScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  AdRevenueAnalytics? _analytics;
  
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
      
      final analytics = await _adminService.getAdRevenueAnalytics(
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
        title: const Text('Reklam Geliri Detayları'),
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
                  // AdMob'dan Güncelle Butonu
                  _buildRefreshFromAdMobButton(),
                  
                  const SizedBox(height: 16),
                  
                  // Tarih Filtresi
                  _buildDateFilter(),
                  
                  const SizedBox(height: 20),
                  
                  // Toplam Kart
                  _buildTotalCard(),
                  
                  const SizedBox(height: 20),
                  
                  // Reklam Türü Bazlı Breakdown
                  const Text(
                    'Reklam Türü Dağılımı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildAdTypeCard(
                    icon: Icons.fullscreen_rounded,
                    title: 'Geçişli Reklam (Interstitial)',
                    revenue: _analytics?.interstitialRevenue ?? 0,
                    impressions: _analytics?.interstitialImpressions ?? 0,
                    color: const Color(0xFF3498DB),
                    description: 'Tam ekran geçişli reklamlar',
                  ),
                  
                  _buildAdTypeCard(
                    icon: Icons.view_agenda_rounded,
                    title: 'Banner Reklam',
                    revenue: _analytics?.bannerRevenue ?? 0,
                    impressions: _analytics?.bannerImpressions ?? 0,
                    color: const Color(0xFF2ECC71),
                    description: 'Sayfa alt/üst banner reklamları',
                  ),
                  
                  _buildAdTypeCard(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Ödüllü Reklam (Rewarded)',
                    revenue: _analytics?.rewardedRevenue ?? 0,
                    impressions: _analytics?.rewardedImpressions ?? 0,
                    color: const Color(0xFFF39C12),
                    description: 'Kullanıcının izlediği ödüllü reklamlar',
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Özet İstatistikler
                  _buildSummarySection(),
                  
                  const SizedBox(height: 20),
                  
                  // Bilgi Notu
                  _buildInfoNote(),
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
                      ? const Color(0xFF2ECC71)
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
    final total = _analytics?.totalRevenue ?? 0;
    final impressions = _analytics?.totalAdImpressions ?? 0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2ECC71).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            '${total.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _filterType == DateFilterType.daily
                ? 'Toplam Reklam Geliri (Kümülatif)'
                : 'Seçili Dönemde Reklam Geliri',
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
              '$impressions gösterim',
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

  Widget _buildAdTypeCard({
    required IconData icon,
    required String title,
    required double revenue,
    required int impressions,
    required Color color,
    required String description,
  }) {
    final total = _analytics?.totalRevenue ?? 1;
    final percentage = total > 0 ? (revenue / total * 100) : 0;
    final cpm = impressions > 0 ? (revenue / impressions * 1000) : 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
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
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${revenue.toStringAsFixed(2)} ₺',
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
          const SizedBox(height: 12),
          
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
          
          const SizedBox(height: 12),
          
          // Alt istatistikler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Gösterim', _formatNumber(impressions), Icons.visibility),
              _buildMiniStat('eCPM', '${cpm.toStringAsFixed(2)} ₺', Icons.trending_up),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    final data = _analytics;
    if (data == null) return const SizedBox.shrink();
    
    final avgCpm = data.totalAdImpressions > 0 
        ? (data.totalRevenue / data.totalAdImpressions * 1000) 
        : 0;
    
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
            'Özet İstatistikler',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildSummaryStat(
                  'Toplam Gösterim',
                  _formatNumber(data.totalAdImpressions),
                  Icons.visibility_rounded,
                  const Color(0xFF3498DB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStat(
                  'Ortalama eCPM',
                  '${avgCpm.toStringAsFixed(2)} ₺',
                  Icons.trending_up_rounded,
                  const Color(0xFF2ECC71),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Reklam gelirleri AdMob üzerinden tahmini olarak hesaplanmaktadır. Gerçek gelirler farklılık gösterebilir.',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// AdMob'dan güncel veri çekme butonu
  Widget _buildRefreshFromAdMobButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sync, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AdMob API Entegrasyonu',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Gerçek reklam gelirlerini AdMob\'dan çek',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _refreshFromAdMob,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.green,
                      ),
                    )
                  : const Icon(Icons.cloud_download),
              label: Text(_isRefreshing ? 'Güncelleniyor...' : 'Şimdi Güncelle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '⏰ Otomatik güncelleme: Her gün 06:00 (İstanbul)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// AdMob'dan veri çek
  Future<void> _refreshFromAdMob() async {
    setState(() => _isRefreshing = true);
    
    try {
      final result = await _adminService.refreshAdRevenueData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Güncelleme tamamlandı'),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );
        
        // Başarılıysa verileri yeniden yükle
        if (result['success'] == true) {
          await _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }
}
