import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/services/menu_remote_service.dart' show MealDoc;
import 'menu_state.dart';

class MenuCubit extends Cubit<MenuState> {
  MenuCubit(this._repo) : super(const MenuState());

  final MenuRepository _repo;
  Timer? _debounce;
  MealDoc? _cursor; // Firestore page cursor: kept here, not in the state
  int _requestId = 0; // lets us ignore responses that arrive late

  Future<void> load() => _fetch(reset: true);

  void selectCategory(MealCategory? category) {
    if (category == state.category) return;
    emit(state.copyWith(category: () => category));
    _fetch(reset: true);
  }

  /// Debounced: one Firestore query after the user stops typing.
  void search(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = text.trim();
      if (q == state.query) return;
      emit(state.copyWith(query: q));
      _fetch(reset: true);
    });
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.status != MenuStatus.success) return;
    await _fetch(reset: false);
  }

  Future<void> _fetch({required bool reset}) async {
    final id = ++_requestId;
    if (reset) {
      _cursor = null;
      emit(state.copyWith(
        status: MenuStatus.loading,
        meals: const [],
        hasMore: false,
        loadingMore: false,
      ));
    } else {
      emit(state.copyWith(loadingMore: true));
    }

    try {
      final page = await _repo.getMeals(
        category: state.category,
        query: state.query,
        after: _cursor,
      );
      if (id != _requestId || isClosed) return;
      _cursor = page.cursor;
      emit(state.copyWith(
        status: MenuStatus.success,
        meals: reset ? page.meals : [...state.meals, ...page.meals],
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } on MenuFailure catch (e) {
      if (id != _requestId || isClosed) return;
      emit(state.copyWith(status: MenuStatus.failure, loadingMore: false, error: e.message));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}