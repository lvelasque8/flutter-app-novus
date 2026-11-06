import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../models/sale.dart';

class SaleLineInput {
  const SaleLineInput({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.taxExempt,
    this.unitCost = 0,
  });

  final String productId;
  final String name;
  final double price;
  final double unitCost;
  final int quantity;
  final bool taxExempt;

  double get subtotal => price * quantity;
}

class PaymentInput {
  const PaymentInput({
    required this.method,
    required this.amount,
    this.reference,
  });

  final String method;
  final double amount;
  final String? reference;
}

class SaleRepository {
  static const _uuid = Uuid();

  Future<Sale> createSale({
    required List<SaleLineInput> lines,
    required List<PaymentInput> payments,
    required double discount,
    required double ivaRate,
    required double rateBs,
    String? customerId,
    String? customerName,
  }) async {
    if (lines.isEmpty) {
      throw Exception('La venta no tiene productos');
    }
    if (payments.isEmpty) {
      throw Exception('La venta no tiene pagos');
    }
    if (payments.any((payment) => payment.amount <= 0)) {
      throw Exception('Cada pago debe ser mayor que cero');
    }

    final db = await AppDatabase.instance.database;
    final now = DateTime.now();

    final openSessionRows = await db.query(
      'cash_sessions',
      columns: ['id'],
      where: "status = 'abierta'",
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    final cashSessionId =
        openSessionRows.isEmpty ? null : openSessionRows.first['id'] as String;

    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.subtotal);
    final taxable = lines
        .where((line) => !line.taxExempt)
        .fold<double>(0, (sum, line) => sum + line.subtotal);
    final tax = taxable * (ivaRate / 100);
    final total =
        (subtotal - discount + tax).clamp(0, double.infinity).toDouble();
    final totalBs = total * rateBs;

    final paid = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    if ((paid - total).abs() > 0.009) {
      throw Exception(
        'Los pagos suman ${paid.toStringAsFixed(2)} y el total es '
        '${total.toStringAsFixed(2)}',
      );
    }

    final credit = payments
        .where((payment) => PaymentMethods.isCredit(payment.method))
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    final status = credit > 0 ? 'pendiente' : 'pagada';

    if (credit > 0 && (customerId == null || customerName == null)) {
      throw Exception('El fiado necesita un cliente');
    }

    final paymentMethod =
        payments.length == 1 ? payments.first.method : PaymentMethods.mixto;
    final reference =
        payments.length == 1 ? payments.first.reference : null;

    late Sale sale;
    final createdItems = <SaleItem>[];
    final createdPayments = <SalePayment>[];

    await db.transaction((txn) async {
      for (final line in lines) {
        final rows = await txn.query(
          'products',
          columns: ['name', 'stock'],
          where: 'id = ?',
          whereArgs: [line.productId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw Exception('Producto no encontrado: ${line.name}');
        }
        final stock = (rows.first['stock'] as num).toInt();
        if (stock < line.quantity) {
          throw Exception(
            'Stock insuficiente de ${line.name} (disponible: $stock)',
          );
        }
      }

      final countResult = await txn.rawQuery(
        'SELECT COUNT(*) AS total FROM sales',
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      final number = 'V-${(count + 1).toString().padLeft(6, '0')}';
      final saleId = _uuid.v4();

      await txn.insert('sales', {
        'id': saleId,
        'number': number,
        'customer_id': customerId,
        'customer_name': customerName,
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'total': total,
        'rate': rateBs,
        'total_bs': totalBs,
        'payment_method': paymentMethod,
        'reference': reference,
        'status': status,
        'cash_session_id': cashSessionId,
        'created_at': now.toIso8601String(),
      });

      for (final line in lines) {
        final itemId = _uuid.v4();
        await txn.insert('sale_items', {
          'id': itemId,
          'sale_id': saleId,
          'product_id': line.productId,
          'name': line.name,
          'price': line.price,
          'unit_cost': line.unitCost,
          'quantity': line.quantity,
          'subtotal': line.subtotal,
        });
        createdItems.add(
          SaleItem(
            id: itemId,
            saleId: saleId,
            productId: line.productId,
            name: line.name,
            price: line.price,
            unitCost: line.unitCost,
            quantity: line.quantity,
            subtotal: line.subtotal,
          ),
        );

        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ?, updated_at = ? WHERE id = ?',
          [line.quantity, now.toIso8601String(), line.productId],
        );

        await txn.insert('inventory_movements', {
          'id': _uuid.v4(),
          'product_id': line.productId,
          'type': 'venta',
          'quantity': -line.quantity,
          'reference': number,
          'created_at': now.toIso8601String(),
        });
      }

      for (final payment in payments) {
        final paymentId = _uuid.v4();
        final amountBs = payment.amount * rateBs;
        await txn.insert('payments', {
          'id': paymentId,
          'sale_id': saleId,
          'method': payment.method,
          'amount': payment.amount,
          'amount_bs': amountBs,
          'reference': payment.reference,
          'created_at': now.toIso8601String(),
        });
        createdPayments.add(
          SalePayment(
            id: paymentId,
            saleId: saleId,
            method: payment.method,
            amount: payment.amount,
            amountBs: amountBs,
            reference: payment.reference,
            createdAt: now,
          ),
        );
      }

      if (credit > 0) {
        await txn.insert('accounts', {
          'id': _uuid.v4(),
          'customer_id': customerId,
          'sale_id': saleId,
          'total': credit,
          'paid': 0,
          'status': 'pendiente',
          'created_at': now.toIso8601String(),
        });
      }

      sale = Sale(
        id: saleId,
        number: number,
        customerId: customerId,
        customerName: customerName,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        rate: rateBs,
        totalBs: totalBs,
        paymentMethod: paymentMethod,
        reference: reference,
        status: status,
        createdAt: now,
        items: createdItems,
        payments: createdPayments,
      );
    });

    return sale;
  }

  Future<List<Sale>> list({int limit = 100}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'sales',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((row) => Sale.fromMap(row)).toList();
  }

  Future<Sale?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final itemRows = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [id],
    );

    final paymentRows = await db.query(
      'payments',
      where: 'sale_id = ?',
      whereArgs: [id],
      orderBy: 'created_at ASC',
    );

    return Sale.fromMap(
      rows.first,
      items: itemRows.map(SaleItem.fromMap).toList(),
      payments: paymentRows.map(SalePayment.fromMap).toList(),
    );
  }

  Future<Sale?> getByNumber(String number) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'sales',
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return getById(rows.first['id'] as String);
  }

  Future<double> todayTotal() async {
    final db = await AppDatabase.instance.database;
    final start = DateTime.now();
    final startOfDay = DateTime(start.year, start.month, start.day);
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS total FROM sales WHERE created_at >= ?',
      [startOfDay.toIso8601String()],
    );
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  Future<int> todayCount() async {
    final db = await AppDatabase.instance.database;
    final start = DateTime.now();
    final startOfDay = DateTime(start.year, start.month, start.day);
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM sales WHERE created_at >= ?',
      [startOfDay.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
