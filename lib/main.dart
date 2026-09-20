import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
      fallbackLocale: const Locale('tr'),
      child: const SporTakipApp(),
    ),
  );
}

class SporTakipApp extends StatelessWidget {
  const SporTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spor Takip',
      home: const Scaffold(
        body: Center(child: Text('F0 iskeleti hazır')),
      ),
    );
  }
}
