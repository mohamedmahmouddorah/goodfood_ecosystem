import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/meal_model.dart';

class CachedMeals {
  const CachedMeals(this.meals);

  final List<MealModel> meals;
}

abstract interface class MealLocalCache {
  Future<CachedMeals?> readMeals();

  Future<void> replaceMeals(List<MealModel> meals);
}

class SqliteMealLocalCache implements MealLocalCache {
  SqliteMealLocalCache({String? databasePath}) : _databasePath = databasePath;

  final String? _databasePath;
  Future<Database>? _database;

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

  @override
  Future<void> replaceMeals(List<MealModel> meals) async {
    final database = await _openDatabase();
    await database.transaction((transaction) async {
      await transaction.delete('meals');
      for (final meal in meals) {
        await transaction.insert(
          'meals',
          _mealToRow(meal),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await transaction.insert('cache_metadata', {
        'key': 'meals_initialized',
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Database> _openDatabase() => _database ??= _createDatabase();

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) await (await database).close();
  }

  Future<Database> _createDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } else if (Platform.isAndroid || Platform.isIOS) {
      databaseFactory = sqflite.databaseFactorySqflitePlugin;
    }

    final databasePath = _databasePath ?? await _defaultDatabasePath();
    return databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) async {
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
        },
      ),
    );
  }

  Future<String> _defaultDatabasePath() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return p.join(directory.path, 'goodfood_menu.db');
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
