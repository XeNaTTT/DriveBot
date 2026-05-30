import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../camera/domain/camera_runtime_state.dart';
import '../../location/domain/sensor_permission_status.dart';
import '../data/ar_runtime_service.dart';
import '../data/ios_arkit_runtime_service.dart';
import '../domain/ar_runtime_state.dart';

typedef ArRuntimeStateChanged = void Function(ArRuntimeState state);

class ArKitCameraBackground extends StatefulWidget {
  const ArKitCameraBackground({
    required this.permissionStatus,
    required this.fallbackBuilder,
    this.runtimeService,
    this.onArStateChanged,
    this.onCameraStateChanged,
    super.key,
  });

  final SensorPermissionStatus permissionStatus;
  final Widget Function() fallbackBuilder;
  final ArRuntimeService? runtimeService;
  final ArRuntimeStateChanged? onArStateChanged;
  final ValueChanged<CameraRuntimeState>? onCameraStateChanged;

  @override
  State<ArKitCameraBackground> createState() => _ArKitCameraBackgroundState();
}

class _ArKitCameraBackgroundState extends State<ArKitCameraBackground>
    with WidgetsBindingObserver {
  late ArRuntimeService _runtimeService;
  ArRuntimeState _state = const ArRuntimeState.initial();
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runtimeService = widget.runtimeService ?? IosArKitRuntimeService();
    _prepareRuntime();
  }

  @override
  void didUpdateWidget(covariant ArKitCameraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtimeService != widget.runtimeService) {
      _runtimeService = widget.runtimeService ?? IosArKitRuntimeService();
      _prepareRuntime();
      return;
    }
    if (oldWidget.permissionStatus.camera != widget.permissionStatus.camera) {
      _prepareRuntime();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_state.shouldUseArKit) return;
    if (state == AppLifecycleState.resumed) {
      _startRuntime();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _runtimeService.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _runtimeService.stop();
    super.dispose();
  }

  Future<void> _prepareRuntime() async {
    if (widget.permissionStatus.camera != SensorPermissionState.granted) {
      _publish(const ArRuntimeState.fallback('Kamera-Fallback'));
      if (mounted) setState(() => _isChecking = false);
      return;
    }
    if (!Platform.isIOS) {
      _publish(const ArRuntimeState.fallback('Kamera-Fallback'));
      if (mounted) setState(() => _isChecking = false);
      return;
    }

    if (mounted) setState(() => _isChecking = true);
    final supported = await _runtimeService.isSupported();
    if (!mounted) return;
    if (!supported) {
      _publish(const ArRuntimeState.fallback('AR nicht verfügbar'));
      setState(() => _isChecking = false);
      return;
    }
    await _startRuntime();
  }

  Future<void> _startRuntime() async {
    try {
      await _runtimeService.start();
      final state = await _runtimeService.getState();
      if (!mounted) return;
      _publish(
        state.shouldUseArKit
            ? state.copyWith(isRunning: true)
            : const ArRuntimeState.fallback('Kamera-Fallback'),
      );
      setState(() => _isChecking = false);
    } on Object {
      if (!mounted) return;
      _publish(const ArRuntimeState.fallback('Kamera-Fallback'));
      setState(() => _isChecking = false);
    }
  }

  void _publish(ArRuntimeState state) {
    _state = state;
    widget.onArStateChanged?.call(state);
    if (state.shouldUseArKit) {
      widget.onCameraStateChanged?.call(
        const CameraRuntimeState.ready(
          currentZoomLevel: 1,
          minZoom: 1,
          maxZoom: 1,
          zoomMode: CameraZoomMode.normal,
          canSwitchLens: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state.shouldUseArKit) {
      return const UiKitView(
        key: Key('arkit-camera-background'),
        viewType: IosArKitRuntimeService.viewType,
        creationParamsCodec: StandardMessageCodec(),
      );
    }

    if (_isChecking && Platform.isIOS) {
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.fallbackBuilder(),
          const ColoredBox(color: Color(0x22000000)),
        ],
      );
    }

    return widget.fallbackBuilder();
  }
}
