class InventoryTransaction {
  final int? id;
  final int itemId;
  final int userId;
  final String transactionType; // SALE, RESTOCK, CREATE, UPDATE, DELETE
  final int quantity;
  final String date;
  final String notes;
  final double? unitPrice;
  final double? totalAmount;

  const InventoryTransaction({
    this.id,
    required this.itemId,
    required this.userId,
    required this.transactionType,
    required this.quantity,
    required this.date,
    required this.notes,
    this.unitPrice,
    this.totalAmount,
  });

  factory InventoryTransaction.fromMap(Map<String, dynamic> map) {
    return InventoryTransaction(
      id: map['id'],
      itemId: map['item_id'],
      userId: map['user_id'],
      transactionType: map['transaction_type'],
      quantity: map['quantity'],
      date: map['date'],
      notes: map['notes'],
      unitPrice: map['unit_price'],
      totalAmount: map['total_amount'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_id': itemId,
      'user_id': userId,
      'transaction_type': transactionType,
      'quantity': quantity,
      'date': date,
      'notes': notes,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
    };
  }
}
