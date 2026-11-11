// import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../menu/data/models/meal_model.dart';
import '../../presentation/view_model/cart_state.dart';

abstract interface class CartLocalStorage {
  Future<List<CartItem>> readItems();

  Future<void> replaceItems(List<CartItem> items);
}

class SqliteCartLocalStorage implements CartLocalStorage {
  SqliteCartLocalStorage({String? databasePath}) : _databasePath = databasePath;

  final String? _databasePath;
  Future<Database>? _database;

  @override
  Future<List<CartItem>> readItems() async {
    final database = await _openDatabase();
    final rows = await database.query('cart_items', orderBy: 'rowid');
    return rows.map(_cartItemFromRow).toList(growable: false);
  }

  @override
  Future<void> replaceItems(List<CartItem> items) async {
    final database = await _openDatabase();
    await database.transaction((transaction) async {
      await transaction.delete('cart_items');
      for (final item in items) {
        await transaction.insert('cart_items', _cartItemToRow(item));
      }
    });
  }

  Future<Database> _openDatabase() {
    return _database ??= openAppDatabase(
      fileName: 'goodfood_cart.db',
      path: _databasePath,
      version: 1,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE cart_items (
            mealId TEXT PRIMARY KEY,
            quantity INTEGER NOT NULL,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            price REAL NOT NULL,
            imageUrl TEXT NOT NULL,
            description TEXT NOT NULL,
            isAvailable INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) await (await database).close();
  }

  Map<String, Object?> _cartItemToRow(CartItem item) => {
    'mealId': item.meal.id,
    'quantity': item.quantity,
    'name': item.meal.name,
    'category': item.meal.category.key,
    'price': item.meal.price,
    'imageUrl': item.meal.imageUrl,
    'description': item.meal.description,
    'isAvailable': item.meal.isAvailable ? 1 : 0,
  };

  CartItem _cartItemFromRow(Map<String, Object?> row) => CartItem(
    quantity: row['quantity']! as int,
    meal: MealModel(
      id: row['mealId']! as String,
      name: row['name']! as String,
      category: MealCategory.fromKey(row['category']! as String),
      price: (row['price']! as num).toDouble(),
      imageUrl: row['imageUrl']! as String,
      description: row['description']! as String,
      isAvailable: row['isAvailable']! as int == 1,
    ),
  );
}