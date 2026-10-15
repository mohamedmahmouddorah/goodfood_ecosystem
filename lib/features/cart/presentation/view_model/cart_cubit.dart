import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../menu/data/models/meal_model.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  void add(MealModel meal) => emit(state.add(meal));

  void increase(String mealId) => emit(state.changeQuantity(mealId, 1));

  void decrease(String mealId) => emit(state.changeQuantity(mealId, -1));

  CartItem? remove(String mealId) {
    final index = state.items.indexWhere((item) => item.meal.id == mealId);
    if (index == -1) return null;

    final item = state.items[index];
    emit(state.remove(mealId));
    return item;
  }

  void restore(CartItem item) => emit(state.restore(item));

  void clear() => emit(const CartState());
}
