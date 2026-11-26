import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/services/meal_image_storage_service.dart';
import 'menu_management_state.dart';

enum MealSaveResult { saved, failed, pending }

class MenuManagementCubit extends Cubit<MenuManagementState> {
  MenuManagementCubit(
    this._repo, {
    this.saveTimeout = const Duration(seconds: 3),
  }) : super(MenuManagementState()) {
    _syncSubscription = _repo.syncEvents.listen((event) {
      _notify(
        event.imageUploaded
            ? 'Image uploaded and product updated successfully.'
            : 'Product changes synced with Firebase.',
      );
    });
    _localChangeSubscription = _repo.localChanges.listen(
      (_) => _refreshFromLocalCache(),
    );
  }

  static const _pendingMessage =
      'Saved on this device. Firebase will sync it automatically when the connection returns.';

  final MenuRepository _repo;
  MenuRepository get repository => _repo;
  String? get syncErrorMessage => _repo.syncErrorMessage;
  final Duration saveTimeout;
  StreamSubscription<List<MealModel>>? _sub;
  late final StreamSubscription<MenuSyncEvent> _syncSubscription;
  late final StreamSubscription<void> _localChangeSubscription;
  bool _hasMealSnapshot = false;

  /// id -> "name\ndescription\ncategory" in lowercase (built once per snapshot).
  Map<String, String> _keys = const {};

  Future<void> _refreshFromLocalCache() async {
    final meals = await _repo.readMealsFromCache();
    if (meals == null || isClosed) return;
    _hasMealSnapshot = true;
    final sorted = [...meals]..sort(_byName);
    _keys = {
      for (final meal in sorted)
        meal.id: '${meal.name}\n${meal.description}\n${meal.category.label}'
            .toLowerCase(),
    };
    _apply(
      state.copyWith(
        status: ManagementStatus.success,
        meals: sorted,
        loadError: () => null,
      ),
    );
  }

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
  Future<MealSaveResult> save(MealModel meal) => _runWrite<void>(() async {
    if (meal.id.isEmpty) {
      await _repo.addMeal(meal);
    } else {
      await _repo.updateMeal(meal);
    }
  }, notifyWhenQueued: false);

  Future<MealSaveResult> updateMealImage(String id, String imageUrl) =>
      _runWrite<void>(() => _repo.updateMealImage(id, imageUrl));

  Future<String> saveImageLocally(PickedMealImage image) =>
      _repo.saveImageLocally(image);

  Future<MealSaveResult> stageMealImage(
    String id,
    String localImagePath, {
    required String fileName,
    MealModel? meal,
  }) => _runWrite<void>(
    () => _repo.stageMealImage(
      id,
      localImagePath,
      fileName: fileName,
      meal: meal,
    ),
    notifyWhenQueued: false,
  );

  Future<MealSaveResult> _runWrite<T>(
    Future<T> Function() operation, {
    bool notifyWhenQueued = true,
  }) async {
    final write = operation();
    try {
      if (_repo.hasPersistentOutbox) {
        await write;
        if (await _repo.syncPendingMutations()) {
          return MealSaveResult.saved;
        }
        if (notifyWhenQueued) {
          _notify(_repo.syncErrorMessage ?? _pendingMessage);
        }
        return MealSaveResult.pending;
      }
      await write.timeout(saveTimeout);
      return MealSaveResult.saved;
    } on TimeoutException {
      _observePending(write);
      _notify(_pendingMessage);
      return MealSaveResult.pending;
    } on MenuFailure catch (e) {
      _notify(e.message);
      return MealSaveResult.failed;
    } on Exception catch (e) {
      _notify(e.toString());
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
    _syncSubscription.cancel();
    _localChangeSubscription.cancel();
    return super.close();
  }
}
