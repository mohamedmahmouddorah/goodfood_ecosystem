import 'package:flutter/material.dart';

import '../../data/models/meal_model.dart';
import 'meal_image.dart';
import 'menu_palette.dart';

class AdminMealTile extends StatelessWidget {
  const AdminMealTile({
    super.key,
    required this.meal,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final MealModel meal;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MenuPalette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MenuPalette.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 220;
            final compact = constraints.maxWidth < 340;
            return Padding(
              padding: EdgeInsets.all(narrow ? 6 : 10),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: MealImage(
                            url: meal.imageUrl,
                            width: double.infinity,
                            height: narrow ? 72 : 100,
                            cacheWidth: 400,
                          ),
                        ),
                        SizedBox(height: narrow ? 4 : 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meal.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '\$${meal.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: MenuPalette.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (narrow)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.scale(
                                    scale: 0.7,
                                    child: _availabilitySwitch(),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: IconButton(
                                      onPressed: onDelete,
                                      tooltip: 'Delete meal',
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _availabilitySwitch(),
                              _deleteButton(),
                            ],
                          ],
                        ),
                        if (!narrow) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              meal.isAvailable
                                  ? 'Visible to customers'
                                  : 'Hidden from customers',
                              style: const TextStyle(
                                color: MenuPalette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: MealImage(
                            url: meal.imageUrl,
                            width: 56,
                            height: 56,
                            cacheWidth: 150,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${meal.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: MenuPalette.muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _availabilitySwitch(),
                            Text(
                              meal.isAvailable ? 'Visible' : 'Hidden',
                              style: const TextStyle(
                                color: MenuPalette.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        _deleteButton(),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _availabilitySwitch() => Switch(
    value: meal.isAvailable,
    onChanged: onToggle,
    thumbColor: const WidgetStatePropertyAll(Colors.white),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? MenuPalette.success
          : const Color(0xFF3A4A52),
    ),
  );

  Widget _deleteButton() => IconButton(
    onPressed: onDelete,
    tooltip: 'Delete meal',
    visualDensity: VisualDensity.compact,
    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
  );
}
