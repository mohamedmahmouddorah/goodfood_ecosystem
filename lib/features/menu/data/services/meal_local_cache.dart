import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../models/meal_model.dart';

class CachedMeals {
  const CachedMeals(this.meals);

  final List<MealModel> meals;
}

abstract interface class MealLocalCache {
  Future<CachedMeals?> readMeals();

  Future<MealModel?> readMeal(String id);

  Future<void> replaceMeals(List<MealModel> meals);

  Future<void> replaceAvailableMeals(List<MealModel> meals);

  Future<void> upsertMeal(MealModel meal);

  Future<void> removeMeal(String id);
}

class SqliteMealLocalCache implements MealLocalCache {
  SqliteMealLocalCache({String? databasePath}) : _databasePath = databasePath;

  static const _initializedRow = {'key': 'meals_initialized', 'value': 'true'};

  final String? _databasePath;
  Future<Database>? _database;

  Future<Database> _openDatabase() => _database ??= openAppDatabase(
    fileName: 'goodfood_menu.db',
    path: _databasePath,
    onCreate: _onCreate,
  );

  static Future<void> _onCreate(Database database, int _) async {
    await database.execute('''
      CREATE TABLE meals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        imageUrl TEXT NOT NULL,
        description TEXT NOT NULL,
        isAvailable INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE cache_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<CachedMeals?> readMeals() async {
    final database = await _openDatabase();
    final initialized = await database.query(
      'cache_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['meals_initialized'],
      limit: 1,
    );
    if (initialized.isEmpty || initialized.single['value'] != 'true') {
      return null;
    }
    final rows = await database.query('meals', orderBy: 'name COLLATE NOCASE');
    return CachedMeals(rows.map(_mealFromRow).toList(growable: false));
  }

  /// Primary-key lookup: no need to read the whole table.
  @override
  Future<MealModel?> readMeal(String id) async {
    final database = await _openDatabase();
    final rows = await database.query(
      'meals',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _mealFromRow(rows.first);
  }

  @override
  Future<void> replaceMeals(List<MealModel> meals) async {
    final database = await _openDatabase();
    await database.transaction((transaction) async {
      final batch = transaction.batch()..delete('meals');
      for (final meal in meals) {
        batch.insert(
          'meals',
          _mealToRow(meal),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      batch.insert(
        'cache_metadata',
        _initializedRow,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);
    });
  }

  /// Hides every cached meal, then upserts the currently available ones
  /// (which makes them visible again). One batch, no per-row awaits.
  @override
  Future<void> replaceAvailableMeals(List<MealModel> meals) async {
    final database = await _openDatabase();
    await database.transaction((transaction) async {
      final batch = transaction.batch()
        ..update('meals', {'isAvailable': 0}, where: 'isAvailable = 1');
      for (final meal in meals) {
        batch.insert(
          'meals',
          _mealToRow(meal),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      batch.insert(
        'cache_metadata',
        _initializedRow,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> upsertMeal(MealModel meal) async {
    final database = await _openDatabase();
    await database.transaction((transaction) async {
      await transaction.insert(
        'meals',
        _mealToRow(meal),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.insert(
        'cache_metadata',
        _initializedRow,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> removeMeal(String id) async {
    final database = await _openDatabase();
    await database.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) await (await database).close();
  }

  Map<String, Object?> _mealToRow(MealModel meal) => {
    'id': meal.id,
    'name': meal.name,
    'category': meal.category.key,
    'price': meal.price,
    'imageUrl': meal.imageUrl,
    'description': meal.description,
    'isAvailable': meal.isAvailable ? 1 : 0,
  };

  MealModel _mealFromRow(Map<String, Object?> row) => MealModel(
    id: row['id']! as String,
    name: row['name']! as String,
    category: MealCategory.fromKey(row['category']! as String),
    price: (row['price']! as num).toDouble(),
    imageUrl: row['imageUrl']! as String,
    description: row['description']! as String,
    isAvailable: row['isAvailable']! as int == 1,
  );
}