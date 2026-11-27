import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../models/product.dart';
import 'default_categories.dart';
import 'inventory_import.dart';

class InventoryImportResult {
  const InventoryImportResult({
    required this.created,
    required this.updated,
    required this.unchanged,
    required this.skipped,
    required this.adjustments,
  });

  final int created;
  final int updated;
  final int unchanged;
  final int skipped;
  final int adjustments;
}

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

  /// Categorías para los atajos: las sugeridas primero y luego las que ya
  /// usaste en el inventario.
  Future<List<String>> categories() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT category FROM products "
      "WHERE active = 1 AND TRIM(category) != '' "
      "ORDER BY category COLLATE NOCASE ASC",
    );

    final used = rows
        .map((row) => ((row['category'] as String?) ?? '').trim())
        .where((category) => category.isNotEmpty)
        .toList();

    final result = <String>[];
    for (final category in [...defaultProductCategories, ...used]) {
      final exists = result.any(
        (item) => item.toLowerCase() == category.toLowerCase(),
      );
      if (!exists) result.add(category);
    }
    return result;
  }

  /// Busca otro producto con el mismo código de barras.
  Future<Product?> findByBarcodeOnly(
    String barcode, {
    String? excludeId,
  }) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'products',
      where: excludeId == null
          ? 'LOWER(barcode) = ?'
          : 'LOWER(barcode) = ? AND id != ?',
      whereArgs: [
        code.toLowerCase(),
        if (excludeId != null) excludeId,
      ],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  /// Busca otro producto con el mismo SKU.
  Future<Product?> findBySku(String sku, {String? excludeId}) async {
    final code = sku.trim();
    if (code.isEmpty) return null;
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'products',
      where: excludeId == null
          ? 'LOWER(sku) = ?'
          : 'LOWER(sku) = ? AND id != ?',
      whereArgs: [
        code.toLowerCase(),
        if (excludeId != null) excludeId,
      ],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  /// Genera un SKU corto a partir de la categoría, por ejemplo `ALI-0007`.
  Future<String> generateSku(String category) async {
    final prefix = _categoryPrefix(category);
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'products',
      columns: ['sku'],
      where: 'sku LIKE ?',
      whereArgs: ['$prefix-%'],
    );

    var max = 0;
    for (final row in rows) {
      final sku = (row['sku'] as String?) ?? '';
      final suffix = sku.split('-').last;
      final number = int.tryParse(suffix);
      if (number != null && number > max) max = number;
    }

    return '$prefix-${(max + 1).toString().padLeft(4, '0')}';
  }

  String _categoryPrefix(String category) {
    final normalized = _withoutAccents(category.trim().toUpperCase());
    final letters = normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (letters.isEmpty) return 'PRO';
    return letters.substring(0, letters.length >= 3 ? 3 : letters.length);
  }

  String _withoutAccents(String value) {
    const replacements = {
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ñ': 'N',
    };
    var result = value;
    replacements.forEach((key, letter) {
      result = result.replaceAll(key, letter);
    });
    return result;
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
    await _insertMovementTxn(db, productId, type, quantity, reference);
  }

  Future<void> _insertMovementTxn(
    DatabaseExecutor txn,
    String productId,
    String type,
    int quantity,
    String reference,
  ) async {
    await txn.insert('inventory_movements', {
      'id': _uuid.v4(),
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'reference': reference,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Aplica las filas válidas de un Excel.
  ///
  /// Los productos existentes se buscan por código de barras, SKU o nombre.
  /// El stock se fija al valor indicado y se registra el ajuste para mantener
  /// la trazabilidad.
  Future<InventoryImportResult> importRows(
    List<InventoryImportRow> rows, {
    bool updateExisting = true,
  }) async {
    final db = await AppDatabase.instance.database;
    final stamp = DateTime.now().toIso8601String();
    var created = 0;
    var updated = 0;
    var unchanged = 0;
    var skipped = 0;
    var adjustments = 0;

    await db.transaction((txn) async {
      final existingRows = await txn.query('products');
      final byBarcode = <String, Map<String, Object?>>{};
      final bySku = <String, Map<String, Object?>>{};
      final byName = <String, Map<String, Object?>>{};
      final usedSkus = <String>{};

      for (final row in existingRows) {
        final barcode = ((row['barcode'] as String?) ?? '').toLowerCase();
        final sku = ((row['sku'] as String?) ?? '').toLowerCase();
        final name = ((row['name'] as String?) ?? '').toLowerCase();
        if (barcode.isNotEmpty) byBarcode[barcode] = row;
        if (sku.isNotEmpty) bySku[sku] = row;
        if (name.isNotEmpty) byName[name] = row;
        final rawSku = ((row['sku'] as String?) ?? '').trim();
        if (rawSku.isNotEmpty) usedSkus.add(rawSku.toUpperCase());
      }

      Map<String, Object?>? matchFor(InventoryImportRow row) {
        final barcode = (row.barcode ?? '').toLowerCase();
        if (barcode.isNotEmpty) {
          final match = byBarcode[barcode];
          if (match != null) return match;
        }
        final sku = (row.sku ?? '').toLowerCase();
        if (sku.isNotEmpty) {
          final match = bySku[sku];
          if (match != null) return match;
        }
        final name = (row.name ?? '').toLowerCase();
        if (name.isNotEmpty) return byName[name];
        return null;
      }

      for (final row in rows.where((row) => row.isValid)) {
        final match = matchFor(row);

        if (match == null) {
          final name = (row.name ?? '').trim();
          if (name.isEmpty) {
            skipped++;
            continue;
          }

          final id = _uuid.v4();
          final sku = (row.sku ?? '').trim().isEmpty
              ? _nextSku(row.category ?? '', usedSkus)
              : row.sku!.trim();
          final stock = row.stock ?? 0;
          final createdRow = <String, Object?>{
            'id': id,
            'name': name,
            'sku': sku,
            'barcode': (row.barcode ?? '').trim(),
            'category': (row.category ?? '').trim(),
            'price': row.price ?? 0,
            'cost': row.cost ?? 0,
            'stock': stock,
            'min_stock': row.minStock ?? 0,
            'tax_exempt': (row.taxExempt ?? false) ? 1 : 0,
            'active': 1,
            'created_at': stamp,
            'updated_at': stamp,
          };
          await txn.insert('products', createdRow);

          if (stock != 0) {
            await _insertMovementTxn(
              txn,
              id,
              'entrada',
              stock,
              'Importación Excel',
            );
          }

          final barcode = (createdRow['barcode'] as String).toLowerCase();
          if (barcode.isNotEmpty) byBarcode[barcode] = createdRow;
          if (sku.isNotEmpty) bySku[sku.toLowerCase()] = createdRow;
          byName[name.toLowerCase()] = createdRow;
          created++;
          continue;
        }

        if (!updateExisting) {
          skipped++;
          continue;
        }

        final id = match['id'] as String;
        final currentStock = ((match['stock'] as num?) ?? 0).toInt();
        final newStock = row.stock ?? currentStock;
        final delta = newStock - currentStock;

        final updates = <String, Object?>{
          'updated_at': stamp,
          'stock': newStock,
        };
        if (row.name != null) updates['name'] = row.name;
        if (row.category != null) updates['category'] = row.category;
        if (row.barcode != null) updates['barcode'] = row.barcode;
        if (row.sku != null) updates['sku'] = row.sku;
        if (row.price != null) updates['price'] = row.price;
        if (row.cost != null) updates['cost'] = row.cost;
        if (row.minStock != null) updates['min_stock'] = row.minStock;
        if (row.taxExempt != null) {
          updates['tax_exempt'] = row.taxExempt! ? 1 : 0;
        }

        await txn.update(
          'products',
          updates,
          where: 'id = ?',
          whereArgs: [id],
        );
        match.addAll(updates);

        if (delta != 0) {
          await _insertMovementTxn(
            txn,
            id,
            'ajuste',
            delta,
            'Importación Excel',
          );
          adjustments++;
        } else {
          unchanged++;
        }
        updated++;
      }
    });

    return InventoryImportResult(
      created: created,
      updated: updated,
      unchanged: unchanged,
      skipped: skipped,
      adjustments: adjustments,
    );
  }

  String _nextSku(String category, Set<String> used) {
    final prefix = _categoryPrefix(category);
    var number = 1;
    while (true) {
      final sku = '$prefix-${number.toString().padLeft(4, '0')}';
      if (!used.contains(sku.toUpperCase())) {
        used.add(sku.toUpperCase());
        return sku;
      }
      number++;
    }
  }
}
