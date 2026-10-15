import 'package:flutter/material.dart';

import '../../data/models/meal_model.dart';
import '../widgets/meal_image.dart';
import '../widgets/menu_palette.dart';

class MealDetailsScreen extends StatelessWidget {
  const MealDetailsScreen({
    super.key,
    required this.meal,
    required this.onAdd,
  });

  final MealModel meal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MenuPalette.bg,
      appBar: AppBar(
        backgroundColor: MenuPalette.bg,
        foregroundColor: Colors.white,
        title: const Text(
          'Meal Details',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final image = ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Hero(
              tag: 'meal_${meal.id}',
              child: AspectRatio(
                aspectRatio: isWide ? 1.45 : 1.25,
                child: MealImage(url: meal.imageUrl, cacheWidth: 900),
              ),
            ),
          );
          final details = _mealInformation();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    image,
                    const SizedBox(height: 22),
                    details,
                    const SizedBox(height: 24),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 500 : double.infinity,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: MenuPalette.goldGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: FilledButton.icon(
                              onPressed: onAdd,
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                color: Colors.black,
                              ),
                              label: const Text(
                                'Add to Cart',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mealInformation() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meal.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '\$${meal.price.toStringAsFixed(2)}',
            style: const TextStyle(
              color: MenuPalette.gold,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: MenuPalette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MenuPalette.border),
            ),
            child: Text(
              meal.category.label,
              style: const TextStyle(color: MenuPalette.muted),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Description',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meal.description.isEmpty
                ? 'No description available.'
                : meal.description,
            style: const TextStyle(
              color: MenuPalette.muted,
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ],
      );
}