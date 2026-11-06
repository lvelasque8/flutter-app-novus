import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../models/product.dart';

class ProductRepository {
  static const _uuid = Uuid();

  Future<List<Product>> list({String query = ''}) async {
    final db = await AppDatabase.instance.database;
    final normalized = query.trim().toLowerCase();

    final rows = await db.query(
      'products',
      where: normalized.isEmpty
          ? 'active = 1'
          : "active = 1 AND (LOWER(name) LIKE ? OR LOWER(sku) LIKE ? OR LOWER(barcode) LIKE ? OR LOWER(category) LIKE ?)",
      whereArgs: normalized.isEmpty
          ? null
          : List.filled(4, '%$normalized%'),
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> findByBarcode(String code) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'products',
      where: 'active = 1 AND (barcode = ? OR sku = ?)',
      whereArgs: [code, code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<void> save(Product product) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> create({
    required String name,
    String sku = '',
    String barcode = '',
    String category = '',
    required double price,
    double cost = 0,
    int stock = 0,
    int minStock = 0,
    bool taxExempt = false,
  }) async {
    final now = DateTime.now();
    final product = Product(
      id: _uuid.v4(),
      name: name,
      sku: sku,
      barcode: barcode,
      category: category,
      price: price,
      cost: cost,
      stock: stock,
      minStock: minStock,
      taxExempt: taxExempt,
      active: true,
      createdAt: now,
      updatedAt: now,
    );
    await save(product);
    if (stock != 0) {
      await _insertMovement(product.id, 'entrada', stock, 'Inventario inicial');
    }
  }

  Future<void> update(Product product) async {
    await save(product.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> deactivate(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'products',
      {'active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> adjustStock(
    String productId,
    int newStock, {
    String reason = 'Ajuste manual',
  }) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final current = (rows.first['stock'] as num).toInt();
      final delta = newStock - current;
      if (delta == 0) return;
      await txn.update(
        'products',
        {
          'stock': newStock,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [productId],
      );
      await txn.insert('inventory_movements', {
        'id': _uuid.v4(),
        'product_id': productId,
        'type': 'ajuste',
        'quantity': delta,
        'reference': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<int> lowStockCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM products '
      'WHERE active = 1 AND stock > 0 AND stock <= min_stock',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> outOfStockCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM products WHERE active = 1 AND stock <= 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> _insertMovement(
    String productId,
    String type,
    int quantity,
    String reference,
  ) async {
    final db = await AppDatabase.instance.database;
    await db.insert('inventory_movements', {
      'id': _uuid.v4(),
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'reference': reference,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
