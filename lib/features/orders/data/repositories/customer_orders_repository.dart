import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/firebase/customer_identity_service.dart';
import 'package:rxdart/rxdart.dart';

import '../../../customer_order_management/data/models/order_model.dart';
import '../services/customer_order_tracking.dart';

/// Live queries for owned and legacy device-tracked orders.
/// Firestore rules, never local IDs, enforce authorization.
class CustomerOrdersRepository {
  CustomerOrdersRepository(this.store);

  final FirebaseFirestore store;

  Future<void> cancelOrder(
    String orderId,
    FirebaseAuth auth, {
    String? reason,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw const OrderCancellationException('Sign in to cancel this order.');
    }

    final trimmedReason = reason?.trim() ?? '';
    if (trimmedReason.runes.length > 200) {
      throw const OrderCancellationException(
        'Cancellation reason must be 200 characters or fewer.',
      );
    }
    final ref = store.collection('orders').doc(orderId);
    await store.runTransaction((transaction) async {
      final data = (await transaction.get(ref)).data();
      if (data == null) {
        throw const OrderCancellationException('This order is unavailable.');
      }
      if (auth.currentUser?.uid != uid || data['customerId'] != uid) {
        throw const OrderCancellationException(
          'Only the customer who placed this order can cancel it.',
        );
      }
      if (data['status'] != OrderStatus.pending.name ||
          data['acceptedByChefId'] != null ||
          data['acceptedByChefName'] != null ||
          data['acceptedAt'] != null ||
          data['readyAt'] != null) {
        throw const OrderCancellationException(
          'This order has already been accepted or is no longer pending.',
        );
      }
      transaction.update(ref, {
        'status': OrderStatus.canceled.name,
        if (trimmedReason.isNotEmpty) 'cancellationReason': trimmedReason,
      });
    });
  }

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

class OrderCancellationException implements Exception {
  const OrderCancellationException(this.message);

  final String message;
}
