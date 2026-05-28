import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseConfigured = await SupabaseConfig.initializeIfConfigured();
  runApp(DriveAssistantApp(supabaseConfigured: supabaseConfigured));
}
