import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view/order_confirmed_view.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';

import '../orders/customer_identity_integration_test.dart'
    show IdentityAuth, IdentityUser;

void main() {
  testWidgets('narrow checkout confirmation tracks the saved order ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = IdentityAuth(IdentityUser('customer'));
    final cubit = CustomerOrderCubit(
      store: FakeFirebaseFirestore(),
      auth: auth,
      secureCustomerFlow: true,
    );
    addTearDown(auth.changes.close);
    addTearDown(cubit.close);
    await tester.runAsync(
      () => cubit.placeOrder(
        [
          OrderItemModel(
            mealId: 'meal',
            mealName: 'Test meal',
            mealImage: '',
            quantity: 2,
            unitPrice: 10,
          ),
        ],
        20,
        22,
        2,
      ),
    );
    final savedId = cubit.order!.docId;
    Object? received;
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const OrderConfirmedView(),
        ),
        routes: {
          '/orders': (context) {
            received = ModalRoute.of(context)?.settings.arguments;
            return const Scaffold(body: Text('Customer orders route'));
          },
        },
      ),
    );
    await tester.pumpAndSettle();
    final track = find.text('Track Your Order');
    await tester.ensureVisible(track);
    await tester.tap(track);
    await tester.pumpAndSettle();
    expect(received, [savedId]);
    expect(find.text('Customer orders route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
