import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/admin_service.dart';
import '../../models/admin_dashboard_stats.dart';

/// Dashboard detay tipi enum
enum DashboardDetailType {
  dailySteps,
  carryover,
  referral,
  donation,
}

/// Dashboard Detay Rapor Ekranı
class AdminDashboardDetailScreen extends StatefulWidget {
  final DashboardDetailType type;

  const AdminDashboardDetailScreen({super.key, required this.type});

  @override
  State<AdminDashboardDetailScreen> createState() => _AdminDashboardDetailScreenState();
}

class _AdminDashboardDetailScreenState extends State<AdminDashboardDetailScreen> {
  final AdminService _adminService = AdminService();
  
  DateFilterType _selectedFilter = DateFilterType.daily;
  late DateTime _startDate;
  late DateTime _endDate;
  
  // Aylık seçim için
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  bool _isLoading = true;
  List<dynamic> _records = [];
  
  // Özet veriler
  DailyStepAnalytics? _dailyStepAnalytics;
  CarryoverAnalytics? _carryoverAnalytics;
  ReferralAnalytics? _referralAnalytics;
  DonationAnalytics? _donationAnalytics;

  @override
  void initState() {
    super.initState();
    // Varsayılan olarak bugünün verileri
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = now;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      switch (widget.type) {
        case DashboardDetailType.dailySteps:
          // Özet panel için de tarih filtresini kullan
          _dailyStepAnalytics = await _adminService.getDailyStepAnalyticsForRange(
            startDate: _startDate,
            endDate: _endDate,
          );
          _records = await _adminService.getDetailedStepRecords(
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
          
        case DashboardDetailType.carryover:
          // Carryover için tarih aralığı ile analiz
          _carryoverAnalytics = await _adminService.getCarryoverAnalyticsForRange(
            startDate: _startDate,
            endDate: _endDate,
          );
          _records = await _adminService.getDetailedCarryoverRecords(
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
          
        case DashboardDetailType.referral:
          // Referral için tarih aralığı ile analiz
          _referralAnalytics = await _adminService.getReferralAnalyticsForRange(
            startDate: _startDate,
            endDate: _endDate,
          );
          _records = await _adminService.getDetailedReferralRecords(
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
          
        case DashboardDetailType.donation:
          _donationAnalytics = await _adminService.getDonationAnalytics(
            startDate: _startDate,
            endDate: _endDate,
          );
          _records = await _adminService.getDetailedDonationRecords(
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Detay veri yükleme hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: _getThemeColor(),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_getTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtre Bölümü
          _buildFilterSection(),
          
          // Özet Kartı
          _buildSummaryCard(),
          
          // Veri Tablosu
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildDataTable(),
          ),
        ],
      ),
    );
  }

  Color _getThemeColor() {
    switch (widget.type) {
      case DashboardDetailType.dailySteps:
        return const Color(0xFF6EC6B5);
      case DashboardDetailType.carryover:
        return const Color(0xFFE07A5F);
      case DashboardDetailType.referral:
        return const Color(0xFFF2C94C);
      case DashboardDetailType.donation:
        return const Color(0xFF9B59B6);
    }
  }

  String _getTitle() {
    switch (widget.type) {
      case DashboardDetailType.dailySteps:
        return 'Günlük Adım Detayları';
      case DashboardDetailType.carryover:
        return 'Taşınan Adım Detayları';
      case DashboardDetailType.referral:
        return 'Referans Detayları';
      case DashboardDetailType.donation:
        return 'Bağış Detayları';
    }
  }

  /// Filtre Bölümü
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtreleme',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          
          // Filtre Seçenekleri
          Row(
            children: [
              _buildFilterChip('Günlük', DateFilterType.daily),
              const SizedBox(width: 8),
              _buildFilterChip('Aylık', DateFilterType.monthly),
              const SizedBox(width: 8),
              _buildFilterChip('Özel Tarih', DateFilterType.custom),
            ],
          ),
          
          // Aylık için Ay Seçici
          if (_selectedFilter == DateFilterType.monthly) ...[
            const SizedBox(height: 12),
            _buildMonthSelector(),
          ],
          
          // Özel Tarih için Tarih Aralığı Seçici
          if (_selectedFilter == DateFilterType.custom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateSelector(
                    'Başlangıç',
                    _startDate,
                    (date) => setState(() {
                      _startDate = date;
                      _loadData();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateSelector(
                    'Bitiş',
                    _endDate,
                    (date) => setState(() {
                      _endDate = date;
                      _loadData();
                    }),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, DateFilterType type) {
    final isSelected = _selectedFilter == type;
    final color = _getThemeColor();
    
    return GestureDetector(
      onTap: () {
        if (type == DateFilterType.monthly) {
          // Aylık seçildiğinde ay seçici dialog aç
          _showMonthPicker();
        } else {
          setState(() {
            _selectedFilter = type;
            // Filtre tipine göre tarihleri ayarla
            final now = DateTime.now();
            switch (type) {
              case DateFilterType.daily:
                _startDate = DateTime(now.year, now.month, now.day);
                _endDate = now;
                break;
              case DateFilterType.monthly:
                // Seçili aya göre ayarlanacak
                break;
              case DateFilterType.custom:
                // Custom seçildiğinde son 7 günü varsayılan yap
                _startDate = now.subtract(const Duration(days: 7));
                _endDate = now;
                break;
            }
          });
          _loadData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime date, Function(DateTime) onDateSelected) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Özet Kartı
  Widget _buildSummaryCard() {
    final color = _getThemeColor();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: _buildSummaryContent(),
    );
  }

  Widget _buildSummaryContent() {
    switch (widget.type) {
      case DashboardDetailType.dailySteps:
        return _buildDailyStepsSummary();
      case DashboardDetailType.carryover:
        return _buildCarryoverSummary();
      case DashboardDetailType.referral:
        return _buildReferralSummary();
      case DashboardDetailType.donation:
        return _buildDonationSummary();
    }
  }

  Widget _buildDailyStepsSummary() {
    final data = _dailyStepAnalytics ?? DailyStepAnalytics.empty();
    
    return Column(
      children: [
        Row(
          children: [
            _buildSummaryItem('Toplam Adım', _formatNumber(data.totalDailySteps)),
            _buildSummaryItem('Dönüştürülen', _formatNumber(data.convertedSteps)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildSummaryItem('Normal Hope', '${data.normalHopeEarned.toStringAsFixed(1)} H'),
            _buildSummaryItem('2x Bonus Hope', '${data.bonusHopeEarned.toStringAsFixed(1)} H'),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF6EC6B5), size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                    children: [
                      const TextSpan(text: '2x Bonus: '),
                      const TextSpan(
                        text: '100 adım = 1H normal + 1H bonus',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' = '),
                      const TextSpan(
                        text: '2 Hope toplam',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6EC6B5)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarryoverSummary() {
    final data = _carryoverAnalytics ?? CarryoverAnalytics.empty();
    
    return Column(
      children: [
        Row(
          children: [
            _buildSummaryItem('Toplam Taşınan', _formatNumber(data.totalCarryoverSteps)),
            _buildSummaryItem('Dönüştürülen', _formatNumber(data.convertedCarryoverSteps)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildSummaryItem('Bekleyen', _formatNumber(data.pendingCarryoverSteps)),
            _buildSummaryItem('Silinen', _formatNumber(data.expiredSteps)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildSummaryItem('Kazanılan Hope', '${data.hopeFromCarryover.toStringAsFixed(1)} H'),
            _buildSummaryItem('Kullanıcı Sayısı', '${data.usersWithCarryover}'),
          ],
        ),
      ],
    );
  }

  Widget _buildReferralSummary() {
    final data = _referralAnalytics ?? ReferralAnalytics.empty();
    
    return Column(
      children: [
        Row(
          children: [
            _buildSummaryItem('Referans Kullanıcı', _formatNumber(data.totalReferralUsers)),
            _buildSummaryItem('Bonus Adım', _formatNumber(data.totalBonusStepsGiven)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildSummaryItem('Dönüştürülen', _formatNumber(data.convertedBonusSteps)),
            _buildSummaryItem('Bekleyen', _formatNumber(data.pendingBonusSteps)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildSummaryItem('Bonus Hope', '${data.hopeFromBonusSteps.toStringAsFixed(1)} H'),
            _buildSummaryItem('Ort. Davet', data.averageReferralsPerUser.toStringAsFixed(1)),
          ],
        ),
      ],
    );
  }

  Widget _buildDonationSummary() {
    final data = _donationAnalytics ?? DonationAnalytics.empty();
    
    return Column(
      children: [
        Row(
          children: [
            _buildSummaryItem('Toplam Bağış', _formatNumber(data.totalDonationCount)),
            _buildSummaryItem('Bağışlanan Hope', '${data.totalDonatedHope.toStringAsFixed(1)} H'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildSummaryItem('Ortalama', '${data.averageDonation.toStringAsFixed(1)} H'),
            _buildSummaryItem('Vakıf Sayısı', '${data.charityBreakdown.length}'),
          ],
        ),
        if (data.charityBreakdown.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Vakıf Dağılımı',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...data.charityBreakdown.entries.take(5).map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    e.key,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${e.value.toStringAsFixed(0)} H',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getThemeColor(),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Veri Tablosu
  Widget _buildDataTable() {
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Bu dönemde kayıt bulunamadı',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detaylı Kayıtlar (${_records.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              // Export butonu
              TextButton.icon(
                onPressed: _exportData,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('CSV İndir', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRecordsList(),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    switch (widget.type) {
      case DashboardDetailType.dailySteps:
      case DashboardDetailType.carryover:
        return _buildStepRecordsList();
      case DashboardDetailType.referral:
        return _buildReferralRecordsList();
      case DashboardDetailType.donation:
        return _buildDonationRecordsList();
    }
  }

  Widget _buildStepRecordsList() {
    final records = _records.cast<UserStepRecord>();
    
    return Column(
      children: records.take(50).map((record) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _getThemeColor().withOpacity(0.2),
              child: Text(
                record.username.isNotEmpty ? record.username[0].toUpperCase() : '?',
                style: TextStyle(color: _getThemeColor(), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.username,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Row(
                    children: [
                      Text(
                        '${_formatNumber(record.steps)} adım',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      if (record.hasBonusMultiplier) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '2x BONUS',
                            style: TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${record.hopeEarned.toStringAsFixed(1)} H',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getThemeColor(),
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatDate(record.date),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildReferralRecordsList() {
    final records = _records.cast<ReferralRecord>();
    
    return Column(
      children: records.take(50).map((record) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _getThemeColor().withOpacity(0.2),
              child: const Icon(Icons.person_add, size: 18, color: Color(0xFFF2C94C)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.referrerUsername,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Davet: ${record.referredUsername}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${_formatNumber(record.bonusStepsGiven)} adım',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getThemeColor(),
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatDate(record.referralDate),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildDonationRecordsList() {
    final records = _records.cast<DonationRecord>();
    
    return Column(
      children: records.take(50).map((record) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _getThemeColor().withOpacity(0.2),
              child: const Icon(Icons.favorite, size: 18, color: Color(0xFF9B59B6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.username,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    record.charityName,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${record.hopeAmount.toStringAsFixed(1)} H',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getThemeColor(),
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatDate(record.date),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  Future<void> _exportData() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dışa aktarılacak veri bulunamadı'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // CSV içeriğini oluştur
      final csvContent = _generateCsvContent();
      
      // Geçici dosya oluştur
      final directory = await getTemporaryDirectory();
      final fileName = _getExportFileName();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent);
      
      // Paylaş
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: _getExportSubject(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV dosyası hazırlandı'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dışa aktarma hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateCsvContent() {
    final buffer = StringBuffer();
    
    // UTF-8 BOM (Excel'de Türkçe karakter desteği için)
    buffer.write('\uFEFF');
    
    switch (widget.type) {
      case DashboardDetailType.dailySteps:
      case DashboardDetailType.carryover:
        // Header
        buffer.writeln('Kullanıcı,Adım,Dönüştürülen,Hope,2x Bonus,Tarih');
        // Data
        for (var record in _records.cast<UserStepRecord>()) {
          buffer.writeln(
            '"${record.username}",${record.steps},${record.convertedSteps},${record.hopeEarned.toStringAsFixed(1)},${record.hasBonusMultiplier ? "Evet" : "Hayır"},${_formatDateForCsv(record.date)}'
          );
        }
        break;
        
      case DashboardDetailType.referral:
        // Header
        buffer.writeln('Davet Eden,Davet Edilen,Bonus Adım,Kullanılan,Tarih');
        // Data
        for (var record in _records.cast<ReferralRecord>()) {
          buffer.writeln(
            '"${record.referrerUsername}","${record.referredUsername}",${record.bonusStepsGiven},${record.bonusStepsUsed},${_formatDateForCsv(record.referralDate)}'
          );
        }
        break;
        
      case DashboardDetailType.donation:
        // Header
        buffer.writeln('Kullanıcı,Vakıf/Kurum,Hope Miktarı,Tarih');
        // Data
        for (var record in _records.cast<DonationRecord>()) {
          buffer.writeln(
            '"${record.username}","${record.charityName}",${record.hopeAmount.toStringAsFixed(1)},${_formatDateForCsv(record.date)}'
          );
        }
        break;
    }
    
    return buffer.toString();
  }

  String _getExportFileName() {
    final dateStr = '${_startDate.year}${_startDate.month.toString().padLeft(2, '0')}${_startDate.day.toString().padLeft(2, '0')}';
    switch (widget.type) {
      case DashboardDetailType.dailySteps:
        return 'gunluk_adim_raporu_$dateStr.csv';
      case DashboardDetailType.carryover:
        return 'tasinan_adim_raporu_$dateStr.csv';
      case DashboardDetailType.referral:
        return 'referans_raporu_$dateStr.csv';
      case DashboardDetailType.donation:
        return 'bagis_raporu_$dateStr.csv';
    }
  }

  String _getExportSubject() {
    switch (widget.type) {
      case DashboardDetailType.dailySteps:
        return 'Bir Adım Umut - Günlük Adım Raporu';
      case DashboardDetailType.carryover:
        return 'Bir Adım Umut - Taşınan Adım Raporu';
      case DashboardDetailType.referral:
        return 'Bir Adım Umut - Referans Raporu';
      case DashboardDetailType.donation:
        return 'Bir Adım Umut - Bağış Raporu';
    }
  }

  String _formatDateForCsv(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      String result = '';
      String numStr = number.toString();
      int count = 0;
      for (int i = numStr.length - 1; i >= 0; i--) {
        count++;
        result = numStr[i] + result;
        if (count % 3 == 0 && i > 0) {
          result = '.$result';
        }
      }
      return result;
    }
    return number.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Ay seçici widget
  Widget _buildMonthSelector() {
    final monthNames = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    
    return GestureDetector(
      onTap: _showMonthPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _getThemeColor().withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
          color: _getThemeColor().withOpacity(0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: _getThemeColor(), size: 20),
                const SizedBox(width: 8),
                Text(
                  '${monthNames[_selectedMonth - 1]} $_selectedYear',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getThemeColor(),
                  ),
                ),
              ],
            ),
            Icon(Icons.arrow_drop_down, color: _getThemeColor()),
          ],
        ),
      ),
    );
  }

  /// Ay seçici dialog
  void _showMonthPicker() {
    final monthNames = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ay Seçin'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Yıl seçimi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: tempYear > 2024 ? () {
                            setDialogState(() => tempYear--);
                          } : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '$tempYear',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: tempYear < DateTime.now().year ? () {
                            setDialogState(() => tempYear++);
                          } : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Ay grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (index) {
                        final month = index + 1;
                        final isSelected = month == tempMonth && tempYear == tempYear; // Seçili ay kontrolü
                        final isDisabled = tempYear == DateTime.now().year && month > DateTime.now().month;
                        
                        return GestureDetector(
                          onTap: isDisabled ? null : () {
                            setDialogState(() => tempMonth = month);
                          },
                          child: Container(
                            width: 70,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? _getThemeColor() 
                                  : (isDisabled ? Colors.grey[200] : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                monthNames[index].substring(0, 3),
                                style: TextStyle(
                                  color: isSelected 
                                      ? Colors.white 
                                      : (isDisabled ? Colors.grey[400] : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedFilter = DateFilterType.monthly;
                  _selectedMonth = tempMonth;
                  _selectedYear = tempYear;
                  // Seçili ayın başı ve sonu
                  _startDate = DateTime(tempYear, tempMonth, 1);
                  // Ayın son günü
                  _endDate = DateTime(tempYear, tempMonth + 1, 0, 23, 59, 59);
                  // Eğer şu anki aysa, bugüne kadar
                  final now = DateTime.now();
                  if (tempYear == now.year && tempMonth == now.month) {
                    _endDate = now;
                  }
                });
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _getThemeColor()),
              child: const Text('Tamam', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
