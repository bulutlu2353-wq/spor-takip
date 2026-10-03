import 'package:flutter/material.dart';

/// F5+ koyu tema paleti (spec §4.1). Yalnız `lib/core/theme/` içinde
/// kullanılır; ekranlar ve bileşenler renkleri temadan alır.
abstract final class AppColors {
  static const background = Color(0xFF0E0F12);
  static const surface = Color(0xFF181A20);
  static const surfaceHigh = Color(0xFF1F2128);
  static const line = Color(0xFF262830);
  static const text = Color(0xFFF2F3F5);
  static const muted = Color(0xFF8A8F98);
  static const accent = Color(0xFFC6FF00);
  static const onAccent = Color(0xFF0E0F12);
  static const error = Color(0xFFFF5C5C);
}
