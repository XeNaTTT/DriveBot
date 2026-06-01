import '../domain/ar_runtime_state.dart';

abstract interface class ArRuntimeService {
  Future<ArRuntimeState> getState();
  Future<bool> isSupported();
  Future<void> start();
  Future<void> stop();
}

final class FallbackArRuntimeService implements ArRuntimeService {
  const FallbackArRuntimeService([this.reason = 'Kamera-Fallback']);

  final String reason;

  @override
  Future<ArRuntimeState> getState() async => ArRuntimeState.fallback(reason);

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
