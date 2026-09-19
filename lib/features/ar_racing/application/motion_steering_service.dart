import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

abstract interface class MotionSteeringService {
  Stream<double> get steering;
}

final class PhoneMotionSteeringService implements MotionSteeringService {
  @override
  Stream<double> get steering => gyroscopeEventStream(
    samplingPeriod: SensorInterval.gameInterval,
  ).map((event) => (event.y / 3).clamp(-1.0, 1.0));
}

final class MockMotionSteeringService implements MotionSteeringService {
  const MockMotionSteeringService();

  @override
  Stream<double> get steering => const Stream<double>.empty();
}
