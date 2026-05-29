import '../../hud/domain/hud_warning_item.dart';

enum InformationCategory {
  speedCamera('Blitzer'),
  roadwork('Baustellen'),
  weather('Wetter'),
  speedLimit('Tempolimits'),
  chargingStation('Ladestationen'),
  notice('Hinweise');

  const InformationCategory(this.label);

  final String label;
}

extension WarningInformationCategory on WarningType {
  InformationCategory get informationCategory {
    return switch (this) {
      WarningType.speedCamera => InformationCategory.speedCamera,
      WarningType.roadwork => InformationCategory.roadwork,
      WarningType.weather => InformationCategory.weather,
      WarningType.speedLimit => InformationCategory.speedLimit,
      WarningType.chargingStation => InformationCategory.chargingStation,
      WarningType.notice => InformationCategory.notice,
    };
  }
}

extension HudWarningCategory on HudWarningItem {
  InformationCategory get informationCategory => type.informationCategory;
}
