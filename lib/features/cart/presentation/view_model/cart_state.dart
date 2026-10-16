import '../../../menu/data/models/meal_model.dart';

class CartItem {
  const CartItem({required this.meal, required this.quantity});

  final MealModel meal;
  final int quantity;

  double get total => meal.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(meal: meal, quantity: quantity ?? this.quantity);
}

class CartRemoval {
  const CartRemoval({required this.item, required this.index});

  final CartItem item;
  final int index;
}

class CartState {
  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.storageError,
  });

  final List<CartItem> items;
  final bool isLoading;
  final String? storageError;

  int get itemCount => items.fold(0, (total, item) => total + item.quantity);

  int get unavailableItemCount => items
      .where((item) => !item.meal.isAvailable)
      .fold(0, (total, item) => total + item.quantity);

  double get total => items
      .where((item) => item.meal.isAvailable)
      .fold(0, (total, item) => total + item.total);

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? storageError,
    bool clearStorageError = false,
  }) => CartState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    storageError: clearStorageError ? null : storageError ?? this.storageError,
  );

  CartState add(MealModel meal) {
    final index = items.indexWhere((item) => item.meal.id == meal.id);
    if (index == -1) {
      return CartState(
        items: [
          ...items,
          CartItem(meal: meal, quantity: 1),
        ],
      );
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
    if (difference > 0 && !items[index].meal.isAvailable) return this;

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

  CartState insert(CartItem item, int index) {
    final existingIndex = items.indexWhere(
      (existing) => existing.meal.id == item.meal.id,
    );
    if (existingIndex != -1) {
      final updated = [...items];
      updated[existingIndex] = updated[existingIndex].copyWith(
        quantity: updated[existingIndex].quantity + item.quantity,
      );
      return CartState(items: updated);
    }

    final updated = [...items];
    updated.insert(index.clamp(0, updated.length), item);
    return CartState(items: updated);
  }

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
