import 'ar_info_object.dart';

class ArMarkerModel {
  const ArMarkerModel({
    required this.infoObject,
    required this.relativeBearing,
    required this.normalizedX,
    required this.top,
    this.isWorldAnchored = false,
  });

  final ArInfoObject infoObject;
  final double relativeBearing;
  final double normalizedX;
  final double top;
  final bool isWorldAnchored;

  ArMarkerModel copyWith({
    double? normalizedX,
    double? top,
    bool? isWorldAnchored,
  }) => ArMarkerModel(
    infoObject: infoObject,
    relativeBearing: relativeBearing,
    normalizedX: normalizedX ?? this.normalizedX,
    top: top ?? this.top,
    isWorldAnchored: isWorldAnchored ?? this.isWorldAnchored,
  );
}
