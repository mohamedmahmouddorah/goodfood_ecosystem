import 'dart:async';

import 'package:flutter/foundation.dart' show ValueGetter, debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/services/menu_remote_service.dart' show RemoteMealsSnapshot;
import 'meal_search_index.dart';
import 'menu_state.dart';

class MenuCubit extends Cubit<MenuState> {
  MenuCubit(this.repo) : super(const MenuState()) {
    _localChangeSubscription = repo.localChanges.listen(
      (_) => _refreshFromLocalCache(),
    );
  }

  final MenuRepository repo;
  Timer? _debounce;
  StreamSubscription<RemoteMealsSnapshot>? _subscription;
  late final StreamSubscription<void> _localChangeSubscription;
  List<MealModel> _allMeals = const [];
  MealSearchIndex _index = MealSearchIndex.empty;
  bool _hasSnapshot = false;
  int _generation = 0;

  List<MealModel> get availableMeals => _allMeals;

  Future<void> _refreshFromLocalCache() async {
    final meals = await repo.readAvailableMealsFromCache();
    if (meals == null || isClosed) return;
    _updateState(meals, isFromCache: true);
  }

  Future<void> load({bool preserveCurrent = false}) async {
    if (isClosed) return;
    final generation = ++_generation;
    final previous = _subscription;
    _subscription = null;
    emit(
      state.copyWith(
        status: _allMeals.isEmpty ? MenuStatus.loading : MenuStatus.success,
        isRefreshing: true,
      ),
    );
    try {
      // Generation guards reject late events. Do not block reconnection on an
      // old transport waiting for its next event to finish cancellation.
      if (previous != null) unawaited(previous.cancel());
      if (isClosed || generation != _generation) return;
      final cachedMeals = await repo.readAvailableMealsFromCache();
      if (isClosed || generation != _generation) return;
      if (cachedMeals != null && cachedMeals.isNotEmpty) {
        _updateState(cachedMeals, isFromCache: true);
      }
      _subscription = repo.watchAvailableMeals().listen(
        (snapshot) {
          if (isClosed || generation != _generation) return;
          _updateState(snapshot.meals, isFromCache: snapshot.isFromCache);
        },
        onError: (Object error, StackTrace stack) {
          if (isClosed || generation != _generation) return;
          _showFailure(error, stack);
        },
      );
    } catch (error, stack) {
      if (!isClosed && generation == _generation) _showFailure(error, stack);
    }
  }

  void _showFailure(Object error, StackTrace stack) {
    debugPrint('Customer menu load failed [${error.runtimeType}]\n$stack');
    final message = error is MenuFailure
        ? error.message
        : 'Could not load meals from Firebase. Please try again.';
    emit(
      state.copyWith(
        status: _allMeals.isEmpty ? MenuStatus.failure : MenuStatus.success,
        error: message,
        isRefreshing: false,
        isFromCache: _allMeals.isNotEmpty,
      ),
    );
  }

  void _updateState(List<MealModel> meals, {required bool isFromCache}) {
    final mealsChanged = !_hasSnapshot || !_sameMeals(_allMeals, meals);
    _hasSnapshot = true;
    _allMeals = meals;
    _index = MealSearchIndex(meals);
    _emitVisible(
      isFromCache: isFromCache,
      newSnapshot: mealsChanged,
      clearError: true,
    );
  }

  void selectCategory(MealCategory? category) {
    if (category == state.category) return;
    _emitVisible(category: () => category);
  }

  void search(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () {
      final query = text.trim().toLowerCase();
      if (query != state.query) _emitVisible(query: query);
    });
  }

  bool _sameMeals(List<MealModel> first, List<MealModel> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void _emitVisible({
    String? query,
    ValueGetter<MealCategory?>? category,
    bool? isFromCache,
    bool newSnapshot = false,
    bool clearError = false,
  }) {
    if (isClosed) return;
    final q = query ?? state.query;
    final c = category == null ? state.category : category();
    emit(
      state.copyWith(
        status: clearError ? MenuStatus.success : state.status,
        query: q,
        category: () => c,
        meals: _index.search(q, category: c),
        isFromCache: isFromCache ?? state.isFromCache,
        revision: newSnapshot ? state.revision + 1 : state.revision,
        isRefreshing: false,
        error: clearError ? null : state.error,
      ),
    );
  }

  @override
  Future<void> close() async {
    ++_generation;
    _debounce?.cancel();
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    await _localChangeSubscription.cancel();
    return super.close();
  }
}
