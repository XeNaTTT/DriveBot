import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseConfig = SupabaseConfig.defaultConfig;
  for (final diagnostic in supabaseConfig.safeDiagnostics) {
    debugPrint(diagnostic);
  }

  final supabaseConfigured = await SupabaseConfig.initializeIfConfigured(
    config: supabaseConfig,
  );
  runApp(DriveAssistantApp(supabaseConfigured: supabaseConfigured));
}
