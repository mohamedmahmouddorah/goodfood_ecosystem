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
  }) : super(const MenuManagementState());

  final MenuRepository _repo;
  MenuRepository get repository => _repo;
  final Duration saveTimeout;
  StreamSubscription<List<MealModel>>? _sub;
  bool _hasMealSnapshot = false;

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
        emit(
          state.copyWith(
            status: ManagementStatus.success,
            meals: meals,
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

  void selectCategory(MealCategory? category) =>
      emit(state.copyWith(category: () => category));

  void search(String query) => emit(state.copyWith(searchQuery: query));

  void selectVisibilityFilter(MealVisibilityFilter filter) =>
      emit(state.copyWith(visibilityFilter: filter));

  /// The repository updates SQLite first; Firestore then queues and emits the
  /// local write while waiting for server acknowledgement.
  Future<void> toggle(String id, bool value) async {
    MealModel? meal;
    for (final current in state.meals) {
      if (current.id == id) {
        meal = current;
        break;
      }
    }
    final write = _repo.setAvailability(id, value, meal: meal);
    try {
      await write.timeout(saveTimeout);
    } on TimeoutException {
      _observePending(write);
      _notify(
        'Saved on this device. Firebase will sync it automatically when the connection returns.',
      );
    } on MenuFailure catch (e) {
      _notify(e.message);
    }
  }

  Future<void> delete(String id) async {
    MealModel? meal;
    for (final current in state.meals) {
      if (current.id == id) {
        meal = current;
        break;
      }
    }
    final write = _repo.deleteMeal(id, meal: meal);
    try {
      await write.timeout(saveTimeout);
    } on TimeoutException {
      _observePending(write);
      _notify(
        'Saved on this device. Firebase will sync it automatically when the connection returns.',
      );
    } on MenuFailure catch (e) {
      _notify(e.message);
    }
  }

  /// Add (empty id) or update. Returns true when the screen can close.
  Future<MealSaveResult> save(MealModel meal) async {
    final write = meal.id.isEmpty
        ? _repo.addMeal(meal)
        : _repo.updateMeal(meal);
    try {
      await write.timeout(saveTimeout);
      return MealSaveResult.saved;
    } on TimeoutException {
      _observePending(write);
      _notify(
        'Saved on this device. Firebase will sync it automatically when the connection returns.',
      );
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
