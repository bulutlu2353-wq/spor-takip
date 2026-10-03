import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dairesel ilerleme (spec §4.2): boş kısım çizgi rengi, dolu kısım vurgu;
/// hedef aşılınca tam dolu ve hata renginde. Dolma ~600 ms canlandırılır.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    required this.target,
    this.size = 120,
    this.strokeWidth = 12,
    this.center,
  });

  final double value;
  final double target;
  final double size;
  final double strokeWidth;
  final Widget? center;

  /// 0–1 doluluk; hedef yoksa 0, aşımda 1.
  static double fraction(double value, double target) =>
      target <= 0 ? 0 : (value / target).clamp(0.0, 1.0).toDouble();

  static bool isOver(double value, double target) => target > 0 && value > target;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isOver(value, target) ? scheme.error : scheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction(value, target)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => CustomPaint(
        key: const ValueKey('ring_paint'),
        painter: RingPainter(
          progress: progress,
          color: color,
          trackColor: scheme.outlineVariant,
          strokeWidth: strokeWidth,
        ),
        child: child,
      ),
      child: SizedBox.square(dimension: size, child: Center(child: center)),
    );
  }
}

class RingPainter extends CustomPainter {
  const RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final arcRect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = trackColor);
    if (progress > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
