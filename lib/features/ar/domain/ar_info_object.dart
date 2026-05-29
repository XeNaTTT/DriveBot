import '../../hud/domain/hud_warning_item.dart';
import '../application/distance_formatter.dart';

class ArInfoObject {
  const ArInfoObject({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.sourceLabel,
    required this.warning,
    required this.distanceMeters,
    required this.formattedDistance,
    required this.locationAccuracyMeters,
    required this.distanceConfidence,
    this.validityLabel,
    this.createdAtLabel,
    this.confidenceLabel,
    this.syncStatusLabel,
    this.description,
    this.actionButtons = const [],
  });

  final String id;
  final WarningType type;
  final String title;
  final String subtitle;
  final String sourceLabel;
  final HudWarningItem warning;
  final double? distanceMeters;
  final String formattedDistance;
  final double? locationAccuracyMeters;
  final DistanceConfidence distanceConfidence;
  final String? validityLabel;
  final String? createdAtLabel;
  final String? confidenceLabel;
  final String? syncStatusLabel;
  final String? description;
  final List<ArInfoAction> actionButtons;

  String get typeLabel => switch (type) {
    WarningType.speedCamera => _speedCameraTypeLabel,
    WarningType.speedLimit => 'Verkehrsmeldung',
    WarningType.roadwork =>
      warning.title.toLowerCase().contains('sperr') ? 'Sperrung' : 'Baustelle',
    WarningType.weather => 'Wetterwarnung',
    WarningType.chargingStation => 'Ladestation',
    WarningType.notice => 'Verkehrsmeldung',
  };

  String get _speedCameraTypeLabel {
    final text = '${warning.title} ${warning.detail}'.toLowerCase();
    if (text.contains('mobil')) return 'Mobiler Blitzer';
    return 'Fester Blitzer';
  }
}

class ArInfoAction {
  const ArInfoAction({required this.label, this.enabled = true});

  final String label;
  final bool enabled;
}
