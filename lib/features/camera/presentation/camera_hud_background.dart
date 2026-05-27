import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../location/domain/sensor_permission_status.dart';
import '../data/camera_runtime_service.dart';
import '../domain/camera_runtime_state.dart';

class CameraHudBackground extends StatefulWidget {
  const CameraHudBackground({
    required this.permissionStatus,
    this.cameraRuntimeService = const CameraRuntimeService(),
    super.key,
  });

  final SensorPermissionStatus permissionStatus;
  final CameraRuntimeService cameraRuntimeService;

  @override
  State<CameraHudBackground> createState() => _CameraHudBackgroundState();
}

class _CameraHudBackgroundState extends State<CameraHudBackground> {
  CameraController? _controller;
  CameraRuntimeState _state = const CameraRuntimeState.initializing();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void didUpdateWidget(covariant CameraHudBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.permissionStatus.camera != widget.permissionStatus.camera ||
        oldWidget.cameraRuntimeService != widget.cameraRuntimeService) {
      _disposeController();
      _state = const CameraRuntimeState.initializing();
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
      if (mounted) {
        setState(() => _state = const CameraRuntimeState.permissionDenied());
      }
      return;
    }

    try {
      final controller =
          await widget.cameraRuntimeService.createBackCameraController();
      if (!mounted) {
        await controller?.dispose();
        return;
      }
      if (controller == null) {
        setState(() => _state = const CameraRuntimeState.unavailable());
        return;
      }

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _state = const CameraRuntimeState.ready();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _state = const CameraRuntimeState.failed());
      }
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
    if (_state.availability == CameraRuntimeAvailability.ready &&
        controller != null &&
        controller.value.isInitialized) {
      return KeyedSubtree(
        key: const Key('camera-preview-layer'),
        child: _CameraPreviewBackground(controller: controller),
      );
    }

    return const KeyedSubtree(
      key: Key('mock-background-layer'),
      child: CameraFallbackHudBackground(),
    );
  }
}

class CameraFallbackHudBackground extends StatelessWidget {
  const CameraFallbackHudBackground({super.key});

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
