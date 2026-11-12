import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view/add_edit_meal_screen.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/widgets/admin_meal_tile.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/widgets/category_chips.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/widgets/meal_card.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/widgets/meal_image.dart';

void main() {
  testWidgets('meal image decode cache matches its physical display size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 150,
            height: 80,
            child: MealImage(url: 'https://example.com/meal.jpg'),
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheWidth, 300);
    expect(image.memCacheHeight, 160);
  });

  testWidgets('Windows camera screen keeps the device picker available', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(const MaterialApp(home: AddEditMealScreen()));
      await tester.tap(find.text('Choose image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Choose from device'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('meal image action offers the camera and device library', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddEditMealScreen()));
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from device'), findsOneWidget);
  });

  testWidgets('meal editor adapts to narrow phone widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 180.0, 100.0]) {
      tester.view.physicalSize = Size(width, 800);

      await tester.pumpWidget(const MaterialApp(home: AddEditMealScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('meal-name')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('meal-price')));
      expect(find.byKey(const ValueKey('meal-price')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
  });

  testWidgets('meal name is limited to 60 characters', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AddEditMealScreen()));
    final nameField = find.byKey(const ValueKey('meal-name'));

    expect(
      tester
          .widget<TextField>(
            find.descendant(of: nameField, matching: find.byType(TextField)),
          )
          .maxLength,
      60,
    );

    await tester.enterText(nameField, 'a' * 150);
    await tester.pump();

    expect(tester.widget<TextFormField>(nameField).controller!.text.length, 60);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal name minimum length is validated when focus changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AddEditMealScreen()));

    await tester.enterText(find.byKey(const ValueKey('meal-name')), 'ab');
    await tester.tap(find.byKey(const ValueKey('meal-description')));
    await tester.pump();

    expect(
      find.text('Meal name must be at least 3 characters.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('description and image URL are limited while typing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AddEditMealScreen()));
    final descriptionField = find.byKey(const ValueKey('meal-description'));
    final imageUrlField = find.byKey(const ValueKey('meal-image-url'));

    await tester.enterText(descriptionField, 'd' * 600);
    await tester.enterText(imageUrlField, 'https://example.com/${'i' * 2100}');
    await tester.pump();

    expect(
      tester.widget<TextFormField>(descriptionField).controller!.text.length,
      500,
    );
    expect(
      tester.widget<TextFormField>(imageUrlField).controller!.text.length,
      2048,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('price accepts at most five digits and two decimals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AddEditMealScreen()));
    final priceField = find.byKey(const ValueKey('meal-price'));

    await tester.enterText(priceField, '99999.99');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(priceField).controller!.text,
      '99999.99',
    );

    await tester.enterText(priceField, '100000.00');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(priceField).controller!.text,
      '99999.99',
    );
    expect(tester.takeException(), isNull);
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

  testWidgets('admin product tile adapts to narrow widths', (tester) async {
    final meal = const MealModel(
      id: 'admin-meal',
      name: 'Grilled Chicken',
      category: MealCategory.mainCourse,
      price: 12.99,
      imageUrl: '',
    );

    for (final width in [100.0, 180.0, 320.0, 760.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: AdminMealTile(
                  meal: meal,
                  onTap: () {},
                  onToggle: (_) {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Grilled Chicken'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
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
