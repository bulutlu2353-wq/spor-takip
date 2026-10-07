import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_theme.dart';
import 'package:spor_takip/features/onboarding/presentation/widgets/big_number_field.dart';
import 'package:spor_takip/features/onboarding/presentation/widgets/choice_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: Center(child: child)));

  testWidgets('ChoiceCard shows label, subtitle and a check only when selected', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(ChoiceCard(
      label: 'Erkek',
      icon: Icons.male,
      subtitle: 'alt',
      subtitleKey: const Key('sub'),
      selected: false,
      onTap: () => taps++,
    )));
    expect(find.text('Erkek'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('sub'))).data, 'alt');
    expect(find.byIcon(Icons.check_circle), findsNothing);
    await tester.tap(find.text('Erkek'));
    expect(taps, 1);

    await tester.pumpWidget(wrap(ChoiceCard(label: 'Erkek', icon: Icons.male, selected: true, onTap: () {})));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('BigNumberField reports parsed values and shows the unit', (tester) async {
    double? value = 1;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(wrap(BigNumberField(
      controller: controller,
      hintText: 'Örn. 180',
      unit: 'cm',
      onChanged: (v) => value = v,
    )));
    expect(tester.widget<Text>(find.byKey(const Key('numeric_step_unit'))).data, 'cm');
    await tester.enterText(find.byKey(const Key('numeric_step_field')), '182');
    expect(value, 182);
    await tester.enterText(find.byKey(const Key('numeric_step_field')), 'abc');
    expect(value, isNull);
  });
}
