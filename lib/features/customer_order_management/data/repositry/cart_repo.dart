import 'dart:async';

import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:hive/hive.dart';

class CartRepo {
  final Box<OrderItemModel> cartBox;
  CartRepo({required this.cartBox});
  OrderItemModel? searchItem(String itemId) {
    return cartBox.get(itemId);
  }

  Future<OrderItemModel> addtoCart(OrderItemModel item) async {
    final OrderItemModel? findItem = searchItem(item.mealId);
    if (findItem != null) {
      findItem.quantity++;
      await cartBox.put(findItem.mealId, findItem);
      return findItem;
    }
    await cartBox.put(item.mealId, item);
    return item;
  }

  Future<void> deleteFromCart(String mealId) async {
    await cartBox.delete(mealId);
  }

  Future<void> clearCart() async {
    await cartBox.clear();
  }

  List<OrderItemModel> getAllItems (){
    return cartBox.values.toList();
  }
  Future<void> updateItem(OrderItemModel item, int newQ) async {
    final findItem = searchItem(item.mealId);
    if (findItem == null) {
      return;
    } else {
      findItem.quantity = newQ;
      await cartBox.put(item.mealId, findItem);
    }
  }
}
