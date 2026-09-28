import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/domain/body_measurement.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';

BodyMeasurement _m(int day, Map<MeasurementSite, double> values) =>
    BodyMeasurement(date: DateTime(2026, 9, day), values: values);

void main() {
  group('BodyWeightLog', () {
    test('fromJson parses a local date and a numeric weight', () {
      final log = BodyWeightLog.fromJson({'logged_on': '2026-09-28', 'weight_kg': 80});
      expect(log.date, DateTime(2026, 9, 28));
      expect(log.weightKg, 80.0);
    });

    test('valid weight is strictly between 0 and 500', () {
      expect(isValidBodyWeight(0), isFalse);
      expect(isValidBodyWeight(0.1), isTrue);
      expect(isValidBodyWeight(499.9), isTrue);
      expect(isValidBodyWeight(500), isFalse);
    });
  });

  group('BodyMeasurement', () {
    test('fromJson keeps only filled sites', () {
      final m = BodyMeasurement.fromJson({
        'measured_on': '2026-09-28',
        'waist': 82.5,
        'arm': 35,
        'neck': null,
      });
      expect(m.date, DateTime(2026, 9, 28));
      expect(m.values, {MeasurementSite.waist: 82.5, MeasurementSite.arm: 35.0});
    });

    test('toUpsertJson writes every site, empty ones as null', () {
      final json = _m(28, {MeasurementSite.waist: 82}).toUpsertJson();
      expect(json['measured_on'], '2026-09-28');
      expect(json['waist'], 82);
      expect(json.containsKey('neck'), isTrue);
      expect(json['neck'], isNull);
      expect(json.length, 1 + MeasurementSite.values.length);
    });

    test('valid measurement is strictly between 0 and 300', () {
      expect(isValidMeasurement(0), isFalse);
      expect(isValidMeasurement(299.9), isTrue);
      expect(isValidMeasurement(300), isFalse);
    });

    test('measurementChange compares the two newest values of the site', () {
      final list = [
        _m(1, {MeasurementSite.waist: 85}),
        _m(10, {MeasurementSite.arm: 34}),
        _m(20, {MeasurementSite.waist: 83, MeasurementSite.arm: 35}),
      ];
      expect(measurementChange(list, MeasurementSite.waist), -2);
      expect(measurementChange(list, MeasurementSite.arm), 1);
      expect(measurementChange(list, MeasurementSite.neck), isNull);
      expect(measurementChange([list.first], MeasurementSite.waist), isNull);
    });
  });
}
