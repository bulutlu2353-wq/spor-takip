import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/presentation/widgets/rank_badge.dart';

import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('a large badge shows the level number', (tester) async {
    await tester.pumpWidget(testApp(const RankBadge(rank: Rank.warrior, level: 37, size: 88)));
    await tester.pumpAndSettle();
    expect(find.text('37'), findsOneWidget);
    expect(tester.getSize(find.byType(RankBadge)), const Size(88, 88 * 1.15));
  });

  testWidgets('a small badge hides the number', (tester) async {
    await tester.pumpWidget(testApp(const RankBadge(rank: Rank.immortal, level: 120)));
    await tester.pumpAndSettle();
    expect(find.text('120'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
