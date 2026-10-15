import '../../../menu/data/models/meal_model.dart';

class CartItem {
  const CartItem({required this.meal, required this.quantity});

  final MealModel meal;
  final int quantity;

  double get total => meal.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(meal: meal, quantity: quantity ?? this.quantity);
}

class CartState {
  const CartState({this.items = const []});

  final List<CartItem> items;

  int get itemCount =>
      items.fold(0, (total, item) => total + item.quantity);

  double get total =>
      items.fold(0, (total, item) => total + item.total);

  CartState add(MealModel meal) {
    final index = items.indexWhere((item) => item.meal.id == meal.id);
    if (index == -1) {
      return CartState(items: [...items, CartItem(meal: meal, quantity: 1)]);
    }

    final updated = [...items];
    updated[index] = updated[index].copyWith(
      quantity: updated[index].quantity + 1,
    );
    return CartState(items: updated);
  }

  CartState changeQuantity(String mealId, int difference) {
    final index = items.indexWhere((item) => item.meal.id == mealId);
    if (index == -1) return this;

    final updated = [...items];
    final quantity = updated[index].quantity + difference;
    if (quantity <= 0) {
      updated.removeAt(index);
    } else {
      updated[index] = updated[index].copyWith(quantity: quantity);
    }
    return CartState(items: updated);
  }

  CartState remove(String mealId) => CartState(
    items: items
        .where((item) => item.meal.id != mealId)
        .toList(growable: false),
  );

  CartState restore(CartItem item) {
    final index = items.indexWhere(
      (existing) => existing.meal.id == item.meal.id,
    );
    if (index == -1) {
      return CartState(items: [...items, item]);
    }

    final updated = [...items];
    updated[index] = updated[index].copyWith(
      quantity: updated[index].quantity + item.quantity,
    );
    return CartState(items: updated);
  }
}
