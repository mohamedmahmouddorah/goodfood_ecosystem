import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/cart_local_storage.dart';
import '../../../menu/data/models/meal_model.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit({CartLocalStorage? storage})
    : _storage = storage,
      super(CartState(isLoading: storage != null)) {
    if (storage != null) _loadFuture = _load();
  }

  final CartLocalStorage? _storage;
  Future<void> _loadFuture = Future<void>.value();
  Future<void>? _writeTask;
  List<CartItem>? _pendingItems;
  List<MealModel>? _latestAvailableMeals;
  bool _hasLocalChanges = false;

  Future<void> get initialized => _loadFuture;

  Future<void> get persistenceComplete => _writeTask ?? Future<void>.value();

  Future<void> _load() async {
    try {
      final items = await _storage!.readItems();
      if (!isClosed) {
        final baseItems = _hasLocalChanges ? state.items : items;
        final availableMeals = _latestAvailableMeals;
        final updatedItems = availableMeals == null
            ? baseItems
            : _syncItems(baseItems, availableMeals);
        final changed = !_sameItems(baseItems, updatedItems);
        emit(
          _hasLocalChanges
              ? state.copyWith(items: updatedItems, isLoading: false)
              : CartState(items: updatedItems),
        );
        if (changed) {
          _hasLocalChanges = true;
          _pendingItems = List<CartItem>.unmodifiable(updatedItems);
          _scheduleWrite(_storage);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Could not load cart from SQLite: $error\n$stackTrace');
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            storageError: 'Could not load your saved cart from this device.',
          ),
        );
      }
    }
  }

  void _update(CartState next) {
    _hasLocalChanges = true;
    emit(next);

    final storage = _storage;
    if (storage == null) return;
    _pendingItems = List<CartItem>.unmodifiable(next.items);
    _scheduleWrite(storage);
  }

  void _scheduleWrite(CartLocalStorage storage) {
    if (_writeTask != null) return;
    _writeTask = _drainWrites(storage);
  }

  Future<void> _drainWrites(CartLocalStorage storage) async {
    try {
      await _loadFuture;
      while (_pendingItems != null && !isClosed) {
        final items = _pendingItems!;
        _pendingItems = null;
        try {
          await storage.replaceItems(items);
          if (!isClosed && state.storageError != null) {
            emit(state.copyWith(clearStorageError: true));
          }
        } catch (error, stackTrace) {
          debugPrint('Could not save cart to SQLite: $error\n$stackTrace');
          if (!isClosed) {
            emit(
              state.copyWith(
                storageError: 'Could not save your cart on this device.',
              ),
            );
          }
        }
      }
    } finally {
      _writeTask = null;
      if (_pendingItems != null && !isClosed) {
        _scheduleWrite(storage);
      }
    }
  }

  void add(MealModel meal) {
    if (meal.isAvailable) _update(state.add(meal));
  }

  void increase(String mealId) => _update(state.changeQuantity(mealId, 1));

  void decrease(String mealId) => _update(state.changeQuantity(mealId, -1));

  void syncAvailableMeals(Iterable<MealModel> availableMeals) {
    _latestAvailableMeals = List<MealModel>.unmodifiable(availableMeals);
    if (state.isLoading) return;
    final items = _syncItems(state.items, _latestAvailableMeals!);
    if (!_sameItems(state.items, items)) _update(state.copyWith(items: items));
  }

  List<CartItem> _syncItems(
    List<CartItem> items,
    List<MealModel> availableMeals,
  ) {
    final mealsById = {for (final meal in availableMeals) meal.id: meal};
    return items
        .map((item) {
          final updatedMeal =
              mealsById[item.meal.id] ?? item.meal.copyWith(isAvailable: false);
          return item.meal == updatedMeal
              ? item
              : CartItem(meal: updatedMeal, quantity: item.quantity);
        })
        .toList(growable: false);
  }

  bool _sameItems(List<CartItem> first, List<CartItem> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].quantity != second[index].quantity ||
          first[index].meal != second[index].meal) {
        return false;
      }
    }
    return true;
  }

  CartRemoval? remove(String mealId) {
    final index = state.items.indexWhere((item) => item.meal.id == mealId);
    if (index == -1) return null;

    final removal = CartRemoval(item: state.items[index], index: index);
    _update(state.remove(mealId));
    return removal;
  }

  void restore(CartItem item) => _update(state.restore(item));

  void restoreRemoval(CartRemoval removal) =>
      _update(state.insert(removal.item, removal.index));

  void restoreAll(List<CartItem> items) {
    final restored = items.fold(state, (cart, item) => cart.restore(item));
    _update(restored);
  }

  List<CartItem> clear() {
    final previousItems = List<CartItem>.unmodifiable(state.items);
    if (previousItems.isNotEmpty) _update(const CartState());
    return previousItems;
  }

  @override
  Future<void> close() async {
    await _loadFuture;
    await persistenceComplete;
    await super.close();
  }
}
