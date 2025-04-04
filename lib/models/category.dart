class Category {
  final int? id;
  final String name;
  final String? description;
  final String? color; // Store color as a hex string

  Category({
    this.id,
    required this.name,
    this.description,
    this.color,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      color: map['color'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
    };
  }
}