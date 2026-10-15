import 'package:flutter/material.dart';

import '../../data/models/meal_model.dart';
import 'menu_palette.dart';

/// Shared by the customer menu and the admin Menu Management screen.
/// `null` means "All".
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final MealCategory? selected;
  final ValueChanged<MealCategory?> onSelected;

  static final List<MealCategory?> _items = [null, ...MealCategory.values];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = [for (final category in _items) _chip(category)];
        if (constraints.maxWidth >= 600) {
          return SizedBox(
            height: 46,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    children[index],
                  ],
                ],
              ),
            ),
          );
        }
        return SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => children[index],
          ),
        );
      },
    );
  }

  Widget _chip(MealCategory? category) {
    final isSelected = category == selected;
    return GestureDetector(
      onTap: () => onSelected(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isSelected ? MenuPalette.goldGradient : null,
          color: isSelected ? null : MenuPalette.surface,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: isSelected ? MenuPalette.gold : MenuPalette.border,
          ),
        ),
        child: Text(
          category?.label ?? 'All',
          style: TextStyle(
            color: isSelected ? Colors.black : MenuPalette.muted,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
