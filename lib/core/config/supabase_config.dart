import 'package:supabase_flutter/supabase_flutter.dart';

/// Compile-time Supabase configuration loaded from Dart defines.
///
/// The Flutter app must never contain Supabase secrets. Only the public anon key
/// is accepted here and the app safely falls back to guest mode if values are
/// missing or initialization fails.
final class SupabaseConfig {
  const SupabaseConfig({
    this.url = const String.fromEnvironment('SUPABASE_URL'),
    this.anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
  });

  final String url;
  final String anonKey;

  bool get canInitialize => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  static const defaultConfig = SupabaseConfig();

  static bool _initialized = false;

  static bool get isConfigured => defaultConfig.canInitialize;

  static Future<bool> initializeIfConfigured({
    SupabaseConfig config = defaultConfig,
  }) async {
    if (!config.canInitialize) return false;
    if (_initialized) return true;

    try {
      await Supabase.initialize(
        url: config.url.trim(),
        anonKey: config.anonKey.trim(),
      );
      _initialized = true;
      return true;
    } on Object {
      return false;
    }
  }

  static Future<bool> initializeSafely({
    SupabaseConfig config = defaultConfig,
  }) =>
      initializeIfConfigured(config: config);
}
