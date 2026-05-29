import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../location/domain/sensor_permission_status.dart';
import '../data/camera_runtime_service.dart';
import '../domain/camera_runtime_state.dart';

class CameraHudBackground extends StatefulWidget {
  const CameraHudBackground({
    required this.permissionStatus,
    this.cameraRuntimeService = const CameraRuntimeService(),
    this.onStateChanged,
    super.key,
  });

  final SensorPermissionStatus permissionStatus;
  final CameraRuntimeService cameraRuntimeService;
  final ValueChanged<CameraRuntimeState>? onStateChanged;

  @override
  State<CameraHudBackground> createState() => _CameraHudBackgroundState();
}

class _CameraHudBackgroundState extends State<CameraHudBackground> {
  CameraRuntimeController? _controller;
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
        _setCameraState(const CameraRuntimeState.permissionDenied());
      }
      return;
    }

    CameraRuntimeController? controller;
    try {
      controller = await widget.cameraRuntimeService
          .createBackCameraController();
      if (!mounted) {
        await controller?.dispose();
        return;
      }
      if (controller == null) {
        _setCameraState(const CameraRuntimeState.unavailable());
        return;
      }

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      final zoomProfile = await _createInitialZoomProfile(controller);
      await controller.setZoomLevel(zoomProfile.defaultZoom);
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      _setCameraState(
        CameraRuntimeState.ready(
          currentZoomLevel: zoomProfile.defaultZoom,
          minZoom: zoomProfile.minZoom,
          maxZoom: zoomProfile.maxZoom,
        ),
      );
    } on CameraException {
      await controller?.dispose();
      if (mounted) {
        _setCameraState(const CameraRuntimeState.failed());
      }
    } catch (_) {
      await controller?.dispose();
      if (mounted) {
        _setCameraState(const CameraRuntimeState.failed());
      }
    }
  }

  Future<CameraZoomProfile> _createInitialZoomProfile(
    CameraRuntimeController controller,
  ) async {
    final minZoom = await controller.getMinZoomLevel();
    final maxZoom = await controller.getMaxZoomLevel();
    return CameraZoomProfile.fromBounds(minZoom: minZoom, maxZoom: maxZoom);
  }

  Future<void> _toggleZoom() async {
    final controller = _controller;
    final currentZoom = _state.currentZoomLevel;
    final minZoom = _state.minZoom;
    final maxZoom = _state.maxZoom;
    if (controller == null ||
        currentZoom == null ||
        minZoom == null ||
        maxZoom == null ||
        !_state.supportsUltraWide ||
        _state.isSwitchingZoom) {
      return;
    }

    final previousZoom = currentZoom;
    final targetZoom = CameraZoomProfile(
      minZoom: minZoom,
      maxZoom: maxZoom,
      defaultZoom: currentZoom,
    ).toggleTarget(currentZoom);

    _setCameraState(
      _state.copyWithZoom(
        currentZoomLevel: previousZoom,
        isSwitchingZoom: true,
      ),
    );

    try {
      await controller.setZoomLevel(targetZoom);
      if (!mounted) return;
      _setCameraState(
        _state.copyWithZoom(
          currentZoomLevel: targetZoom,
          isSwitchingZoom: false,
        ),
      );
    } on CameraException {
      if (!mounted) return;
      _setCameraState(
        _state.copyWithZoom(
          currentZoomLevel: previousZoom,
          isSwitchingZoom: false,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _setCameraState(
        _state.copyWithZoom(
          currentZoomLevel: previousZoom,
          isSwitchingZoom: false,
        ),
      );
    }
  }

  void _setCameraState(CameraRuntimeState state) {
    setState(() => _state = state);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onStateChanged?.call(state);
    });
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady =
        _state.availability == CameraRuntimeAvailability.ready &&
        controller != null &&
        controller.isInitialized;

    return Stack(
      children: [
        if (isReady)
          KeyedSubtree(
            key: const Key('camera-preview-layer'),
            child: controller.buildPreview(),
          )
        else
          const KeyedSubtree(
            key: Key('mock-background-layer'),
            child: CameraFallbackHudBackground(),
          ),
        if (!isReady && _state.shouldUseFallback)
          _CameraFallbackStatus(state: _state),
        if (isReady) _ZoomToggle(state: _state, onPressed: _toggleZoom),
      ],
    );
  }
}

class _CameraFallbackStatus extends StatelessWidget {
  const _CameraFallbackStatus({required this.state});

  final CameraRuntimeState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state.availability) {
      CameraRuntimeAvailability.permissionDenied => 'Kamerazugriff verweigert',
      CameraRuntimeAvailability.unavailable ||
      CameraRuntimeAvailability.failed => 'Kamera nicht verfügbar',
      _ => 'Fallback',
    };

    return SafeArea(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          key: const Key('camera-fallback-status'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x99FFA94D)),
          ),
          child: Text(label),
        ),
      ),
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

class _ZoomToggle extends StatelessWidget {
  const _ZoomToggle({required this.state, required this.onPressed});

  final CameraRuntimeState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Semantics(
            label: 'Kamera-Zoom wechseln',
            button: true,
            enabled: state.supportsUltraWide,
            child: FilledButton.tonal(
              key: const Key('camera-zoom-toggle'),
              onPressed: state.supportsUltraWide && !state.isSwitchingZoom
                  ? onPressed
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(56, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
                shape: const StadiumBorder(),
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white70,
              ),
              child: Text(
                state.currentZoomLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
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
