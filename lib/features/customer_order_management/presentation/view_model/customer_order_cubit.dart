import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/firebase/customer_identity_service.dart';
import '../../../../core/firebase/firebase_environment.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/payment_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_state.dart';
import '../../../orders/data/services/customer_order_tracking.dart';

class CustomerOrderCubit extends Cubit<CustomerOrderState> {
  CustomerOrderCubit({
    FirebaseFirestore? store,
    CustomerOrderTracking? tracking,
    FirebaseAuth? auth,
    bool secureCustomerFlow = FirebaseEnvironment.useOwnedCustomerOrders,
  }) : store = store ?? FirebaseEnvironment.store,
       _tracking = tracking,
       _auth = auth,
       _secureCustomerFlow = secureCustomerFlow,
       super(CustomerOrderIntialState()) {
    if (_secureCustomerFlow) {
      _identitySubscription = (_auth ?? FirebaseEnvironment.auth)
          .authStateChanges()
          .listen((user) {
            final previousUid = _observedUid;
            _observedUid = user?.uid;
            if ((previousUid != null && previousUid != user?.uid) ||
                (order != null && order!.customerId != user?.uid)) {
              name = null;
              tableNo = null;
              noOfGuests = null;
              resetForNewOrder();
            }
          });
    }
  }
  StreamSubscription<User?>? _identitySubscription;
  String? _observedUid;
  String? pendingOrderId;
  final FirebaseFirestore store;
  final CustomerOrderTracking? _tracking;
  final FirebaseAuth? _auth;
  final bool _secureCustomerFlow;
  late final _identity = CustomerIdentityService(
    _auth ?? FirebaseEnvironment.auth,
  );
  String? trackingWarning;

  Future<void> _rememberSavedOrder(String id) async {
    if (_secureCustomerFlow) {
      // Ownership query restores tracking; no local ID persistence is needed.
      trackingWarning = null;
      return;
    }
    try {
      final tracking = _tracking ?? CustomerOrderTracking.forCurrentDevice();
      // Check deployed read permissions; a local ID never grants access.
      final snapshot = await store
          .collection('orders')
          .doc(id)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (!snapshot.exists) throw StateError('Saved order is not readable.');
      await tracking.rememberReadableOrder(id);
      trackingWarning = null;
    } catch (_) {
      // The server write already succeeded. Never report it as a failed order
      // or resubmit it because device tracking could not be stored.
      trackingWarning =
          'Your order was saved, but tracking could not be saved '
          'on this device. Reopening Orders may not show it.';
    }
  }

  OrderModel? order;
  int? tableNo;
  int? noOfGuests;
  String? name;
  void setCustomerDeyails({
    required int tableno,
    required int noofguests,
    String? custName,
  }) {
    pendingOrderId = null;
    order = null;
    trackingWarning = null;
    tableNo = tableno;
    noOfGuests = noofguests;
    name = custName;
    emit(
      CustomerDeatailsSuccessState(
        tableNo: tableNo!,
        guests: noOfGuests!,
        name: name,
      ),
    );
  }

  @override
  void emit(CustomerOrderState state) {
    if (isClosed) return;
    super.emit(state);
  }

  void resetForNewOrder() {
    pendingOrderId = null;
    order = null;
    trackingWarning = null;
    emit(CustomerOrderIntialState());
  }

  @override
  Future<void> close() async {
    await _identitySubscription?.cancel();
    return super.close();
  }

  void updateGuests(int count) {
    noOfGuests = count;
    emit(CustomerGuestsUpdatedState(guests: count));
  }

  Future<void> updatePayment(PaymentMethod paymentMethod) async {
    emit(UpdatePaymentLoadingState());

    final payment = PaymentModel(
      paymentMethod: paymentMethod,
      paymentDate: DateTime.now(),
    );

    try {
      final savedOrder = order;
      if (savedOrder == null || savedOrder.docId.isEmpty) {
        throw StateError('Place an order successfully before paying.');
      }
      if (_secureCustomerFlow &&
          (_auth ?? FirebaseEnvironment.auth).currentUser?.uid !=
              savedOrder.customerId) {
        throw StateError('Customer identity changed. Reopen your orders.');
      }
      await store.collection('orders').doc(savedOrder.docId).update({
        'payment_data': _secureCustomerFlow
            ? {
                'payment_method': paymentMethod.name,
                'payment_date': FieldValue.serverTimestamp(),
              }
            : payment.toMap(),
      });
      if (_secureCustomerFlow &&
          ((_auth ?? FirebaseEnvironment.auth).currentUser?.uid !=
                  savedOrder.customerId ||
              !identical(order, savedOrder))) {
        return;
      }
      savedOrder.paymentData = payment;

      await _rememberSavedOrder(savedOrder.docId);
      pendingOrderId = null;
      emit(UpdatePaymentSuccessState(payment: payment));
    } on FirebaseException catch (e) {
      emit(UpdatePaymentFailState(msg: e.message ?? 'Payment failed'));
    } catch (e) {
      emit(UpdatePaymentFailState(msg: e.toString()));
    }
  }

  Future<void> placeOrder(
    List<OrderItemModel> items,
    double sub,
    double tot,
    double tax,
  ) async {
    if (isClosed || state is PlaceOrderLoadingState) return;

    emit(PlaceOrderLoadingState());

    var step = 'prepare order';
    try {
      if (_secureCustomerFlow && (items.isEmpty || items.length > 5)) {
        pendingOrderId = null;
        emit(
          PlaceOrderFailState(
            msg: 'Choose between 1 and 5 different meals per order.',
          ),
        );
        return;
      }
      step = 'authenticate customer';
      final customer = _secureCustomerFlow
          ? await _identity.ensureSignedIn()
          : null;
      step = 'create order';
      order = OrderModel(
        customerId: customer?.uid,
        tableNo: tableNo ?? 1,
        noOfGuests: noOfGuests ?? 1,
        meals: List<OrderItemModel>.from(items),
        paymentData: null,
        createdAt: DateTime.now(),
        serviceCharge: tax,
        subtotal: sub,
        total: tot,
        clientName: name,
      );

      final orderRef = store.collection('orders').doc();
      pendingOrderId = orderRef.id;

      order!.docId = orderRef.id;
      order!.dispId = 'GF-${orderRef.id.substring(0, 6).toUpperCase()}';

      if (_secureCustomerFlow &&
          (_auth ?? FirebaseEnvironment.auth).currentUser?.uid !=
              customer!.uid) {
        throw StateError('Customer identity changed. Please try again.');
      }
      final createdOrder = order!;
      await orderRef.set({
        ...createdOrder.toMap(),
        if (_secureCustomerFlow) 'created_at': FieldValue.serverTimestamp(),
      });
      if (_secureCustomerFlow &&
          ((_auth ?? FirebaseEnvironment.auth).currentUser?.uid !=
                  customer!.uid ||
              !identical(order, createdOrder))) {
        return;
      }
      await _rememberSavedOrder(orderRef.id);

      emit(PlaceOrderSuccessState(orderId: createdOrder.dispId));
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('Order placement failed ($step): [${e.plugin}/${e.code}]');
      }
      pendingOrderId = null;
      order = null;

      final message = switch (e.code) {
        'operation-not-allowed' || 'admin-restricted-operation' =>
          'Guest sign-in is unavailable. Please contact support.',
        'unavailable' ||
        'network-request-failed' => 'Please check your internet connection.',
        'permission-denied' => 'You are not allowed to place this order.',
        'deadline-exceeded' => 'The request took too long. Please try again.',
        'resource-exhausted' ||
        'too-many-requests' => 'Too many requests. Please try again later.',
        _ when e is FirebaseAuthException =>
          'Could not sign in to place your order. Please try again.',
        _ => 'Something went wrong. Please try again.',
      };
      emit(PlaceOrderFailState(msg: message));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Order placement failed ($step): ${e.runtimeType}');
      }
      pendingOrderId = null;
      order = null;
      emit(PlaceOrderFailState(msg: 'Something went wrong. Please try again.'));
    }
  }
}
