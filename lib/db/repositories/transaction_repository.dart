import '../database_service.dart';

class TransactionRepository {
  final DatabaseService _databaseService = DatabaseService.instance;

  Future<int> recordTransaction(int itemId, int userId, String type, int quantity, String notes, {double? unitPrice, double? totalAmount}) async {
    final db = await _databaseService.database;
    
    final now = DateTime.now().toIso8601String();
    return db.insert('inventory_transactions', {
      'item_id': itemId,
      'user_id': userId,
      'transaction_type': type,
      'quantity': quantity,
      'date': now,
      'notes': notes,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
    });
  }

  Future<int> sellItem(int itemId, int userId, int quantity, double unitPrice, String notes) async {
    final totalAmount = quantity * unitPrice;
    return recordTransaction(
      itemId, 
      userId, 
      'SALE', 
      quantity, 
      notes,
      unitPrice: unitPrice,
      totalAmount: totalAmount,
    );
  }

  Future<int> restockItem(int itemId, int userId, int quantity, double unitPrice, String notes) async {
    final totalAmount = quantity * unitPrice;
    return recordTransaction(
      itemId, 
      userId, 
      'RESTOCK', 
      quantity, 
      notes,
      unitPrice: unitPrice,
      totalAmount: totalAmount,
    );
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
  
  Future<List<Map<String, dynamic>>> getSalesTransactions({DateTime? startDate, DateTime? endDate}) async {
    final db = await _databaseService.database;
    
    String whereClause = "transaction_type = 'SALE'";
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause += " AND date BETWEEN ? AND ?";
      whereArgs.add(startDate.toIso8601String());
      whereArgs.add(endDate.toIso8601String());
    }
    
    return db.query(
      'inventory_transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
  }
  
  Future<double> getTotalSalesAmount({DateTime? startDate, DateTime? endDate}) async {
    final db = await _databaseService.database;
    
    String whereClause = "transaction_type = 'SALE'";
    List<dynamic> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause += " AND date BETWEEN ? AND ?";
      whereArgs.add(startDate.toIso8601String());
      whereArgs.add(endDate.toIso8601String());
    }
    
    final result = await db.rawQuery(
      'SELECT SUM(total_amount) as total FROM inventory_transactions WHERE $whereClause',
      whereArgs,
    );
    
    if (result.isNotEmpty && result[0]['total'] != null) {
      return result[0]['total'] as double;
    }
    return 0.0;
  }
}
