import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

class AppSupabase {
  static Future<void> init() {
    // `anonKey` is deprecated in supabase_flutter 2.17+ in favor of
    // `publishableKey`. `Env.supabaseAnonKey` holds the same underlying
    // value (from SUPABASE_ANON_KEY) and is passed to the new param name.
    return Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
