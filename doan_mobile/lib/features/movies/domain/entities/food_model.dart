class Food {
  final int id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String type;
  final int brandId;

  Food({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.type,
    required this.brandId,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: int.tryParse(json['FoodID']?.toString() ?? '') ?? 0,
      name: json['Name'] ?? '',
      description: json['description'] ?? '',
      price: double.parse(json['Price'].toString()),
      imageUrl: (json['ImageURL'] ?? json['imageUrl'] ?? json['image'] ?? json['Image'] ?? '') as String,
      type: json['Type'] ?? 'Combo',
      brandId: int.tryParse(json['brand_id']?.toString() ?? '') ?? 1,
    );
  }
}