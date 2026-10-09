import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../domain/levels.dart';

/// Kalkan biçimli rütbe rozeti: kademe rengi, kademe içi sıra kadar chevron şerit;
/// büyük boyda (≥ 56) altta seviye numarası (O1 spec §6.1).
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, required this.level, this.size = 28});

  final Rank rank;
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (rank.tier) {
      1 => scheme.onSurfaceVariant,
      2 => scheme.primary.withValues(alpha: 0.55),
      _ => scheme.primary,
    };
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: CustomPaint(
        painter: _RankBadgePainter(
          color: color,
          background: scheme.surfaceContainerLowest,
          stripes: rank.stripes,
          glow: rank.tier == 4,
        ),
        child: size >= 56
            ? Align(
                alignment: const Alignment(0, 0.62),
                child: Text(
                  '$level',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.26,
                    color: scheme.onSurface,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _RankBadgePainter extends CustomPainter {
  const _RankBadgePainter({required this.color, required this.background, required this.stripes, required this.glow});

  final Color color;
  final Color background;
  final int stripes;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shield = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.15)
      ..lineTo(w, h * 0.55)
      ..quadraticBezierTo(w, h * 0.85, w * 0.5, h)
      ..quadraticBezierTo(0, h * 0.85, 0, h * 0.55)
      ..lineTo(0, h * 0.15)
      ..close();
    if (glow) {
      canvas.drawPath(
        shield,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
      );
    }
    canvas.drawPath(shield, Paint()..color = background);
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, w * 0.06)
        ..color = color,
    );
    final chevron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, w * 0.08)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (var i = 0; i < stripes; i++) {
      final y = h * (0.18 + i * 0.1);
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.28, y)
          ..lineTo(w * 0.5, y + h * 0.08)
          ..lineTo(w * 0.72, y),
        chevron,
      );
    }
  }

  @override
  bool shouldRepaint(_RankBadgePainter old) =>
      old.color != color || old.background != background || old.stripes != stripes || old.glow != glow;
}
