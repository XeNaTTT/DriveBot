import '../domain/hud_repository.dart';
import '../domain/hud_warning_item.dart';

class MockHudRepository implements HudRepository {
  @override
  List<HudWarningItem> getNearbyWarnings() {
    return const [
      HudWarningItem(
        type: WarningType.speedCamera,
        title: 'Speed Camera Ahead',
        detail: 'Fixed camera in 450 m',
        distanceMeters: 450,
        severity: 4,
      ),
      HudWarningItem(
        type: WarningType.speedLimit,
        title: 'Speed Limit 80 km/h',
        detail: 'Zone starts in 300 m',
        distanceMeters: 300,
        severity: 5,
      ),
      HudWarningItem(
        type: WarningType.roadwork,
        title: 'Roadwork Zone',
        detail: 'Lane narrowing in 1.2 km',
        distanceMeters: 1200,
        severity: 3,
      ),
      HudWarningItem(
        type: WarningType.weather,
        title: 'Weather Warning',
        detail: 'Heavy rain segment in 2.4 km',
        distanceMeters: 2400,
        severity: 3,
      ),
      HudWarningItem(
        type: WarningType.chargingStation,
        title: 'Charging Station Nearby',
        detail: '150 kW charger in 3.1 km',
        distanceMeters: 3100,
        severity: 1,
      ),
    ];
  }
}
