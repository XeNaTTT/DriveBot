import 'hud_warning_item.dart';

abstract class HudRepository {
  List<HudWarningItem> getNearbyWarnings();
}
