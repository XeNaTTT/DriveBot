import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../location/domain/sensor_permission_status.dart';

typedef CameraDescriptionsLoader = Future<List<CameraDescription>> Function();
typedef CameraControllerFactory = CameraController Function(
  CameraDescription camera,
);

class CameraHudLayer extends StatefulWidget {
  const CameraHudLayer({
    required this.permissionStatus,
    this.loadCameraDescriptions = availableCameras,
    this.createCameraController = _createDefaultCameraController,
    super.key,
  });

  final SensorPermissionStatus permissionStatus;
  final CameraDescriptionsLoader loadCameraDescriptions;
  final CameraControllerFactory createCameraController;

  @override
  State<CameraHudLayer> createState() => _CameraHudLayerState();
}

class _CameraHudLayerState extends State<CameraHudLayer> {
  CameraController? _controller;
  bool _useFallback = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void didUpdateWidget(covariant CameraHudLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.permissionStatus.camera != widget.permissionStatus.camera) {
      _disposeController();
      _useFallback = false;
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (widget.permissionStatus.camera != SensorPermissionState.granted) {
      if (mounted) setState(() => _useFallback = true);
      return;
    }

    try {
      final cameras = await widget.loadCameraDescriptions();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _useFallback = true);
        return;
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = widget.createCameraController(camera);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _useFallback = false;
      });
    } catch (_) {
      if (mounted) setState(() => _useFallback = true);
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_useFallback && controller != null && controller.value.isInitialized) {
      return KeyedSubtree(
        key: Key('camera-preview-layer'),
        child: _CameraPreviewBackground(controller: controller),
      );
    }

    return const KeyedSubtree(
      key: Key('mock-background-layer'),
      child: _CameraPlaceholderBackground(),
    );
  }
}

CameraController _createDefaultCameraController(CameraDescription camera) {
  return CameraController(
    camera,
    ResolutionPreset.high,
    enableAudio: false,
  );
}

class _CameraPreviewBackground extends StatelessWidget {
  const _CameraPreviewBackground({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
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

class _CameraPlaceholderBackground extends StatelessWidget {
  const _CameraPlaceholderBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2A39), Color(0xFF0A0F14)],
        ),
      ),
      child: CustomPaint(painter: _HudGridPainter(), size: Size.infinite),
    );
  }
}

class _HudGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x2257E3FF)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
