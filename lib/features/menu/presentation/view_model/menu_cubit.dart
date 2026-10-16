import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/services/menu_remote_service.dart' show RemoteMealsSnapshot;
import 'menu_state.dart';

class MenuCubit extends Cubit<MenuState> {
  MenuCubit(this._repo) : super(const MenuState());

  final MenuRepository _repo;
  List<MealModel> get availableMeals => _allMeals;
  Timer? _debounce;
  StreamSubscription<RemoteMealsSnapshot>? _subscription;
  List<MealModel> _allMeals = const [];
  bool _hasSnapshot = false;

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
        _emitVisible(snapshot.isFromCache);
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
    emit(state.copyWith(category: () => category));
    _emitVisible(state.isFromCache);
  }

  /// Debounced: one Firestore query after the user stops typing.
  void search(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = text.trim();
      if (q == state.query) {
        return;
      }
      emit(state.copyWith(query: q));
      _emitVisible(state.isFromCache);
    });
  }

  void _emitVisible(bool isFromCache) {
    if (isClosed) return;
    final query = state.query.toLowerCase();
    final meals =
        _allMeals
            .where(
              (meal) =>
                  (state.category == null || meal.category == state.category) &&
                  meal.name.toLowerCase().startsWith(query),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    emit(
      state.copyWith(
        status: MenuStatus.success,
        meals: meals,
        isFromCache: isFromCache,
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
