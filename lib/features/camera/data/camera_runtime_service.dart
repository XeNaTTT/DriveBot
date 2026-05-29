import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

typedef CameraDescriptionsLoader = Future<List<CameraDescription>> Function();
typedef CameraControllerFactory =
    CameraRuntimeController Function(CameraDescription camera);

class CameraRuntimeCameraSelection {
  const CameraRuntimeCameraSelection({
    required this.camera,
    required this.controller,
    required this.availableCameras,
  });

  final CameraDescription camera;
  final CameraRuntimeController controller;
  final List<CameraDescription> availableCameras;

  bool get hasSeparateUltraWideBackCamera => availableCameras.any(
    (camera) =>
        camera.lensDirection == CameraLensDirection.back &&
        camera.lensType == CameraLensType.ultraWide,
  );

  bool get hasSeparateNormalBackCamera => availableCameras.any(
    (camera) =>
        camera.lensDirection == CameraLensDirection.back &&
        camera.lensType != CameraLensType.ultraWide,
  );

  bool get canSwitchBackLens =>
      hasSeparateUltraWideBackCamera && hasSeparateNormalBackCamera;
}

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
    final selection = await createInitialBackCameraSelection();
    return selection?.controller;
  }

  Future<CameraRuntimeCameraSelection?>
  createInitialBackCameraSelection() async {
    final cameras = await loadCameraDescriptions();
    if (cameras.isEmpty) return null;

    final camera = selectInitialBackCamera(cameras) ?? cameras.first;
    return CameraRuntimeCameraSelection(
      camera: camera,
      controller: createCameraController(camera),
      availableCameras: cameras,
    );
  }

  CameraRuntimeController createControllerFor(CameraDescription camera) {
    return createCameraController(camera);
  }

  static CameraDescription? selectInitialBackCamera(
    List<CameraDescription> cameras,
  ) {
    final backCameras = cameras
        .where((camera) => camera.lensDirection == CameraLensDirection.back)
        .toList(growable: false);
    if (backCameras.isEmpty) return null;

    return _firstCameraOfType(backCameras, CameraLensType.ultraWide) ??
        _firstCameraOfType(backCameras, CameraLensType.wide) ??
        backCameras.first;
  }

  static CameraDescription? selectNormalBackCamera(
    List<CameraDescription> cameras,
  ) {
    final backCameras = cameras
        .where((camera) => camera.lensDirection == CameraLensDirection.back)
        .toList(growable: false);
    if (backCameras.isEmpty) return null;

    return _firstCameraOfType(backCameras, CameraLensType.wide) ??
        backCameras.firstWhere(
          (camera) => camera.lensType != CameraLensType.ultraWide,
          orElse: () => backCameras.first,
        );
  }

  static CameraDescription? selectUltraWideBackCamera(
    List<CameraDescription> cameras,
  ) {
    final backCameras = cameras
        .where((camera) => camera.lensDirection == CameraLensDirection.back)
        .toList(growable: false);
    if (backCameras.isEmpty) return null;

    return _firstCameraOfType(backCameras, CameraLensType.ultraWide);
  }

  static CameraDescription? _firstCameraOfType(
    List<CameraDescription> cameras,
    CameraLensType lensType,
  ) {
    for (final camera in cameras) {
      if (camera.lensType == lensType) return camera;
    }
    return null;
  }
}

CameraRuntimeController createDefaultCameraController(
  CameraDescription camera,
) {
  return CameraControllerAdapter(
    CameraController(camera, ResolutionPreset.high, enableAudio: false),
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
