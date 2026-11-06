class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.category,
    required this.price,
    required this.cost,
    required this.stock,
    required this.minStock,
    required this.taxExempt,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String sku;
  final String barcode;
  final String category;

  /// Precio de venta en dólares.
  final double price;

  /// Costo en dólares.
  final double cost;

  final int stock;
  final int minStock;
  final bool taxExempt;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get lowStock => stock > 0 && stock <= minStock;
  bool get outOfStock => stock <= 0;
  bool get hasStock => stock > 0;

  Product copyWith({
    String? name,
    String? sku,
    String? barcode,
    String? category,
    double? price,
    double? cost,
    int? stock,
    int? minStock,
    bool? taxExempt,
    bool? active,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      taxExempt: taxExempt ?? this.taxExempt,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'category': category,
      'price': price,
      'cost': cost,
      'stock': stock,
      'min_stock': minStock,
      'tax_exempt': taxExempt ? 1 : 0,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      sku: (map['sku'] as String?) ?? '',
      barcode: (map['barcode'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      price: ((map['price'] as num?) ?? 0).toDouble(),
      cost: ((map['cost'] as num?) ?? 0).toDouble(),
      stock: ((map['stock'] as num?) ?? 0).toInt(),
      minStock: ((map['min_stock'] as num?) ?? 0).toInt(),
      taxExempt: ((map['tax_exempt'] as num?) ?? 0) == 1,
      active: ((map['active'] as num?) ?? 1) == 1,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
