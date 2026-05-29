import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260529000000_create_speed_camera_reports.sql',
  );

  test('migration file exists', () {
    expect(migration.existsSync(), isTrue);
  });

  test('speed_camera_reports table exists in SQL', () {
    expect(
      migration.readAsStringSync(),
      contains('public.speed_camera_reports'),
    );
  });

  test('RLS enabled in SQL', () {
    expect(
      migration.readAsStringSync(),
      contains(
        'alter table public.speed_camera_reports enable row level security',
      ),
    );
  });

  test('select policy filters active/non-expired', () {
    final sql = migration.readAsStringSync();
    expect(sql, contains("moderation_status = 'active'"));
    expect(sql, contains('expires_at > now()'));
  });

  test('insert policy requires auth.uid()', () {
    expect(migration.readAsStringSync(), contains('user_id = auth.uid()'));
  });

  test('mobile expiry uses 3 days', () {
    expect(migration.readAsStringSync(), contains("interval '3 days'"));
  });

  test('fixed expiry uses 1 year', () {
    expect(migration.readAsStringSync(), contains("interval '1 year'"));
  });

  test('no service role key is committed', () {
    final files = Directory.current
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => !file.path.contains('/.git/'));
    for (final file in files) {
      if (file.path.contains('/build/') ||
          file.path.contains('/.dart_tool/') ||
          file.path.contains('/node_modules/') ||
          file.path.endsWith('docs/community-reporting.md') ||
          file.path.endsWith('docs/supabase.md')) {
        continue;
      }
      String contents;
      try {
        contents = file.readAsStringSync();
      } on FileSystemException {
        continue;
      }
      expect(
        contents,
        isNot(
          contains(
            'service'
            '_role',
          ),
        ),
      );
    }
  });
}
