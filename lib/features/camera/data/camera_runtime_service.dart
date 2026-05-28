import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

typedef CameraDescriptionsLoader = Future<List<CameraDescription>> Function();
typedef CameraControllerFactory = CameraRuntimeController Function(
  CameraDescription camera,
);

abstract class CameraRuntimeController {
  Future<void> initialize();
  Future<void> dispose();
  Future<double> getMinZoomLevel();
  Future<double> getMaxZoomLevel();
  Future<void> setZoomLevel(double zoom);
  bool get isInitialized;
  Widget buildPreview();
}

class CameraRuntimeService {
  const CameraRuntimeService({
    this.loadCameraDescriptions = availableCameras,
    this.createCameraController = createDefaultCameraController,
  });

  final CameraDescriptionsLoader loadCameraDescriptions;
  final CameraControllerFactory createCameraController;

  Future<CameraRuntimeController?> createBackCameraController() async {
    final cameras = await loadCameraDescriptions();
    if (cameras.isEmpty) return null;

    final camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    return createCameraController(camera);
  }
}

CameraRuntimeController createDefaultCameraController(
    CameraDescription camera) {
  return CameraControllerAdapter(
    CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    ),
  );
}

class CameraControllerAdapter implements CameraRuntimeController {
  const CameraControllerAdapter(this._controller);

  final CameraController _controller;

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  Future<double> getMinZoomLevel() => _controller.getMinZoomLevel();

  @override
  Future<double> getMaxZoomLevel() => _controller.getMaxZoomLevel();

  @override
  Future<void> setZoomLevel(double zoom) => _controller.setZoomLevel(zoom);

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  Widget buildPreview() => _CameraPreviewBackground(controller: _controller);
}

class _CameraPreviewBackground extends StatelessWidget {
  const _CameraPreviewBackground({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
