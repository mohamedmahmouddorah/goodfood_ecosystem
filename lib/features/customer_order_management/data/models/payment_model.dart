import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethod {
  cash,
  card,
  mobileWallet,
}


class PaymentModel {

  final PaymentMethod paymentMethod;
  DateTime? paymentDate;

  PaymentModel({
    required this.paymentMethod,
    this.paymentDate,
  }){
    paymentDate = paymentDate ?? DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      "payment_method": paymentMethod.name,
      "payment_date": paymentDate != null
          ? Timestamp.fromDate(paymentDate!)
          : null,
    };
  }

  factory PaymentModel.fromMap(
    Map<String, dynamic> data,
  ) {
    return PaymentModel(

      paymentMethod: PaymentMethod.values.byName(
        data["payment_method"],
      ),
      paymentDate: data["payment_date"] != null
          ? (data["payment_date"] as Timestamp).toDate()
          : null,
    );
  }
}