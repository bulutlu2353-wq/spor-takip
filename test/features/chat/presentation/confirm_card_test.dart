import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/chat/application/chat_notifier.dart';
import 'package:spor_takip/features/chat/application/chat_providers.dart';
import 'package:spor_takip/features/chat/data/chat_repository.dart';
import 'package:spor_takip/features/chat/domain/card_data.dart';
import 'package:spor_takip/features/chat/domain/chat_models.dart';
import 'package:spor_takip/features/chat/presentation/widgets/confirm_card.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../fixtures.dart';

/// Kartı notifier'daki son mesajın olayıyla çizer (gerçek balondaki gibi).
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatNotifierProvider).value;
    if (state == null) return const SizedBox();
    final event = state.messages.last.event!;
    return ConfirmCard(key: ValueKey(event.id), event: event);
  }
}

void main() {
  setUpAll(initTestLocalization);

  late FakeChatRepository repo;

  Future<void> pumpCard(WidgetTester tester, ChatEvent event) async {
    repo = FakeChatRepository(messages: [assistantMessage(event)]);
    await tester.pumpWidget(testApp(const _Host(), overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      profileProvider.overrideWith((ref) async => testProfile),
      weightLogsProvider.overrideWith((ref) async => [BodyWeightLog(date: DateTime(2026, 9, 30), weightKg: 80)]),
      nowProvider.overrideWithValue(() => DateTime(2026, 10, 1, 12)),
    ]));
    await tester.pumpAndSettle();
  }

  Text text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key)));

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('weight card shows before → after with new targets and applies them', (tester) async {
    await pumpCard(tester, weightEvent(kg: 82));

    expect(text(tester, 'card_weight_change').data, '80 → 82 kg');
    expect(find.byKey(const Key('card_targets')), findsOneWidget);

    await tapKey(tester, 'card_apply');

    final expected = targetsAfter(testProfile, weightEvent(kg: 82), currentYear: 2026)!;
    expect(repo.applied.single.extras, {
      'calorie_target': expected.calorieTarget,
      'protein_target': expected.proteinTargetG,
    });
    expect(find.byKey(const Key('card_applied')), findsOneWidget);
    expect(find.byKey(const Key('card_undo')), findsOneWidget);
  });

  testWidgets('a past-dated weight hides the targets but still sends them', (tester) async {
    await pumpCard(tester, weightEvent(date: '2026-09-01', kg: 79, logBefore: 81));

    expect(text(tester, 'card_weight_change').data, '81 → 79 kg');
    expect(find.byKey(const Key('card_targets')), findsNothing);

    await tapKey(tester, 'card_apply');
    expect(repo.applied.single.extras.keys, containsAll(['calorie_target', 'protein_target']));
  });

  testWidgets('cancel marks the card cancelled', (tester) async {
    await pumpCard(tester, goalEvent());
    await tapKey(tester, 'card_cancel');

    expect(repo.cancelled, ['e-goal']);
    expect(find.byKey(const Key('card_status_cancelled')), findsOneWidget);
    expect(find.byKey(const Key('card_apply')), findsNothing);
  });

  testWidgets('undo after a later change shows "changed since" and disables undo', (tester) async {
    await pumpCard(tester, weightEvent(status: ChatEventStatus.applied));
    repo.undoOutcome = UndoOutcome.modified;

    await tapKey(tester, 'card_undo');

    expect(find.byKey(const Key('card_modified')), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('card_undo'))).onPressed, isNull);
  });

  testWidgets('undo reverts the card to undone', (tester) async {
    await pumpCard(tester, weightEvent(status: ChatEventStatus.applied));
    await tapKey(tester, 'card_undo');

    expect(repo.undone, ['e-weight']);
    expect(find.byKey(const Key('card_status_undone')), findsOneWidget);
  });

  testWidgets('meal card recomputes macros for edited grams and sends them', (tester) async {
    await pumpCard(tester, mealEvent());

    expect(text(tester, 'card_meal_macros_0').data, '330 kcal · P 62 g · C 0 g · F 7.2 g');
    expect(find.byKey(const Key('card_meal_review_1')), findsOneWidget);
    expect(find.byKey(const Key('card_meal_review_0')), findsNothing);

    await tester.enterText(find.byKey(const Key('card_meal_grams_0')), '150');
    await tester.pump();
    expect(text(tester, 'card_meal_macros_0').data, '247.5 kcal · P 46.5 g · C 0 g · F 5.4 g');
    expect(text(tester, 'card_meal_total').data, contains('247.5 kcal'));

    await tapKey(tester, 'card_apply');
    expect(repo.applied.single.extras, {
      'item_grams': [150.0, 200.0],
    });
  });

  testWidgets('invalid grams disable confirm', (tester) async {
    await pumpCard(tester, mealEvent());
    await tester.enterText(find.byKey(const Key('card_meal_grams_1')), '0');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('card_apply'))).onPressed, isNull);
  });

  testWidgets('profile card lists changed fields and sends new targets', (tester) async {
    await pumpCard(tester, profileEvent());

    expect(find.byKey(const Key('card_field_height_cm')), findsOneWidget);
    expect(find.byKey(const Key('card_field_activity_level')), findsOneWidget);
    expect(find.byKey(const Key('card_targets')), findsOneWidget);

    await tapKey(tester, 'card_apply');
    final expected = targetsAfter(testProfile, profileEvent(), currentYear: 2026)!;
    expect(repo.applied.single.extras['calorie_target'], expected.calorieTarget);
  });

  testWidgets('set card shows the exercise and the values', (tester) async {
    await pumpCard(tester, setEvent());
    expect(text(tester, 'card_set_exercise').data, 'Barbell Squat');
    expect(text(tester, 'card_set_value').data, '80 kg × 5');
  });

  testWidgets('program card lists the changes', (tester) async {
    await pumpCard(tester, programEvent());
    expect(text(tester, 'card_program_change_0').data, '+ A: Barbell Deadlift 1×5');
    expect(text(tester, 'card_program_change_1').data, '− A: Barbell Squat');
  });

  testWidgets('stale cards show the stale note without buttons', (tester) async {
    await pumpCard(tester, setEvent(status: ChatEventStatus.stale));
    expect(find.byKey(const Key('card_status_stale')), findsOneWidget);
    expect(find.byKey(const Key('card_apply')), findsNothing);
  });

  testWidgets('a failed action shows a snackbar and keeps the card pending', (tester) async {
    await pumpCard(tester, setEvent());
    repo.actionError = Exception('network');

    await tapKey(tester, 'card_apply');

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('card_apply')), findsOneWidget);
  });
}
