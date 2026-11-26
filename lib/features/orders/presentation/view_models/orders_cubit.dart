import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../customer_order_management/data/models/order_model.dart';
import 'orders_state.dart';

typedef OrdersLoader = Stream<List<OrderModel>> Function();

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({required OrdersLoader loadOrders})
    : _loadOrders = loadOrders,
      super(OrdersInitialState());

  final OrdersLoader _loadOrders;
  StreamSubscription<List<OrderModel>>? _subscription;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    final previous = _subscription;
    _subscription = null;
    emit(OrdersLoadingState(tab: state.tab));
    await previous?.cancel();
    if (isClosed || generation != _generation) return;
    try {
      _subscription = _loadOrders().listen(
        (orders) {
          if (isClosed || generation != _generation) return;
          final sorted = List<OrderModel>.of(orders)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          emit(OrdersLoadedState(orders: sorted, tab: state.tab));
        },
        onError: (Object error, StackTrace stack) {
          if (!isClosed && generation == _generation) _showError(error);
        },
      );
    } catch (error) {
      if (!isClosed && generation == _generation) _showError(error);
    }
  }

  void _showError(Object error) => emit(
    OrdersErrorState(
      message: error is FirebaseException && error.code == 'permission-denied'
          ? 'Order access was denied. Please contact the restaurant.'
          : 'We couldn’t load your orders. Please try again.',
      tab: state.tab,
    ),
  );

  void selectTab(OrdersTab tab) {
    final current = state;
    if (current is OrdersLoadedState) {
      emit(OrdersLoadedState(orders: current.orders, tab: tab));
    } else if (current is OrdersErrorState) {
      emit(OrdersErrorState(message: current.message, tab: tab));
    } else {
      emit(OrdersLoadingState(tab: tab));
    }
  }

  @override
  Future<void> close() async {
    ++_generation;
    await _subscription?.cancel();
    return super.close();
  }
}
