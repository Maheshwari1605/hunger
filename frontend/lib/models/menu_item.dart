class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String sku;
  final bool available;
  final List<String> tags;
  final int? stock;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.sku,
    required this.available,
    required this.tags,
    required this.stock,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['_id'] as String,
        name: j['name'] as String,
        description: (j['description'] ?? '') as String,
        price: (j['price'] as num).toDouble(),
        category: j['category'] as String,
        sku: (j['sku'] ?? '') as String,
        available: (j['available'] ?? true) as bool,
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        stock: j['stock'] == null ? null : (j['stock'] as num).toInt(),
      );
}
