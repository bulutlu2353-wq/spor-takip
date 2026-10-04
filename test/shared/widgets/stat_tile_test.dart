import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/widgets/section_header.dart';
import 'package:spor_takip/shared/widgets/stat_tile.dart';

import 'themed.dart';

Text _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key)));

void main() {
  testWidgets('shows the label upper-cased, the value and the detail', (tester) async {
    await tester.pumpWidget(themed(StatTile(label: 'Kilo', value: '82.4 kg', detail: '▼ 0.6 kg', onTap: () {})));

    expect(find.text('KILO'), findsOneWidget); // test yerel ayarı en
    expect(_text(tester, 'stat_tile_value').data, '82.4 kg');
    expect(_text(tester, 'stat_tile_detail').data, '▼ 0.6 kg');
    expect(_text(tester, 'stat_tile_detail').style!.color, AppColors.muted);
  });

  testWidgets('a highlighted detail uses the accent color', (tester) async {
    await tester.pumpWidget(themed(StatTile(label: 'Güç', value: '110 kg', detail: '▲ 10', highlight: true, onTap: () {})));

    expect(_text(tester, 'stat_tile_detail').style!.color, AppColors.accent);
  });

  testWidgets('without a value it shows a dash and the hint', (tester) async {
    await tester.pumpWidget(themed(StatTile(label: 'Ölçü', emptyHint: 'Ölçü ekle', highlight: true, onTap: () {})));

    expect(_text(tester, 'stat_tile_value').data, '—');
    expect(_text(tester, 'stat_tile_detail').data, 'Ölçü ekle');
    expect(_text(tester, 'stat_tile_detail').style!.color, AppColors.muted);
  });

  testWidgets('tapping calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(themed(StatTile(label: 'Kilo', value: '80 kg', onTap: () => taps++)));

    await tester.tap(find.byType(StatTile));
    expect(taps, 1);
  });

  testWidgets('skeleton has the tile height', (tester) async {
    await tester.pumpWidget(themed(const StatTileSkeleton()));

    expect(tester.getSize(find.byType(StatTileSkeleton)).height, StatTile.height);
  });

  testWidgets('section header is upper-cased and muted', (tester) async {
    await tester.pumpWidget(themed(const SectionHeader('İlerleme')));

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, 'İLERLEME');
    expect(text.style!.color, AppColors.muted);
  });

  testWidgets('section header shows an optional trailing text in the normal text color', (tester) async {
    await tester.pumpWidget(themed(const SectionHeader('Kahvaltı', trailing: '520 kcal')));

    final trailing = tester.widget<Text>(find.byKey(const ValueKey('section_header_trailing')));
    expect(trailing.data, '520 kcal');
    expect(trailing.style!.color, AppColors.text);
  });
}
