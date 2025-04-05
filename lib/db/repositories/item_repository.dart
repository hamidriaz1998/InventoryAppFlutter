import '../database_service.dart';
import '../../models/item.dart';

class ItemRepository {
  final DatabaseService _databaseService = DatabaseService.instance;

  Future<int> insertItem(Item item) async {
    final db = await _databaseService.database;
    return await db.insert('items', item.toMap());
  }

  Future<List<Item>> getItems({int? userId, String? category, String? searchQuery, int? categoryId}) async {
    final db = await _databaseService.database;
    
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
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<int> updateItem(Item item) async {
    final db = await _databaseService.database;
    return db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await _databaseService.database;
    return db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<List<Map<String, dynamic>>> getLowStockItems(int userId, int threshold) async {
    final db = await _databaseService.database;
    return db.query(
      'items',
      where: 'user_id = ? AND quantity <= ?',
      whereArgs: [userId, threshold],
      orderBy: 'quantity ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getInventoryValueByCategory(int userId) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery('''
      SELECT c.name as category, SUM(i.price * i.quantity) as total_value
      FROM items i
      LEFT JOIN categories c ON i.category_id = c.id
      WHERE i.user_id = ?
      GROUP BY i.category_id
    ''', [userId]);
    
    return result;
  }
}
