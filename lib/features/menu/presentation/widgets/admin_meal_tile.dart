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
  });

  final MealModel meal;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

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
            final compact = constraints.maxWidth < 300;
            return Padding(
              padding: const EdgeInsets.all(10),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: MealImage(
                            url: meal.imageUrl,
                            width: double.infinity,
                            height: 100,
                            cacheWidth: 400,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: _availabilitySwitch(),
                        ),
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
                        _availabilitySwitch(),
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
}