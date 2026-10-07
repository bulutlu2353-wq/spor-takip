import 'package:flutter/material.dart';

/// LevelUp Fit logosu (G2 spec §9.2): koyu yuvarlatılmış kare içinde iki neon
/// rütbe şeridi; alttaki %55 opak. Renkler temadan gelir.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _LogoPainter(
        background: theme.scaffoldBackgroundColor,
        border: theme.colorScheme.outlineVariant,
        accent: theme.colorScheme.primary,
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.background, required this.border, required this.accent});

  final Color background;
  final Color border;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 100;
    final tile = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.22));
    canvas.drawRRect(tile, Paint()..color = background);
    canvas.drawRRect(
      tile.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = border,
    );
    // 100×100 birimlik çizim: şeridin tepesi [top], kolları 24 birim aşağıda.
    Path chevron(double top) => Path()
      ..moveTo(22 * unit, (top + 24) * unit)
      ..lineTo(50 * unit, top * unit)
      ..lineTo(78 * unit, (top + 24) * unit);
    final stripe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12 * unit
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(chevron(52), stripe..color = accent.withValues(alpha: 0.55));
    canvas.drawPath(chevron(28), stripe..color = accent);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.background != background || old.border != border || old.accent != accent;
}
