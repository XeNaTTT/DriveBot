import '../domain/hud_repository.dart';
import '../domain/hud_warning_item.dart';

class MockHudRepository implements HudRepository {
  @override
  List<HudWarningItem> getNearbyWarnings() {
    return const [
      HudWarningItem(
        type: WarningType.speedCamera,
        title: 'Blitzer voraus',
        detail: 'Feste Kamera in 450 m',
        distanceMeters: 450,
        bearingDegrees: 75,
        severity: 4,
      ),
      HudWarningItem(
        type: WarningType.speedLimit,
        title: 'Tempolimit 80 km/h',
        detail: 'Zone beginnt in 300 m',
        distanceMeters: 300,
        bearingDegrees: 55,
        severity: 5,
      ),
      HudWarningItem(
        type: WarningType.roadwork,
        title: 'Baustelle',
        detail: 'Spurverengung in 1.2 km',
        distanceMeters: 1200,
        bearingDegrees: 105,
        severity: 3,
      ),
      HudWarningItem(
        type: WarningType.weather,
        title: 'Wetterwarnung',
        detail: 'Starkregenabschnitt in 2.4 km',
        distanceMeters: 2400,
        bearingDegrees: 12,
        severity: 3,
      ),
      HudWarningItem(
        type: WarningType.chargingStation,
        title: 'Ladestation in der Nähe',
        detail: '150-kW-Lader in 3.1 km',
        distanceMeters: 3100,
        bearingDegrees: 330,
        severity: 1,
      ),
      HudWarningItem(
        type: WarningType.notice,
        title: 'Hinweis',
        detail: 'Rastplatz in 5 km',
        distanceMeters: 5000,
        bearingDegrees: 15,
        severity: 1,
      ),
    ];
  }
}
