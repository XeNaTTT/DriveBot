import 'dart:math' as math;

import 'vehicle_shift_profile.dart';

class ShiftRecommendation {
  const ShiftRecommendation({required this.gear, required this.rpm});

  final int gear;
  final int rpm;
}

class ShiftAdvisor {
  const ShiftAdvisor(this.profile);

  final VehicleShiftProfile profile;

  ShiftRecommendation recommend(int speedKph) {
    if (speedKph <= 0) {
      return ShiftRecommendation(gear: 1, rpm: profile.idleRpm);
    }

    final candidates = List.generate(profile.gearRatios.length, (index) {
      final gear = index + 1;
      return ShiftRecommendation(gear: gear, rpm: rpmFor(speedKph, gear));
    }).where((candidate) => candidate.rpm >= profile.idleRpm).toList();

    if (candidates.isEmpty) {
      return ShiftRecommendation(gear: 1, rpm: profile.idleRpm);
    }
    final efficientCandidates = candidates
        .where(
          (candidate) =>
              candidate.rpm >= profile.ecoRpmStart - 100 &&
              candidate.rpm <= profile.ecoRpmEnd,
        )
        .toList();
    if (efficientCandidates.isNotEmpty) {
      return efficientCandidates.last;
    }
    final ecoTarget = (profile.ecoRpmStart + profile.ecoRpmEnd) / 2;
    candidates.sort(
      (a, b) => (a.rpm - ecoTarget).abs().compareTo((b.rpm - ecoTarget).abs()),
    );
    return candidates.first;
  }

  int rpmFor(int speedKph, int gear) {
    final safeGear = gear.clamp(1, profile.gearRatios.length);
    final wheelRpm = speedKph * 1000 / 60 / profile.wheelCircumferenceMeters;
    final engineRpm =
        wheelRpm * profile.gearRatios[safeGear - 1] * profile.finalDriveRatio;
    return math.max(profile.idleRpm, engineRpm.round());
  }
}
