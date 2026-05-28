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
  CameraRuntimeController? _controller;
  CameraDescription? _activeCamera;
  List<CameraDescription> _backCameras = const [];
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
      final cameras =
          await widget.cameraRuntimeService.loadCameraDescriptions();
      final selectedCamera =
          CameraRuntimeService.selectInitialBackCamera(cameras);
      if (!mounted) return;
      if (selectedCamera == null) {
        setState(() => _state = const CameraRuntimeState.unavailable());
        return;
      }

      _backCameras = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back)
          .toList(growable: false);
      final initialized = await _createInitializedCamera(
        selectedCamera,
        preferUltraWide: true,
      );
      if (!mounted) {
        await initialized.controller.dispose();
        return;
      }

      setState(() {
        _controller = initialized.controller;
        _activeCamera = selectedCamera;
        _state = initialized.state;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _state = const CameraRuntimeState.failed());
      }
    }
  }

  Future<void> _toggleZoom() async {
    if (!_state.supportsUltraWide || _state.isSwitchingZoom) return;

    final targetMode = CameraZoomProfile(
      minZoom: _state.minZoom ?? CameraZoomProfile.normal,
      maxZoom: _state.maxZoom ?? CameraZoomProfile.normal,
      defaultZoom: _state.currentZoomLevel ?? CameraZoomProfile.normal,
      defaultZoomMode: _state.currentZoomMode,
      supportsUltraWide: _state.supportsUltraWide,
    ).toggledMode(_state.currentZoomMode);

    final targetCamera = _cameraForMode(targetMode);
    final activeCamera = _activeCamera;
    if (targetCamera != null && targetCamera != activeCamera) {
      await _switchCameraLens(targetCamera, targetMode);
      return;
    }

    await _setZoomOnActiveController(targetMode);
  }

  Future<_InitializedCamera> _createInitializedCamera(
    CameraDescription camera, {
    required bool preferUltraWide,
  }) async {
    final controller = widget.cameraRuntimeService.createControllerFor(camera);
    await controller.initialize();

    final minZoom = await controller.getMinZoomLevel();
    final maxZoom = await controller.getMaxZoomLevel();
    final zoomProfile = CameraZoomProfile.fromBounds(
      minZoom: minZoom,
      maxZoom: maxZoom,
      hasUltraWideLens: _hasUltraWideLens,
      preferUltraWide: preferUltraWide,
    );
    final mode = preferUltraWide && _isUltraWideLens(camera)
        ? CameraZoomMode.ultraWide
        : zoomProfile.defaultZoomMode;
    final zoom = zoomProfile.zoomForMode(
      mode,
      usesUltraWideLens: _isUltraWideLens(camera),
    );
    await controller.setZoomLevel(zoom);

    return _InitializedCamera(
      controller: controller,
      state: CameraRuntimeState.ready(
        currentZoomLevel: zoom,
        minZoom: zoomProfile.minZoom,
        maxZoom: zoomProfile.maxZoom,
        supportsUltraWide: zoomProfile.supportsUltraWide,
        currentZoomMode: mode,
        lensType: camera.lensType,
      ),
    );
  }

  Future<void> _switchCameraLens(
    CameraDescription targetCamera,
    CameraZoomMode targetMode,
  ) async {
    final previousState = _state;
    setState(() => _state = previousState.copyWithZoom(
          currentZoomLevel:
              previousState.currentZoomLevel ?? CameraZoomProfile.normal,
          isSwitchingZoom: true,
        ));

    CameraRuntimeController? nextController;
    try {
      final initialized = await _createInitializedCamera(
        targetCamera,
        preferUltraWide: targetMode == CameraZoomMode.ultraWide,
      );
      nextController = initialized.controller;
      if (!mounted) {
        await nextController.dispose();
        return;
      }

      final previousController = _controller;
      setState(() {
        _controller = initialized.controller;
        _activeCamera = targetCamera;
        _state = initialized.state.copyWithZoom(
          currentZoomLevel: initialized.state.currentZoomLevel!,
          isSwitchingZoom: false,
          currentZoomMode: targetMode,
          lensType: targetCamera.lensType,
        );
      });
      await previousController?.dispose();
    } on CameraException {
      await nextController?.dispose();
      if (!mounted) return;
      setState(() => _state = previousState.copyWithZoom(
            currentZoomLevel:
                previousState.currentZoomLevel ?? CameraZoomProfile.normal,
            isSwitchingZoom: false,
          ));
    } catch (_) {
      await nextController?.dispose();
      if (!mounted) return;
      setState(() => _state = previousState.copyWithZoom(
            currentZoomLevel:
                previousState.currentZoomLevel ?? CameraZoomProfile.normal,
            isSwitchingZoom: false,
          ));
    }
  }

  Future<void> _setZoomOnActiveController(CameraZoomMode targetMode) async {
    final controller = _controller;
    final currentZoom = _state.currentZoomLevel;
    final minZoom = _state.minZoom;
    final maxZoom = _state.maxZoom;
    if (controller == null ||
        currentZoom == null ||
        minZoom == null ||
        maxZoom == null) {
      return;
    }

    final previousState = _state;
    final profile = CameraZoomProfile(
      minZoom: minZoom,
      maxZoom: maxZoom,
      defaultZoom: currentZoom,
      defaultZoomMode: _state.currentZoomMode,
      supportsUltraWide: _state.supportsUltraWide,
    );
    final targetZoom = profile.zoomForMode(
      targetMode,
      usesUltraWideLens: _isUltraWideLens(_activeCamera),
    );

    setState(() => _state = _state.copyWithZoom(
          currentZoomLevel: currentZoom,
          isSwitchingZoom: true,
        ));

    try {
      await controller.setZoomLevel(targetZoom);
      if (!mounted) return;
      setState(() => _state = _state.copyWithZoom(
            currentZoomLevel: targetZoom,
            currentZoomMode: targetMode,
            isSwitchingZoom: false,
          ));
    } on CameraException {
      if (!mounted) return;
      setState(() => _state = previousState.copyWithZoom(
            currentZoomLevel: previousState.currentZoomLevel!,
            isSwitchingZoom: false,
          ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = previousState.copyWithZoom(
            currentZoomLevel: previousState.currentZoomLevel!,
            isSwitchingZoom: false,
          ));
    }
  }

  CameraDescription? _cameraForMode(CameraZoomMode mode) {
    return switch (mode) {
      CameraZoomMode.ultraWide =>
        CameraRuntimeService.selectUltraWideBackCamera(_backCameras),
      CameraZoomMode.normal =>
        CameraRuntimeService.selectNormalBackCamera(_backCameras),
    };
  }

  bool get _hasUltraWideLens =>
      CameraRuntimeService.selectUltraWideBackCamera(_backCameras) != null;

  bool _isUltraWideLens(CameraDescription? camera) =>
      camera?.lensType == CameraLensType.ultraWide;

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _activeCamera = null;
    _backCameras = const [];
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = _state.availability == CameraRuntimeAvailability.ready &&
        controller != null &&
        controller.isInitialized;

    return Stack(children: [
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
    ]);
  }
}

class _InitializedCamera {
  const _InitializedCamera({required this.controller, required this.state});

  final CameraRuntimeController controller;
  final CameraRuntimeState state;
}

class _CameraFallbackStatus extends StatelessWidget {
  const _CameraFallbackStatus({required this.state});

  final CameraRuntimeState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state.availability) {
      CameraRuntimeAvailability.permissionDenied => 'Kamerazugriff verweigert',
      CameraRuntimeAvailability.unavailable ||
      CameraRuntimeAvailability.failed =>
        'Kamera nicht verfügbar',
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
