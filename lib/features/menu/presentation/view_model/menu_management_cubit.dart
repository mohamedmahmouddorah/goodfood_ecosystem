import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import 'menu_management_state.dart';

enum MealSaveResult { saved, failed, pending }

class MenuManagementCubit extends Cubit<MenuManagementState> {
  MenuManagementCubit(
    this._repo, {
    this.saveTimeout = const Duration(seconds: 10),
  }) : super(const MenuManagementState());

  final MenuRepository _repo;
  final Duration saveTimeout;
  StreamSubscription<List<MealModel>>? _sub;
  bool _hasMealSnapshot = false;

  /// One live listener for the whole screen.
  void watch() {
    _sub?.cancel();
    if (!_hasMealSnapshot) {
      emit(
        state.copyWith(
          status: ManagementStatus.loading,
          loadError: () => null,
        ),
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

  /// No optimistic code needed: Firestore applies the write locally at once
  /// and the stream re-emits, so the switch moves instantly.
  Future<void> toggle(String id, bool value) async {
    try {
      await _repo.setAvailability(id, value);
    } on MenuFailure catch (e) {
      _notify(e.message);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.deleteMeal(id);
    } on MenuFailure catch (e) {
      _notify(e.message);
    }
  }

  /// Add (empty id) or update. Returns true when the screen can close.
  Future<MealSaveResult> save(MealModel meal) async {
    try {
      final write = meal.id.isEmpty ? _repo.addMeal(meal) : _repo.updateMeal(meal);
      await write.timeout(saveTimeout);
      return MealSaveResult.saved;
    } on TimeoutException {
      _notify(
        'Firebase has not confirmed the save yet. Check the meal list before trying again.',
      );
      return MealSaveResult.pending;
    } on MenuFailure catch (e) {
      _notify(e.message);
      return MealSaveResult.failed;
    }
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