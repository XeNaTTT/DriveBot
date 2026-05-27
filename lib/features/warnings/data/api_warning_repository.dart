import 'dart:async';

import '../domain/warning_repository.dart';
import '../domain/warning_repository_result.dart';
import '../domain/warning_request.dart';
import 'warning_cache.dart';
import 'warning_mapper.dart';

typedef WarningApiClient = Future<List<ApiWarningPayload>> Function(
  WarningRequest request,
);

class ApiWarningRepository implements WarningRepository {
  ApiWarningRepository({
    required this.client,
    this.mapper = const WarningMapper(),
    this.cache,
    this.timeout = const Duration(seconds: 4),
  });

  final WarningApiClient client;
  final WarningMapper mapper;
  final WarningCache? cache;
  final Duration timeout;

  @override
  Future<WarningRepositoryResult> getWarnings(WarningRequest request) async {
    final cached = cache?.read(request.cacheKey);
    if (cached != null && cached.hasWarnings) {
      return WarningRepositoryResult.cache(cached.warnings);
    }

    try {
      final payloads = await client(request).timeout(timeout);
      if (payloads.isEmpty) {
        return const WarningRepositoryResult.empty();
      }

      final result = WarningRepositoryResult.live(mapper.mapAll(payloads));
      cache?.write(request.cacheKey, result);
      return result;
    } on TimeoutException {
      return const WarningRepositoryResult.failure('warning-api-timeout');
    } catch (_) {
      return const WarningRepositoryResult.failure('warning-api-error');
    }
  }
}
