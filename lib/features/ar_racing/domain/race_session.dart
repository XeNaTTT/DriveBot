import 'dart:math' as math;

class RaceSession {
  const RaceSession({
    this.speedKmh = 0,
    this.damage = 0,
    this.lap = 1,
    this.steering = 0,
    this.runProgress = 0,
    this.lateralPosition = 0,
  });

  final double speedKmh;
  final int damage;
  final int lap;
  final double steering;

  /// Normalized distance from the camera towards the room's vanishing point.
  final double runProgress;

  /// Normalized horizontal position on the scanned track (-1 left, 1 right).
  final double lateralPosition;

  RaceSession steer(double value) => RaceSession(
    speedKmh: speedKmh,
    damage: damage,
    lap: lap,
    steering: value.clamp(-1, 1),
    runProgress: runProgress,
    lateralPosition: lateralPosition,
  );

  RaceSession drive({
    required double elapsedSeconds,
    required bool accelerating,
    required bool braking,
  }) {
    final acceleration = accelerating ? 42.0 : -9.0;
    final brakeForce = braking ? 76.0 : 0.0;
    final nextSpeed = (speedKmh + (acceleration - brakeForce) * elapsedSeconds)
        .clamp(0.0, 96.0);
    final steeringTravel = steering * (0.28 + nextSpeed / 150) * elapsedSeconds;
    return RaceSession(
      speedKmh: nextSpeed,
      damage: damage,
      lap: lap,
      steering: steering,
      runProgress: math.min(1, runProgress + nextSpeed / 450 * elapsedSeconds),
      lateralPosition: (lateralPosition + steeringTravel).clamp(-1.0, 1.0),
    );
  }

  RaceSession accelerate() => RaceSession(
    speedKmh: math.min(96, speedKmh + 8),
    damage: damage,
    lap: lap,
    steering: steering,
    runProgress: math.min(1, runProgress + .12),
    lateralPosition: lateralPosition,
  );

  RaceSession collide({required double impact}) => RaceSession(
    speedKmh: math.max(8, speedKmh * .42),
    damage: math.min(100, damage + (impact * 24).round()),
    lap: lap,
    steering: steering,
    runProgress: runProgress,
    lateralPosition: lateralPosition,
  );

  double get perspectiveScale => 1 - (runProgress * .64);
}
