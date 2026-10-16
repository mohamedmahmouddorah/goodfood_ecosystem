import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import 'menu_management_state.dart';

enum MealSaveResult { saved, failed, pending }

class MenuManagementCubit extends Cubit<MenuManagementState> {
  MenuManagementCubit(
    this._repo, {
    this.saveTimeout = const Duration(seconds: 3),
  }) : super(MenuManagementState());

  static const _pendingMessage =
      'Saved on this device. Firebase will sync it automatically when the connection returns.';

  final MenuRepository _repo;
  MenuRepository get repository => _repo;
  final Duration saveTimeout;
  StreamSubscription<List<MealModel>>? _sub;
  bool _hasMealSnapshot = false;

  /// id -> "name\ndescription\ncategory" in lowercase (built once per snapshot).
  Map<String, String> _keys = const {};

  /// One live listener for the whole screen.
  void watch() {
    _sub?.cancel();
    if (!_hasMealSnapshot) {
      emit(
        state.copyWith(status: ManagementStatus.loading, loadError: () => null),
      );
    }
    _sub = _repo.watchAllMeals().listen(
      (meals) {
        _hasMealSnapshot = true;
        final sorted = [...meals]..sort(_byName);
        _keys = {
          for (final m in sorted)
            m.id: '${m.name}\n${m.description}\n${m.category.label}'
                .toLowerCase(),
        };
        _apply(
          state.copyWith(
            status: ManagementStatus.success,
            meals: sorted,
            loadError: () => null,
          ),
        );
      },
      onError: (Object error, StackTrace _) {
        final message = error is MenuFailure
            ? error.message
            : 'Could not load meals from Firebase.';
        if (_hasMealSnapshot) {
          _notify(message);
          return;
        }
        emit(
          state.copyWith(
            status: ManagementStatus.failure,
            loadError: () => message,
          ),
        );
      },
    );
  }

  static int _byName(MealModel a, MealModel b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  void selectCategory(MealCategory? category) =>
      _apply(state.copyWith(category: () => category));

  void search(String query) {
    if (query != state.searchQuery) _apply(state.copyWith(searchQuery: query));
  }

  void selectVisibilityFilter(MealVisibilityFilter filter) =>
      _apply(state.copyWith(visibilityFilter: filter));

  void _apply(MenuManagementState next) =>
      emit(next.copyWith(visible: _filter(next)));

  List<MealModel> _filter(MenuManagementState s) {
    final query = s.searchQuery.trim().toLowerCase();
    final category = s.category;
    return [
      for (final meal in s.meals)
        if ((category == null || meal.category == category) &&
            s.visibilityFilter.matches(meal) &&
            (query.isEmpty || (_keys[meal.id] ?? '').contains(query)))
          meal,
    ];
  }

  MealModel? _find(String id) {
    for (final meal in state.meals) {
      if (meal.id == id) return meal;
    }
    return null;
  }

  /// The repository updates SQLite first; Firestore then queues the write.
  Future<void> toggle(String id, bool value) async {
    final meal = _find(id);
    await _runWrite<void>(() => _repo.setAvailability(id, value, meal: meal));
  }

  Future<void> delete(String id) async {
    final meal = _find(id);
    await _runWrite<void>(() => _repo.deleteMeal(id, meal: meal));
  }

  /// Add (empty id) or update.
  Future<MealSaveResult> save(MealModel meal) => _runWrite<void>(
    () => meal.id.isEmpty ? _repo.addMeal(meal) : _repo.updateMeal(meal),
  );

  Future<MealSaveResult> _runWrite<T>(Future<T> Function() operation) async {
    final write = operation();
    try {
      await write.timeout(saveTimeout);
      return MealSaveResult.saved;
    } on TimeoutException {
      _observePending(write);
      _notify(_pendingMessage);
      return MealSaveResult.pending;
    } on MenuFailure catch (e) {
      _notify(e.message);
      return MealSaveResult.failed;
    }
  }

  void _observePending<T>(Future<T> write) {
    unawaited(
      write.then<void>(
        (_) {},
        onError: (Object error, StackTrace _) {
          _notify(
            error is MenuFailure
                ? error.message
                : 'Firebase did not accept this change. Check the Firestore write rules.',
          );
        },
      ),
    );
  }

  void _notify(String text) {
    if (isClosed) return;
    emit(state.copyWith(message: () => text));
    emit(state.copyWith(message: () => null)); // clear so the next one can show
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}