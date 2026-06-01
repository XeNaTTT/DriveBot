import '../domain/ar_anchor_projection.dart';
import '../domain/ar_world_anchor_state.dart';
import '../domain/ar_runtime_state.dart';

abstract interface class ArRuntimeService {
  Future<ArRuntimeState> getState();
  Future<bool> isSupported();
  Future<void> start();
  Future<void> stop();
  Future<List<ArWorldAnchorState>> syncAnchors(
    List<ArAnchorProjection> projections,
  );
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

  @override
  Future<List<ArWorldAnchorState>> syncAnchors(
    List<ArAnchorProjection> projections,
  ) async => const [];
}
