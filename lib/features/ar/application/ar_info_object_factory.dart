import '../../hud/domain/hud_warning_item.dart';
import '../../location/domain/location_status.dart';
import 'distance_calculator.dart';
import 'distance_formatter.dart';
import '../domain/ar_info_object.dart';

class ArInfoObjectFactory {
  const ArInfoObjectFactory({
    this.distanceCalculator = const DistanceCalculator(),
    this.distanceFormatter = const DistanceFormatter(),
  });

  final DistanceCalculator distanceCalculator;
  final DistanceFormatter distanceFormatter;

  List<ArInfoObject> createAll({
    required List<HudWarningItem> warnings,
    required LocationStatus location,
  }) {
    return warnings.map((warning) => create(warning, location)).toList();
  }

  ArInfoObject create(HudWarningItem warning, LocationStatus location) {
    final liveDistance = _liveDistance(warning, location);
    final accuracy = location.hasLiveLocation ? location.accuracyMeters : null;
    final formattedDistance = liveDistance == null
        ? (warning.hasCoordinates
              ? 'Entfernung unbekannt'
              : distanceFormatter.format(
                  distanceMeters: warning.distanceMeters.toDouble(),
                  accuracyMeters: null,
                ))
        : distanceFormatter.format(
            distanceMeters: liveDistance,
            accuracyMeters: accuracy,
          );

    return ArInfoObject(
      id: warning.stableId,
      type: warning.type,
      title: _titleFor(warning),
      subtitle: warning.detail,
      sourceLabel: _sourceFor(warning),
      warning: warning,
      distanceMeters: liveDistance ?? warning.distanceMeters.toDouble(),
      formattedDistance: formattedDistance,
      locationAccuracyMeters: accuracy,
      distanceConfidence: warning.hasCoordinates && liveDistance != null
          ? distanceFormatter.confidenceFor(accuracy)
          : DistanceConfidence.unavailable,
      validityLabel: _validityLabel(warning),
      createdAtLabel: _createdAtLabel(warning),
      confidenceLabel: _confidenceLabel(warning, accuracy),
      syncStatusLabel: _syncStatusLabel(warning),
      description: warning.detail,
      actionButtons: _actionsFor(warning),
    );
  }

  double? _liveDistance(HudWarningItem warning, LocationStatus location) {
    final targetLat = warning.latitude;
    final targetLon = warning.longitude;
    final userLat = location.latitude;
    final userLon = location.longitude;
    if (!location.hasLiveLocation ||
        targetLat == null ||
        targetLon == null ||
        userLat == null ||
        userLon == null) {
      return null;
    }
    return distanceCalculator.distanceMeters(
      fromLatitude: userLat,
      fromLongitude: userLon,
      toLatitude: targetLat,
      toLongitude: targetLon,
    );
  }

  String _titleFor(HudWarningItem warning) => switch (warning.type) {
    WarningType.speedCamera =>
      warning.title.contains('Blitzer') ? warning.title : 'Blitzer',
    WarningType.chargingStation => warning.title,
    WarningType.weather => 'Wetterwarnung',
    WarningType.roadwork => warning.title,
    WarningType.speedLimit => warning.title,
    WarningType.notice => warning.title,
  };

  String _sourceFor(HudWarningItem warning) {
    final explicit = warning.source;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return switch (warning.type) {
      WarningType.speedCamera => 'Community',
      WarningType.roadwork || WarningType.speedLimit || WarningType.notice =>
        warning.roadId == null ? 'Autobahn' : 'Autobahn ${warning.roadId}',
      WarningType.weather => 'Wetter',
      WarningType.chargingStation => 'Ladestation',
    };
  }

  String? _validityLabel(HudWarningItem warning) {
    final validTo = warning.validTo;
    if (validTo == null) return null;
    return _dateTimeLabel(validTo);
  }

  String? _createdAtLabel(HudWarningItem warning) {
    final validFrom = warning.validFrom;
    if (validFrom == null) return null;
    return _dateTimeLabel(validFrom);
  }

  String? _confidenceLabel(HudWarningItem warning, double? accuracy) {
    if (accuracy == null) return null;
    return '${accuracy.round()} m';
  }

  String? _syncStatusLabel(HudWarningItem warning) =>
      warning.type == WarningType.speedCamera ? 'Synchronisiert' : null;

  List<ArInfoAction> _actionsFor(HudWarningItem warning) {
    if (warning.type == WarningType.chargingStation) {
      return const [
        ArInfoAction(label: 'Dorthin navigieren'),
        ArInfoAction(label: 'In Karten öffnen'),
      ];
    }
    if (warning.type == WarningType.speedCamera) {
      return const [
        ArInfoAction(label: 'Bestätigen', enabled: false),
        ArInfoAction(label: 'Nicht mehr da', enabled: false),
      ];
    }
    return const [];
  }

  String _dateTimeLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute Uhr';
  }
}
