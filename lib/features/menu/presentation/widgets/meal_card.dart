import 'package:flutter/material.dart';

import '../../data/models/meal_model.dart';
import 'meal_image.dart';
import 'menu_palette.dart';

class MealCard extends StatelessWidget {
  const MealCard({
    super.key,
    required this.meal,
    required this.onTap,
    required this.onAdd,
  });

  final MealModel meal;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MenuPalette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: MenuPalette.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Hero(
                      tag: 'meal_${meal.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: MealImage(
                          url: meal.imageUrl,
                          width: double.infinity,
                          cacheWidth: 600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    meal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\$${meal.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onAdd,
                          customBorder: const CircleBorder(),
                          child: Ink(
                            width: constraints.maxWidth < 120 ? 26 : 30,
                            height: constraints.maxWidth < 120 ? 26 : 30,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: MenuPalette.goldGradient,
                            ),
                            child: Icon(
                              Icons.add,
                              color: Colors.black,
                              size: constraints.maxWidth < 120 ? 17 : 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}