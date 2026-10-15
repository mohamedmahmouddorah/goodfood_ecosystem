import 'package:flutter/foundation.dart' show ValueGetter;

import '../../data/models/meal_model.dart';

enum ManagementStatus { loading, success, failure }

class MenuManagementState {
  const MenuManagementState({
    this.status = ManagementStatus.loading,
    this.meals = const [],
    this.category,
    this.message,
    this.loadError,
  });

  final ManagementStatus status;
  final List<MealModel> meals; // ALL meals, including hidden ones
  final MealCategory? category; // null = All
  final String? message; // one-shot snackbar text
  final String? loadError;

  /// The admin menu is small, so the category filter runs locally:
  /// no extra Firestore reads and no extra index.
  List<MealModel> get visible => category == null
      ? meals
      : meals.where((m) => m.category == category).toList(growable: false);

  MenuManagementState copyWith({
    ManagementStatus? status,
    List<MealModel>? meals,
    ValueGetter<MealCategory?>? category,
    ValueGetter<String?>? message,
    ValueGetter<String?>? loadError,
  }) =>
      MenuManagementState(
        status: status ?? this.status,
        meals: meals ?? this.meals,
        category: category != null ? category() : this.category,
        message: message != null ? message() : this.message,
        loadError: loadError != null ? loadError() : this.loadError,
      );
}