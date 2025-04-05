import '../database_service.dart';

class TransactionRepository {
  final DatabaseService _databaseService = DatabaseService.instance;

  Future<int> recordTransaction(int itemId, int userId, String type, int quantity, String notes) async {
    final db = await _databaseService.database;
    
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
    final db = await _databaseService.database;
    return db.query(
      'inventory_transactions',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'date DESC',
    );
  }
}
