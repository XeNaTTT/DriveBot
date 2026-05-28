import '../../hud/domain/hud_warning_item.dart';

class ArMarkerModel {
  const ArMarkerModel({
    required this.warning,
    required this.relativeBearing,
    required this.normalizedX,
    required this.top,
  });

  final HudWarningItem warning;
  final double relativeBearing;
  final double normalizedX;
  final double top;
}
