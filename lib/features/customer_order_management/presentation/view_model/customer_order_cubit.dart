import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/payment_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_state.dart';

class CustomerOrderCubit extends Cubit<CustomerOrderState> {
  CustomerOrderCubit() : super(CustomerOrderIntialState());
  String? pendingOrderId;
  final store = FirebaseFirestore.instance;
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
    emit(CustomerOrderIntialState());
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
      if (order != null) {
        order!.paymentData = payment;

        final id = order!.docId.isNotEmpty ? order!.docId : pendingOrderId;
        if (id != null && id.isNotEmpty) {
          await store.collection("orders").doc(id).update({
            'payment_data': payment.toMap(),
          });
        }
      } else {
        final docRef = store.collection("orders").doc();
        order = OrderModel(
          docId: docRef.id,
          dispId: 'GF-${docRef.id.substring(0, 6).toUpperCase()}',
          tableNo: tableNo ?? 1,
          noOfGuests: noOfGuests ?? 1,
          meals: [],
          createdAt: DateTime.now(),
          serviceCharge: 0,
          subtotal: 0,
          total: 0,
          clientName: name,
          paymentData: payment,
        );
        await docRef.set(order!.toMap());
      }

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

  pendingOrderId = store.collection("orders").doc().id;

  emit(PlaceOrderLoadingState());

  order = OrderModel(
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

  try {
    final orderRef = store.collection("orders").doc(pendingOrderId);

    order!.docId = orderRef.id;
    order!.dispId = 'GF-${orderRef.id.substring(0, 6).toUpperCase()}';

    await orderRef.set(order!.toMap());

    emit(PlaceOrderSuccessState(orderId: order!.dispId));
  } on FirebaseException catch (e) {
    pendingOrderId = null;

    String message;

    switch (e.code) {
      case 'unavailable':
        message = 'Please check your internet connection.';
        break;
      case 'permission-denied':
        message = 'You are not allowed to place this order.';
        break;
      case 'deadline-exceeded':
        message = 'The request took too long. Please try again.';
        break;
      case 'resource-exhausted':
        message = 'Too many requests. Please try again later.';
        break;
      default:
        message = 'Something went wrong. Please try again.';
    }

    emit(PlaceOrderFailState(msg: message));
  } catch (e) {
    pendingOrderId = null;
    emit(PlaceOrderFailState(msg: e.toString()));
  }
}
}
