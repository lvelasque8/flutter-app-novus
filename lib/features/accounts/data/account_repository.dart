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
  }) async {
    final db = await AppDatabase.instance.database;
    final customer = Customer(
      id: _uuid.v4(),
      name: name,
      document: document,
      phone: phone,
      address: address,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await db.insert('customers', customer.toMap());
    return customer;
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<List<AccountSummary>> listSummaries() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT c.*, SUM(a.total - a.paid) AS balance, COUNT(a.id) AS open_accounts
      FROM customers c
      INNER JOIN accounts a ON a.customer_id = c.id
      WHERE a.status != 'pagada' AND (a.total - a.paid) > 0.005
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
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Account.fromMap).toList();
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
      final newPaid = (account.paid + amount).clamp(0, account.total);
      final settled = (account.total - newPaid) <= 0.005;

      await txn.insert('account_payments', {
        'id': _uuid.v4(),
        'account_id': accountId,
        'amount': amount,
        'method': method,
        'note': note,
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
      WHERE status != 'pagada'
    ''');
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  Future<int> openAccountsCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM accounts WHERE status != 'pagada'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
