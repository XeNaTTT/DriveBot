import 'ar_info_object.dart';

class ArMarkerModel {
  const ArMarkerModel({
    required this.infoObject,
    required this.relativeBearing,
    required this.normalizedX,
    required this.top,
  });

  final ArInfoObject infoObject;
  final double relativeBearing;
  final double normalizedX;
  final double top;
}
