import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../domain/ar_runtime_state.dart';
import 'ar_runtime_service.dart';

final class IosArKitRuntimeService implements ArRuntimeService {
  IosArKitRuntimeService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const viewType = 'drivebot/arkit_view';
  static const _channelName = 'drivebot/arkit_runtime';

  final MethodChannel _channel;

  @override
  Future<ArRuntimeState> getState() async {
    if (!Platform.isIOS) {
      return const ArRuntimeState.fallback('Kamera-Fallback');
    }
    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'currentState',
      );
      if (response == null) {
        return const ArRuntimeState.fallback('AR nicht verfügbar');
      }
      return ArRuntimeState.fromNativeMap(response);
    } on PlatformException catch (error) {
      return ArRuntimeState.fallback(
        error.message?.isNotEmpty == true ? error.message! : 'Kamera-Fallback',
      );
    } on MissingPluginException {
      return const ArRuntimeState.fallback('Kamera-Fallback');
    }
  }

  @override
  Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> start() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('start');
    } on PlatformException {
      // Flutter keeps the camera fallback when the native bridge fails.
    } on MissingPluginException {
      // Flutter keeps the camera fallback when the native bridge is absent.
    }
  }

  @override
  Future<void> stop() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Stopping ARKit must not block HUD teardown.
    } on MissingPluginException {
      // Stopping ARKit must not block HUD teardown.
    }
  }
}
