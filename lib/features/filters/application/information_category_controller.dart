import 'package:flutter/foundation.dart';

import '../domain/information_category.dart';

class InformationCategoryController extends ChangeNotifier {
  InformationCategoryController({Set<InformationCategory>? activeCategories})
    : _activeCategories =
          activeCategories ?? Set.of(InformationCategory.values);

  Set<InformationCategory> _activeCategories;

  Set<InformationCategory> get activeCategories =>
      Set.unmodifiable(_activeCategories);

  bool get hasActiveCategories => _activeCategories.isNotEmpty;

  bool isActive(InformationCategory category) {
    return _activeCategories.contains(category);
  }

  void setActive(InformationCategory category, bool isActive) {
    final next = Set<InformationCategory>.of(_activeCategories);
    if (isActive) {
      next.add(category);
    } else {
      next.remove(category);
    }
    _replaceIfChanged(next);
  }

  void toggle(InformationCategory category) {
    setActive(category, !isActive(category));
  }

  void showAll() {
    _replaceIfChanged(Set.of(InformationCategory.values));
  }

  void _replaceIfChanged(Set<InformationCategory> next) {
    if (setEquals(_activeCategories, next)) return;
    _activeCategories = next;
    notifyListeners();
  }
}
