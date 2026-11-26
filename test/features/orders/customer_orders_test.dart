import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view/customer_orders_screen.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view_models/orders_cubit.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view_models/orders_state.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/widgets/order_card.dart';

OrderModel order(String id, OrderStatus status, int day) => OrderModel(
  docId: id,
  dispId: id,
  tableNo: 5,
  noOfGuests: 2,
  meals: [
    OrderItemModel(
      mealId: 'meal',
      mealName: 'Meal',
      mealImage: '',
      quantity: 3,
      unitPrice: 10,
    ),
  ],
  status: status,
  subtotal: 30,
  serviceCharge: 0,
  total: 30,
  createdAt: DateTime(2026, 11, day),
);

void main() {
  test('sorts newest first and classifies every existing status', () async {
    final cubit = OrdersCubit(
      loadOrders: () => Stream.value([
        order('pending', OrderStatus.pending, 1),
        order('delivered', OrderStatus.delivered, 2),
        order('preparing', OrderStatus.preparing, 3),
        order('canceled', OrderStatus.canceled, 4),
        order('ready', OrderStatus.ready, 5),
      ]),
    );
    addTearDown(cubit.close);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(
      (cubit.state as OrdersLoadedState).visibleOrders.map((o) => o.docId),
      ['ready', 'preparing', 'pending'],
    );
    cubit.selectTab(OrdersTab.history);
    expect(
      (cubit.state as OrdersLoadedState).visibleOrders.map((o) => o.docId),
      ['canceled', 'delivered'],
    );
  });

  testWidgets('loading, error, retry and empty states', (tester) async {
    final source = StreamController<List<OrderModel>>();
    addTearDown(source.close);
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerOrdersScreen(
          loadOrders: () => ++attempts == 1 ? source.stream : Stream.value([]),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    source.addError(StateError('private error'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load orders'), findsOneWidget);
    // Subscription cancellation may complete outside the fake clock's zone.
    await tester.runAsync(() async {
      await tester.tap(find.text('Try again'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('No active orders'), findsOneWidget);
    await tester.tap(find.text('Order History'));
    await tester.pumpAndSettle();
    expect(find.text('No order history yet'), findsOneWidget);
  });

  for (final width in [320.0, 760.0]) {
    testWidgets(
      'filters live orders and opens selected order at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = StreamController<List<OrderModel>>();
        addTearDown(source.close);
        OrderModel? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: CustomerOrdersScreen(
              loadOrders: () => source.stream,
              onOrderTap: (value) => selected = value,
            ),
          ),
        );
        await tester.pump();
        final active = order('GF-1', OrderStatus.ready, 10);
        source.add([active]);
        await tester.pumpAndSettle();
        expect(find.text('3 items'), findsOneWidget);
        await tester.tap(find.byType(OrderCard));
        expect(selected, same(active));
        source.add([order('GF-1', OrderStatus.delivered, 10)]);
        await tester.pumpAndSettle();
        expect(find.text('No active orders'), findsOneWidget);
        await tester.tap(find.text('Order History'));
        await tester.pumpAndSettle();
        expect(find.text('Delivered'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
