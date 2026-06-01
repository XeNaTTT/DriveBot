import 'package:flutter/foundation.dart';

class ArSelectionController extends ChangeNotifier {
  String? _selectedInfoObjectId;

  String? get selectedInfoObjectId => _selectedInfoObjectId;

  void select(String id) {
    if (_selectedInfoObjectId == id) return;
    _selectedInfoObjectId = id;
    notifyListeners();
  }

  void collapse() {
    if (_selectedInfoObjectId == null) return;
    _selectedInfoObjectId = null;
    notifyListeners();
  }

  void collapseIfMissing(Iterable<String> visibleIds) {
    final selected = _selectedInfoObjectId;
    if (selected == null) return;
    if (!visibleIds.contains(selected)) collapse();
  }
}
