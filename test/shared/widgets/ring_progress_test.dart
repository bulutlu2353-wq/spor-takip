import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/widgets/ring_progress.dart';

import 'themed.dart';

RingPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const ValueKey('ring_paint'))).painter! as RingPainter;

void main() {
  test('fraction is clamped and zero without a target', () {
    expect(RingProgress.fraction(500, 2000), 0.25);
    expect(RingProgress.fraction(2500, 2000), 1);
    expect(RingProgress.fraction(500, 0), 0);
    expect(RingProgress.isOver(2001, 2000), isTrue);
    expect(RingProgress.isOver(2000, 2000), isFalse);
    expect(RingProgress.isOver(10, 0), isFalse);
  });

  testWidgets('fills to the fraction in the accent color', (tester) async {
    await tester.pumpWidget(themed(const RingProgress(value: 1000, target: 2000, center: Text('1000'))));
    await tester.pumpAndSettle();

    expect(_painter(tester).progress, 0.5);
    expect(_painter(tester).color, AppColors.accent);
    expect(_painter(tester).trackColor, AppColors.line);
    expect(find.text('1000'), findsOneWidget);
  });

  testWidgets('over the target it is full and uses the error color', (tester) async {
    await tester.pumpWidget(themed(const RingProgress(value: 2500, target: 2000)));
    await tester.pumpAndSettle();

    expect(_painter(tester).progress, 1);
    expect(_painter(tester).color, AppColors.error);
  });

  testWidgets('without a target the ring stays empty', (tester) async {
    await tester.pumpWidget(themed(const RingProgress(value: 500, target: 0)));
    await tester.pumpAndSettle();

    expect(_painter(tester).progress, 0);
  });
}
