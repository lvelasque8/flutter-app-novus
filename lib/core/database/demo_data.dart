import '../../features/products/data/product_repository.dart';

/// Datos de demostración para probar la app en la tablet sin digitar todo.
class DemoData {
  DemoData._();

  static Future<void> seedProducts() async {
    final repo = ProductRepository();
    final existing = await repo.list();
    if (existing.isNotEmpty) return;

    final items = <Map<String, Object?>>[
      {
        'name': 'Harina PAN 1 kg',
        'category': 'Alimentos',
        'sku': 'PAN-001',
        'price': 1.20,
        'cost': 0.95,
        'stock': 40,
        'min': 8,
      },
      {
        'name': 'Arroz blanco 1 kg',
        'category': 'Alimentos',
        'sku': 'ARR-001',
        'price': 1.10,
        'cost': 0.85,
        'stock': 35,
        'min': 8,
      },
      {
        'name': 'Aceite de girasol 1 L',
        'category': 'Alimentos',
        'sku': 'ACE-001',
        'price': 2.50,
        'cost': 2.10,
        'stock': 24,
        'min': 6,
      },
      {
        'name': 'Café molido 250 g',
        'category': 'Alimentos',
        'sku': 'CAF-001',
        'price': 3.00,
        'cost': 2.40,
        'stock': 18,
        'min': 5,
      },
      {
        'name': 'Azúcar 1 kg',
        'category': 'Alimentos',
        'sku': 'AZU-001',
        'price': 1.30,
        'cost': 1.00,
        'stock': 30,
        'min': 6,
      },
      {
        'name': 'Leche en polvo 900 g',
        'category': 'Lácteos',
        'sku': 'LEC-001',
        'price': 4.80,
        'cost': 4.00,
        'stock': 15,
        'min': 4,
      },
      {
        'name': 'Queso blanco 500 g',
        'category': 'Lácteos',
        'sku': 'QUE-001',
        'price': 4.50,
        'cost': 3.70,
        'stock': 10,
        'min': 3,
      },
      {
        'name': 'Refresco 2 L',
        'category': 'Bebidas',
        'sku': 'REF-001',
        'price': 1.60,
        'cost': 1.20,
        'stock': 48,
        'min': 12,
      },
    ];

    for (final item in items) {
      await repo.create(
        name: item['name'] as String,
        category: item['category'] as String,
        sku: item['sku'] as String,
        price: (item['price'] as num).toDouble(),
        cost: (item['cost'] as num).toDouble(),
        stock: item['stock'] as int,
        minStock: item['min'] as int,
      );
    }
  }
}
