import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../sales/models/sale.dart';
import '../models/cash_session.dart';

class CashRepository {
  static const _uuid = Uuid();

  Future<CashSession?> getOpenSession() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'cash_sessions',
      where: "status = 'abierta'",
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CashSession.fromMap(rows.first);
  }

  Future<String?> getOpenSessionId() async {
    return (await getOpenSession())?.id;
  }

  Future<CashSession> openSession({
    required double openingBs,
    required double openingUsd,
    String notes = '',
  }) async {
    final existing = await getOpenSession();
    if (existing != null) {
      throw Exception('Ya hay una caja abierta');
    }

    final db = await AppDatabase.instance.database;
    final session = CashSession(
      id: _uuid.v4(),
      openedAt: DateTime.now(),
      openingBs: openingBs,
      openingUsd: openingUsd,
      notes: notes.isEmpty ? null : notes,
      status: 'abierta',
    );
    await db.insert('cash_sessions', session.toMap());
    return session;
  }

  Future<CashSessionSummary> summary(CashSession session) async {
    final db = await AppDatabase.instance.database;

    final totals = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS count,
        COALESCE(SUM(subtotal), 0) AS subtotal,
        COALESCE(SUM(tax), 0) AS tax,
        COALESCE(SUM(discount), 0) AS discount,
        COALESCE(SUM(total), 0) AS total,
        COALESCE(SUM(total_bs), 0) AS total_bs
      FROM sales
      WHERE cash_session_id = ?
      ''',
      [session.id],
    );

    final row = totals.first;
    final salesCount = (row['count'] as num?)?.toInt() ?? 0;
    final salesTotalUsd = (row['total'] as num?)?.toDouble() ?? 0;
    final salesTotalBs = (row['total_bs'] as num?)?.toDouble() ?? 0;
    final tax = (row['tax'] as num?)?.toDouble() ?? 0;
    final discount = (row['discount'] as num?)?.toDouble() ?? 0;

    final salesByMethod = <String, double>{};
    final salesBsByMethod = <String, double>{};
    final paymentRows = await db.rawQuery(
      '''
      SELECT p.method,
             COALESCE(SUM(p.amount), 0) AS total,
             COALESCE(SUM(p.amount_bs), 0) AS total_bs
      FROM payments p
      INNER JOIN sales s ON s.id = p.sale_id
      WHERE s.cash_session_id = ?
      GROUP BY p.method
      ''',
      [session.id],
    );
    for (final methodRow in paymentRows) {
      final method = methodRow['method'] as String;
      salesByMethod[method] =
          ((methodRow['total'] as num?) ?? 0).toDouble();
      salesBsByMethod[method] =
          ((methodRow['total_bs'] as num?) ?? 0).toDouble();
    }

    final abonosByMethod = <String, double>{};
    final abonoRows = await db.rawQuery(
      '''
      SELECT method, COALESCE(SUM(amount), 0) AS total
      FROM account_payments
      WHERE cash_session_id = ?
      GROUP BY method
      ''',
      [session.id],
    );
    for (final methodRow in abonoRows) {
      abonosByMethod[methodRow['method'] as String] =
          ((methodRow['total'] as num?) ?? 0).toDouble();
    }

    final cashSalesBs = salesBsByMethod[PaymentMethods.efectivoBs] ?? 0;
    final cashSalesUsd = salesByMethod[PaymentMethods.efectivoUsd] ?? 0;

    final cashAbonosBsResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_bs), 0) AS total
      FROM account_payments
      WHERE cash_session_id = ? AND method = ?
      ''',
      [session.id, PaymentMethods.efectivoBs],
    );
    final cashAbonosBs =
        ((cashAbonosBsResult.first['total'] as num?) ?? 0).toDouble();
    final cashAbonosUsd = abonosByMethod[PaymentMethods.efectivoUsd] ?? 0;

    return CashSessionSummary(
      session: session,
      salesCount: salesCount,
      salesTotalUsd: salesTotalUsd,
      salesTotalBs: salesTotalBs,
      salesTax: tax,
      salesDiscount: discount,
      salesByMethod: salesByMethod,
      abonosByMethod: abonosByMethod,
      expectedBs: session.openingBs + cashSalesBs + cashAbonosBs,
      expectedUsd: session.openingUsd + cashSalesUsd + cashAbonosUsd,
    );
  }

  Future<CashSession> closeSession({
    required double countedBs,
    required double countedUsd,
    String notes = '',
  }) async {
    final session = await getOpenSession();
    if (session == null) {
      throw Exception('No hay una caja abierta');
    }

    final summaryData = await summary(session);
    final differenceBs = countedBs - summaryData.expectedBs;
    final differenceUsd = countedUsd - summaryData.expectedUsd;
    final db = await AppDatabase.instance.database;
    final closed = CashSession(
      id: session.id,
      openedAt: session.openedAt,
      closedAt: DateTime.now(),
      openingBs: session.openingBs,
      openingUsd: session.openingUsd,
      countedBs: countedBs,
      countedUsd: countedUsd,
      expectedBs: summaryData.expectedBs,
      expectedUsd: summaryData.expectedUsd,
      differenceBs: differenceBs,
      differenceUsd: differenceUsd,
      notes: notes.isEmpty ? session.notes : notes,
      status: 'cerrada',
    );

    await db.update(
      'cash_sessions',
      closed.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
    return closed;
  }

  Future<List<CashSession>> history({int limit = 30}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'cash_sessions',
      orderBy: 'opened_at DESC',
      limit: limit,
    );
    return rows.map(CashSession.fromMap).toList();
  }

  Future<int> salesCountForSession(String sessionId) async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM sales WHERE cash_session_id = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
