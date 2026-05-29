import 'package:flutter/material.dart';

import '../application/information_category_controller.dart';
import '../domain/information_category.dart';

class CategoryFilterButton extends StatelessWidget {
  const CategoryFilterButton({required this.controller, super.key});

  final InformationCategoryController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => PopupMenuButton<_CategoryFilterAction>(
        key: const Key('category-filter-button'),
        tooltip: 'Informationskategorien filtern',
        position: PopupMenuPosition.under,
        color: Colors.black.withValues(alpha: 0.92),
        constraints: const BoxConstraints(minWidth: 220),
        onSelected: (action) {
          switch (action) {
            case _ShowAllAction():
              controller.showAll();
            case _ToggleCategoryAction(:final category):
              controller.toggle(category);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem<_CategoryFilterAction>(
            enabled: false,
            child: Text(
              'Informationskategorien',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ...InformationCategory.values.map(
            (category) => CheckedPopupMenuItem<_CategoryFilterAction>(
              key: Key('category-filter-${category.name}'),
              value: _ToggleCategoryAction(category),
              checked: controller.isActive(category),
              child: Text(category.label),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<_CategoryFilterAction>(
            value: _ShowAllAction(),
            child: Text('Alle anzeigen'),
          ),
        ],
        child: Semantics(
          button: true,
          label: 'Informationskategorien filtern',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x9957E3FF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  controller.hasActiveCategories
                      ? Icons.filter_alt
                      : Icons.filter_alt_off,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Filter',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

sealed class _CategoryFilterAction {
  const _CategoryFilterAction();
}

class _ToggleCategoryAction extends _CategoryFilterAction {
  const _ToggleCategoryAction(this.category);

  final InformationCategory category;
}

class _ShowAllAction extends _CategoryFilterAction {
  const _ShowAllAction();
}
