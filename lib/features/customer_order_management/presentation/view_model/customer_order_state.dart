import 'package:goodfood_ecosystem/features/customer_order_management/data/models/payment_model.dart';

class CustomerOrderState {}
class CustomerOrderIntialState extends CustomerOrderState{}
class CustomerDeatailsSuccessState extends CustomerOrderState{
  int tableNo;
  int guests;
  String? name;
  CustomerDeatailsSuccessState({
    required this.tableNo,
    required this.guests,
    this.name
  });
}
class PlaceOrderLoadingState extends CustomerOrderState {}
class PlaceOrderSuccessState extends CustomerOrderState {
  String orderId ;
  PlaceOrderSuccessState({required this.orderId});
}
class PlaceOrderFailState extends CustomerOrderState {
  String msg;
  PlaceOrderFailState({required this.msg});
}

class UpdatePaymentLoadingState extends CustomerOrderState {}

class UpdatePaymentSuccessState extends CustomerOrderState {
  final PaymentModel payment;
  UpdatePaymentSuccessState({required this.payment});
}

class UpdatePaymentFailState extends CustomerOrderState {
  final String msg;
  UpdatePaymentFailState({required this.msg});
}

class CustomerGuestsUpdatedState extends CustomerOrderState {
  final int guests;
  CustomerGuestsUpdatedState({required this.guests});
}
