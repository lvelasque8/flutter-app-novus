import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/accounts/models/account.dart';
import '../../features/cash/models/cash_session.dart';
import '../../features/products/models/product.dart';
import '../../features/sales/models/sale.dart';

class AdminData {
  const AdminData({
    required this.businessName,
    required this.lastSyncAt,
    required this.products,
    required this.customers,
    required this.sales,
    required this.accounts,
    required this.accountPayments,
    required this.cashSessions,
    required this.settings,
  });

  final String businessName;
  final DateTime? lastSyncAt;
  final List<Product> products;
  final List<Customer> customers;
  final List<Sale> sales;
  final List<Account> accounts;
  final List<AccountPayment> accountPayments;
  final List<CashSession> cashSessions;
  final Map<String, String> settings;

  double get receivable => accounts
      .where((account) => !account.cancelled && !account.isPaid)
      .fold<double>(0, (sum, account) => sum + account.balance);

  List<Account> get openAccounts => accounts
      .where((account) => !account.cancelled && !account.isPaid)
      .toList();

  int get overdueCount => openAccounts
      .where((account) => account.isOverdue)
      .length;

  double get overdueAmount => openAccounts
      .where((account) => account.isOverdue)
      .fold<double>(0, (sum, account) => sum + account.balance);

  List<Product> get lowStock => products
      .where((product) => product.active && product.stock <= product.minStock)
      .toList();

  Customer? customerById(String? id) {
    if (id == null) return null;
    for (final customer in customers) {
      if (customer.id == id) return customer;
    }
    return null;
  }

  List<AccountPayment> paymentsFor(String accountId) {
    return accountPayments
        .where((payment) => payment.accountId == accountId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

class AdminRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<AdminData> load() async {
    final business = await _client
        .from('businesses')
        .select('name')
        .limit(1)
        .maybeSingle();

    final settingsRows = await _client
        .from('business_settings')
        .select('key, value');

    final device = await _client
        .from('sync_devices')
        .select('last_sync_at')
        .order('last_sync_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final productRows = await _client
        .from('products')
        .select()
        .order('name', ascending: true);

    final customerRows = await _client
        .from('customers')
        .select()
        .order('name', ascending: true);

    final accountRows = await _client
        .from('accounts')
        .select()
        .order('created_at', ascending: false);

    final accountPaymentRows = await _client
        .from('account_payments')
        .select()
        .order('created_at', ascending: false);

    final cashRows = await _client
        .from('cash_sessions')
        .select()
        .order('opened_at', ascending: false)
        .limit(100);

    final saleRows = await _client
        .from('sales')
        .select()
        .order('created_at', ascending: false)
        .limit(600);

    final sales = await _buildSales(saleRows);

    return AdminData(
      businessName: (business?['name'] as String?) ?? 'Mi negocio',
      lastSyncAt: DateTime.tryParse(
        (device?['last_sync_at'] as String?) ?? '',
      ),
      products: productRows
          .map((row) => Product.fromMap(_map(row)))
          .toList(),
      customers: customerRows
          .map((row) => Customer.fromMap(_map(row)))
          .toList(),
      sales: sales,
      accounts: accountRows
          .map((row) => Account.fromMap(_map(row)))
          .toList(),
      accountPayments: accountPaymentRows
          .map((row) => AccountPayment.fromMap(_map(row)))
          .toList(),
      cashSessions: cashRows
          .map((row) => CashSession.fromMap(_map(row)))
          .toList(),
      settings: {
        for (final row in settingsRows)
          (row['key'] as String): (row['value'] as String?) ?? '',
      },
    );
  }

  Future<List<Sale>> _buildSales(List<dynamic> saleRows) async {
    final ids = [
      for (final row in saleRows) (row['id'] as String),
    ];
    if (ids.isEmpty) return const [];

    final itemRows = await _selectIn('sale_items', 'sale_id', ids);
    final paymentRows = await _selectIn('payments', 'sale_id', ids);
    final returnRows = await _selectIn('sale_returns', 'sale_id', ids);
    final returnIds = [
      for (final row in returnRows) (row['id'] as String),
    ];
    final returnItemRows = await _selectIn(
      'sale_return_items',
      'return_id',
      returnIds,
    );

    final itemsBySale = <String, List<SaleItem>>{};
    for (final row in itemRows) {
      final map = _map(row);
      itemsBySale
          .putIfAbsent(map['sale_id'] as String, () => [])
          .add(SaleItem.fromMap(map));
    }

    final paymentsBySale = <String, List<SalePayment>>{};
    for (final row in paymentRows) {
      final map = _map(row);
      paymentsBySale
          .putIfAbsent(map['sale_id'] as String, () => [])
          .add(SalePayment.fromMap(map));
    }

    final returnItemsByReturn = <String, List<SaleReturnItem>>{};
    for (final row in returnItemRows) {
      final map = _map(row);
      returnItemsByReturn
          .putIfAbsent(map['return_id'] as String, () => [])
          .add(SaleReturnItem.fromMap(map));
    }

    final returnsBySale = <String, List<SaleReturn>>{};
    for (final row in returnRows) {
      final map = _map(row);
      final id = map['id'] as String;
      returnsBySale
          .putIfAbsent(map['sale_id'] as String, () => [])
          .add(
            SaleReturn.fromMap(
              map,
              items: returnItemsByReturn[id] ?? const [],
            ),
          );
    }

    return [
      for (final row in saleRows)
        Sale.fromMap(
          _map(row),
          items: itemsBySale[row['id']] ?? const [],
          payments: paymentsBySale[row['id']] ?? const [],
          returns: returnsBySale[row['id']] ?? const [],
        ),
    ];
  }

  Future<List<dynamic>> _selectIn(
    String table,
    String column,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final result = <dynamic>[];
    for (var start = 0; start < ids.length; start += 80) {
      final end = math.min(start + 80, ids.length);
      final chunk = ids.sublist(start, end);
      final rows = await _client
          .from(table)
          .select()
          .inFilter(column, chunk);
      result.addAll(rows);
    }
    return result;
  }

  Map<String, Object?> _map(dynamic row) {
    return Map<String, Object?>.from(row as Map);
  }
}
