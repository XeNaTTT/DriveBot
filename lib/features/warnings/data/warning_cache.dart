import '../domain/warning_repository_result.dart';

abstract class WarningCache {
  WarningRepositoryResult? read(String key);
  void write(String key, WarningRepositoryResult result);
  void clear();
}

class InMemoryWarningCache implements WarningCache {
  final Map<String, WarningRepositoryResult> _entries = {};

  @override
  WarningRepositoryResult? read(String key) => _entries[key];

  @override
  void write(String key, WarningRepositoryResult result) {
    _entries[key] = result;
  }

  @override
  void clear() => _entries.clear();
}
