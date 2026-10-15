import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view/add_edit_meal_screen.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/widgets/category_chips.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/widgets/meal_card.dart';

void main() {
  testWidgets('meal editor adapts to narrow phone widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 180.0, 100.0]) {
      tester.view.physicalSize = Size(width, 800);

      await tester.pumpWidget(const MaterialApp(home: AddEditMealScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('meal-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('meal-price')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
  });

  testWidgets('meal card does not overflow at a very narrow width', (
    tester,
  ) async {
    final meal = const MealModel(
      id: 'meal-1',
      name: 'Grilled Chicken',
      category: MealCategory.mainCourse,
      price: 12.99,
      imageUrl: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 68,
              height: 100,
              child: MealCard(meal: meal, onTap: () {}, onAdd: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Grilled Chicken'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category filters are centered on wide screens', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CategoryChips(selected: null, onSelected: (_) {})),
      ),
    );

    final allChip = tester.getRect(
      find
          .ancestor(of: find.text('All'), matching: find.byType(Container))
          .first,
    );
    final dessertsChip = tester.getRect(
      find
          .ancestor(of: find.text('Desserts'), matching: find.byType(Container))
          .first,
    );
    expect(((allChip.left + dessertsChip.right) / 2), closeTo(500, 1));
    expect(tester.takeException(), isNull);
  });
}
