import 'package:supabase_flutter/supabase_flutter.dart';

/// Compile-time Supabase configuration loaded from Dart defines.
///
/// The Flutter app must never contain Supabase secrets. Only the public anon key
/// is accepted here and the app safely falls back to guest mode if values are
/// missing or initialization fails.
final class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<bool> initializeSafely() async {
    if (!isConfigured) {
      return false;
    }

    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      return true;
    } on Object {
      return false;
    }
  }
}
