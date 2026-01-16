import 'package:flutter/material.dart';
import 'dart:math';

/// Konfetili başarı dialogu göster
Future<void> showSuccessDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? subtitle,
  String? imagePath,
  IconData? icon,
  List<Color>? gradientColors,
  String buttonText = 'Muhteşem!',
  VoidCallback? onClose,
  List<Widget>? socialButtons,
}) async {
  final colors = gradientColors ?? [const Color(0xFF6EC6B5), const Color(0xFFE07A5F), const Color(0xFFF2C94C)];
  
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SuccessDialogContent(
      title: title,
      message: message,
      subtitle: subtitle,
      imagePath: imagePath,
      icon: icon,
      gradientColors: colors,
      buttonText: buttonText,
      onClose: onClose,
      socialButtons: socialButtons,
    ),
  );
}

class _SuccessDialogContent extends StatefulWidget {
  final String title;
  final String message;
  final String? subtitle;
  final String? imagePath;
  final IconData? icon;
  final List<Color> gradientColors;
  final String buttonText;
  final VoidCallback? onClose;
  final List<Widget>? socialButtons;

  const _SuccessDialogContent({
    required this.title,
    required this.message,
    this.subtitle,
    this.imagePath,
    this.icon,
    required this.gradientColors,
    required this.buttonText,
    this.onClose,
    this.socialButtons,
  });

  @override
  State<_SuccessDialogContent> createState() => _SuccessDialogContentState();
}

class _SuccessDialogContentState extends State<_SuccessDialogContent> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sol konfeti
          Positioned(
            left: -50,
            top: 0,
            bottom: 0,
            child: ConfettiAnimation(isLeft: true),
          ),
          // Sağ konfeti
          Positioned(
            right: -50,
            top: 0,
            bottom: 0,
            child: ConfettiAnimation(isLeft: false),
          ),
          // Dialog içeriği
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.gradientColors.first.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon veya Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.gradientColors.first.withOpacity(0.2),
                        widget.gradientColors.last.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.gradientColors.first.withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                  child: widget.imagePath != null
                      ? ClipOval(
                          child: Image.asset(
                            widget.imagePath!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Icon(
                          widget.icon ?? Icons.celebration,
                          size: 40,
                          color: widget.gradientColors.first,
                        ),
                ),
                const SizedBox(height: 20),
                
                // Başlık
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: widget.gradientColors.first,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Mesaj
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Alt başlık (opsiyonel)
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // Sosyal butonlar (opsiyonel)
                if (widget.socialButtons != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.socialButtons!,
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Kapat butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onClose?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.gradientColors.first,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.buttonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('🎉', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Konfeti animasyonu widget'ı
class ConfettiAnimation extends StatefulWidget {
  final bool isLeft;
  const ConfettiAnimation({Key? key, required this.isLeft}) : super(key: key);

  @override
  State<ConfettiAnimation> createState() => _ConfettiAnimationState();
}

class _ConfettiAnimationState extends State<ConfettiAnimation>
    with TickerProviderStateMixin {
  late List<_ConfettiPiece> _confettiPieces;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    final random = Random();
    _confettiPieces = List.generate(50, (index) {
      final direction = index % 4;
      double startX, startY, endX, endY;
      
      if (widget.isLeft) {
        switch (direction) {
          case 0:
            startX = random.nextDouble() * 150 - 50;
            startY = -50;
            endX = startX + (random.nextDouble() * 100 - 50);
            endY = random.nextDouble() * 500 + 200;
            break;
          case 1:
            startX = random.nextDouble() * 150 - 50;
            startY = 600;
            endX = startX + (random.nextDouble() * 100 - 50);
            endY = random.nextDouble() * 300;
            break;
          case 2:
            startX = -80;
            startY = random.nextDouble() * 400;
            endX = random.nextDouble() * 200 + 50;
            endY = startY + (random.nextDouble() * 200 - 100);
            break;
          default:
            startX = random.nextDouble() * 100;
            startY = random.nextDouble() * 200 + 100;
            endX = startX + (random.nextDouble() * 150 - 75);
            endY = startY + (random.nextDouble() * 300);
        }
      } else {
        switch (direction) {
          case 0:
            startX = random.nextDouble() * 150 - 100;
            startY = -50;
            endX = startX + (random.nextDouble() * 100 - 50);
            endY = random.nextDouble() * 500 + 200;
            break;
          case 1:
            startX = random.nextDouble() * 150 - 100;
            startY = 600;
            endX = startX + (random.nextDouble() * 100 - 50);
            endY = random.nextDouble() * 300;
            break;
          case 2:
            startX = 80;
            startY = random.nextDouble() * 400;
            endX = -(random.nextDouble() * 200 + 50);
            endY = startY + (random.nextDouble() * 200 - 100);
            break;
          default:
            startX = -(random.nextDouble() * 100);
            startY = random.nextDouble() * 200 + 100;
            endX = startX - (random.nextDouble() * 150 - 75);
            endY = startY + (random.nextDouble() * 300);
        }
      }
      
      return _ConfettiPiece(
        color: [
          const Color(0xFF6EC6B5),
          const Color(0xFF6EC6B5).withOpacity(0.7),
          const Color(0xFFE07A5F),
          const Color(0xFFE07A5F).withOpacity(0.7),
          const Color(0xFFF2C94C),
          const Color(0xFFF2C94C).withOpacity(0.7),
          const Color(0xFFE8F7F5),
          Colors.orange,
          Colors.orange.shade300,
          Colors.green,
          Colors.green.shade300,
          Colors.red,
          Colors.red.shade300,
          Colors.yellow,
          Colors.white,
          Colors.white70,
        ][random.nextInt(16)],
        startX: startX,
        startY: startY,
        endX: endX,
        endY: endY,
        rotation: random.nextDouble() * 1080,
        size: random.nextDouble() * 10 + 5,
        delay: random.nextDouble() * 0.4,
        shape: random.nextInt(3),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 150,
          height: 600,
          child: Stack(
            clipBehavior: Clip.none,
            children: _confettiPieces.map((piece) {
              final progress = (_controller.value - piece.delay).clamp(0.0, 1.0) / (1.0 - piece.delay);
              if (progress <= 0) return const SizedBox();

              final curvedProgress = Curves.easeOut.transform(progress);
              final x = piece.startX + (piece.endX - piece.startX) * curvedProgress;
              final y = piece.startY + (piece.endY - piece.startY) * curvedProgress;
              final opacity = (0.5 - progress * 0.4).clamp(0.0, 0.5);

              Widget confettiWidget;
              if (piece.shape == 2) {
                confettiWidget = Container(
                  width: piece.size,
                  height: piece.size,
                  decoration: BoxDecoration(
                    color: piece.color.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                );
              } else if (piece.shape == 1) {
                confettiWidget = Container(
                  width: piece.size,
                  height: piece.size,
                  decoration: BoxDecoration(
                    color: piece.color.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              } else {
                confettiWidget = Container(
                  width: piece.size,
                  height: piece.size * 0.4,
                  decoration: BoxDecoration(
                    color: piece.color.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }

              return Positioned(
                left: widget.isLeft ? x + 75 : null,
                right: widget.isLeft ? null : -x + 75,
                top: y,
                child: Transform.rotate(
                  angle: piece.rotation * progress * 3.14159 / 180,
                  child: Opacity(
                    opacity: opacity,
                    child: confettiWidget,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ConfettiPiece {
  final Color color;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double rotation;
  final double size;
  final double delay;
  final int shape;

  _ConfettiPiece({
    required this.color,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.rotation,
    required this.size,
    required this.delay,
    required this.shape,
  });
}
