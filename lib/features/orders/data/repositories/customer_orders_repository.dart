import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/firebase/customer_identity_service.dart';
import 'package:rxdart/rxdart.dart';

import '../../../customer_order_management/data/models/order_model.dart';
import '../services/customer_order_tracking.dart';

/// Ownership-scoped live queries for the emulator integration. The legacy
/// ID-based reader remains for the unchanged production flow and preview tests.
/// Firestore rules, never local IDs, enforce authorization.
class CustomerOrdersRepository {
  CustomerOrdersRepository(this.store);

  final FirebaseFirestore store;

  /// Server rules enforce ownership. Identity events first clear the old UI.
  Stream<List<OrderModel>> watchCustomerOrders(FirebaseAuth auth) {
    return auth.authStateChanges().switchMap((user) {
      if (user == null) return Stream.value(<OrderModel>[]);
      return store
          .collection('orders')
          .where('customerId', isEqualTo: user.uid)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(OrderModel.fromDocument).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          )
          .startWith(<OrderModel>[]);
    });
  }

  Stream<List<OrderModel>> watchSignedInCustomerOrders(
    FirebaseAuth auth,
  ) async* {
    await CustomerIdentityService(auth).ensureSignedIn();
    yield* watchCustomerOrders(auth);
  }

  Stream<List<OrderModel>> watchTrackedOrders({
    required CustomerOrderTracking tracking,
    List<String> extraIds = const [],
  }) async* {
    final saved = await tracking.readIds();
    yield* watchOrders([...saved, ...extraIds]);
  }

  Stream<List<OrderModel>> watchOrders(List<String> orderIds) {
    final ids = orderIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return Stream.value(const []);

    return Rx.combineLatestList<OrderModel?>([
      for (final id in ids)
        store.collection('orders').doc(id).snapshots().map((snapshot) {
          final data = snapshot.data();
          if (data == null) return null;
          return OrderModel.fromDocument(snapshot);
        }),
    ]).map((orders) => orders.whereType<OrderModel>().toList());
  }
}
