import 'package:camera/camera.dart';
import 'package:driveassistant_ar/features/camera/data/camera_runtime_service.dart';
import 'package:driveassistant_ar/features/camera/domain/camera_runtime_state.dart';
import 'package:driveassistant_ar/features/camera/presentation/camera_hud_background.dart';
import 'package:driveassistant_ar/features/location/domain/sensor_permission_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('camera zoom profile', () {
    test('default uses 0.5x when minZoom supports ultra-wide', () {
      final profile = CameraZoomProfile.fromBounds(minZoom: 0.5, maxZoom: 6);

      expect(profile.supportsUltraWide, isTrue);
      expect(profile.defaultZoom, 0.5);
    });

    test('default uses 1x when 0.5x is unavailable', () {
      final profile = CameraZoomProfile.fromBounds(minZoom: 0.7, maxZoom: 6);

      expect(profile.supportsUltraWide, isFalse);
      expect(profile.defaultZoom, 1);
    });

    test('requested zoom is clamped to min and max', () {
      expect(CameraZoomProfile.clamp(0.5, 0.7, 3), 0.7);
      expect(CameraZoomProfile.clamp(4, 0.5, 3), 3);
    });
  });

  group('camera HUD zoom toggle', () {
    testWidgets('defaults to 0.5x and toggles to 1x', (tester) async {
      final controller = _FakeCameraRuntimeController(minZoom: 0.5, maxZoom: 6);

      await tester.pumpWidget(_buildCameraHud(controller));
      await tester.pumpAndSettle();

      expect(controller.zoomLevels, [0.5]);
      expect(find.text('0.5x'), findsOneWidget);

      await tester.tap(find.byKey(const Key('camera-zoom-toggle')));
      await tester.pumpAndSettle();

      expect(controller.zoomLevels, [0.5, 1]);
      expect(find.text('1x'), findsOneWidget);
    });

    testWidgets('toggles from 1x to 0.5x when ultra-wide is supported',
        (tester) async {
      final controller = _FakeCameraRuntimeController(minZoom: 0.5, maxZoom: 6);

      await tester.pumpWidget(_buildCameraHud(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('camera-zoom-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('camera-zoom-toggle')));
      await tester.pumpAndSettle();

      expect(controller.zoomLevels, [0.5, 1, 0.5]);
      expect(find.text('0.5x'), findsOneWidget);
    });

    testWidgets('shows disabled 1x when ultra-wide is unavailable',
        (tester) async {
      final controller = _FakeCameraRuntimeController(minZoom: 0.7, maxZoom: 6);

      await tester.pumpWidget(_buildCameraHud(controller));
      await tester.pumpAndSettle();

      expect(controller.zoomLevels, [1]);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('camera-zoom-toggle')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('1x'), findsOneWidget);
    });

    testWidgets('hides zoom toggle when camera is unavailable', (tester) async {
      await tester.pumpWidget(_buildCameraHud(null));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mock-background-layer')), findsOneWidget);
      expect(find.byKey(const Key('camera-zoom-toggle')), findsNothing);
    });

    testWidgets('exposes German zoom toggle semantics label', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = _FakeCameraRuntimeController(minZoom: 0.5, maxZoom: 6);

      await tester.pumpWidget(_buildCameraHud(controller));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Kamera-Zoom wechseln'), findsOneWidget);
      semantics.dispose();
    });
  });
}

Widget _buildCameraHud(_FakeCameraRuntimeController? controller) {
  return MaterialApp(
    home: CameraHudBackground(
      permissionStatus: const SensorPermissionStatus(
        camera: SensorPermissionState.granted,
        location: SensorPermissionState.granted,
        motion: SensorPermissionState.granted,
      ),
      cameraRuntimeService: CameraRuntimeService(
        loadCameraDescriptions: () async => controller == null
            ? const []
            : const [
                CameraDescription(
                  name: 'Back Camera',
                  lensDirection: CameraLensDirection.back,
                  sensorOrientation: 90,
                ),
              ],
        createCameraController: (_) => controller!,
      ),
    ),
  );
}

class _FakeCameraRuntimeController implements CameraRuntimeController {
  _FakeCameraRuntimeController({required this.minZoom, required this.maxZoom});

  final double minZoom;
  final double maxZoom;
  final List<double> zoomLevels = [];
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Widget buildPreview() => const ColoredBox(
        key: Key('fake-camera-preview'),
        color: Colors.black,
      );

  @override
  Future<void> dispose() async {}

  @override
  Future<double> getMaxZoomLevel() async => maxZoom;

  @override
  Future<double> getMinZoomLevel() async => minZoom;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<void> setZoomLevel(double zoom) async {
    zoomLevels.add(zoom);
  }
}
