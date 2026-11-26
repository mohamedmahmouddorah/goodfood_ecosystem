import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../models/meal_model.dart';

class CachedMeals {
  const CachedMeals(this.meals);

  final List<MealModel> meals;
}

enum MealMutationType { create, update, delete }

class PendingMealMutation {
  const PendingMealMutation({
    required this.mealId,
    required this.type,
    required this.version,
  });

  final String mealId;
  final MealMutationType type;
  final int version;
}

abstract interface class MealMutationOutbox {
  Future<int> enqueueUpsert(MealModel meal, {required bool isCreate});

  Future<String?> enqueueDelete(String mealId);

  Future<List<PendingMealMutation>> readPendingMutations();

  Future<bool> isMutationCurrent(String mealId, int version);

  Future<bool> saveUploadedImageUrl(
    String mealId,
    int version,
    String imageUrl,
  );

  Future<bool> completeMutation(String mealId, int version);
}

abstract interface class MealLocalCache {
  Future<CachedMeals?> readMeals();

  Future<MealModel?> readMeal(String id);

  Future<void> replaceMeals(List<MealModel> meals);

  Future<void> replaceAvailableMeals(List<MealModel> meals);

  Future<void> upsertMeal(MealModel meal);

  Future<void> removeMeal(String id);
}

class SqliteMealLocalCache implements MealLocalCache, MealMutationOutbox {
  SqliteMealLocalCache({String? databasePath}) : _databasePath = databasePath;

  static const _initializedRow = {'key': 'meals_initialized', 'value': 'true'};

  final String? _databasePath;
  Future<Database>? _database;

  Future<Database> _openDatabase() => _database ??= openAppDatabase(
    fileName: 'goodfood_menu.db',
    path: _databasePath,
    version: 3,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
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
        isAvailable INTEGER NOT NULL,
        localImagePath TEXT,
        localImageName TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE cache_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await _createOutboxTable(database);
  }

  static Future<void> _onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE meals ADD COLUMN localImagePath TEXT',
      );
      await _createOutboxTable(database);
    }
    if (oldVersion < 3) {
      await database.execute(
        'ALTER TABLE meals ADD COLUMN localImageName TEXT',
      );
    }
  }

  static Future<void> _createOutboxTable(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE meal_outbox (
        mealId TEXT PRIMARY KEY,
        operation TEXT NOT NULL,
        version INTEGER NOT NULL
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
      final pendingRows = await transaction.query(
        'meal_outbox',
        columns: ['mealId'],
      );
      final pendingIds = pendingRows
          .map((row) => row['mealId']! as String)
          .toSet();
      final remoteIds = meals.map((meal) => meal.id).toSet();
      final localRows = await transaction.query('meals', columns: ['id']);
      final batch = transaction.batch();
      for (final row in localRows) {
        final id = row['id']! as String;
        if (!pendingIds.contains(id) && !remoteIds.contains(id)) {
          batch.delete('meals', where: 'id = ?', whereArgs: [id]);
        }
      }
      for (final meal in meals) {
        if (pendingIds.contains(meal.id)) continue;
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
        ..update(
          'meals',
          {'isAvailable': 0},
          where:
              'isAvailable = 1 AND id NOT IN (SELECT mealId FROM meal_outbox)',
        );
      final pendingRows = await transaction.query(
        'meal_outbox',
        columns: ['mealId'],
      );
      final pendingIds = pendingRows
          .map((row) => row['mealId']! as String)
          .toSet();
      for (final meal in meals) {
        if (pendingIds.contains(meal.id)) continue;
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
  Future<int> enqueueUpsert(MealModel meal, {required bool isCreate}) async {
    final database = await _openDatabase();
    return database.transaction((transaction) async {
      final pending = await transaction.query(
        'meal_outbox',
        columns: ['operation', 'version'],
        where: 'mealId = ?',
        whereArgs: [meal.id],
        limit: 1,
      );
      final previousOperation = pending.isEmpty
          ? null
          : pending.single['operation']! as String;
      final previousVersion = pending.isEmpty
          ? 0
          : pending.single['version']! as int;
      final operation =
          previousOperation == MealMutationType.create.name || isCreate
          ? MealMutationType.create.name
          : MealMutationType.update.name;
      final version = previousVersion + 1;
      await transaction.insert(
        'meals',
        _mealToRow(meal),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.insert('meal_outbox', {
        'mealId': meal.id,
        'operation': operation,
        'version': version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.insert(
        'cache_metadata',
        _initializedRow,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return version;
    });
  }

  @override
  Future<String?> enqueueDelete(String mealId) async {
    final database = await _openDatabase();
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'meals',
        columns: ['localImagePath'],
        where: 'id = ?',
        whereArgs: [mealId],
        limit: 1,
      );
      final localImagePath = rows.isEmpty
          ? null
          : rows.single['localImagePath'] as String?;
      final pending = await transaction.query(
        'meal_outbox',
        columns: ['version'],
        where: 'mealId = ?',
        whereArgs: [mealId],
        limit: 1,
      );
      final version = pending.isEmpty
          ? 1
          : (pending.single['version']! as int) + 1;
      await transaction.delete('meals', where: 'id = ?', whereArgs: [mealId]);
      await transaction.insert('meal_outbox', {
        'mealId': mealId,
        'operation': MealMutationType.delete.name,
        'version': version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return localImagePath;
    });
  }

  @override
  Future<List<PendingMealMutation>> readPendingMutations() async {
    final database = await _openDatabase();
    final rows = await database.query('meal_outbox', orderBy: 'rowid');
    return rows
        .map(
          (row) => PendingMealMutation(
            mealId: row['mealId']! as String,
            type: MealMutationType.values.byName(row['operation']! as String),
            version: row['version']! as int,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<bool> isMutationCurrent(String mealId, int version) async {
    final database = await _openDatabase();
    final rows = await database.query(
      'meal_outbox',
      columns: ['version'],
      where: 'mealId = ?',
      whereArgs: [mealId],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['version'] == version;
  }

  @override
  Future<bool> saveUploadedImageUrl(
    String mealId,
    int version,
    String imageUrl,
  ) async {
    final database = await _openDatabase();
    return database.transaction((transaction) async {
      final pending = await transaction.query(
        'meal_outbox',
        columns: ['version'],
        where: 'mealId = ?',
        whereArgs: [mealId],
        limit: 1,
      );
      if (pending.isEmpty || pending.single['version'] != version) return false;
      final rows = await transaction.query(
        'meals',
        where: 'id = ?',
        whereArgs: [mealId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      await transaction.update(
        'meals',
        _mealToRow(
          _mealFromRow(
            rows.single,
          ).copyWith(imageUrl: imageUrl, clearLocalImagePath: true),
        ),
        where: 'id = ?',
        whereArgs: [mealId],
      );
      return true;
    });
  }

  @override
  Future<bool> completeMutation(String mealId, int version) async {
    final database = await _openDatabase();
    return database.transaction((transaction) async {
      final pending = await transaction.query(
        'meal_outbox',
        columns: ['operation', 'version'],
        where: 'mealId = ?',
        whereArgs: [mealId],
        limit: 1,
      );
      if (pending.isEmpty || pending.single['version'] != version) return false;
      if (pending.single['operation'] == MealMutationType.delete.name) {
        await transaction.delete('meals', where: 'id = ?', whereArgs: [mealId]);
      }
      await transaction.delete(
        'meal_outbox',
        where: 'mealId = ?',
        whereArgs: [mealId],
      );
      return true;
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
    'localImagePath': meal.localImagePath,
    'localImageName': meal.localImageName,
  };

  MealModel _mealFromRow(Map<String, Object?> row) => MealModel(
    id: row['id']! as String,
    name: row['name']! as String,
    category: MealCategory.fromKey(row['category']! as String),
    price: (row['price']! as num).toDouble(),
    imageUrl: row['imageUrl']! as String,
    description: row['description']! as String,
    isAvailable: row['isAvailable']! as int == 1,
    localImagePath: row['localImagePath'] as String?,
    localImageName: row['localImageName'] as String?,
  );
}
