import 'package:flutter_test/flutter_test.dart';
import 'package:novus/features/reports/models/reports_data.dart';

void main() {
  test('ReportRange de hoy cubre el día completo', () {
    final range = ReportRange.today();
    expect(range.start.hour, 0);
    expect(range.start.minute, 0);
    expect(range.end.difference(range.start).inDays, 1);
  });

  test('ReportRange de 7 días tiene una semana', () {
    final range = ReportRange.last7Days();
    expect(range.end.difference(range.start).inDays, 7);
  });

  test('ReportRange se puede comparar como clave de provider', () {
    final a = ReportRange(
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 2),
    );
    final b = ReportRange(
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 2),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('La utilidad se calcula sobre subtotal menos costo', () {
    const summary = ReportSummary(
      salesCount: 2,
      totalUsd: 100,
      totalBs: 3600,
      subtotal: 90,
      tax: 10,
      discount: 5,
      cost: 50,
    );
    expect(summary.profit, 35);
    expect(summary.averageTicket, 50);
  });
}
