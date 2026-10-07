import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_theme.dart';
import 'package:spor_takip/shared/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo paints at the given size', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Center(child: AppLogo(key: Key('logo'), size: 80)),
    ));
    expect(tester.getSize(find.byKey(const Key('logo'))), const Size(80, 80));
    expect(find.descendant(of: find.byKey(const Key('logo')), matching: find.byType(CustomPaint)), findsOneWidget);
  });
}
