import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/payment_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_state.dart';
import 'package:goodfood_ecosystem/features/orders/data/repositories/customer_orders_repository.dart';
import 'package:goodfood_ecosystem/features/orders/data/services/customer_order_tracking.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view_models/orders_cubit.dart';
import 'package:goodfood_ecosystem/features/orders/presentation/view_models/orders_state.dart';

List<OrderItemModel> meals() => [
  OrderItemModel(
    mealId: 'test-meal',
    mealName: 'Test meal',
    mealImage: 'https://example.com/meal.jpg',
    quantity: 2,
    unitPrice: 10,
  ),
];

class FailingTracking extends CustomerOrderTracking {
  FailingTracking() : super(scope: 'test-device');
  @override
  Future<void> rememberReadableOrder(String documentId) async {
    throw StateError('Storage unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'saved order survives new sessions and status updates use real models',
    () async {
      final store =
          FakeFirebaseFirestore(); // Test double only, never production.
      final tracking = CustomerOrderTracking(scope: 'test-device');
      final creator = CustomerOrderCubit(store: store, tracking: tracking);
      addTearDown(creator.close);
      creator.setCustomerDeyails(tableno: 7, noofguests: 2);
      await creator.placeOrder(meals(), 20, 22, 2);
      expect(creator.state, isA<PlaceOrderSuccessState>());
      final id = creator.order!.docId;
      final saved = await store.collection('orders').doc(id).get();
      expect(saved.data()!['meals'][0]['quantity'], 2);
      expect(saved.data()!['table_no'], 7);
      expect(await tracking.readIds(), [id]);
      await creator.updatePayment(PaymentMethod.cash);
      expect(creator.state, isA<UpdatePaymentSuccessState>());
      expect(await tracking.readIds(), [
        id,
      ]); // Payment never duplicates tracking.

      // Untracked restaurant orders must not appear on this device.
      await store.collection('orders').add(creator.order!.toMap());
      final restartedTracking = CustomerOrderTracking(scope: 'test-device');
      final repository = CustomerOrdersRepository(store);
      OrdersCubit openOrders() => OrdersCubit(
        loadOrders: () =>
            repository.watchTrackedOrders(tracking: restartedTracking),
      );
      final orders = openOrders();
      addTearDown(orders.close);
      final loaded = orders.stream.firstWhere(
        (state) => state is OrdersLoadedState,
      );
      await orders.load();
      final state = await loaded as OrdersLoadedState;
      expect(state.orders.single.docId, id);
      expect(state.orders.single.dispId, creator.order!.dispId);
      expect(
        state.orders.single.meals.single.mealImage,
        meals().single.mealImage,
      );
      expect(state.orders.single.total, 22);
      expect(state.orders.single.createdAt, creator.order!.createdAt);
      expect(state.visibleOrders.single.status, OrderStatus.pending);

      final updated = orders.stream.firstWhere(
        (state) =>
            state is OrdersLoadedState &&
            state.orders.single.status == OrderStatus.delivered,
      );
      await store.collection('orders').doc(id).update({'status': 'delivered'});
      final delivered = await updated as OrdersLoadedState;
      expect(delivered.visibleOrders, isEmpty);
      orders.selectTab(OrdersTab.history);
      expect(
        (orders.state as OrdersLoadedState).visibleOrders.single.docId,
        id,
      );
      await orders.close();

      final reopened = openOrders();
      addTearDown(reopened.close);
      final reopenedLoaded = reopened.stream.firstWhere(
        (s) => s is OrdersLoadedState,
      );
      await reopened.load();
      expect(
        (await reopenedLoaded as OrdersLoadedState).orders.single.docId,
        id,
      );
      expect(
        await CustomerOrderTracking(scope: 'other-principal').readIds(),
        isEmpty,
      );
    },
  );

  test(
    'device writes are deduplicated and concurrent saves are retained',
    () async {
      final tracking = CustomerOrderTracking(scope: 'test-device');
      await Future.wait([
        tracking.rememberReadableOrder('one'),
        CustomerOrderTracking(
          scope: 'test-device',
        ).rememberReadableOrder('two'),
        tracking.rememberReadableOrder('one'),
      ]);
      expect(await tracking.readIds(), ['one', 'two']);
    },
  );

  test('denied creation leaves no tracking or empty payment order', () async {
    final store = FakeFirebaseFirestore(
      // Minimal test policy; this does not validate deployed security rules.
      securityRules: '''
          service cloud.firestore {
            match /databases/{database}/documents {
              match /orders/{id} { allow read, write: if false; }
            }
          }
        ''',
    );
    final tracking = CustomerOrderTracking(scope: 'test-device');
    final creator = CustomerOrderCubit(store: store, tracking: tracking);
    addTearDown(creator.close);
    await creator.placeOrder(meals(), 20, 22, 2);
    expect(creator.state, isA<PlaceOrderFailState>());
    expect(creator.order, isNull);
    expect(await tracking.readIds(), isEmpty);
    await creator.updatePayment(PaymentMethod.cash);
    expect(creator.state, isA<UpdatePaymentFailState>());
    expect(await tracking.readIds(), isEmpty);
  });

  test(
    'write success with denied read does not persist IDs or fail the order',
    () async {
      final store = FakeFirebaseFirestore(
        securityRules: '''
      service cloud.firestore {
        match /databases/{database}/documents {
          match /orders/{id} { allow write: if true; allow read: if false; }
        }
      }
    ''',
      );
      final tracking = CustomerOrderTracking(scope: 'test-device');
      final creator = CustomerOrderCubit(store: store, tracking: tracking);
      addTearDown(creator.close);
      await creator.placeOrder(meals(), 20, 22, 2);
      expect(creator.state, isA<PlaceOrderSuccessState>());
      expect(creator.trackingWarning, isNotNull);
      expect(await tracking.readIds(), isEmpty);
    },
  );

  test(
    'local persistence failure never turns a successful write into a failed order',
    () async {
      final store = FakeFirebaseFirestore();
      final creator = CustomerOrderCubit(
        store: store,
        tracking: FailingTracking(),
      );
      addTearDown(creator.close);
      await creator.placeOrder(meals(), 20, 22, 2);
      expect(creator.state, isA<PlaceOrderSuccessState>());
      expect(creator.trackingWarning, isNotNull);
      expect((await store.collection('orders').get()).docs, hasLength(1));
    },
  );
}
