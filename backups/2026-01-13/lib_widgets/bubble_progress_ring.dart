import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Baloncuklu Gradient Progress Ring
/// - Arka plan: Mor-Pembe gradient (dönüştürülmemiş)
/// - Ön plan: Turkuaz-Mavi gradient (dönüştürülen)
/// - Baloncuk animasyonu
/// - Saat 12 yönünden başlar
class BubbleProgressRing extends StatefulWidget {
  final double progress; // 0.0 - 1.0 (dönüştürülen / toplam)
  final double size;
  final double strokeWidth;

  const BubbleProgressRing({
    Key? key,
    required this.progress,
    this.size = 200,
    this.strokeWidth = 20,
  }) : super(key: key);

  @override
  State<BubbleProgressRing> createState() => _BubbleProgressRingState();
}

class _BubbleProgressRingState extends State<BubbleProgressRing>
    with TickerProviderStateMixin {
  late AnimationController _bubbleController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  final List<Bubble> _bubbles = [];
  final math.Random _random = math.Random();
  double _currentProgress = 0;

  @override
  void initState() {
    super.initState();
    
    // Baloncuk animasyonu
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _bubbleController.addListener(() {
      _updateBubbles();
      if (mounted) setState(() {});
    });
    
    // Progress animasyonu
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));
    
    _progressController.forward();
    
    // Başlangıç baloncukları
    _initBubbles();
  }

  void _initBubbles() {
    for (int i = 0; i < 15; i++) {
      _bubbles.add(_createBubble());
    }
  }

  Bubble _createBubble() {
    return Bubble(
      angle: _random.nextDouble() * 2 * math.pi,
      radius: _random.nextDouble() * 0.3 + 0.7, // 0.7-1.0 (halka içinde)
      size: _random.nextDouble() * 6 + 3, // 3-9
      speed: _random.nextDouble() * 0.02 + 0.01,
      opacity: _random.nextDouble() * 0.5 + 0.3, // 0.3-0.8
    );
  }

  void _updateBubbles() {
    for (var bubble in _bubbles) {
      bubble.angle += bubble.speed;
      if (bubble.angle > 2 * math.pi) {
        bubble.angle -= 2 * math.pi;
      }
      // Rastgele parıldama
      bubble.opacity += (_random.nextDouble() - 0.5) * 0.05;
      bubble.opacity = bubble.opacity.clamp(0.2, 0.8);
    }
  }

  @override
  void didUpdateWidget(BubbleProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(
        begin: _currentProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ));
      _progressController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bubbleController, _progressController]),
      builder: (context, child) {
        _currentProgress = _progressAnimation.value;
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _BubbleRingPainter(
            progress: _currentProgress,
            strokeWidth: widget.strokeWidth,
            bubbles: _bubbles,
          ),
        );
      },
    );
  }
}

class Bubble {
  double angle;
  double radius;
  double size;
  double speed;
  double opacity;

  Bubble({
    required this.angle,
    required this.radius,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _BubbleRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final List<Bubble> bubbles;

  _BubbleRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.bubbles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    // Başlangıç açısı: Saat 12 yönü (-90 derece = -π/2)
    const startAngle = -math.pi / 2;
    
    // 1. ARKA PLAN - Mor-Pembe gradient (tüm halka)
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [
          Color(0xFFE07A5F), // Mor
          Color(0xFFF2C94C), // Pembe
          Color(0xFFE07A5F), // Mor (döngü için)
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawCircle(center, radius, backgroundPaint);
    
    // 2. ÖN PLAN - Turkuaz-Mavi gradient (dönüştürülen kısım)
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress;
      
      final foregroundPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: const [
            Color(0xFFE07A5F), // Turkuaz
            Color(0xFF6EC6B5), // Mavi
            Color(0xFFE07A5F), // Turkuaz
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(startAngle),
        ).createShader(rect);

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        foregroundPaint,
      );
    }
    
    // 3. BALONCUKLAR
    final bubblePaint = Paint()..style = PaintingStyle.fill;
    
    for (var bubble in bubbles) {
      final bubbleRadius = radius * bubble.radius;
      final x = center.dx + bubbleRadius * math.cos(bubble.angle);
      final y = center.dy + bubbleRadius * math.sin(bubble.angle);
      
      // Baloncuk bu noktada hangi renkte olmalı?
      final normalizedAngle = (bubble.angle + math.pi / 2) / (2 * math.pi);
      final isInConvertedArea = normalizedAngle <= progress;
      
      Color bubbleColor;
      if (isInConvertedArea) {
        // Turkuaz-Mavi alanında
        bubbleColor = Color.lerp(
          const Color(0xFFE07A5F),
          const Color(0xFF6EC6B5),
          normalizedAngle / progress.clamp(0.01, 1.0),
        )!.withOpacity(bubble.opacity);
      } else {
        // Mor-Pembe alanında
        bubbleColor = Color.lerp(
          const Color(0xFFE07A5F),
          const Color(0xFFF2C94C),
          (normalizedAngle - progress) / (1 - progress).clamp(0.01, 1.0),
        )!.withOpacity(bubble.opacity);
      }
      
      bubblePaint.color = bubbleColor;
      
      // Baloncuk glow efekti
      canvas.drawCircle(
        Offset(x, y),
        bubble.size * 1.5,
        Paint()
          ..color = bubbleColor.withOpacity(bubble.opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      
      // Ana baloncuk
      canvas.drawCircle(Offset(x, y), bubble.size, bubblePaint);
      
      // Parlak nokta
      canvas.drawCircle(
        Offset(x - bubble.size * 0.3, y - bubble.size * 0.3),
        bubble.size * 0.3,
        Paint()..color = Colors.white.withOpacity(bubble.opacity * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubbleRingPainter oldDelegate) {
    return oldDelegate.progress != progress || true; // Baloncuklar için her zaman
  }
}
