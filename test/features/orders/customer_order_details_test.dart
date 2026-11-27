import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/widgets/meal_image.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view/customer_orders_screen.dart';

import 'customer_orders_test.dart' as fixtures;

void main() {
  testWidgets('correct order and meal IDs follow live order status', (
    tester,
  ) async {
    final orders = StreamController<List<OrderModel>>();
    addTearDown(orders.close);
    final ratings = <List<String>>[];
    final original = fixtures.order('GF-FIRST', OrderStatus.pending, 2);
    final other = fixtures.order('GF-SECOND', OrderStatus.pending, 1);
    final firstMeal = original.meals.single;
    final secondMeal = OrderItemModel(
      mealId: 'second-meal-id',
      mealName: 'Second saved meal',
      mealImage: '',
      quantity: 2,
      unitPrice: 4,
    );
    final meals = [firstMeal, secondMeal, firstMeal];
    OrderModel update(OrderStatus status) => OrderModel.fromMap({
      ...original.toMap(),
      'status': status.name,
      'disp_id': 'GF-FIRST',
    }, meals)..docId = 'first-document-id';

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerOrdersScreen(
          loadOrders: () => orders.stream,
          onRateMeal: (orderId, mealId) => ratings.add([orderId, mealId]),
        ),
      ),
    );
    orders.add([update(OrderStatus.pending), other]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('#GF-SECOND'));
    await tester.pumpAndSettle();
    expect(find.text('Order Details'), findsOneWidget);
    expect(find.text('Second saved meal'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Your orders'), findsOneWidget);

    await tester.tap(find.text('#GF-FIRST'));
    await tester.pumpAndSettle();
    expect(find.text('Order Items'), findsOneWidget);
    expect(find.text('Table 5'), findsOneWidget);
    expect(find.text('Second saved meal'), findsOneWidget);
    expect(find.text('Qty: 2'), findsOneWidget);
    expect(find.text('Qty: 3'), findsNWidgets(2));
    final rate = find.widgetWithText(OutlinedButton, 'Rate Meal');
    expect(rate, findsNothing);

    orders.add([update(OrderStatus.preparing), other]);
    await tester.pumpAndSettle();
    expect(find.text('Preparing'), findsOneWidget);
    expect(rate, findsNothing);

    for (final status in [OrderStatus.ready, OrderStatus.delivered]) {
      orders.add([update(status), other]);
      await tester.pumpAndSettle();
      expect(rate, findsNWidgets(2));
      await tester.ensureVisible(rate.at(0));
      await tester.tap(rate.at(0));
      await tester.ensureVisible(rate.at(1));
      await tester.tap(rate.at(1));
    }
    expect(ratings, [
      ['first-document-id', firstMeal.mealId],
      ['first-document-id', secondMeal.mealId],
      ['first-document-id', firstMeal.mealId],
      ['first-document-id', secondMeal.mealId],
    ]);

    orders.add([update(OrderStatus.canceled), other]);
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
    expect(rate, findsNothing);
    orders.add([other]);
    await tester.pumpAndSettle();
    expect(find.text('This order is unavailable.'), findsOneWidget);
  });

  testWidgets('saved image and disabled rating fit a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = fixtures.order('GF-READY', OrderStatus.ready, 1);
    const imageUrl = 'https://example.test/saved-order-image.jpg';
    final meal = OrderItemModel(
      mealId: 'meal-id',
      mealName: 'A long meal name that needs to wrap across multiple lines',
      mealImage: imageUrl,
      quantity: 3,
      unitPrice: 10,
    );
    final order = OrderModel.fromMap(original.toMap(), [meal])
      ..docId = original.docId;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: CustomerOrdersScreen(loadOrders: () => Stream.value([order])),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('#GF-READY'));
    await tester.pumpAndSettle();

    expect(find.text(meal.mealName), findsOneWidget);
    expect(find.text('Qty: 3'), findsOneWidget);
    final image = tester.widget<MealImage>(find.byType(MealImage));
    expect(image.url, imageUrl);
    final rate = find.widgetWithText(OutlinedButton, 'Rate Meal');
    expect(tester.widget<OutlinedButton>(rate).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
