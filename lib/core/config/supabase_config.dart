import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  const SupabaseConfig({
    this.url = const String.fromEnvironment('SUPABASE_URL'),
    this.anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
  });

  final String url;
  final String anonKey;

  bool get canInitialize => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  static bool _initialized = false;

  static Future<bool> initializeIfConfigured({
    SupabaseConfig config = const SupabaseConfig(),
  }) async {
    if (!config.canInitialize) return false;
    if (_initialized) return true;

    try {
      await Supabase.initialize(url: config.url, anonKey: config.anonKey);
      _initialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }
}
