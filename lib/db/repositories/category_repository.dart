import '../database_service.dart';
import '../../models/category.dart';

class CategoryRepository {
  final DatabaseService _databaseService = DatabaseService.instance;

  Future<int> insertCategory(Category category) async {
    final db = await _databaseService.database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getCategories() async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    
    return List.generate(maps.length, (i) {
      return Category.fromMap(maps[i]);
    });
  }

  Future<Category?> getCategory(int id) async {
    final db = await _databaseService.database;
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
    final db = await _databaseService.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await _databaseService.database;
    
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
