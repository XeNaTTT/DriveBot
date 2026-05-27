import 'package:camera/camera.dart';

typedef CameraDescriptionsLoader = Future<List<CameraDescription>> Function();
typedef CameraControllerFactory = CameraController Function(
  CameraDescription camera,
);

class CameraRuntimeService {
  const CameraRuntimeService({
    this.loadCameraDescriptions = availableCameras,
    this.createCameraController = createDefaultCameraController,
  });

  final CameraDescriptionsLoader loadCameraDescriptions;
  final CameraControllerFactory createCameraController;

  Future<CameraController?> createBackCameraController() async {
    final cameras = await loadCameraDescriptions();
    if (cameras.isEmpty) return null;

    final camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    return createCameraController(camera);
  }
}

CameraController createDefaultCameraController(CameraDescription camera) {
  return CameraController(
    camera,
    ResolutionPreset.high,
    enableAudio: false,
  );
}
