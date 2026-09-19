import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

abstract interface class MotionSteeringService {
  Stream<double> get steering;
}

final class PhoneMotionSteeringService implements MotionSteeringService {
  @override
  Stream<double> get steering {
    var smoothed = 0.0;
    return accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).map((event) {
      final target = (event.x / 5.2).clamp(-1.0, 1.0);
      smoothed += (target - smoothed) * .22;
      return smoothed.abs() < .04 ? 0.0 : smoothed;
    });
  }
}

final class MockMotionSteeringService implements MotionSteeringService {
  const MockMotionSteeringService();

  @override
  Stream<double> get steering => const Stream<double>.empty();
}
