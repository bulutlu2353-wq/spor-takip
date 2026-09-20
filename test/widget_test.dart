import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/main.dart';

void main() {
  testWidgets('App boots and shows F0 placeholder text', (tester) async {
    await tester.pumpWidget(const SporTakipApp());

    expect(find.text('F0 iskeleti hazır'), findsOneWidget);
  });
}
