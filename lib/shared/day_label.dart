import 'package:easy_localization/easy_localization.dart';

/// "Cumartesi, 4 Ekim" — ana sayfa ve beslenme ekranı başlığındaki tarih.
String dayLabel(DateTime day) =>
    '${'home.weekday_${day.weekday}'.tr()}, ${day.day} ${'home.month_${day.month}'.tr()}';
