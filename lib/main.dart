import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await AppSupabase.init();
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
