import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';

abstract class CartState {
  final List<OrderItemModel> cartItems;

  const CartState({this.cartItems = const []});
}

class CartIntialState extends CartState {
  const CartIntialState() : super();
}

class AddToCartLoadingState extends CartState {
  const AddToCartLoadingState({
    required super.cartItems,
  });
}

class AddToCartSuccessState extends CartState {
  final OrderItemModel item;

  const AddToCartSuccessState({
    required super.cartItems,
    required this.item,
  });

  int get numOfItems => cartItems.fold(
        0,
        (sum, item) => sum + item.quantity,
      );
}

class AddToCartFailState extends CartState {
  final String msg;

  const AddToCartFailState({
    required this.msg,
    required super.cartItems,
  });
}

class RemoveFromCartLoadingState extends CartState {
  const RemoveFromCartLoadingState({
    required super.cartItems,
  });
}

class RemoveFromCartSccessState extends CartState {
  final OrderItemModel removedItem;

  const RemoveFromCartSccessState({
    required super.cartItems,
    required this.removedItem,
  });
}

class RemoveFromCartFailState extends CartState {
  final String msg;

  const RemoveFromCartFailState({
    required this.msg,
    required super.cartItems,
  });
}

class CartLoadDataLoadingState extends CartState {
  const CartLoadDataLoadingState();
}

class CartLoadDataSuccessState extends CartState {
  const CartLoadDataSuccessState({
    required super.cartItems,
  });
}

class CartLoadDataFailState extends CartState {
  final String msg;

  const CartLoadDataFailState({
    required this.msg,
    required super.cartItems,
  });
}

class CartUpdateQuantitySuccessState extends CartState {
  final int newQuan;

  const CartUpdateQuantitySuccessState({
    required this.newQuan,
    required super.cartItems,
  });
}