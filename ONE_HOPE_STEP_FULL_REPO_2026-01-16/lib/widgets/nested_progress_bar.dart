import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

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
    final lang = context.watch<LanguageProvider>();
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
                  Text(
                    lang.dailyStepGoal,
                    style: const TextStyle(
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
                      ? const Color(0xFF6EC6B5).withOpacity(0.1)
                      : const Color(0xFFE07A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  totalSteps >= dailyGoal
                      ? lang.goalCompleted
                      : lang.stepsRemaining(dailyGoal - totalSteps),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: totalSteps >= dailyGoal
                        ? const Color(0xFF6EC6B5)
                        : const Color(0xFFE07A5F),
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
                  lang.carryOverStepsLabel(carryOverSteps),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange,
                  ),
                ),
                const Spacer(),
                Text(
                  lang.use7Days,
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
                  backgroundColor: const Color(0xFF6EC6B5).withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6EC6B5)),
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
                        const AlwaysStoppedAnimation<Color>(Color(0xFFE07A5F)),
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
                  Text(
                    lang.convertedLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    lang.stepsAmount(convertedSteps),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6EC6B5),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    lang.convertibleLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    lang.stepsAmount(availableSteps),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE07A5F),
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
                backgroundColor: const Color(0xFF6EC6B5),
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
                        Text(
                          lang.convertStepsToHope,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (availableSteps > 0)
                          Text(
                            lang.canEarnHope(((availableSteps > 2500 ? 2500 : availableSteps) / 100.0).toStringAsFixed(0)),
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
                    Text(
                      lang.convertCarryOverSteps,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      lang.stepsWaiting(carryOverSteps, ((carryOverSteps > 2500 ? 2500 : carryOverSteps) / 2500 * 0.10).toStringAsFixed(2)),
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
                      lang.minutesUntilNextConversion(minutesUntilConversion!),
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
                color: const Color(0xFF6EC6B5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF6EC6B5).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF6EC6B5),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang.watchAdRequired,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE07A5F),
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
