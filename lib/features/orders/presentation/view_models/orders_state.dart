import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_model.dart';

enum OrdersTab { active, history }

abstract class OrdersState {
  const OrdersState({this.tab = OrdersTab.active});
  final OrdersTab tab;
}

class OrdersInitialState extends OrdersState {}

class OrdersLoadingState extends OrdersState {
  const OrdersLoadingState({super.tab});
}

class OrdersLoadedState extends OrdersState {
  final List<OrderModel> orders;
  OrdersLoadedState({required List<OrderModel> orders, super.tab})
    : orders = List.unmodifiable(orders);

  List<OrderModel> get visibleOrders => orders.where((order) {
    final isHistory =
        order.status == OrderStatus.delivered ||
        order.status == OrderStatus.canceled;
    return tab == OrdersTab.history ? isHistory : !isHistory;
  }).toList();
}

class OrdersErrorState extends OrdersState {
  final String message;
  const OrdersErrorState({required this.message, super.tab});
}
