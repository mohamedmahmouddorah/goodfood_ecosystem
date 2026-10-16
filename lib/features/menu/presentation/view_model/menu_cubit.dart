import 'dart:async';

import 'package:flutter/foundation.dart' show ValueGetter;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/services/menu_remote_service.dart' show RemoteMealsSnapshot;
import 'meal_search_index.dart';
import 'menu_state.dart';

class MenuCubit extends Cubit<MenuState> {
  MenuCubit(this._repo) : super(const MenuState());

  final MenuRepository _repo;
  Timer? _debounce;
  StreamSubscription<RemoteMealsSnapshot>? _subscription;
  List<MealModel> _allMeals = const [];
  MealSearchIndex _index = MealSearchIndex.empty;
  bool _hasSnapshot = false;

  List<MealModel> get availableMeals => _allMeals;

  Future<void> load() async {
    await _subscription?.cancel();
    _hasSnapshot = false;
    emit(
      state.copyWith(
        status: MenuStatus.loading,
        meals: const [],
        isFromCache: false,
      ),
    );
    _subscription = _repo.watchAvailableMeals().listen(
      (snapshot) {
        _hasSnapshot = true;
        _allMeals = snapshot.meals;
        _index = MealSearchIndex(snapshot.meals);
        _emitVisible(isFromCache: snapshot.isFromCache, newSnapshot: true);
      },
      onError: (Object error, StackTrace _) {
        if (_hasSnapshot) return;
        final message = error is MenuFailure
            ? error.message
            : 'Could not load meals from Firebase.';
        emit(state.copyWith(status: MenuStatus.failure, error: message));
      },
    );
  }

  void selectCategory(MealCategory? category) {
    if (category == state.category) return;
    _emitVisible(category: () => category);
  }

  /// Local in-memory search: O(log n) per keystroke, short debounce only
  /// to avoid rebuilding the grid for every single character.
  void search(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () {
      final query = text.trim().toLowerCase();
      if (query != state.query) _emitVisible(query: query);
    });
  }

  void _emitVisible({
    String? query,
    ValueGetter<MealCategory?>? category,
    bool? isFromCache,
    bool newSnapshot = false,
  }) {
    if (isClosed) return;
    final q = query ?? state.query;
    final c = category == null ? state.category : category();
    emit(
      state.copyWith(
        status: MenuStatus.success,
        query: q,
        category: () => c,
        meals: _index.search(q, category: c),
        isFromCache: isFromCache ?? state.isFromCache,
        revision: newSnapshot ? state.revision + 1 : state.revision,
      ),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _subscription?.cancel();
    return super.close();
  }
}