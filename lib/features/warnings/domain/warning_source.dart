import 'drive_warning.dart';
import 'warning_request.dart';

abstract class WarningSource {
  String get sourceLabel;

  Future<List<DriveWarning>> loadWarnings(WarningRequest request);
}
