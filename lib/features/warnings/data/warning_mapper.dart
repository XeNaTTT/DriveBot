import '../../hud/domain/hud_warning_item.dart';

class ApiWarningPayload {
  const ApiWarningPayload({
    required this.type,
    required this.title,
    required this.detail,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.severity,
  });

  final String type;
  final String title;
  final String detail;
  final int distanceMeters;
  final int bearingDegrees;
  final int severity;
}

class WarningMapper {
  const WarningMapper();

  HudWarningItem map(ApiWarningPayload payload) {
    return HudWarningItem(
      type: _mapType(payload.type),
      title: payload.title,
      detail: payload.detail,
      distanceMeters: payload.distanceMeters.clamp(0, 999999),
      bearingDegrees: payload.bearingDegrees % 360,
      severity: payload.severity.clamp(1, 5),
    );
  }

  List<HudWarningItem> mapAll(List<ApiWarningPayload> payloads) {
    return payloads.map(map).toList(growable: false);
  }

  WarningType _mapType(String type) {
    return switch (type.toLowerCase()) {
      'speedcamera' || 'speed_camera' => WarningType.speedCamera,
      'speedlimit' || 'speed_limit' => WarningType.speedLimit,
      'roadwork' || 'roadworks' => WarningType.roadwork,
      'weather' => WarningType.weather,
      'chargingstation' || 'charging_station' => WarningType.chargingStation,
      _ => WarningType.weather,
    };
  }
}
