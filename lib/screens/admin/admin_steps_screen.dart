import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../services/admin_service.dart';

/// Adım istatistikleri ekranı
class AdminStepsScreen extends StatefulWidget {
  const AdminStepsScreen({super.key});

  @override
  State<AdminStepsScreen> createState() => _AdminStepsScreenState();
}

class _AdminStepsScreenState extends State<AdminStepsScreen> {
  final AdminService _adminService = AdminService();
  
  bool _isLoading = true;
  Map<String, dynamic> _detailedStats = {};
  Map<String, dynamic> _dateStats = {};
  
  // Tarih seçimi için
  bool _isDateMode = false; // false = Genel, true = Tarih bazlı
  String _dateViewMode = 'daily'; // 'daily' veya 'monthly'
  DateTime _selectedDate = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    // Türkçe date formatting için locale'i başlat
    initializeDateFormatting('tr_TR', null).then((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Detaylı istatistikler
      final detailed = await _adminService.getDetailedStepStats();
      
      if (mounted) {
        setState(() {
          _detailedStats = detailed;
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
  
  Future<void> _loadDateStats() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> stats;
      
      if (_dateViewMode == 'daily') {
        stats = await _adminService.getStatsForDate(_selectedDate);
      } else {
        stats = await _adminService.getStatsForMonth(_selectedYear, _selectedMonth);
      }
      
      if (mounted) {
        setState(() {
          _dateStats = stats;
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
  
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDateStats();
    }
  }
  
  void _selectMonth() {
    showDialog(
      context: context,
      builder: (context) {
        int tempMonth = _selectedMonth;
        int tempYear = _selectedYear;
        
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
                    // Ay grid - Wrap ile daha güvenli
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (index) {
                        final month = index + 1;
                        final isSelected = month == tempMonth;
                        final isDisabled = tempYear == DateTime.now().year && month > DateTime.now().month;
                        
                        return GestureDetector(
                          onTap: isDisabled ? null : () {
                            setDialogState(() => tempMonth = month);
                          },
                          child: Container(
                            width: 60,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : (isDisabled ? Colors.grey[200] : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getMonthName(month),
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isDisabled ? Colors.grey : Colors.black),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                setState(() {
                  _selectedMonth = tempMonth;
                  _selectedYear = tempYear;
                });
                Navigator.pop(context);
                _loadDateStats();
              },
              child: const Text('Seç'),
            ),
          ],
        );
      },
    );
  }
  
  String _getMonthName(int month) {
    const monthNames = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return monthNames[month - 1];
  }
  
  String _getFullMonthName(int month) {
    const monthNames = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return monthNames[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Mobil uyumlu
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adım & Hope İstatistikleri',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Detaylı adım ve Hope dönüşüm raporları',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Mod seçimi (Genel / Tarih Bazlı)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Rapor Modu',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Toggle butonları - tam genişlik
                SizedBox(
                  width: double.infinity,
                  child: ToggleButtons(
                    isSelected: [!_isDateMode, _isDateMode],
                    onPressed: (index) {
                      setState(() {
                        _isDateMode = index == 1;
                        if (_isDateMode && _dateStats.isEmpty) {
                          _loadDateStats();
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Colors.white,
                    fillColor: Colors.blue,
                    constraints: BoxConstraints(
                      minHeight: 36,
                      minWidth: (MediaQuery.of(context).size.width - 80) / 2,
                    ),
                    children: const [
                      Text('Genel'),
                      Text('Tarih Bazlı'),
                    ],
                  ),
                ),
                
                // Tarih seçim paneli
                if (_isDateMode) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  // Günlük/Aylık seçimi - Mobil uyumlu Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ToggleButtons(
                        isSelected: [_dateViewMode == 'daily', _dateViewMode == 'monthly'],
                        onPressed: (index) {
                          setState(() {
                            _dateViewMode = index == 0 ? 'daily' : 'monthly';
                          });
                          _loadDateStats();
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: Colors.green,
                        constraints: BoxConstraints(
                          minHeight: 36,
                          minWidth: (MediaQuery.of(context).size.width - 80) / 2,
                        ),
                        children: const [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.today, size: 16),
                              SizedBox(width: 4),
                              Text('Günlük'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month, size: 16),
                              SizedBox(width: 4),
                              Text('Aylık'),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Tarih seçici buton
                      if (_dateViewMode == 'daily')
                        ElevatedButton.icon(
                          onPressed: _selectDate,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            DateFormat('d MMMM yyyy', 'tr_TR').format(_selectedDate),
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _selectMonth,
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: Text(
                            '${_getFullMonthName(_selectedMonth)} $_selectedYear',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_isDateMode)
            _buildDateStats()
          else ...[
            // ==================== 1. GÜNLÜK ADIMLAR (00:00 - 23:59) ====================
            _buildSectionHeader(
              'Günlük Adımlar (00:00 - 23:59)',
              Icons.today,
              Colors.blue,
              'Bugün cihazdan aktarılan adım verileri',
            ),
            const SizedBox(height: 12),
            
            // Mobil uyumlu GridView
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Toplam Adım',
                  _formatNumber(_detailedStats['today_total_steps'] ?? 0),
                  Icons.directions_walk,
                  Colors.blue,
                  'Bugün aktarılan',
                ),
                _buildStatCard(
                  'Dönüştürülen',
                  _formatNumber(_detailedStats['today_converted_steps'] ?? 0),
                  Icons.swap_horiz,
                  Colors.green,
                  'Hope\'a çevrilen',
                ),
                _buildStatCard(
                  'Bekleyen',
                  _formatNumber(_detailedStats['today_pending_steps'] ?? 0),
                  Icons.hourglass_empty,
                  Colors.orange,
                  'Henüz dönüştürülmemiş',
                ),
                _buildStatCard(
                  'Kazanılan Hope',
                  '${(_detailedStats['today_hope_earned'] ?? 0).toStringAsFixed(1)} H',
                  Icons.stars,
                  Colors.amber,
                  'Bugün kazanılan',
                ),
                _buildStatCard(
                  'Normal Hope (1x)',
                  '${(_detailedStats['today_hope_normal'] ?? 0).toStringAsFixed(1)} H',
                  Icons.star_outline,
                  Colors.grey,
                  'Normal dönüşüm',
                ),
                _buildStatCard(
                  'Bonus Hope (2x)',
                  '${(_detailedStats['today_hope_bonus'] ?? 0).toStringAsFixed(1)} H',
                  Icons.star,
                  Colors.deepOrange,
                  '2x bonus',
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ==================== 2. AKTARILAN ADIMLAR (CARRY-OVER) ====================
            _buildSectionHeader(
              'Taşınan Adımlar (Carry-Over)',
              Icons.history,
              Colors.orange,
              'Gece 00:00\'da aktarılan dönüştürülmemiş adımlar (Ay sonuna kadar geçerli)',
            ),
            const SizedBox(height: 12),
            
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Toplam Aktarılan',
                  _formatNumber(_detailedStats['carryover_total_steps'] ?? 0),
                  Icons.move_down,
                  Colors.purple,
                  'Bu aydan',
                ),
                _buildStatCard(
                  'Dönüştürülen',
                  _formatNumber(_detailedStats['carryover_converted_steps'] ?? 0),
                  Icons.check_circle,
                  Colors.green,
                  'Aktarılandan',
                ),
                _buildStatCard(
                  'Bekleyen',
                  _formatNumber(_detailedStats['carryover_pending_steps'] ?? 0),
                  Icons.schedule,
                  Colors.orange,
                  'Dönüştürülmeyi bekleyen',
                ),
                _buildStatCard(
                  'Aktarılan Hope',
                  '${(_detailedStats['carryover_hope_earned'] ?? 0).toStringAsFixed(1)} H',
                  Icons.stars,
                  Colors.amber,
                  'Aktarılandan kazanılan',
                ),
                _buildStatCard(
                  'Süresi Dolan',
                  _formatNumber(_detailedStats['carryover_expired_steps'] ?? 0),
                  Icons.delete_forever,
                  Colors.red,
                  'Önceki aydan silinen',
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ==================== 3. BONUS ADIMLAR (DAVET/REFERRAL) ====================
            _buildSectionHeader(
              'Bonus Adımlar (Davet/Referral)',
              Icons.card_giftcard,
              const Color(0xFF6EC6B5), // Turkuaz
              'Davet bonusu olarak verilen adımlar (Süresiz geçerli)',
            ),
            const SizedBox(height: 12),
            
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Toplam Davet',
                  _formatNumber(_detailedStats['total_referral_count'] ?? 0),
                  Icons.people,
                  Colors.teal,
                  'Başarılı davet sayısı',
                ),
                _buildStatCard(
                  'Verilen Bonus',
                  _formatNumber(_detailedStats['total_bonus_steps'] ?? 0),
                  Icons.card_giftcard,
                  Colors.indigo,
                  'Verilen bonus adım',
                ),
                _buildStatCard(
                  'Dönüştürülen',
                  _formatNumber(_detailedStats['total_bonus_converted'] ?? 0),
                  Icons.redeem,
                  Colors.green,
                  'Hope\'a çevrilen bonus',
                ),
                _buildStatCard(
                  'Kalan Bonus',
                  _formatNumber(_detailedStats['total_bonus_pending'] ?? 0),
                  Icons.savings,
                  Colors.orange,
                  'Henüz kullanılmamış',
                ),
                _buildStatCard(
                  'Bonus Hope',
                  '${(_detailedStats['bonus_hope_earned'] ?? 0).toStringAsFixed(1)} H',
                  Icons.stars,
                  Colors.amber,
                  'Bonuslardan kazanılan',
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ==================== GENEL İSTATİSTİKLER ====================
            _buildSectionHeader(
              'Genel Toplam İstatistikler',
              Icons.analytics,
              Colors.blueGrey,
              'Tüm zamanların özeti',
            ),
            const SizedBox(height: 12),
            
            // Tüm istatistikler GridView
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Toplam Adım',
                  _formatNumber(_detailedStats['total_daily_steps'] ?? 0),
                  Icons.directions_walk,
                  Colors.teal,
                  'Tüm zamanlar',
                ),
                _buildStatCard(
                  'Dönüştürülen',
                  _formatNumber(_detailedStats['total_converted_steps'] ?? 0),
                  Icons.swap_horiz,
                  Colors.green,
                  'Hope\'a çevrilen',
                ),
                _buildStatCard(
                  'Bekleyen',
                  _formatNumber(_detailedStats['total_pending_steps'] ?? 0),
                  Icons.hourglass_empty,
                  Colors.orange,
                  'Henüz dönüştürülmemiş',
                ),
                _buildStatCard(
                  'Toplam Hope',
                  '${_formatNumber((_detailedStats['total_hope_converted'] ?? 0).toInt())} H',
                  Icons.stars,
                  Colors.amber,
                  'Üretilen toplam Hope',
                ),
                _buildStatCard(
                  'Cüzdanlarda',
                  '${_formatNumber((_detailedStats['total_hope_in_wallets'] ?? 0).toInt())} H',
                  Icons.account_balance_wallet,
                  Colors.blue,
                  'Kullanıcı bakiyeleri',
                ),
                _buildStatCard(
                  'Bağışlanan',
                  '${_formatNumber((_detailedStats['total_hope_donated'] ?? 0).toInt())} H',
                  Icons.volunteer_activism,
                  Colors.red,
                  'Vakıf/Topluluk/Birey',
                ),
                _buildStatCard(
                  'Bugün Aktif',
                  _formatNumber(_detailedStats['active_users_today'] ?? 0),
                  Icons.person_outline,
                  Colors.cyan,
                  'Bugün adım kaydeden',
                ),
                _buildStatCard(
                  'Toplam Kullanıcı',
                  _formatNumber(_detailedStats['total_users'] ?? 0),
                  Icons.group,
                  Colors.blueGrey,
                  'Kayıtlı kullanıcılar',
                ),
                _buildStatCard(
                  'Ort. Hope',
                  '${((_detailedStats['total_hope_converted'] ?? 0) / ((_detailedStats['total_users'] ?? 1) > 0 ? _detailedStats['total_users'] : 1)).toStringAsFixed(1)} H',
                  Icons.analytics,
                  Colors.lime,
                  'Kullanıcı başına',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  // Tarih bazlı istatistikler widget'ı
  Widget _buildDateStats() {
    final isDaily = _dateViewMode == 'daily';
    final dateTitle = isDaily 
        ? DateFormat('d MMMM yyyy', 'tr_TR').format(_selectedDate)
        : '${_getFullMonthName(_selectedMonth)} $_selectedYear';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tarih Başlığı
        _buildSectionHeader(
          isDaily ? 'Günlük: $dateTitle' : 'Aylık: $dateTitle',
          isDaily ? Icons.today : Icons.calendar_month,
          Colors.blue,
          isDaily ? 'Seçili güne ait tüm istatistikler' : 'Seçili aya ait tüm istatistikler',
        ),
        const SizedBox(height: 16),
        
        // Adım İstatistikleri
        _buildSectionHeader(
          'Adım İstatistikleri',
          Icons.directions_walk,
          Colors.teal,
          'Toplam adım ve dönüşüm verileri',
        ),
        const SizedBox(height: 12),
        
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Toplam Adım',
              _formatNumber(_dateStats['total_steps'] ?? 0),
              Icons.directions_walk,
              Colors.blue,
              isDaily ? 'O gün atılan' : 'Ay boyunca atılan',
            ),
            _buildStatCard(
              'Dönüştürülen',
              _formatNumber(_dateStats['converted_steps'] ?? 0),
              Icons.swap_horiz,
              Colors.green,
              'Hope\'a çevrilen',
            ),
            _buildStatCard(
              'Bekleyen',
              _formatNumber(_dateStats['pending_steps'] ?? 0),
              Icons.hourglass_empty,
              Colors.orange,
              'Henüz dönüştürülmemiş',
            ),
            _buildStatCard(
              'Silinen/Aktarılan',
              _formatNumber(_dateStats['deleted_carry_over'] ?? 0),
              Icons.delete_sweep,
              Colors.red,
              'Carry-over silinen',
            ),
            _buildStatCard(
              'Hope Kazanılan',
              '${(_dateStats['total_hope_converted'] ?? 0).toStringAsFixed(1)} H',
              Icons.stars,
              Colors.amber,
              'Dönüşümden kazanılan',
            ),
            _buildStatCard(
              'Dönüşüm Oranı',
              '%${_dateStats['conversion_rate'] ?? '0'}',
              Icons.percent,
              Colors.cyan,
              'Adım → Hope oranı',
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Bağış İstatistikleri
        _buildSectionHeader(
          'Bağış İstatistikleri',
          Icons.volunteer_activism,
          Colors.pink,
          'Hope bağış aktiviteleri',
        ),
        const SizedBox(height: 12),
        
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Bağış Sayısı',
              _formatNumber(_dateStats['donation_count'] ?? 0),
              Icons.favorite,
              Colors.pink,
              'Yapılan bağış',
            ),
            _buildStatCard(
              'Bağış Miktarı',
              '${(_dateStats['donation_amount'] ?? 0).toStringAsFixed(1)} H',
              Icons.volunteer_activism,
              Colors.red,
              'Bağışlanan toplam Hope',
            ),
            _buildStatCard(
              'Dönüşüm Sayısı',
              _formatNumber(_dateStats['conversion_count'] ?? 0),
              Icons.transform,
              Colors.purple,
              'Adım → Hope dönüşümü',
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Kullanıcı İstatistikleri
        _buildSectionHeader(
          'Kullanıcı İstatistikleri',
          Icons.people,
          Colors.indigo,
          'Aktif kullanıcı verileri',
        ),
        const SizedBox(height: 12),
        
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Aktif Kullanıcı',
              _formatNumber(_dateStats['active_users'] ?? 0),
              Icons.person,
              Colors.indigo,
              isDaily ? 'O gün aktif' : 'Ay boyunca aktif',
            ),
            _buildStatCard(
              'Ort. Adım',
              _formatNumber((_dateStats['active_users'] ?? 0) > 0 
                  ? ((_dateStats['total_steps'] ?? 0) / (_dateStats['active_users'] ?? 1)).toInt() 
                  : 0),
              Icons.trending_up,
              Colors.teal,
              'Kullanıcı başına',
            ),
            _buildStatCard(
              'Ort. Hope',
              ((_dateStats['active_users'] ?? 0) > 0 
                  ? ((_dateStats['total_hope_converted'] ?? 0) / (_dateStats['active_users'] ?? 1))
                  : 0).toStringAsFixed(1),
              Icons.star,
              Colors.amber,
              'Kullanıcı başına',
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Özet Bilgi Kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.purple.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.summarize, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    isDaily ? 'Gün Özeti' : 'Ay Özeti',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isDaily 
                    ? '📅 $dateTitle\n'
                      '👥 Aktif: ${_dateStats['active_users'] ?? 0}\n'
                      '🚶 Adım: ${_formatNumber(_dateStats['total_steps'] ?? 0)}\n'
                      '✨ Hope: ${(_dateStats['total_hope_converted'] ?? 0).toStringAsFixed(1)} H\n'
                      '❤️ ${_formatNumber(_dateStats['donation_count'] ?? 0)} bağış (${(_dateStats['donation_amount'] ?? 0).toStringAsFixed(1)} H)'
                    : '📅 $dateTitle\n'
                      '👥 Aktif: ${_dateStats['active_users'] ?? 0}\n'
                      '🚶 Adım: ${_formatNumber(_dateStats['total_steps'] ?? 0)}\n'
                      '✨ Üretilen Hope: ${(_dateStats['total_hope_converted'] ?? 0).toStringAsFixed(1)} H\n'
                      '❤️ Yapılan Bağış: ${_formatNumber(_dateStats['donation_count'] ?? 0)} adet (${(_dateStats['donation_amount'] ?? 0).toStringAsFixed(1)} H)',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, color: color, size: 12),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
}
