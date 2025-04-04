// Item model
class Item {
  final int? id;
  final String name;
  final String? description;
  final int quantity;
  final double price;
  final int? categoryId; 
  final int? userId; 
  final String? imagePath;
  final String? barcode;
  final String createdAt;
  final String updatedAt;

  Item({
    this.id,
    required this.name,
    this.description,
    required this.quantity,
    required this.price,
    this.categoryId, 
    this.userId,
    this.imagePath,
    this.barcode,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'quantity': quantity,
      'price': price,
      'category_id': categoryId, 
      'user_id': userId,
      'image_path': imagePath,
      'barcode': barcode,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      quantity: map['quantity'],
      price: map['price']?.toDouble() ?? 0.0,
      categoryId: map['category_id'],
      userId: map['user_id'],
      imagePath: map['image_path'],
      barcode: map['barcode'],
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
    );
  }

  Item copyWith({
    int? id,
    String? name,
    String? description,
    int? quantity,
    double? price,
    int? categoryId,
    int? userId,
    String? category,
    String? imagePath,
    String? barcode,
    String? createdAt,
    String? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      userId: userId ?? this.userId,
      imagePath: imagePath ?? this.imagePath,
      barcode: barcode ?? this.barcode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}