import '../../sensors/domain/heading_utils.dart';

enum GpsFixStatus { strong, moderate, weak, denied, unavailable }

class LocationStatus {
  const LocationStatus({
    required this.speedKph,
    required this.headingDegrees,
    required this.gpsFixStatus,
    required this.isMock,
    required this.isSpeedEstimatedFromGps,
    this.isHeadingFromCompass = false,
    this.isHeadingFromGps = false,
  });

  final int speedKph;
  final int headingDegrees;
  final GpsFixStatus gpsFixStatus;
  final bool isMock;
  final bool isSpeedEstimatedFromGps;
  final bool isHeadingFromCompass;
  final bool isHeadingFromGps;

  bool get hasLiveLocation =>
      gpsFixStatus == GpsFixStatus.strong ||
      gpsFixStatus == GpsFixStatus.moderate ||
      gpsFixStatus == GpsFixStatus.weak;

  bool get hasLiveHeading => isHeadingFromCompass || isHeadingFromGps;

  String get cardinalHeading => HeadingUtils.cardinalDirection(headingDegrees);

  String get gpsLabel => switch (gpsFixStatus) {
        GpsFixStatus.strong => 'GPS strong',
        GpsFixStatus.moderate => 'GPS moderate',
        GpsFixStatus.weak => 'GPS weak',
        GpsFixStatus.denied => 'GPS denied',
        GpsFixStatus.unavailable => 'GPS unavailable',
      };

  LocationStatus copyWith({
    int? speedKph,
    int? headingDegrees,
    GpsFixStatus? gpsFixStatus,
    bool? isMock,
    bool? isSpeedEstimatedFromGps,
    bool? isHeadingFromCompass,
    bool? isHeadingFromGps,
  }) {
    return LocationStatus(
      speedKph: speedKph ?? this.speedKph,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      gpsFixStatus: gpsFixStatus ?? this.gpsFixStatus,
      isMock: isMock ?? this.isMock,
      isSpeedEstimatedFromGps:
          isSpeedEstimatedFromGps ?? this.isSpeedEstimatedFromGps,
      isHeadingFromCompass: isHeadingFromCompass ?? this.isHeadingFromCompass,
      isHeadingFromGps: isHeadingFromGps ?? this.isHeadingFromGps,
    );
  }
}
