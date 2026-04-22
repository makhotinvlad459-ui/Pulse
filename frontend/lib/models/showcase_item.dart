class ShowcaseItem {
  final int id;
  final int companyId;
  final String name;
  final double price;
  final int sortOrder;
  final String? imageUrl;
  final String? recipe;
  final int? categoryId;        // добавлено
  final DateTime createdAt;
  final DateTime updatedAt;

  ShowcaseItem({
    required this.id,
    required this.companyId,
    required this.name,
    required this.price,
    required this.sortOrder,
    this.imageUrl,
    this.recipe,
    this.categoryId,            // добавлено
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShowcaseItem.fromJson(Map<String, dynamic> json) {
    return ShowcaseItem(
      id: json['id'],
      companyId: json['company_id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      sortOrder: json['sort_order'],
      imageUrl: json['image_url'],
      recipe: json['recipe'],
      categoryId: json['category_id'],  // добавлено
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'name': name,
    'price': price,
    'sort_order': sortOrder,
    'image_url': imageUrl,
    'recipe': recipe,
    'category_id': categoryId,   // добавлено
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}