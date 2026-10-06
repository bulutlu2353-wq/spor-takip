import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/core/theme/app_theme.dart';
import 'package:spor_takip/features/onboarding/presentation/steps/step_scaffolds.dart';

void main() {
  setUpAll(() async {
    // easy_localization needs shared_preferences mocked in tests — see
    // Task 8's widget_test.dart for why (MissingPluginException otherwise).
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Widget child) {
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: MaterialApp(theme: AppTheme.dark(), home: child),
    );
  }

  testWidgets('Next button disabled until a value within range is entered', (tester) async {
    double? saved;
    var nextTapped = false;

    await tester.pumpWidget(
      wrap(
        NumericStepScreen(
          title: 'Test',
          hintText: 'Değer gir',
          min: 20,
          max: 300,
          initialValue: null,
          onSave: (value) => saved = value,
          onNext: () => nextTapped = true,
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const Key('wizard_next_button'));
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('numeric_step_field')), '75');
    await tester.pump();

    expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);

    await tester.tap(nextButton);
    expect(saved, 75.0);
    expect(nextTapped, isTrue);
  });

  testWidgets('Next button stays disabled for an out-of-range value', (tester) async {
    await tester.pumpWidget(
      wrap(
        NumericStepScreen(
          title: 'Test',
          hintText: 'Değer gir',
          min: 20,
          max: 300,
          initialValue: null,
          onSave: (_) {},
          onNext: () {},
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('numeric_step_field')), '5');
    await tester.pump();

    final nextButton = find.byKey(const Key('wizard_next_button'));
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
  });

  testWidgets('ChoiceStepScreen: Next button disabled until an option is selected', (tester) async {
    String? selected;
    await tester.pumpWidget(
      wrap(
        ChoiceStepScreen<String>(
          title: 'Test',
          options: const [('a', 'Seçenek A', Icons.star), ('b', 'Seçenek B', Icons.star_border)],
          selected: null,
          onSave: (value) => selected = value,
          onNext: () {},
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const Key('wizard_next_button'));
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

    await tester.tap(find.byKey(const Key('choice_option_a')));
    await tester.pump();

    expect(selected, 'a');
  });

  testWidgets('TextStepScreen: required=true disables Next until non-empty text', (tester) async {
    await tester.pumpWidget(
      wrap(
        TextStepScreen(
          title: 'Test',
          hintText: 'Yaz',
          initialValue: null,
          required: true,
          onSave: (_) {},
          onNext: () {},
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const Key('wizard_next_button'));
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('text_step_field')), 'Fitness');
    await tester.pump();

    expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);
  });

  testWidgets('TextStepScreen: required=false leaves Next enabled when empty', (tester) async {
    await tester.pumpWidget(
      wrap(
        TextStepScreen(
          title: 'Test',
          hintText: 'Yaz',
          initialValue: null,
          required: false,
          onSave: (_) {},
          onNext: () {},
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const Key('wizard_next_button'));
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);
  });

  testWidgets('step bar has one segment per step and lights done and current ones', (tester) async {
    await tester.pumpWidget(
      wrap(
        NumericStepScreen(
          title: 'Test',
          hintText: 'Değer gir',
          min: 20,
          max: 300,
          initialValue: null,
          unit: 'kg',
          onSave: (_) {},
          onNext: () {},
          onBack: null,
          stepNumber: 2,
          totalSteps: 5,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Color segmentColor(int i) =>
        (tester.widget<Container>(find.byKey(Key('wizard_segment_$i'))).decoration! as BoxDecoration).color!;
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(Key('wizard_segment_$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('wizard_segment_5')), findsNothing);
    expect(segmentColor(1), AppColors.accent);
    expect(segmentColor(2), AppColors.line);
    expect(tester.widget<Text>(find.byKey(const Key('wizard_step_label'))).style!.color, AppColors.accent);
    expect(tester.widget<Text>(find.byKey(const Key('numeric_step_unit'))).data, 'kg');
  });

  testWidgets('ChoiceStepScreen: only the selected card shows a check mark', (tester) async {
    await tester.pumpWidget(
      wrap(
        ChoiceStepScreen<String>(
          title: 'Test',
          options: const [('a', 'Seçenek A', Icons.star), ('b', 'Seçenek B', Icons.star_border)],
          selected: 'b',
          onSave: (_) {},
          onNext: () {},
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('choice_option_b')), matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
}