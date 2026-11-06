import '../../../core/database/app_database.dart';
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
        COALESCE(SUM(total), 0) AS total,
        COALESCE(SUM(total_bs), 0) AS total_bs,
        COALESCE(SUM(subtotal), 0) AS subtotal,
        COALESCE(SUM(tax), 0) AS tax,
        COALESCE(SUM(discount), 0) AS discount
      FROM sales
      WHERE created_at >= ? AND created_at < ?
      ''',
      [start, end],
    );

    final totals = totalsResult.first;
    final count = (totals['count'] as num?)?.toInt() ?? 0;
    final totalUsd = (totals['total'] as num?)?.toDouble() ?? 0;
    final totalBs = (totals['total_bs'] as num?)?.toDouble() ?? 0;
    final subtotal = (totals['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (totals['tax'] as num?)?.toDouble() ?? 0;
    final discount = (totals['discount'] as num?)?.toDouble() ?? 0;

    final costResult = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(si.unit_cost * si.quantity), 0) AS cost
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at >= ? AND s.created_at < ?
      ''',
      [start, end],
    );
    final cost = ((costResult.first['cost'] as num?) ?? 0).toDouble();

    final methodRows = await db.rawQuery(
      '''
      SELECT payment_method,
             COALESCE(SUM(total), 0) AS total,
             COUNT(*) AS count
      FROM sales
      WHERE created_at >= ? AND created_at < ?
      GROUP BY payment_method
      ORDER BY total DESC
      ''',
      [start, end],
    );

    final productRows = await db.rawQuery(
      '''
      SELECT si.name,
             SUM(si.quantity) AS quantity,
             COALESCE(SUM(si.subtotal), 0) AS revenue,
             COALESCE(SUM((si.price - si.unit_cost) * si.quantity), 0) AS profit
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY si.name
      ORDER BY revenue DESC
      LIMIT 10
      ''',
      [start, end],
    );

    final dailyRows = await db.rawQuery(
      '''
      SELECT substr(created_at, 1, 10) AS day,
             COALESCE(SUM(total), 0) AS total,
             COUNT(*) AS count
      FROM sales
      WHERE created_at >= ? AND created_at < ?
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
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        cost: cost,
      ),
      byMethod: methodRows
          .map(
            (row) => ReportMethodTotal(
              method: (row['payment_method'] as String?) ?? '',
              totalUsd: ((row['total'] as num?) ?? 0).toDouble(),
              count: ((row['count'] as num?) ?? 0).toInt(),
            ),
          )
          .toList(),
      topProducts: productRows
          .map(
            (row) => ReportProductTotal(
              name: (row['name'] as String?) ?? '',
              quantity: ((row['quantity'] as num?) ?? 0).toInt(),
              revenue: ((row['revenue'] as num?) ?? 0).toDouble(),
              profit: ((row['profit'] as num?) ?? 0).toDouble(),
            ),
          )
          .toList(),
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
