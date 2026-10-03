import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/shared/text_case.dart';

void main() {
  test('turkish upper case keeps the dotted and dotless i apart', () {
    expect(upperCaseFor('cuma, 3 ekim', 'tr'), 'CUMA, 3 EKİM');
    expect(upperCaseFor('ılık iğne', 'tr'), 'ILIK İĞNE');
  });

  test('other languages use the default upper case', () {
    expect(upperCaseFor('friday, 3 october', 'en'), 'FRIDAY, 3 OCTOBER');
  });
}
