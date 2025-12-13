import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

/// İç İçe Progress Bar Widget (Dashboard)
/// 
/// En Dış Progress Bar: Taşınan (Carry-over) Adımlar - Turuncu
/// Orta Progress Bar: Günlük Adım (Hedef 15K) - Mavi
/// İç Progress Bar: Dönüştürülen Adım - Yeşil
class NestedProgressBar extends StatelessWidget {
  final int totalSteps;
  final int convertedSteps;
  final int carryOverSteps; // Taşınan adımlar
  final int dailyGoal;
  final VoidCallback onConvertPress;
  final VoidCallback? onCarryOverConvertPress; // Taşınan adımları dönüştür
  final bool isLoading;
  final int? minutesUntilConversion; // Cooldown kalan dakika

  const NestedProgressBar({
    Key? key,
    required this.totalSteps,
    required this.convertedSteps,
    this.carryOverSteps = 0,
    this.dailyGoal = 15000,
    required this.onConvertPress,
    this.onCarryOverConvertPress,
    required this.isLoading,
    this.minutesUntilConversion,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalPercent = (totalSteps / dailyGoal).clamp(0.0, 1.0);
    final convertedPercent = (convertedSteps / dailyGoal).clamp(0.0, 1.0);
    final carryOverPercent = (carryOverSteps / dailyGoal).clamp(0.0, 1.0);
    final availableSteps = totalSteps - convertedSteps;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Günlük Adım Hedefi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalSteps / $dailyGoal',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Hedef durumu
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: totalSteps >= dailyGoal
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  totalSteps >= dailyGoal
                      ? '✅ Hedef Tamamlandı!'
                      : '${dailyGoal - totalSteps} adım kaldı',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: totalSteps >= dailyGoal
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Taşınan Adımlar Progress Bar (varsa)
          if (carryOverSteps > 0) ...[
            Row(
              children: [
                const Icon(Icons.history, size: 16, color: Colors.deepOrange),
                const SizedBox(width: 6),
                Text(
                  'Taşınan Adımlar: $carryOverSteps',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange,
                  ),
                ),
                const Spacer(),
                Text(
                  '7 gün içinde kullan!',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: carryOverPercent,
                minHeight: 16,
                backgroundColor: Colors.deepOrange.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // İç İçe Progress Bar (Günlük)
          Stack(
            children: [
              // Dış Progress Bar (Total)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: totalPercent,
                  minHeight: 28,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              // İç Progress Bar (Dönüştürülen) - üzerine çakışmış
              Positioned(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: convertedPercent,
                    minHeight: 28,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              ),
              // Merkezdeki yüzde metni
              Positioned.fill(
                child: Center(
                  child: Text(
                    '${(totalPercent * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Açıklama
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dönüştürülen',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '$convertedSteps adım',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Dönüştürülebilir',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '$availableSteps adım',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Dönüştür Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading || minutesUntilConversion! > 0
                  ? null
                  : onConvertPress,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Column(
                      children: [
                        const Text(
                          'Adımları Hope\'e Dönüştür',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (availableSteps > 0)
                          Text(
                            '${((availableSteps > 2500 ? 2500 : availableSteps) / 2500 * 0.10).toStringAsFixed(2)} Hope kazanabilirsin',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
            ),
          ),

          // Taşınan Adımları Dönüştür Butonu
          if (carryOverSteps > 0 && onCarryOverConvertPress != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isLoading || minutesUntilConversion! > 0
                    ? null
                    : onCarryOverConvertPress,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepOrange,
                  side: const BorderSide(color: Colors.deepOrange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🔥 Taşınan Adımları Dönüştür',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$carryOverSteps adım bekliyor (${((carryOverSteps > 2500 ? 2500 : carryOverSteps) / 2500 * 0.10).toStringAsFixed(2)} Hope)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.deepOrange.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Cooldown Uyarısı
          if (minutesUntilConversion! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sonraki dönüştürmeye $minutesUntilConversion dakika kaldı',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Zorunlu Reklam Uyarısı
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dönüştürmek için bir reklam izlemeniz gerekmektedir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
