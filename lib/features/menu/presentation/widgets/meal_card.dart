import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
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
    return RepaintBoundary(
      child: Material(
        color: MenuPalette.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: MenuPalette.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
              builder: (context, constraints) {
                final isLargeCard = constraints.maxWidth >= 360;
                final cardPadding = constraints.maxWidth >= 420 ? 18.0 : 14.0;
                return Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: 'meal_${meal.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: MealImage(
                                url: meal.imageUrl,
                                localPath: meal.localImagePath,
                                width: double.infinity,
                                cacheWidth: 350,
                              ),
                            ),
                          ),
                          if (constraints.maxWidth >= 120)
                            PositionedDirectional(
                              top: 6,
                              end: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: MenuPalette.surface.withValues(
                                    alpha: .94,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: meal.isAvailable
                                          ? MenuPalette.success
                                          : MenuPalette.muted,
                                    ),
                                    const SizedBox(width: 4),
                                    AppText(
                                      meal.isAvailable
                                          ? 'Available'
                                          : 'Unavailable',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      meal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isLargeCard ? 22 : constraints.maxWidth >= 300 ? 19 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (meal.description.isNotEmpty &&
                        constraints.maxWidth >= 120) ...[
                      Text(
                        meal.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: MenuPalette.muted,
                          fontSize: isLargeCard ? 16 : constraints.maxWidth >= 300 ? 14 : 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            alignment: AlignmentDirectional.centerStart,
                            fit: BoxFit.scaleDown,
                            child: AppText(
                              '\$${meal.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: MenuPalette.gold,
                                fontSize: isLargeCard ? 21 : constraints.maxWidth >= 300 ? 18 : 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: meal.isAvailable ? onAdd : null,
                            customBorder: const CircleBorder(),
                            child: Ink(
                              width: isLargeCard ? 48 : constraints.maxWidth >= 300 ? 42 : constraints.maxWidth < 120 ? 26 : 34,
                              height: isLargeCard ? 48 : constraints.maxWidth >= 300 ? 42 : constraints.maxWidth < 120 ? 26 : 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: meal.isAvailable
                                    ? MenuPalette.gold
                                    : MenuPalette.border,
                              ),
                              child: Icon(
                                meal.isAvailable ? Icons.add : Icons.remove,
                                color: Colors.black,
                                size: isLargeCard ? 28 : constraints.maxWidth >= 300 ? 25 : constraints.maxWidth < 120 ? 17 : 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
                );
              },
            ),
        ),
      ),
    );
  }
}
