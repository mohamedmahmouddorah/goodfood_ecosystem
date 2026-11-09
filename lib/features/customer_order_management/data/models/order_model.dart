
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/payment_model.dart';

enum OrderStatus {
  pending,
  preparing,
  ready,
  delivered,
  canceled
}

class OrderModel {
  String docId ;
  String dispId;
  final int tableNo;
  final int noOfGuests;
  final String? clientName;
  final List<OrderItemModel> meals;
  OrderStatus status ;
  final double subtotal;
  final double serviceCharge;
  final double total;
  PaymentModel? paymentData;
  final DateTime createdAt;

  OrderModel({
    this.docId = "",
    this.dispId = "",
    required this.tableNo,
    required this.noOfGuests,
    this.clientName,
    required this.meals,
    this.status = OrderStatus.pending,
    required this.subtotal,
    required this.serviceCharge,
    required this.total,
    this.paymentData,
    required this.createdAt,
  }) ;


  Map<String, dynamic> toMap() {
    return {
      'disp_id' : dispId,
      'table_no': tableNo,
      'no_of_guests': noOfGuests,
      'client_name': clientName,
      'meals': meals.map((meal) => meal.toMap()).toList(),
      'status': status.name,
      'subtotal': subtotal,
      'service_charge': serviceCharge,
      'total': total,
      'payment_data':paymentData!=null ? paymentData!.toMap() : null,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  factory OrderModel.fromMap(
    Map<String, dynamic> data,
    List<OrderItemModel> meals,
  ) {
    return OrderModel(
      dispId: data["disp_id"],
      tableNo: data['table_no'],
      noOfGuests: data['no_of_guests'],
      clientName: data['client_name'],
      meals: meals,
      status: OrderStatus.values.byName(data['status']),
      subtotal: (data['subtotal'] as num).toDouble(),
      serviceCharge: (data['service_charge'] as num).toDouble(),
      total: (data['total'] as num).toDouble(),
      paymentData: data['payment_data'] != null
          ? PaymentModel.fromMap(data['payment_data'])
          : null,
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }
}