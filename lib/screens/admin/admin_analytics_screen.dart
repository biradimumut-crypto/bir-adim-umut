import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../models/admin_stats_model.dart';

/// Analitik ekranı - İndirme ve Reklam istatistikleri
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final AdminService _adminService = AdminService();
  
  bool _isLoading = true;
  AdminStatsModel? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _adminService.getAdminStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showUpdateStatsDialog() {
    final iosController = TextEditingController(text: (_stats?.iosDownloads ?? 0).toString());
    final androidController = TextEditingController(text: (_stats?.androidDownloads ?? 0).toString());
    final adRevenueController = TextEditingController(text: (_stats?.adRevenue ?? 0).toStringAsFixed(2));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Platform İstatistiklerini Güncelle'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bu veriler genellikle App Store Connect, Google Play Console ve AdMob\'dan alınır. '
                'Buradan manuel olarak güncelleyebilirsiniz.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: iosController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'iOS İndirme Sayısı',
                  prefixIcon: Icon(Icons.apple),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: androidController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Android İndirme Sayısı',
                  prefixIcon: Icon(Icons.android),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: adRevenueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Aylık Reklam Geliri (\$)',
                  prefixIcon: Icon(Icons.monetization_on),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('admin_stats').doc('current').set({
                  'ios_downloads': int.tryParse(iosController.text) ?? 0,
                  'android_downloads': int.tryParse(androidController.text) ?? 0,
                  'ad_revenue': double.tryParse(adRevenueController.text) ?? 0,
                  'updated_at': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                
                Navigator.pop(context);
                _loadStats();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('İstatistikler güncellendi ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
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
            children: const [
              Text(
                'Analitik & Gelir',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'İndirme sayıları ve reklam gelirleri',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Platform İndirme İstatistikleri
            const Text(
              'Uygulama İndirmeleri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Mobil uyumlu GridView
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
              children: [
                // iOS
                _buildPlatformCard(
                  'iOS',
                  Icons.apple,
                  _stats?.iosDownloads ?? 0,
                  Colors.grey[800]!,
                  'App Store',
                ),
                // Android
                _buildPlatformCard(
                  'Android',
                  Icons.android,
                  _stats?.androidDownloads ?? 0,
                  Colors.green[700]!,
                  'Google Play',
                ),
                // Toplam
                _buildPlatformCard(
                  'Toplam',
                  Icons.download,
                  (_stats?.iosDownloads ?? 0) + (_stats?.androidDownloads ?? 0),
                  Colors.blue,
                  'Tüm Platformlar',
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Uyarı kartı
            Card(
              color: Colors.amber.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Not: İndirme Verileri',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'İndirme sayıları App Store Connect ve Google Play Console\'dan alınır.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Reklam Gelirleri
            const Text(
              'Reklam Gelirleri (AdMob)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
              children: [
                _buildRevenueCard(
                  'Günlük Gelir',
                  (_stats?.adRevenue ?? 0) / 30,
                  Icons.today,
                  Colors.green,
                ),
                _buildRevenueCard(
                  'Haftalık Gelir',
                  (_stats?.adRevenue ?? 0) / 4,
                  Icons.date_range,
                  Colors.blue,
                ),
                _buildRevenueCard(
                  'Aylık Gelir',
                  _stats?.adRevenue ?? 0,
                  Icons.calendar_month,
                  Colors.purple,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Reklam türleri
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reklam Türleri Bazında Gelir',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _buildAdTypeRow('Ödüllü Reklamlar', 0.65, Colors.green),
                    const SizedBox(height: 10),
                    _buildAdTypeRow('Geçiş Reklamları', 0.25, Colors.blue),
                    const SizedBox(height: 10),
                    _buildAdTypeRow('Banner Reklamlar', 0.10, Colors.orange),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 📊 Gerçek Reklam İstatistikleri (ad_logs'tan)
            const Text(
              'Reklam Gösterim İstatistikleri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Firestore ad_logs koleksiyonundan',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),
            
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.9,
              children: [
                _buildAdStatCard(
                  'Interstitial',
                  _stats?.totalInterstitialAds ?? 0,
                  Icons.rectangle_outlined,
                  Colors.blue,
                ),
                _buildAdStatCard(
                  'Rewarded',
                  _stats?.totalRewardedAds ?? 0,
                  Icons.star_outline,
                  Colors.amber,
                ),
                _buildAdStatCard(
                  'Tamamlanan',
                  _stats?.totalRewardedCompleted ?? 0,
                  Icons.check_circle_outline,
                  Colors.green,
                ),
                _buildAdStatCard(
                  'Bonus Hope',
                  _stats?.totalRewardedHope.toInt() ?? 0,
                  Icons.favorite_outline,
                  Colors.pink,
                ),
                _buildAdStatCard(
                  'Bugün',
                  _stats?.todayAdsWatched ?? 0,
                  Icons.today,
                  Colors.purple,
                ),
                _buildAdStatCard(
                  'Tamamlanma %',
                  _stats != null && _stats!.totalRewardedAds > 0
                      ? (_stats!.totalRewardedCompleted * 100 ~/ _stats!.totalRewardedAds)
                      : 0,
                  Icons.percent,
                  Colors.teal,
                  isPercentage: true,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Uyarı kartı
            Card(
              color: Colors.blue.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.monetization_on, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Not: Reklam Gelirleri',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Reklam gelirleri AdMob konsolundan alınır.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Hızlı Linkler
            const Text(
              'Hızlı Erişim',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildQuickLink(
                  'App Store Connect',
                  Icons.apple,
                  'https://appstoreconnect.apple.com',
                  Colors.grey[800]!,
                ),
                _buildQuickLink(
                  'Google Play Console',
                  Icons.android,
                  'https://play.google.com/console',
                  Colors.green,
                ),
                _buildQuickLink(
                  'Firebase Console',
                  Icons.local_fire_department,
                  'https://console.firebase.google.com',
                  Colors.orange,
                ),
                _buildQuickLink(
                  'AdMob',
                  Icons.monetization_on,
                  'https://admob.google.com',
                  Colors.blue,
                ),
                _buildQuickLink(
                  'Firebase Analytics',
                  Icons.analytics,
                  'https://analytics.google.com/analytics/web/',
                  Colors.purple,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformCard(String title, IconData icon, int downloads, Color color, String subtitle) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _formatNumber(downloads),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(String title, double amount, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Icon(Icons.trending_up, color: Colors.green[400], size: 16),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdTypeRow(String title, double percentage, Color color) {
    final amount = (_stats?.adRevenue ?? 0) * percentage;
    
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(title),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 100,
          child: Text(
            '\$${amount.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            '${(percentage * 100).toInt()}%',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLink(String title, IconData icon, String url, Color color) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          // URL açma işlemi - url_launcher kullanılabilir
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$url açılıyor...')),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.open_in_new, color: color, size: 12),
            ],
          ),
        ),
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

  Widget _buildAdStatCard(String title, int value, IconData icon, Color color, {bool isPercentage = false}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isPercentage ? '$value%' : _formatNumber(value),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
