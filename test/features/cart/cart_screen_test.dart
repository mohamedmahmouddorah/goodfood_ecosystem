import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/features/cart/presentation/view/cart_screen.dart';
import 'package:goodfood_ecosystem/features/cart/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';

void main() {
  testWidgets('undoing consecutive removals restores items in original order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cartCubit = CartCubit()
      ..add(
        const MealModel(
          id: 'meal-1',
          name: 'First meal',
          category: MealCategory.starters,
          price: 2,
          imageUrl: '',
        ),
      )
      ..add(
        const MealModel(
          id: 'meal-2',
          name: 'Second meal',
          category: MealCategory.mainCourse,
          price: 3,
          imageUrl: '',
        ),
      )
      ..add(
        const MealModel(
          id: 'meal-3',
          name: 'Third meal',
          category: MealCategory.desserts,
          price: 4,
          imageUrl: '',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cartCubit, child: const CartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final name in ['First meal', 'Second meal', 'Third meal']) {
      await tester.tap(find.byTooltip('Remove $name'));
      await tester.pumpAndSettle();
      expect(find.text('$name removed from your cart.'), findsOneWidget);
    }
    expect(find.text('Undo (3)'), findsOneWidget);
    expect(find.text('Your cart is empty'), findsOneWidget);

    for (final name in ['Second meal', 'First meal']) {
      await tester.tap(find.textContaining('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('$name removed from your cart.'), findsOneWidget);
    }
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(cartCubit.state.items.map((item) => item.meal.name).toList(), [
      'First meal',
      'Second meal',
      'Third meal',
    ]);
    expect(tester.takeException(), isNull);

    await cartCubit.close();
  });

  testWidgets(
    'multiple removals keep undo available 5 seconds after the last',
    (tester) async {
      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cartCubit = CartCubit()
        ..add(
          const MealModel(
            id: 'meal-1',
            name: 'First meal',
            category: MealCategory.starters,
            price: 2,
            imageUrl: '',
          ),
        )
        ..add(
          const MealModel(
            id: 'meal-2',
            name: 'Second meal',
            category: MealCategory.mainCourse,
            price: 3,
            imageUrl: '',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: cartCubit, child: const CartScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove First meal'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.byTooltip('Remove Second meal'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Undo (2)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Undo (2)'), findsNothing);
      expect(cartCubit.state.items, isEmpty);
      expect(tester.takeException(), isNull);

      await cartCubit.close();
    },
  );

  testWidgets('clearing the cart can be undone with all quantities restored', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cartCubit = CartCubit()
      ..add(
        const MealModel(
          id: 'meal-1',
          name: 'Grilled Chicken',
          category: MealCategory.mainCourse,
          price: 12.99,
          imageUrl: '',
        ),
      )
      ..increase('meal-1')
      ..add(
        const MealModel(
          id: 'meal-2',
          name: 'Fresh Juice',
          category: MealCategory.drinks,
          price: 4.5,
          imageUrl: '',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cartCubit, child: const CartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('All items removed from your cart.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Grilled Chicken'), findsOneWidget);
    expect(find.text('Fresh Juice'), findsOneWidget);
    expect(cartCubit.state.items, hasLength(2));
    expect(cartCubit.state.items.first.quantity, 2);
    expect(cartCubit.state.items.last.quantity, 1);
    expect(cartCubit.state.total, closeTo(30.48, 0.001));
    expect(tester.takeException(), isNull);

    await cartCubit.close();
  });

  testWidgets('cart fits a narrow viewport and updates item quantity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cartCubit = CartCubit()
      ..add(
        const MealModel(
          id: 'meal-1',
          name: 'Grilled Chicken',
          category: MealCategory.mainCourse,
          price: 12.99,
          imageUrl: '',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cartCubit, child: const CartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Grilled Chicken'), findsOneWidget);
    expect(find.text('\$12.99'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('\$25.98'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Remove Grilled Chicken'));
    await tester.pumpAndSettle();

    expect(
      find.text('Grilled Chicken removed from your cart.'),
      findsOneWidget,
    );
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Grilled Chicken'), findsOneWidget);
    expect(find.text('\$25.98'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Remove Grilled Chicken'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);
    await cartCubit.close();
  });

  testWidgets(
    'menu changes refresh cart cards and mark hidden products unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const meal = MealModel(
        id: 'meal-1',
        name: 'Original name',
        category: MealCategory.mainCourse,
        price: 10,
        imageUrl: '',
      );
      const hiddenMeal = MealModel(
        id: 'meal-2',
        name: 'Hidden meal',
        category: MealCategory.starters,
        price: 5,
        imageUrl: '',
      );
      final cartCubit = CartCubit()
        ..add(meal)
        ..add(hiddenMeal);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: cartCubit, child: const CartScreen()),
        ),
      );
      await tester.pumpAndSettle();

      const updatedMeal = MealModel(
        id: 'meal-1',
        name: 'Updated name',
        category: MealCategory.mainCourse,
        price: 12,
        imageUrl: '',
      );
      cartCubit.syncAvailableMeals([updatedMeal]);
      await tester.pumpAndSettle();

      expect(find.text('Original name'), findsNothing);
      expect(find.text('Updated name'), findsOneWidget);
      expect(find.text('\$12.00 each'), findsOneWidget);
      expect(find.text('Hidden meal'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('\$12.00'), findsNWidgets(2));
      expect(cartCubit.state.items, hasLength(2));
      expect(cartCubit.state.items.last.meal.isAvailable, isFalse);
      expect(cartCubit.state.total, 12);

      cartCubit.increase(hiddenMeal.id);
      expect(cartCubit.state.items.last.quantity, 1);

      await tester.tap(find.byTooltip('Remove Hidden meal'));
      await tester.pumpAndSettle();
      expect(cartCubit.state.items, hasLength(1));
      expect(cartCubit.state.items.single.meal.id, meal.id);
      expect(tester.takeException(), isNull);
      await cartCubit.close();
    },
  );

  testWidgets('floating notifications stay compact on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cartCubit = CartCubit()
      ..add(
        const MealModel(
          id: 'meal-1',
          name: 'Grilled Chicken',
          category: MealCategory.mainCourse,
          price: 12.99,
          imageUrl: '',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cartCubit, child: const CartScreen()),
      ),
    );
    await tester.tap(find.byTooltip('Remove Grilled Chicken'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).width,
      lessThanOrEqualTo(560),
    );
    expect(tester.takeException(), isNull);
    await cartCubit.close();
  });

  testWidgets('cart and undo notification fit a very narrow window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(100, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cartCubit = CartCubit()
      ..add(
        const MealModel(
          id: 'meal-1',
          name: 'Grilled Chicken',
          category: MealCategory.mainCourse,
          price: 12.99,
          imageUrl: '',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cartCubit, child: const CartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Grilled Chicken'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Remove Grilled Chicken'));
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Clear cart'));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('All items removed from your cart.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Grilled Chicken'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cartCubit.close();
  });
}
