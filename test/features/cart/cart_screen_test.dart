import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/features/cart/presentation/view/cart_screen.dart';
import 'package:goodfood_ecosystem/features/cart/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';

void main() {
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
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
    await cartCubit.close();
  });
}
