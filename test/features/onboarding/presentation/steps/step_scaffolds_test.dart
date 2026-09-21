import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      child: MaterialApp(home: child),
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
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('numeric_step_field')), '75');
    await tester.pump();

    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNotNull);

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
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNull);
  });

  testWidgets('ChoiceStepScreen: Next button disabled until an option is selected', (tester) async {
    String? selected;
    await tester.pumpWidget(
      wrap(
        ChoiceStepScreen<String>(
          title: 'Test',
          options: const [('a', 'Seçenek A'), ('b', 'Seçenek B')],
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
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNull);

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
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('text_step_field')), 'Fitness');
    await tester.pump();

    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNotNull);
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
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNotNull);
  });
}
