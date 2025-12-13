import 'package:flutter/material.dart';

/// Adım Takibi Ekranı
class StepsScreen extends StatefulWidget {
  const StepsScreen({Key? key}) : super(key: key);

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  int _todaySteps = 0;
  double _convertibleHope = 0;
  bool _canConvert = true;
  
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adımlarım',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bugünkü adımlarını takip et ve Hope kazan!',
              style: TextStyle(color: Colors.grey[600]),
            ),
            
            const SizedBox(height: 24),
            
            // Adım Göstergesi
            _buildStepCircle(),
            
            const SizedBox(height: 24),
            
            // İstatistikler
            Row(
              children: [
                Expanded(child: _buildStatCard(
                  icon: Icons.local_fire_department,
                  value: '${(_todaySteps * 0.04).toStringAsFixed(0)}',
                  label: 'Kalori',
                  color: Colors.orange,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(
                  icon: Icons.straighten,
                  value: '${(_todaySteps * 0.0008).toStringAsFixed(2)}',
                  label: 'Km',
                  color: Colors.blue,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(
                  icon: Icons.timer,
                  value: '${(_todaySteps / 100).toStringAsFixed(0)}',
                  label: 'Dakika',
                  color: Colors.green,
                )),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Dönüştür Butonu
            _buildConvertSection(),
            
            const SizedBox(height: 24),
            
            // Bilgi Kartı
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle() {
    const double goal = 10000;
    double progress = _todaySteps / goal;
    if (progress > 1) progress = 1;
    
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                progress >= 1 ? Colors.green : Colors.blue[600],
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_walk,
                size: 32,
                color: Colors.blue[600],
              ),
              const SizedBox(height: 8),
              Text(
                '$_todaySteps',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'adım',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hedef: ${goal.toInt()}',
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

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConvertSection() {
    _convertibleHope = _todaySteps / 1000; // Her 1000 adım = 1 Hope
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dönüştürülebilir',
                style: TextStyle(color: Colors.white70),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_convertibleHope.toStringAsFixed(1)} H',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canConvert && _convertibleHope > 0
                  ? _handleConvert
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.purple[600],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sync),
                  const SizedBox(width: 8),
                  Text(
                    _canConvert ? 'Hope\'a Dönüştür' : 'Bekleme Süresi Dolmadı',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_canConvert) ...[
            const SizedBox(height: 8),
            const Text(
              'Sonraki dönüştürme: 2 saat sonra',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Nasıl Çalışır?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('Her 1000 adım = 1 Hope puanı'),
          _buildInfoItem('Günde maksimum 10 Hope kazanabilirsiniz'),
          _buildInfoItem('Dönüştürme işlemi 4 saatte bir yapılabilir'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[600], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  void _handleConvert() {
    // TODO: Implement conversion logic with StepService
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_convertibleHope.toStringAsFixed(1)} Hope kazandınız! 🎉'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
