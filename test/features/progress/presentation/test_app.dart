import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/core/theme/app_theme.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';

Future<void> initTestLocalization() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

/// [home] '/' rotasında. [scaffold] true ise (kartlar) kaydırılabilir bir
/// Scaffold içine konur; ekranlar kendi Scaffold'unu getirdiği için false.
/// [stubRoutes]: yol → o rotada gösterilecek düz metin (gezinme doğrulaması).
Widget testApp(
  Widget home, {
  List overrides = const [],
  Map<String, String> stubRoutes = const {},
  bool scaffold = true,
}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => scaffold ? Scaffold(body: SingleChildScrollView(child: home)) : home,
    ),
    for (final MapEntry(key: path, value: text) in stubRoutes.entries)
      GoRoute(path: path, builder: (context, state) => Scaffold(body: Text(text))),
  ]);
  return EasyLocalization(
    supportedLocales: const [Locale('tr'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('tr'),
    child: ProviderScope(
      overrides: [isLoggedInProvider.overrideWithValue(true), ...overrides.cast()],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
}
