import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

class AppSupabase {
  static Future<void> init() {
    return Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
