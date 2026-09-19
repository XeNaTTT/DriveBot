import 'dart:math' as math;

class RaceSession {
  const RaceSession({
    this.speedKmh = 0,
    this.damage = 0,
    this.lap = 1,
    this.steering = 0,
    this.runProgress = 0,
  });

  final double speedKmh;
  final int damage;
  final int lap;
  final double steering;

  /// Normalized distance from the camera towards the room's vanishing point.
  final double runProgress;

  RaceSession steer(double value) => RaceSession(
    speedKmh: speedKmh,
    damage: damage,
    lap: lap,
    steering: value.clamp(-1, 1),
    runProgress: runProgress,
  );

  RaceSession accelerate() => RaceSession(
    speedKmh: math.min(96, speedKmh + 8),
    damage: damage,
    lap: lap,
    steering: steering,
    runProgress: math.min(1, runProgress + .12),
  );

  RaceSession collide({required double impact}) => RaceSession(
    speedKmh: math.max(8, speedKmh * .42),
    damage: math.min(100, damage + (impact * 24).round()),
    lap: lap,
    steering: steering,
    runProgress: runProgress,
  );

  double get perspectiveScale => 1 - (runProgress * .64);
}
