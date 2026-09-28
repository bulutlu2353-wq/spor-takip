import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/domain/strength.dart';

import '../fixtures.dart';

void main() {
  group('estimateOneRepMax', () {
    test('Epley, single rep is the weight itself', () {
      expect(estimateOneRepMax(weightKg: 100, reps: 1), 100);
      expect(estimateOneRepMax(weightKg: 100, reps: 5), closeTo(116.67, 0.01));
      expect(estimateOneRepMax(weightKg: 100, reps: 10), closeTo(133.33, 0.01));
    });

    test('ignores sets above 10 reps, without weight or without reps', () {
      expect(estimateOneRepMax(weightKg: 100, reps: 11), isNull);
      expect(estimateOneRepMax(weightKg: null, reps: 5), isNull);
      expect(estimateOneRepMax(weightKg: 0, reps: 5), isNull);
      expect(estimateOneRepMax(weightKg: 100, reps: null), isNull);
      expect(estimateOneRepMax(weightKg: 100, reps: 0), isNull);
    });
  });

  group('strengthSeries', () {
    test('one point per session: its best estimate, dated at the finish', () {
      final series = strengthSeries([
        finishedSession('s1', DateTime(2026, 9, 1, 11), [
          doneSet('squat', kg: 100, reps: 5),
          doneSet('squat', kg: 105, reps: 3, setIndex: 1),
          doneSet('squat', kg: 110, reps: 5, done: false, setIndex: 2), // yapılmadı
        ]),
      ]);
      expect(series, hasLength(1));
      final point = series.single.points.single;
      expect(point.date, DateTime(2026, 9, 1, 11));
      expect(point.estimateKg, closeTo(116.67, 0.01)); // 100×5 > 105×3 (115.5)
      expect(point.weightKg, 100);
      expect(point.reps, 5);
      expect(series.single.exerciseName, 'squat name');
    });

    test('skips in-progress sessions and exercises without countable sets', () {
      final series = strengthSeries([
        finishedSession('s1', DateTime(2026, 9, 1), [
          doneSet('pullup', kg: null, reps: 8), // kilosuz
          doneSet('curl', kg: 15, reps: 12), // 10 tekrardan fazla
        ]),
        finishedSession('s2', null, [doneSet('squat')]), // devam ediyor
      ]);
      expect(series, isEmpty);
    });

    test('sorted by session count, ties by the most recent; points oldest first', () {
      final series = strengthSeries([
        finishedSession('s3', DateTime(2026, 9, 20), [doneSet('bench'), doneSet('row')]),
        finishedSession('s1', DateTime(2026, 9, 1), [doneSet('squat'), doneSet('bench')]),
        finishedSession('s2', DateTime(2026, 9, 10), [doneSet('squat')]),
      ]);
      expect(series.map((s) => s.exerciseId), ['bench', 'squat', 'row']);
      expect(series.first.points.map((p) => p.date), [DateTime(2026, 9, 1), DateTime(2026, 9, 20)]);
      expect(series.first.latest.date, DateTime(2026, 9, 20));
      expect(series.first.valuePoints.last.value, series.first.latest.estimateKg);
    });
  });

  group('topStrengthSeries', () {
    test('counts only the last 90 days and returns at most three', () {
      final now = DateTime(2026, 9, 28);
      final all = strengthSeries([
        // 90 gün öncesinden eski: yalnızca 'old'
        finishedSession('o1', DateTime(2026, 6, 1), [doneSet('old')]),
        finishedSession('o2', DateTime(2026, 6, 2), [doneSet('old')]),
        finishedSession('o3', DateTime(2026, 6, 3), [doneSet('old')]),
        finishedSession('a', DateTime(2026, 9, 1), [doneSet('squat'), doneSet('bench'), doneSet('row')]),
        finishedSession('b', DateTime(2026, 9, 5), [doneSet('squat'), doneSet('press')]),
        finishedSession('c', DateTime(2026, 9, 9), [doneSet('bench')]),
      ]);
      final top = topStrengthSeries(all, now);
      // squat 2, bench 2 (son: 9.9 → önce), sonra row (1.9) ile press (5.9) → press daha yeni
      expect(top.map((s) => s.exerciseId), ['bench', 'squat', 'press']);
    });
  });
}
