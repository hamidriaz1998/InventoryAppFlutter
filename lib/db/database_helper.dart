// database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/item.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<void> init() async {
    if (_database != null) return;
    _database = await _initDatabase();

    await _createCategoryTable(_database!);
    await _addCategoryToItemsTable(_database!);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'inventory_database.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password_hash TEXT,
        email TEXT,
        created_at TEXT
      )
    ''');

    // Create items table
    await db.execute('''
      CREATE TABLE items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        name TEXT,
        quantity INTEGER,
        category TEXT,
        price REAL,
        image_path TEXT,
        barcode TEXT,
        created_at TEXT,
        updated_at TEXT,
        category_id INTEGER,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Create inventory_transactions table for history
    await db.execute('''
      CREATE TABLE inventory_transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER,
        user_id INTEGER,
        transaction_type TEXT,
        quantity INTEGER,
        date TEXT,
        notes TEXT,
        FOREIGN KEY (item_id) REFERENCES items (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await _createCategoryTable(db);
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add users table if upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE,
          password_hash TEXT,
          email TEXT,
          created_at TEXT
        )
      ''');

      // Add user_id column to items table if it doesn't exist
      var columns = await db.rawQuery('PRAGMA table_info(items)');
      bool hasUserIdColumn = columns.any((column) => column['name'] == 'user_id');
      
      if (!hasUserIdColumn) {
        await db.execute('ALTER TABLE items ADD COLUMN user_id INTEGER');
      }
      
      // Create inventory_transactions table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS inventory_transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_id INTEGER,
          user_id INTEGER,
          transaction_type TEXT,
          quantity INTEGER,
          date TEXT,
          notes TEXT,
          FOREIGN KEY (item_id) REFERENCES items (id),
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');

      // Add additional columns to items table
      var itemsColumns = await db.rawQuery('PRAGMA table_info(items)');
      if (!itemsColumns.any((column) => column['name'] == 'image_path')) {
        await db.execute('ALTER TABLE items ADD COLUMN image_path TEXT');
      }
      if (!itemsColumns.any((column) => column['name'] == 'barcode')) {
        await db.execute('ALTER TABLE items ADD COLUMN barcode TEXT');
      }
      if (!itemsColumns.any((column) => column['name'] == 'created_at')) {
        await db.execute('ALTER TABLE items ADD COLUMN created_at TEXT');
      }
      if (!itemsColumns.any((column) => column['name'] == 'updated_at')) {
        await db.execute('ALTER TABLE items ADD COLUMN updated_at TEXT');
      }

      await _addCategoryToItemsTable(db);
      await _createCategoryTable(db);
    }
  }

  Future<void> _createCategoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        color TEXT
      )
    ''');
  }

  Future<void> _addCategoryToItemsTable(Database db) async {
    // Check if category_id column exists
    var columns = await db.rawQuery('PRAGMA table_info(items)');
    bool categoryColumnExists = columns.any((column) => column['name'] == 'category_id');
    
    if (!categoryColumnExists) {
      await db.execute('ALTER TABLE items ADD COLUMN category_id INTEGER');
    }
  }

  // User operations
  Future<User?> getUser(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    return db.insert('users', user.toMap());
  }

  String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> validateUser(String username, String password) async {
    final user = await getUser(username);
    if (user == null) return false;
    
    final passwordHash = hashPassword(password);
    return user.passwordHash == passwordHash;
  }

  // Item operations
  Future<int> insertItem(Item item) async {
    final db = await database;
    return await db.insert('items', {
      'name': item.name,
      'quantity': item.quantity,
      'price': item.price,
      'category_id': item.categoryId,
      'user_id': item.userId,
      'image_path': item.imagePath,
      'barcode': item.barcode,
      'created_at': item.createdAt,
      'updated_at': item.updatedAt,
    });
  }

  Future<List<Item>> getItems({int? userId, String? category, String? searchQuery, int? categoryId}) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (userId != null) {
      whereClause = 'user_id = ?';
      whereArgs = [userId];
    }
    
    if (category != null && category.isNotEmpty) {
      whereClause = whereClause.isEmpty ? 'category = ?' : '$whereClause AND category = ?';
      whereArgs.add(category);
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClause = whereClause.isEmpty ? 'name LIKE ?' : '$whereClause AND name LIKE ?';
      whereArgs.add('%$searchQuery%');
    }

    if (categoryId != null) {
      whereClause = whereClause.isEmpty ? 'category_id = ?' : '$whereClause AND category_id = ?';
      whereArgs.add(categoryId);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
    );
    
    return List.generate(maps.length, (i) => Item.fromMap(maps[i]));
  }

  Future<Item?> getItem(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    return db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Transaction operations
  Future<int> recordTransaction(int itemId, int userId, String type, int quantity, String notes) async {
    final db = await database;
    
    final now = DateTime.now().toIso8601String();
    return db.insert('inventory_transactions', {
      'item_id': itemId,
      'user_id': userId,
      'transaction_type': type,
      'quantity': quantity,
      'date': now,
      'notes': notes,
    });
  }

  Future<List<Map<String, dynamic>>> getItemTransactions(int itemId) async {
    final db = await database;
    return db.query(
      'inventory_transactions',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'date DESC',
    );
  }

  // Reporting methods
  Future<List<Map<String, dynamic>>> getInventoryValueByCategory(int userId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT category, SUM(price * quantity) as total_value
      FROM items
      WHERE user_id = ?
      GROUP BY category
    ''', [userId]);
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getLowStockItems(int userId, int threshold) async {
    final db = await database;
    return db.query(
      'items',
      where: 'user_id = ? AND quantity <= ?',
      whereArgs: [userId, threshold],
      orderBy: 'quantity ASC',
    );
  }

  // Category operations
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    
    return List.generate(maps.length, (i) {
      return Category.fromMap(maps[i]);
    });
  }

  Future<Category?> getCategory(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) {
      return null;
    }
    
    return Category.fromMap(maps[0]);
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    
    // First, set category_id to null for all items in this category
    await db.update(
      'items',
      {'category_id': null},
      where: 'category_id = ?',
      whereArgs: [id],
    );
    
    // Then delete the category
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}