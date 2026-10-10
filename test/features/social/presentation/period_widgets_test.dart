import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/social/presentation/widgets/period_widgets.dart';

import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('titles list and standings render at phone width without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const Column(
      children: [
        PeriodTitlesList(
          kind: PeriodKind.week,
          lines: [
            TitleLine(category: 'xp', holders: ['Ayşe Kaya'], value: 1240),
            TitleLine(category: 'lats', holders: ['Ayşe Kaya', 'Burak Uzunisimlioğlu'], value: 14.5),
          ],
        ),
        StandingsList(
          lines: [
            StandingLine(
              userId: 'ayse',
              position: 1,
              name: 'Ayşe Kaya',
              initials: 'AK',
              level: 34,
              rank: Rank.determined,
              xp: 1420,
            ),
            StandingLine(
              userId: 'me',
              position: 4,
              name: 'Samet Çok Uzun Bir İsim Soyisim Daha',
              initials: 'S',
              level: 31,
              rank: Rank.determined,
              xp: 640,
              handle: 'samet_fit',
              title: 'Kanat Şampiyonu',
              isMe: true,
            ),
          ],
        ),
      ],
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key('title_xp')), findsOneWidget);
    expect(find.byKey(const Key('title_lats')), findsOneWidget);
    expect(find.text('social.period_star_week'), findsOneWidget);
    expect(find.text('social.period_title_week'), findsOneWidget);
    expect(find.text('Ayşe Kaya, Burak Uzunisimlioğlu'), findsOneWidget);

    expect(find.byKey(const Key('standing_ayse')), findsOneWidget);
    expect(find.byKey(const Key('standing_me')), findsOneWidget);
    expect(find.byKey(const Key('standing_me_label')), findsOneWidget);
    expect(find.text('@samet_fit'), findsOneWidget);
    expect(find.text('Kanat Şampiyonu'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('the period switch reports the chosen period', (tester) async {
    PeriodKind? chosen;
    await tester.pumpWidget(testApp(PeriodSwitch(
      kind: PeriodKind.week,
      keyPrefix: 'period',
      onChanged: (k) => chosen = k,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('period_month')));
    await tester.pumpAndSettle();
    expect(chosen, PeriodKind.month);
  });
}
