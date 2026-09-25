import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
    await AppSupabase.init();
  } catch (error, stackTrace) {
    debugPrint(
      'Failed to load app config from .env. Check that .env exists and '
      'matches the keys in .env.example (SUPABASE_URL, SUPABASE_ANON_KEY): '
      '$error',
    );
    debugPrint('$stackTrace');
    rethrow;
  }
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      // Turkish by default regardless of device/browser language; a locale
      // picked later via setLocale is saved and takes precedence.
      startLocale: const Locale('tr'),
      fallbackLocale: const Locale('tr'),
      child: const ProviderScope(child: SporTakipApp()),
    ),
  );
}

class SporTakipApp extends ConsumerWidget {
  const SporTakipApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Spor Takip',
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
