import '../../data/models/meal_model.dart';

/// Prefix search over meal names.
/// Build: O(n log n) once per snapshot. Search: O(log n * L + k).
class MealSearchIndex {
  MealSearchIndex(Iterable<MealModel> meals)
    : _entries = [
        for (final meal in meals) (key: meal.name.toLowerCase(), meal: meal),
      ]..sort((a, b) => a.key.compareTo(b.key));

  static final empty = MealSearchIndex(const []);

  final List<({String key, MealModel meal})> _entries;

  /// [prefix] must already be trimmed + lowercase.
  List<MealModel> search(String prefix, {MealCategory? category}) {
    final result = <MealModel>[];
    for (var i = _lowerBound(prefix); i < _entries.length; i++) {
      final entry = _entries[i];
      if (!entry.key.startsWith(prefix)) break;
      if (category == null || entry.meal.category == category) {
        result.add(entry.meal);
      }
    }
    return result;
  }

  int _lowerBound(String query) {
    var lo = 0, hi = _entries.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_entries[mid].key.compareTo(query) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}