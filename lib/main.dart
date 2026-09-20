import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const SporTakipApp());
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
