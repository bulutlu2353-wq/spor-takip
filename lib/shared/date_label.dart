import 'package:easy_localization/easy_localization.dart';

/// "4 Ekim"; yıl [now]'ınkinden farklıysa "30 Aralık 2025".
String shortDateLabel(DateTime date, DateTime now) {
  final d = date.toLocal();
  final label = '${d.day} ${'home.month_${d.month}'.tr()}';
  return d.year == now.year ? label : '$label ${d.year}';
}
