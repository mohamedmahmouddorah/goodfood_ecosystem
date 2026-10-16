import 'package:flutter/foundation.dart' show ValueGetter;

import '../../data/models/meal_model.dart';

enum MenuStatus { loading, success, failure }

/// Customer menu state. `success` + empty `meals` = the "Empty" state.
class MenuState {
  const MenuState({
    this.status = MenuStatus.loading,
    this.meals = const [],
    this.category, // null = All
    this.query = '',
    this.isFromCache = false,
    this.revision = 0,
    this.error,
  });

  final MenuStatus status;
  final List<MealModel> meals;
  final MealCategory? category;
  final String query;
  final bool isFromCache;

  /// Increases only when a new snapshot arrives (not on search/category).
  final int revision;
  final String? error;

  /// `error` is intentionally NOT carried over: it only lives in a failure state.
  MenuState copyWith({
    MenuStatus? status,
    List<MealModel>? meals,
    ValueGetter<MealCategory?>? category,
    String? query,
    bool? isFromCache,
    int? revision,
    String? error,
  }) => MenuState(
    status: status ?? this.status,
    meals: meals ?? this.meals,
    category: category != null ? category() : this.category,
    query: query ?? this.query,
    isFromCache: isFromCache ?? this.isFromCache,
    revision: revision ?? this.revision,
    error: error,
  );
}