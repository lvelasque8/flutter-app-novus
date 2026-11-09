import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../models/account.dart';

class AccountRepository {
  static const _uuid = Uuid();

  Future<List<Customer>> listCustomers({String query = ''}) async {
    final db = await AppDatabase.instance.database;
    final normalized = query.trim().toLowerCase();
    final rows = await db.query(
      'customers',
      where: normalized.isEmpty
          ? null
          : 'LOWER(name) LIKE ? OR LOWER(document) LIKE ? OR LOWER(phone) LIKE ?',
      whereArgs: normalized.isEmpty
          ? null
          : List.filled(3, '%$normalized%'),
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer> createCustomer({
    required String name,
    String document = '',
    String phone = '',
    String address = '',
    String notes = '',
    double creditLimit = 0,
  }) async {
    final normalizedName = name.trim();
    final normalizedDocument = document.trim();
    final normalizedPhone = phone.trim();

    await _ensureUnique(document: normalizedDocument);

    final db = await AppDatabase.instance.database;
    final customer = Customer(
      id: _uuid.v4(),
      name: normalizedName,
      document: normalizedDocument,
      phone: normalizedPhone,
      address: address.trim(),
      notes: notes.trim(),
      createdAt: DateTime.now(),
      creditLimit: creditLimit,
    );
    await db.insert('customers', customer.toMap());
    return customer;
  }

  Future<void> updateCustomer(Customer customer) async {
    await _ensureUnique(
      document: customer.document,
      excludeId: customer.id,
    );

    final db = await AppDatabase.instance.database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> _ensureUnique({
    required String document,
    String? excludeId,
  }) async {
    final normalized = _normalizeDocument(document);
    if (normalized.isEmpty) return;

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'customers',
      columns: ['id', 'document'],
      where: excludeId == null ? null : 'id != ?',
      whereArgs: excludeId == null ? null : [excludeId],
    );

    for (final row in rows) {
      final other = _normalizeDocument(
        (row['document'] as String?) ?? '',
      );
      if (other == normalized) {
        throw Exception('Ya existe un cliente con esa cédula o RIF');
      }
    }
  }

  String _normalizeDocument(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^0-9a-z]'), '');
  }

  Future<List<AccountSummary>> listSummaries() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT c.*, SUM(a.total - a.paid) AS balance, COUNT(a.id) AS open_accounts
      FROM customers c
      INNER JOIN accounts a ON a.customer_id = c.id
      WHERE a.status != 'pagada' AND a.cancelled = 0
        AND (a.total - a.paid) > 0.005
      GROUP BY c.id
      ORDER BY balance DESC, c.name COLLATE NOCASE ASC
    ''');

    return rows.map((row) {
      return AccountSummary(
        customer: Customer.fromMap(row),
        balance: ((row['balance'] as num?) ?? 0).toDouble(),
        openAccounts: ((row['open_accounts'] as num?) ?? 0).toInt(),
      );
    }).toList();
  }

  Future<List<Account>> accountsForCustomer(String customerId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'customer_id = ? AND cancelled = 0',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Account.fromMap).toList();
  }

  /// Saldo fiado pendiente del cliente (solo cuentas activas).
  Future<double> balanceForCustomer(String customerId) async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total - paid), 0) AS balance
      FROM accounts
      WHERE customer_id = ? AND cancelled = 0 AND status != 'pagada'
      ''',
      [customerId],
    );
    return ((result.first['balance'] as num?) ?? 0).toDouble();
  }

  Future<List<AccountPayment>> paymentsForAccount(String accountId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'account_payments',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'created_at DESC',
    );
    return rows.map(AccountPayment.fromMap).toList();
  }

  Future<void> addPayment({
    required String accountId,
    required double amount,
    required String method,
    String note = '',
  }) async {
    if (amount <= 0) {
      throw Exception('El abono debe ser mayor que cero');
    }

    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw Exception('Cuenta no encontrada');
      }

      final account = Account.fromMap(rows.first);
      if (account.cancelled) {
        throw Exception('Esta cuenta fue anulada');
      }
      final newPaid =
          (account.paid + amount).clamp(0, account.total).toDouble();
      final settled = (account.total - newPaid) <= 0.005;

      final rateRows = await txn.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['rate_bs'],
        limit: 1,
      );
      final rate = rateRows.isEmpty
          ? 0.0
          : double.tryParse(rateRows.first['value'] as String? ?? '') ?? 0.0;

      final sessionRows = await txn.query(
        'cash_sessions',
        columns: ['id'],
        where: "status = 'abierta'",
        orderBy: 'opened_at DESC',
        limit: 1,
      );
      final cashSessionId =
          sessionRows.isEmpty ? null : sessionRows.first['id'] as String;

      await txn.insert('account_payments', {
        'id': _uuid.v4(),
        'account_id': accountId,
        'amount': amount,
        'amount_bs': amount * rate,
        'method': method,
        'note': note,
        'cash_session_id': cashSessionId,
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.update(
        'accounts',
        {
          'paid': newPaid,
          'status': settled ? 'pagada' : 'pendiente',
        },
        where: 'id = ?',
        whereArgs: [accountId],
      );

      if (settled && account.saleId != null) {
        await txn.update(
          'sales',
          {'status': 'pagada'},
          where: 'id = ?',
          whereArgs: [account.saleId],
        );
      }
    });
  }

  Future<double> totalReceivable() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(total - paid), 0) AS total
      FROM accounts
      WHERE status != 'pagada' AND cancelled = 0
    ''');
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  Future<int> openAccountsCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM accounts "
      "WHERE status != 'pagada' AND cancelled = 0",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
