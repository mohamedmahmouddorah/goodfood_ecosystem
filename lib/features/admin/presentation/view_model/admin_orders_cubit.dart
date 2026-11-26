import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../customer_order_management/data/models/order_model.dart';

typedef AdminOrderStream = Stream<List<OrderModel>> Function();

class AdminOrdersState {
  const AdminOrdersState({this.orders, this.failed = false});

  final List<OrderModel>? orders;
  final bool failed;

  int count(OrderStatus status) =>
      orders!.where((order) => order.status == status).length;

  Iterable<OrderModel> get kitchen => orders!.where(
    (order) =>
        (order.status == OrderStatus.pending && order.isUnassigned) ||
        order.status == OrderStatus.preparing ||
        order.status == OrderStatus.ready,
  );

  Iterable<OrderModel> matching(
    String search,
    OrderStatus? status, {
    bool kitchenOnly = false,
  }) {
    final query = search.trim().toLowerCase().replaceFirst(RegExp(r'^#'), '');
    return (kitchenOnly ? kitchen : orders!).where(
      (order) =>
          (status == null || order.status == status) &&
          order.dispId.toLowerCase().contains(query),
    );
  }
}

class AdminOrdersCubit extends Cubit<AdminOrdersState> {
  AdminOrdersCubit(this.watchOrders) : super(const AdminOrdersState());

  final AdminOrderStream watchOrders;
  StreamSubscription<List<OrderModel>>? _subscription;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    final previous = _subscription;
    _subscription = null;
    emit(const AdminOrdersState());
    await previous?.cancel();
    if (isClosed || generation != _generation) return;
    try {
      _subscription = watchOrders().listen(
        (orders) {
          if (isClosed || generation != _generation) return;
          final sorted = [...orders]
            ..sort((a, b) {
              final date = b.createdAt.compareTo(a.createdAt);
              return date == 0 ? a.docId.compareTo(b.docId) : date;
            });
          emit(AdminOrdersState(orders: List.unmodifiable(sorted)));
        },
        onError: (Object error) {
          if (!isClosed && generation == _generation) {
            emit(const AdminOrdersState(failed: true));
          }
        },
      );
    } catch (_) {
      if (!isClosed && generation == _generation) {
        emit(const AdminOrdersState(failed: true));
      }
    }
  }

  @override
  Future<void> close() async {
    ++_generation;
    await _subscription?.cancel();
    await super.close();
  }
}
