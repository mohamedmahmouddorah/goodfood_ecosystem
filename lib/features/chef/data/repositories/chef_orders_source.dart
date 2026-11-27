import '../../../customer_order_management/data/models/order_model.dart';
import '../services/chef_identity_service.dart';

class ChefOrderQueues {
  ChefOrderQueues({
    required this.chef,
    required List<OrderModel> incoming,
    required List<OrderModel> active,
    required List<OrderModel> ready,
    List<OrderModel> history = const [],
  }) : incoming = List.unmodifiable(incoming),
       active = List.unmodifiable(active),
       ready = List.unmodifiable(ready),
       history = List.unmodifiable(history);
  final ChefIdentity chef;
  final List<OrderModel> incoming;
  final List<OrderModel> active;
  final List<OrderModel> ready;
  final List<OrderModel> history;
}

class ChefOrderConflict implements Exception {
  const ChefOrderConflict();
}

abstract interface class ChefOrdersSource {
  Stream<ChefOrderQueues> watch();
  Future<void> accept(String orderId);
  Future<void> markReady(String orderId);
  String? assignmentName(OrderModel order);
}
