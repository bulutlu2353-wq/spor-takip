import 'dart:math' as math;

import '../../progress/domain/weekly_summary.dart';

/// Sıralama ve unvan dönemi (S2 spec §2.3): ISO hafta (pazartesi) ya da takvim ayı.
enum PeriodKind { week, month }

String _two(int n) => n.toString().padLeft(2, '0');

/// ISO hafta anahtarı: '2026-W41'. Hafta, perşembesinin düştüğü yıla aittir.
String weekKey(DateTime local) {
  final thursday = DateTime.utc(local.year, local.month, local.day + 4 - local.weekday);
  final week = thursday.difference(DateTime.utc(thursday.year)).inDays ~/ 7 + 1;
  return '${thursday.year}-W${_two(week)}';
}

/// '2026-10'.
String monthKey(DateTime local) => '${local.year}-${_two(local.month)}';

/// Yerel `[start, end)`; [previous] true ise bir önceki dönem.
({DateTime start, DateTime end}) periodRange(PeriodKind kind, DateTime local, {bool previous = false}) {
  switch (kind) {
    case PeriodKind.week:
      final current = startOfWeek(local);
      final start = previous ? DateTime(current.year, current.month, current.day - 7) : current;
      return (start: start, end: DateTime(start.year, start.month, start.day + 7));
    case PeriodKind.month:
      final start = DateTime(local.year, local.month - (previous ? 1 : 0));
      return (start: start, end: DateTime(start.year, start.month + 1));
  }
}

String periodKey(PeriodKind kind, DateTime local, {bool previous = false}) {
  final start = periodRange(kind, local, previous: previous).start;
  return kind == PeriodKind.week ? weekKey(start) : monthKey(start);
}

/// Dönem bitişine kalan: 24 saatten azsa saat, değilse gün; ikisi de yukarı yuvarlanır, en az 1.
({int n, bool hours}) periodRemaining(PeriodKind kind, DateTime now) {
  final minutes = periodRange(kind, now).end.difference(now).inMinutes;
  final hours = math.max(1, (minutes / 60).ceil());
  return hours < 24 ? (n: hours, hours: true) : (n: (hours / 24).ceil(), hours: false);
}
