import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://biuydcyyqeutfddxtruu.supabase.co';
  static const String anonKey =
      'sb_publishable_vsEIUhzsOGFY6HYKGeDGMA_eZ_ffdp-';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}
