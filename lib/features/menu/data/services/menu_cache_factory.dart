import 'package:flutter/foundation.dart';
import 'meal_local_cache.dart';

/// Web uses Firestore's IndexedDB persistence. SQLite and its filesystem outbox
/// remain enabled on native platforms only.
MealLocalCache? createMenuLocalCache() =>
    kIsWeb ? null : SqliteMealLocalCache();
