import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._privateConstructor();
  static Database? _database;

  DatabaseService._privateConstructor();

  Future<void> init() async {
    if (_database != null) return;
    _database = await _initDatabase();
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
      version: 4, 
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

    // Create categories table
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        color TEXT
      )
    ''');

    // Create items table with all fields
    await db.execute('''
      CREATE TABLE items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        name TEXT,
        description TEXT,
        quantity INTEGER,
        price REAL,
        category_id INTEGER,
        image_path TEXT,
        barcode TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (category_id) REFERENCES categories (id)
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
        unit_price REAL,
        total_amount REAL,
        FOREIGN KEY (item_id) REFERENCES items (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
    
    // Seed the database with initial data
    if (version >= 4) {
      await _seedDatabase(db);
    }
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Only perform schema changes here
    if (oldVersion < 2) {
      // Add any missing columns to items table
      var columns = await db.rawQuery('PRAGMA table_info(items)');
      
      Map<String, String> missingColumns = {
        'description': 'TEXT',
        'user_id': 'INTEGER',
        'category_id': 'INTEGER',
        'image_path': 'TEXT',
        'barcode': 'TEXT',
        'created_at': 'TEXT',
        'updated_at': 'TEXT',
      };
      
      for (var col in columns) {
        String name = col['name'] as String;
        if (missingColumns.containsKey(name)) {
          missingColumns.remove(name);
        }
      }
      
      // Add missing columns
      for (var entry in missingColumns.entries) {
        try {
          await db.execute('ALTER TABLE items ADD COLUMN ${entry.key} ${entry.value}');
        } catch (e) {
          print('Error adding column ${entry.key}: $e');
        }
      }
    }

    if (oldVersion < 3) {
      // Add the unit_price and total_amount columns to support sales and restocks
      try {
        await db.execute('ALTER TABLE inventory_transactions ADD COLUMN unit_price REAL');
        await db.execute('ALTER TABLE inventory_transactions ADD COLUMN total_amount REAL');
      } catch (e) {
        print('Error adding sales columns to inventory_transactions: $e');
      }
    }

    // Seed data if upgrading to version 4
    if (oldVersion < 4 && newVersion >= 4) {
      await _seedDatabase(db);
    }
  }

  Future<void> _seedDatabase(Database db) async {
    // Insert sample data
    
    // First check if data already exists
    final categoryCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories'));
    if (categoryCount != null && categoryCount > 0) {
      return; // Data already exists, no need to seed
    }
    
    // Insert sample categories
    await db.insert('categories', {
      'name': 'Electronics',
      'description': 'Electronic devices and accessories',
      'color': '#FF5722'
    });

    await db.insert('categories', {
      'name': 'Office Supplies',
      'description': 'Items used in office environments',
      'color': '#2196F3'
    });

    await db.insert('categories', {
      'name': 'Kitchen',
      'description': 'Kitchen appliances and utensils',
      'color': '#4CAF50'
    });

    final timestamp = DateTime.now().toIso8601String();
    // Insert sample items
    await db.insert('items', {
      'user_id': 1,
      'name': 'Laptop',
      'description': 'High-performance laptop',
      'quantity': 5,
      'price': 1200.00,
      'category_id': 1,
      'created_at': timestamp,
      'updated_at': timestamp
    });

    await db.insert('items', {
      'user_id': 1,
      'name': 'Notebook',
      'description': 'Lined paper notebook',
      'quantity': 20,
      'price': 4.99,
      'category_id': 2,
      'created_at': timestamp,
      'updated_at': timestamp
    });

    // Insert sample transaction
    await db.insert('inventory_transactions', {
      'item_id': 1,
      'user_id': 1,
      'transaction_type': 'initial_stock',
      'quantity': 5,
      'date': timestamp,
      'notes': 'Initial inventory',
      'unit_price': 1000.00,
      'total_amount': 5000.00
    });
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
