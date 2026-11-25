import '../../../core/database/app_database.dart';
import '../../sales/models/sale.dart';
import '../models/reports_data.dart';

class ReportsRepository {
  Future<ReportsData> get(ReportRange range) async {
    final db = await AppDatabase.instance.database;
    final start = range.start.toIso8601String();
    final end = range.end.toIso8601String();

    final totalsResult = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS count,
        COALESCE(SUM(total - refunded), 0) AS total,
        COALESCE(SUM(total_bs - refunded_bs), 0) AS total_bs,
        COALESCE(SUM(refunded), 0) AS refunded,
        COALESCE(SUM(subtotal), 0) AS subtotal,
        COALESCE(SUM(tax), 0) AS tax,
        COALESCE(SUM(discount), 0) AS discount
      FROM sales
      WHERE created_at >= ? AND created_at < ? AND cancelled = 0
      ''',
      [start, end],
    );

    final totals = totalsResult.first;
    final count = (totals['count'] as num?)?.toInt() ?? 0;
    final totalUsd = (totals['total'] as num?)?.toDouble() ?? 0;
    final totalBs = (totals['total_bs'] as num?)?.toDouble() ?? 0;
    final refunded = (totals['refunded'] as num?)?.toDouble() ?? 0;
    final subtotal = (totals['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (totals['tax'] as num?)?.toDouble() ?? 0;
    final discount = (totals['discount'] as num?)?.toDouble() ?? 0;

    final costResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(si.unit_cost * si.quantity), 0) AS cost
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at >= ? AND s.created_at < ? AND s.cancelled = 0
      ''',
      [start, end],
    );
    var cost = ((costResult.first['cost'] as num?) ?? 0).toDouble();

    final returnedCostResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(si.unit_cost * sri.quantity), 0) AS cost
      FROM sale_return_items sri
      INNER JOIN sale_returns sr ON sr.id = sri.return_id
      INNER JOIN sale_items si ON si.id = sri.sale_item_id
      INNER JOIN sales s ON s.id = sr.sale_id
      WHERE s.created_at >= ? AND s.created_at < ? AND s.cancelled = 0
      ''',
      [start, end],
    );
    cost -= ((returnedCostResult.first['cost'] as num?) ?? 0).toDouble();

    final methodRows = await db.rawQuery(
      '''
      SELECT p.method,
             COALESCE(SUM(p.amount), 0) AS total,
             COALESCE(SUM(p.amount_bs), 0) AS total_bs,
             COUNT(DISTINCT p.sale_id) AS count
      FROM payments p
      INNER JOIN sales s ON s.id = p.sale_id
      WHERE s.created_at >= ? AND s.created_at < ? AND s.cancelled = 0
      GROUP BY p.method
      ORDER BY total DESC
      ''',
      [start, end],
    );

    final returnMethodRows = await db.rawQuery(
      '''
      SELECT sr.method,
             COALESCE(SUM(sr.total), 0) AS total,
             COALESCE(SUM(sr.total_bs), 0) AS total_bs
      FROM sale_returns sr
      INNER JOIN sales s ON s.id = sr.sale_id
      WHERE s.created_at >= ? AND s.created_at < ? AND s.cancelled = 0
      GROUP BY sr.method
      ''',
      [start, end],
    );

    final methods = <String, ReportMethodTotal>{};
    for (final row in methodRows) {
      final method = (row['method'] as String?) ?? '';
      methods[method] = ReportMethodTotal(
        method: method,
        totalUsd: ((row['total'] as num?) ?? 0).toDouble(),
        totalBs: ((row['total_bs'] as num?) ?? 0).toDouble(),
        count: ((row['count'] as num?) ?? 0).toInt(),
      );
    }
    for (final row in returnMethodRows) {
      final rawMethod = (row['method'] as String?) ?? '';
      // Las devoluciones de un fiado se descuentan del fiado, no de un método
      // de pago que nunca cobró ese dinero.
      final method = rawMethod == PaymentMethods.devolucion
          ? PaymentMethods.fiado
          : rawMethod;
      final current = methods[method];
      final returnedUsd = ((row['total'] as num?) ?? 0).toDouble();
      final returnedBs = ((row['total_bs'] as num?) ?? 0).toDouble();
      methods[method] = ReportMethodTotal(
        method: method,
        totalUsd: (current?.totalUsd ?? 0) - returnedUsd,
        totalBs: (current?.totalBs ?? 0) - returnedBs,
        count: current?.count ?? 0,
      );
    }
    final methodTotals = methods.values
        .where(
          (item) =>
              item.totalUsd.abs() > 0.005 || item.totalBs.abs() > 0.005,
        )
        .toList()
      ..sort((a, b) => b.totalUsd.compareTo(a.totalUsd));

    final productRows = await db.rawQuery(
      '''
      SELECT si.name,
             SUM(si.quantity) AS quantity,
             COALESCE(SUM(si.subtotal), 0) AS revenue,
             COALESCE(SUM((si.price - si.unit_cost) * si.quantity), 0) AS profit
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at >= ? AND s.created_at < ? AND s.cancelled = 0
      GROUP BY si.name
      ORDER BY revenue DESC
      ''',
      [start, end],
    );

    final returnedProductRows = await db.rawQuery(
      '''
      SELECT sri.name,
             SUM(sri.quantity) AS quantity,
             COALESCE(SUM(sri.subtotal), 0) AS revenue,
             COALESCE(SUM(sri.subtotal - si.unit_cost * sri.quantity), 0)
               AS profit
      FROM sale_return_items sri
      INNER JOIN sale_returns sr ON sr.id = sri.return_id
      INNER JOIN sale_items si ON si.id = sri.sale_item_id
      INNER JOIN sales s ON s.id = sr.sale_id
      WHERE s.created_at >= ? AND s.created_at < ? AND s.cancelled = 0
      GROUP BY sri.name
      ''',
      [start, end],
    );

    final products = <String, ReportProductTotal>{
      for (final row in productRows)
        ((row['name'] as String?) ?? ''): ReportProductTotal(
          name: (row['name'] as String?) ?? '',
          quantity: ((row['quantity'] as num?) ?? 0).toInt(),
          revenue: ((row['revenue'] as num?) ?? 0).toDouble(),
          profit: ((row['profit'] as num?) ?? 0).toDouble(),
        ),
    };
    for (final row in returnedProductRows) {
      final name = (row['name'] as String?) ?? '';
      final current = products[name];
      products[name] = ReportProductTotal(
        name: name,
        quantity:
            (current?.quantity ?? 0) - ((row['quantity'] as num?) ?? 0).toInt(),
        revenue:
            (current?.revenue ?? 0) - ((row['revenue'] as num?) ?? 0).toDouble(),
        profit:
            (current?.profit ?? 0) - ((row['profit'] as num?) ?? 0).toDouble(),
      );
    }
    final topProducts = products.values
        .where((item) => item.quantity > 0)
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final dailyRows = await db.rawQuery(
      '''
      SELECT substr(created_at, 1, 10) AS day,
             COALESCE(SUM(total - refunded), 0) AS total,
             COUNT(*) AS count
      FROM sales
      WHERE created_at >= ? AND created_at < ? AND cancelled = 0
      GROUP BY day
      ORDER BY day ASC
      ''',
      [start, end],
    );

    return ReportsData(
      range: range,
      summary: ReportSummary(
        salesCount: count,
        totalUsd: totalUsd,
        totalBs: totalBs,
        refunded: refunded,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        cost: cost,
      ),
      byMethod: methodTotals,
      topProducts: topProducts.take(10).toList(),
      daily: dailyRows.map((row) {
        final day = DateTime.tryParse((row['day'] as String?) ?? '');
        return ReportDailyTotal(
          date: day ?? range.start,
          totalUsd: ((row['total'] as num?) ?? 0).toDouble(),
          count: ((row['count'] as num?) ?? 0).toInt(),
        );
      }).toList(),
    );
  }
}
