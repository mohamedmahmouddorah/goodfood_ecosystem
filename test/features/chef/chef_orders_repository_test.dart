import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/features/chef/data/repositories/chef_orders_repository.dart';
import 'package:goodfood_ecosystem/features/chef/data/repositories/chef_orders_source.dart';
import 'package:goodfood_ecosystem/features/chef/data/services/chef_identity_service.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/orders/data/repositories/customer_orders_repository.dart';

class TestUser implements User {
  TestUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuth implements FirebaseAuth {
  TestAuth(String uid) : currentUser = TestUser(uid);
  @override
  User? currentUser;
  final changes = StreamController<User?>.broadcast();
  void signOutLocally() {
    currentUser = null;
    changes.add(null);
  }

  @override
  Stream<User?> authStateChanges() => Stream.multi((controller) {
    controller.add(currentUser);
    final subscription = changes.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> legacyOrder() => {
  'disp_id': 'GF-TEST',
  'table_no': 5,
  'no_of_guests': 2,
  'meals': [
    {
      'meal_id': 'test',
      'meal_name': 'Test meal',
      'meal_image': '',
      'quantity': 2,
      'unit_price': 10,
    },
  ],
  'status': 'pending',
  'subtotal': 20,
  'service_charge': 0,
  'total': 20,
  'created_at': Timestamp.fromDate(DateTime.utc(2026, 11, 17, 12)),
};

Future<ChefOrderQueues> waitQueue(
  ChefOrdersRepository repo,
  bool Function(ChefOrderQueues) predicate,
) => repo.watch().firstWhere(predicate).timeout(const Duration(seconds: 5));

void main() {
  test(
    'legacy missing and explicit null fields preserve original serialization',
    () {
      for (final fields in [
        <String, dynamic>{},
        {
          'acceptedByChefId': null,
          'acceptedByChefName': null,
          'acceptedAt': null,
          'readyAt': null,
        },
      ]) {
        final model = OrderModel.fromMap({...legacyOrder(), ...fields}, []);
        expect(model.isUnassigned, isTrue);
        expect(model.acceptedAt, isNull);
        expect(model.readyAt, isNull);
        expect(model.toMap().containsKey('acceptedByChefId'), isFalse);
        expect(model.toMap()['status'], 'pending');
      }
    },
  );

  test(
    'optional assignment metadata round-trips without changing the enum',
    () {
      final accepted = Timestamp.fromDate(DateTime.utc(2026, 11, 17, 12, 1));
      final ready = Timestamp.fromDate(DateTime.utc(2026, 11, 17, 12, 15));
      final data = {
        ...legacyOrder(),
        'status': 'ready',
        'acceptedByChefId': 'a',
        'acceptedByChefName': 'Original Chef',
        'acceptedAt': accepted,
        'readyAt': ready,
      };
      final model = OrderModel.fromMap(data, []);
      expect(model.acceptedByChefId, 'a');
      expect(model.acceptedByChefName, 'Original Chef');
      expect(model.toMap()['acceptedAt'], accepted);
      expect(model.toMap()['readyAt'], ready);
      expect(model.status, OrderStatus.ready);
      expect(model.isUnassigned, isFalse);
      expect(OrderStatus.values.map((value) => value.name), [
        'pending',
        'preparing',
        'ready',
        'delivered',
        'canceled',
      ]);
    },
  );

  test(
    'real repository assigns an Auth UID, switches queues, and customer parsing receives Ready',
    () async {
      final store = FakeFirebaseFirestore();
      final authA = TestAuth('auth-a'), authB = TestAuth('auth-b');
      addTearDown(authA.changes.close);
      addTearDown(authB.changes.close);
      await store.collection('users').doc('auth-a').set({
        'uid': 'forged-profile-id',
        'name': 'Original Chef',
        'role': 'Chef',
        'status': 'Active',
      });
      await store.collection('users').doc('auth-b').set({
        'name': 'Chef B',
        'role': 'Chef',
        'status': 'Active',
      });
      await store.collection('orders').doc('order').set(legacyOrder());
      final a = ChefOrdersRepository(store: store, auth: authA);
      final b = ChefOrdersRepository(store: store, auth: authB);
      expect(
        (await waitQueue(
          a,
          (queue) => queue.incoming.isNotEmpty,
        )).incoming.single.docId,
        'order',
      );
      expect(
        (await waitQueue(
          b,
          (queue) => queue.incoming.isNotEmpty,
        )).incoming.single.docId,
        'order',
      );
      await a.accept('order');
      final assigned = (await store.collection('orders').doc('order').get())
          .data()!;
      expect(assigned['acceptedByChefId'], 'auth-a');
      expect(assigned['acceptedByChefName'], 'Original Chef');
      expect(assigned['acceptedAt'], isA<Timestamp>());
      expect(
        (await waitQueue(
          a,
          (queue) => queue.active.isNotEmpty,
        )).active.single.status,
        OrderStatus.preparing,
      );
      final other = await waitQueue(b, (queue) => queue.incoming.isEmpty);
      expect(other.active, isEmpty);
      expect(other.ready, isEmpty);
      await expectLater(b.accept('order'), throwsA(isA<ChefOrderConflict>()));
      await expectLater(b.markReady('order'), throwsA(isA<ChefAccessDenied>()));

      final customerUpdates = CustomerOrdersRepository(
        store,
      ).watchOrders(['order']);
      final receivedReady = customerUpdates.firstWhere(
        (orders) => orders.single.status == OrderStatus.ready,
      );
      await store.collection('users').doc('auth-a').update({
        'name': 'Renamed Chef',
      });
      await a.markReady('order');
      final customerOrder = (await receivedReady).single;
      expect(customerOrder.acceptedByChefName, 'Original Chef');
      expect(customerOrder.readyAt, isNotNull);
      final reopened = ChefOrdersRepository(store: store, auth: authA);
      final restored = await waitQueue(
        reopened,
        (queue) => queue.ready.isNotEmpty,
      );
      expect(restored.ready.single.acceptedByChefId, 'auth-a');
      expect(restored.active, isEmpty);
    },
  );

  test(
    'inactive users and partially assigned pending orders cannot be claimed',
    () async {
      final store = FakeFirebaseFirestore();
      final auth = TestAuth('a');
      addTearDown(auth.changes.close);
      final repo = ChefOrdersRepository(store: store, auth: auth);
      await store.collection('users').doc('a').set({
        'name': 'A',
        'role': 'Chef',
        'status': 'Inactive',
      });
      await store.collection('orders').doc('order').set(legacyOrder());
      await expectLater(repo.accept('order'), throwsA(isA<ChefAccessDenied>()));
      await store.collection('users').doc('a').update({'status': 'Active'});
      await store.collection('orders').doc('order').update({
        'acceptedByChefName': 'Partial assignment',
      });
      expect(
        (await waitQueue(repo, (queue) => queue.incoming.isEmpty)).incoming,
        isEmpty,
      );
      await expectLater(
        repo.accept('order'),
        throwsA(isA<ChefOrderConflict>()),
      );
    },
  );

  test(
    'sign-out cancels the old identity listeners before further data can appear',
    () async {
      final store = FakeFirebaseFirestore();
      final auth = TestAuth('a');
      addTearDown(auth.changes.close);
      await store.collection('users').doc('a').set({
        'name': 'A',
        'role': 'Chef',
        'status': 'Active',
      });
      final repo = ChefOrdersRepository(store: store, auth: auth);
      final loaded = Completer<void>(), denied = Completer<void>();
      var eventCount = 0;
      final subscription = repo.watch().listen(
        (_) {
          eventCount++;
          if (!loaded.isCompleted) loaded.complete();
        },
        onError: (Object error) {
          if (error is ChefAccessDenied && !denied.isCompleted) {
            denied.complete();
          }
        },
      );
      addTearDown(subscription.cancel);
      await loaded.future.timeout(const Duration(seconds: 5));
      auth.signOutLocally();
      await denied.future.timeout(const Duration(seconds: 5));
      final before = eventCount;
      await store.collection('orders').doc('new').set(legacyOrder());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(eventCount, before);
      await expectLater(repo.accept('new'), throwsA(isA<ChefAccessDenied>()));
    },
  );
}
