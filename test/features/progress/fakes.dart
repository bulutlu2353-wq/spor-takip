import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/progress/data/body_measurement_repository.dart';
import 'package:spor_takip/features/progress/data/body_weight_repository.dart';
import 'package:spor_takip/features/progress/data/progress_data_repository.dart';
import 'package:spor_takip/features/progress/domain/body_measurement.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/progress/domain/profile_weight_update.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

class FakeBodyWeightRepository implements BodyWeightRepository {
  FakeBodyWeightRepository([List<BodyWeightLog>? logs]) : logs = [...?logs];

  final List<BodyWeightLog> logs;
  final List<({DateTime date, ProfileWeightUpdate update})> logged = [];
  final List<({DateTime date, ProfileWeightUpdate? newLatest})> deleted = [];

  /// Doluysa yazma/silme bu hatayı fırlatır.
  Object? error;

  @override
  Future<List<BodyWeightLog>> fetchLogs() async => [...logs]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> logWeight({required DateTime date, required ProfileWeightUpdate update}) async {
    if (error != null) throw error!;
    logged.add((date: date, update: update));
    logs
      ..removeWhere((l) => l.date == date)
      ..add(BodyWeightLog(date: date, weightKg: update.weightKg));
  }

  @override
  Future<void> deleteLog({required DateTime date, ProfileWeightUpdate? newLatest}) async {
    if (error != null) throw error!;
    deleted.add((date: date, newLatest: newLatest));
    logs.removeWhere((l) => l.date == date);
  }
}

class FakeBodyMeasurementRepository implements BodyMeasurementRepository {
  FakeBodyMeasurementRepository([List<BodyMeasurement>? items]) : items = [...?items];

  final List<BodyMeasurement> items;
  Object? error;

  @override
  Future<List<BodyMeasurement>> fetchMeasurements() async =>
      [...items]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> saveMeasurement(BodyMeasurement measurement) async {
    if (error != null) throw error!;
    items
      ..removeWhere((m) => m.date == measurement.date)
      ..add(measurement);
  }

  @override
  Future<void> deleteMeasurement(DateTime date) async {
    if (error != null) throw error!;
    items.removeWhere((m) => m.date == date);
  }
}

class FakeProgressDataRepository implements ProgressDataRepository {
  FakeProgressDataRepository({List<WorkoutSession>? sessions, List<Meal>? meals})
      : sessions = [...?sessions],
        meals = [...?meals];

  final List<WorkoutSession> sessions;
  final List<Meal> meals;
  int sessionFetches = 0;

  @override
  Future<List<WorkoutSession>> fetchFinishedSessions({DateTime? since}) async {
    sessionFetches++;
    return [
      for (final s in sessions)
        if (s.finishedAt case final finishedAt? when since == null || !finishedAt.isBefore(since)) s,
    ]..sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));
  }

  @override
  Future<List<Meal>> fetchMeals({required DateTime from, required DateTime to}) async => [
        for (final m in meals)
          if (!m.loggedAt.isBefore(from) && m.loggedAt.isBefore(to)) m,
      ];

  @override
  Future<List<DateTime>> fetchMealTimes() async => [for (final m in meals) m.loggedAt]..sort();
}
