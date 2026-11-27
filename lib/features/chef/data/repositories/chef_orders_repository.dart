import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../services/chef_identity_service.dart';
import 'chef_orders_source.dart';

/// Uses the same orders documents as Customer Orders. Authorization is also
/// required on the server; see the separately reviewed chef assignment rules.
class ChefOrdersRepository implements ChefOrdersSource {
  ChefOrdersRepository({required this.store, required this.auth});
  final FirebaseFirestore store;
  final FirebaseAuth auth;

  @override
  Stream<ChefOrderQueues> watch() {
    final identity = ChefIdentityService(auth: auth, store: store);
    // Turn access errors into switch events so an invalidated identity cancels
    // its old order listeners before the error reaches the UI.
    return identity.watch().materialize().switchMap((event) {
      if (event is ErrorNotification) {
        return Stream<ChefOrderQueues>.error(event.error, event.stackTrace);
      }
      if (event is! DataNotification<ChefIdentity?>) {
        return const Stream<ChefOrderQueues>.empty();
      }
      final chef = event.value;
      if (chef == null) {
        return Stream<ChefOrderQueues>.error(const ChefAccessDenied());
      }
      return Rx.combineLatest2<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        ChefOrderQueues
      >(
        store
            .collection('orders')
            .where('status', isEqualTo: OrderStatus.pending.name)
            .snapshots(),
        store
            .collection('orders')
            .where('acceptedByChefId', isEqualTo: chef.uid)
            .snapshots(),
        (pending, assigned) {
          final incoming =
              pending.docs
                  .map(OrderModel.fromDocument)
                  .where((order) => order.isUnassigned)
                  .toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          final mine = assigned.docs.map(OrderModel.fromDocument).toList();
          final active =
              mine
                  .where((order) => order.status == OrderStatus.preparing)
                  .toList()
                ..sort(
                  (a, b) => (a.acceptedAt ?? a.createdAt).compareTo(
                    b.acceptedAt ?? b.createdAt,
                  ),
                );
          final ready =
              mine.where((order) => order.status == OrderStatus.ready).toList()
                ..sort(
                  (a, b) => (b.readyAt ?? b.createdAt).compareTo(
                    a.readyAt ?? a.createdAt,
                  ),
                );
          final history =
              mine
                  .where(
                    (order) =>
                        order.status == OrderStatus.ready ||
                        order.status == OrderStatus.delivered ||
                        order.status == OrderStatus.canceled,
                  )
                  .toList()
                ..sort(
                  (a, b) => (b.readyAt ?? b.createdAt).compareTo(
                    a.readyAt ?? a.createdAt,
                  ),
                );
          return ChefOrderQueues(
            chef: chef,
            incoming: incoming,
            active: active,
            ready: ready,
            history: history,
          );
        },
      );
    });
  }

  @override
  Future<void> accept(String orderId) async {
    final uid = _currentUid();
    _validateId(orderId);
    try {
      await store.runTransaction((transaction) async {
        _checkSession(uid);
        final profile = await transaction.get(
          store.collection('users').doc(uid),
        );
        final chef = ChefIdentityService.identityFromProfile(
          uid,
          profile.data(),
        );
        final reference = store.collection('orders').doc(orderId);
        final snapshot = await transaction.get(reference);
        _checkSession(uid);
        if (!snapshot.exists) throw const ChefOrderConflict();
        final order = OrderModel.fromDocument(snapshot);
        if (order.status != OrderStatus.pending || !order.isUnassigned) {
          throw const ChefOrderConflict();
        }
        transaction.update(reference, {
          'status': OrderStatus.preparing.name,
          'acceptedByChefId': chef.uid,
          'acceptedByChefName': chef.name,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      // Once another chef owns it, the proposed rules intentionally revoke our
      // read access. A denied transaction is therefore also an unavailable item.
      if (error.code == 'permission-denied' ||
          error.code == 'aborted' ||
          error.code == 'not-found') {
        throw const ChefOrderConflict();
      }
      rethrow;
    }
  }

  @override
  Future<void> markReady(String orderId) async {
    final uid = _currentUid();
    _validateId(orderId);
    await store.runTransaction((transaction) async {
      _checkSession(uid);
      final profile = await transaction.get(store.collection('users').doc(uid));
      ChefIdentityService.identityFromProfile(uid, profile.data());
      final reference = store.collection('orders').doc(orderId);
      final snapshot = await transaction.get(reference);
      _checkSession(uid);
      if (!snapshot.exists) throw const ChefOrderConflict();
      final order = OrderModel.fromDocument(snapshot);
      if (order.acceptedByChefId != uid) throw const ChefAccessDenied();
      if (order.status != OrderStatus.preparing || order.readyAt != null) {
        throw const ChefOrderConflict();
      }
      transaction.update(reference, {
        'status': OrderStatus.ready.name,
        'readyAt': FieldValue.serverTimestamp(),
      });
    });
  }

  String _currentUid() {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw const ChefAccessDenied();
    return uid;
  }

  void _checkSession(String expectedUid) {
    if (auth.currentUser?.uid != expectedUid) throw const ChefAccessDenied();
  }

  void _validateId(String id) {
    if (id.isEmpty || id.contains('/')) {
      throw ArgumentError.value(id, 'orderId');
    }
  }

  @override
  String? assignmentName(OrderModel order) => order.acceptedByChefName;
}
