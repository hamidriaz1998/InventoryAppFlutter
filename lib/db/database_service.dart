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
      version: 3, // Increment version number for migrations
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
        FOREIGN KEY (item_id) REFERENCES items (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // All migrations consolidated into a single function
    if (oldVersion < 2) {
      // Ensure all tables exist (in case upgrading from version 1)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE,
          password_hash TEXT,
          email TEXT,
          created_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          color TEXT
        )
      ''');

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

      // Check if items table exists and create it if it doesn't
      var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='items'");
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            name TEXT,
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
      } else {
        // If the table exists, make sure all columns exist
        var columns = await db.rawQuery('PRAGMA table_info(items)');
        
        Map<String, bool> columnExists = {
          'user_id': false,
          'category_id': false,
          'image_path': false,
          'barcode': false,
          'created_at': false,
          'updated_at': false,
          'description': false,
        };
        
        for (var col in columns) {
          String name = col['name'] as String;
          if (columnExists.containsKey(name)) {
            columnExists[name] = true;
          }
        }
        
        // Add missing columns
        for (var entry in columnExists.entries) {
          if (!entry.value) {
            String type = entry.key == 'description' ? 'TEXT' : 
                        (entry.key.endsWith('_id') ? 'INTEGER' : 
                         (entry.key.endsWith('_at') ? 'TEXT' : 'TEXT'));
            try {
              await db.execute('ALTER TABLE items ADD COLUMN ${entry.key} $type');
            } catch (e) {
              print('Error adding column ${entry.key}: $e');
            }
          }
        }
      }
    }

    // For any future migrations, add conditions like:
    if (oldVersion < 3) {
      // Add new migrations for version 3 here
    }
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
