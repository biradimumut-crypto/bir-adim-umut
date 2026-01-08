import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Hope Sıvı Dolum Progress Bar
/// bosyeni.png içi canlı sıvıyla doluyor + glow efekti
/// ARKA PLAN YOK - sadece dolan kısım görünür
class HopeLiquidProgress extends StatefulWidget {
  final double progress;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool isActive;

  const HopeLiquidProgress({
    Key? key,
    required this.progress,
    this.width = 280,
    this.height = 140,
    this.onTap,
    this.isActive = false,
  }) : super(key: key);

  @override
  State<HopeLiquidProgress> createState() => _HopeLiquidProgressState();
}

class _HopeLiquidProgressState extends State<HopeLiquidProgress>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _wave2Controller;
  late AnimationController _progressController;
  late AnimationController _glowController;
  late Animation<double> _progressAnimation;
  double _currentProgress = 0;

  @override
  void initState() {
    super.initState();
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    
    _wave2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));
    
    _progressController.forward();
  }

  @override
  void didUpdateWidget(HopeLiquidProgress oldWidget) {
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
    _waveController.dispose();
    _wave2Controller.dispose();
    _progressController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _waveController,
        _wave2Controller,
        _progressController,
        _glowController,
      ]),
      builder: (context, child) {
        _currentProgress = _progressAnimation.value;
        final glowIntensity = 0.6 + _glowController.value * 0.4;
        
        return GestureDetector(
          onTap: widget.isActive ? widget.onTap : null,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              children: [
                // 1. BOŞ LOGO - SOLUK GRİ (progress 0 iken görünür)
                Opacity(
                  opacity: 1.0 - (_currentProgress * 0.7), // Dolunca yavaşça kaybolur
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(<double>[
                      0.3, 0.3, 0.3, 0, 0,
                      0.3, 0.3, 0.3, 0, 0,
                      0.3, 0.3, 0.3, 0, 0,
                      0, 0, 0, 0.5, 0, // Yarı saydam gri
                    ]),
                    child: Image.asset(
                      'assets/hopesteps_dolu.png',
                      width: widget.width,
                      height: widget.height,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                // 2. SIVI DOLUM - RENKLİ GRADIENT (alttan yukarı doluyor)
                if (_currentProgress > 0)
                  ClipPath(
                    clipper: _FillClipper(
                      progress: _currentProgress,
                      wavePhase: _waveController.value * 2 * math.pi,
                      wave2Phase: _wave2Controller.value * 2 * math.pi,
                    ),
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF6EC6B5), // Turkuaz
                            Color(0xFFE07A5F), // Turuncu
                            Color(0xFFF2C94C), // Sarı
                          ],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcATop,
                      child: Image.asset(
                        'assets/hopesteps_dolu.png',
                        width: widget.width,
                        height: widget.height,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                
                // 3. PARLAK GLOW EFEKTİ - Sıvı yüzeyinde parıltı
                if (_currentProgress > 0)
                  ClipPath(
                    clipper: _FillClipper(
                      progress: _currentProgress,
                      wavePhase: _waveController.value * 2 * math.pi,
                      wave2Phase: _wave2Controller.value * 2 * math.pi,
                    ),
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.15, 0.5, 1.0],
                          colors: [
                            Colors.white.withOpacity(0.9 * glowIntensity),
                            Colors.white.withOpacity(0.4 * glowIntensity),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcATop,
                      child: Image.asset(
                        'assets/hopesteps_dolu.png',
                        width: widget.width,
                        height: widget.height,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Harflerin içini alttan yukarı dolduran clipper - dalga efektli
class _FillClipper extends CustomClipper<Path> {
  final double progress;
  final double wavePhase;
  final double wave2Phase;

  _FillClipper({
    required this.progress,
    required this.wavePhase,
    required this.wave2Phase,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    
    if (progress <= 0) return path;
    
    // Sıvı seviyesi (alttan yukarı dolum)
    final liquidHeight = size.height * (1 - progress);
    
    // Dalga yüksekliği (0 ve 1'de dalga yok)
    final waveHeight = (progress > 0.02 && progress < 0.98) ? 5.0 : 0.0;
    final waveLength = size.width / 1.5;
    
    path.moveTo(0, size.height);
    path.lineTo(0, liquidHeight);
    
    // Dalga çizgisi - sıvı yüzeyi
    for (double x = 0; x <= size.width; x += 1) {
      final wave1 = math.sin((x / waveLength * 2 * math.pi) + wavePhase) * waveHeight;
      final wave2 = math.sin((x / waveLength * 4 * math.pi) + wave2Phase) * (waveHeight * 0.4);
      final y = liquidHeight + wave1 + wave2;
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(covariant _FillClipper oldClipper) {
    return oldClipper.progress != progress ||
           oldClipper.wavePhase != wavePhase ||
           oldClipper.wave2Phase != wave2Phase;
  }
}
