import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'features/auth/data/guest_auth_repository.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/domain/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseClient = await SupabaseConfig.initialize();
  final AuthRepository authRepository = supabaseClient == null
      ? const GuestAuthRepository()
      : SupabaseAuthRepository(supabaseClient);

  runApp(DriveAssistantApp(authRepository: authRepository));
}
