import 'package:flutter/material.dart';

/// Supply only a document ID obtained from a successfully confirmed order.
/// The production route merges this ID with this device's saved order IDs.
Future<T?> openCustomerOrders<T>(
  BuildContext context, {
  String? confirmedOrderId,
}) {
  return Navigator.of(context).pushNamed<T>(
    '/orders',
    arguments: <String>[
      if (confirmedOrderId != null && confirmedOrderId.isNotEmpty)
        confirmedOrderId,
    ],
  );
}
