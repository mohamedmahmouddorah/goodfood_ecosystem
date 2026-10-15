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
    this.hasMore = false,
    this.loadingMore = false,
    this.error,
  });

  final MenuStatus status;
  final List<MealModel> meals;
  final MealCategory? category;
  final String query;
  final bool hasMore;
  final bool loadingMore;
  final String? error;

  /// `category` takes a getter so that `() => null` can mean "All".
  /// `error` is intentionally NOT carried over: it only lives in a failure state.
  MenuState copyWith({
    MenuStatus? status,
    List<MealModel>? meals,
    ValueGetter<MealCategory?>? category,
    String? query,
    bool? hasMore,
    bool? loadingMore,
    String? error,
  }) =>
      MenuState(
        status: status ?? this.status,
        meals: meals ?? this.meals,
        category: category != null ? category() : this.category,
        query: query ?? this.query,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
      );
}