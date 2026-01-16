import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'package:intl/intl.dart';

/// Firebase'den gelen verileri güvenli şekilde Map<String, dynamic>'e dönüştür
Map<String, dynamic> _convertToStringDynamicMap(dynamic data) {
  if (data == null) return {};
  if (data is Map<String, dynamic>) return data;
  if (data is Map) {
    return data.map((key, value) {
      final stringKey = key?.toString() ?? '';
      if (value is Map) {
        return MapEntry(stringKey, _convertToStringDynamicMap(value));
      } else if (value is List) {
        return MapEntry(stringKey, value.map((e) => e is Map ? _convertToStringDynamicMap(e) : e).toList());
      }
      return MapEntry(stringKey, value);
    });
  }
  return {};
}

/// Aylık Hope Değeri Yönetim Sayfası
/// - Aylık Hope/TL değerlerini gösterir
/// - Manuel hesaplama yapabilir
/// - Pending bağışları onaylayabilir
class AdminMonthlyHopeValueScreen extends StatefulWidget {
  const AdminMonthlyHopeValueScreen({super.key});

  @override
  State<AdminMonthlyHopeValueScreen> createState() => _AdminMonthlyHopeValueScreenState();
}

class _AdminMonthlyHopeValueScreenState extends State<AdminMonthlyHopeValueScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  bool _isCalculating = false;
  bool _isApproving = false;
  List<dynamic> _monthlyData = [];
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _adminService.getMonthlyHopeSummary();
      
      if (mounted && result['success'] == true) {
        setState(() {
          _monthlyData = result['data'] ?? [];
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Veri yükleme hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _calculateMonth(String monthKey) async {
    setState(() => _isCalculating = true);
    
    try {
      final result = await _adminService.calculateMonthlyHopeValue(monthKey);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Hesaplama tamamlandı'),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );
        
        if (result['success'] == true) {
          await _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCalculating = false);
      }
    }
  }

  Future<void> _approveDonations(String monthKey, {String? charityId}) async {
    // Onay dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bağışları Onayla'),
        content: Text(
          charityId != null 
            ? 'Seçili dernek için bağışlar onaylanacak ve aktarıma hazır olacak.'
            : '$monthKey ayındaki tüm bağışlar onaylanacak ve derneğe aktarıma hazır olacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isApproving = true);
    
    try {
      final result = await _adminService.approvePendingDonations(monthKey, charityId: charityId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Onay tamamlandı'),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );
        
        if (result['success'] == true) {
          await _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
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
        title: const Text('Aylık Hope Değeri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _monthlyData.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Açıklama kartı
                      _buildInfoCard(),
                      
                      const SizedBox(height: 20),
                      
                      // Manuel Hesaplama
                      _buildManualCalculationCard(),
                      
                      const SizedBox(height: 20),
                      
                      // Aylık Değerler Listesi
                      const Text(
                        'Aylık Hope Değerleri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      ..._monthlyData.map((data) => _buildMonthCard(data)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Henüz hesaplanmış ay yok',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Her ayın 7\'sinde otomatik hesaplanır\nveya manuel hesaplama yapabilirsiniz',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showMonthPicker(),
            icon: const Icon(Icons.calculate),
            label: const Text('Manuel Hesapla'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Hope Değeri Sistemi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Formül: 1 Hope = (Aylık Reklam Geliri × %60) ÷ Üretilen Hope',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '• Her ayın 7\'sinde otomatik hesaplanır\n'
            '• Bağışlar "Pending" durumunda bekler\n'
            '• Hesaplama sonrası TL değeri belirlenir\n'
            '• Admin onayı ile derneğe aktarılır',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildManualCalculationCard() {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final defaultMonthKey = '${previousMonth.year}-${previousMonth.month.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate, color: Color(0xFF1E3A5F)),
              SizedBox(width: 8),
              Text(
                'Manuel Hesaplama',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMonth ?? defaultMonthKey,
                  decoration: InputDecoration(
                    labelText: 'Ay Seçin',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _getLast12Months().map((month) {
                    return DropdownMenuItem(
                      value: month,
                      child: Text(_formatMonthDisplay(month)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedMonth = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isCalculating 
                    ? null 
                    : () => _calculateMonth(_selectedMonth ?? defaultMonthKey),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                child: _isCalculating
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Hesapla'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCard(dynamic data) {
    // Firebase'den gelen veriyi güvenli şekilde dönüştür
    final safeData = _convertToStringDynamicMap(data);
    final month = safeData['month']?.toString() ?? '';
    final hopeValueTl = ((safeData['hope_value_tl'] ?? 0) as num).toDouble();
    final totalAdRevenueTl = ((safeData['total_ad_revenue_tl'] ?? 0) as num).toDouble();
    final donationPoolTl = ((safeData['donation_pool_tl'] ?? 0) as num).toDouble();
    final totalHopeProduced = ((safeData['total_hope_produced'] ?? 0) as num).toInt();
    final status = safeData['status']?.toString() ?? 'calculated';
    final pendingDonations = _convertToStringDynamicMap(safeData['pendingDonations']);
    final pendingCount = ((pendingDonations['totalCount'] ?? 0) as num).toInt();
    final charityBreakdown = _convertToStringDynamicMap(pendingDonations['charityBreakdown']);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Onaylandı';
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'Tamamlandı';
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Hesaplandı';
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMonthDisplay(month),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Hope Değeri
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[100]!, Colors.green[50]!],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1 Hope Değeri',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '₺${hopeValueTl.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // İstatistikler
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Reklam Geliri',
                        '₺${NumberFormat('#,###').format(totalAdRevenueTl.toInt())}',
                        Icons.ads_click,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        'Bağış Havuzu',
                        '₺${NumberFormat('#,###').format(donationPoolTl.toInt())}',
                        Icons.savings,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                _buildStatItem(
                  'Üretilen Hope',
                  NumberFormat('#,###').format(totalHopeProduced),
                  Icons.auto_awesome,
                  Colors.purple,
                ),
                
                // Pending Bağışlar
                if (pendingCount > 0) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Bekleyen Bağışlar ($pendingCount)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  ...charityBreakdown.entries.map((entry) {
                    final charityData = _convertToStringDynamicMap(entry.value);
                    final charityName = charityData['charityName']?.toString() ?? 'Bilinmeyen';
                    final hope = ((charityData['hope'] ?? 0) as num).toDouble();
                    final tl = ((charityData['tl'] ?? 0) as num).toDouble();
                    final count = ((charityData['count'] ?? 0) as num).toInt();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  charityName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '$count bağış • ${NumberFormat('#,###').format(hope.toInt())} Hope • ₺${tl.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            onPressed: _isApproving 
                                ? null 
                                : () => _approveDonations(month, charityId: entry.key),
                            tooltip: 'Bu derneği onayla',
                          ),
                        ],
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 8),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isApproving ? null : () => _approveDonations(month),
                      icon: _isApproving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle),
                      label: const Text('Tüm Bağışları Onayla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getLast12Months() {
    final List<String> months = [];
    final now = DateTime.now();
    
    for (int i = 1; i <= 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }
    
    return months;
  }

  String _formatMonthDisplay(String monthKey) {
    if (monthKey.isEmpty) return '';
    
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final date = DateTime(year, month);
      
      final months = [
        '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
      ];
      
      return '${months[month]} $year';
    } catch (e) {
      return monthKey;
    }
  }

  void _showMonthPicker() {
    final defaultMonth = _getLast12Months().first;
    _selectedMonth = defaultMonth;
    _calculateMonth(defaultMonth);
  }
}
