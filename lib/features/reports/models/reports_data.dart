import 'package:intl/intl.dart';

class ReportRange {
  const ReportRange({required this.start, required this.end});

  /// Inicio inclusive.
  final DateTime start;

  /// Fin exclusivo.
  final DateTime end;

  factory ReportRange.today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return ReportRange(start: start, end: start.add(const Duration(days: 1)));
  }

  factory ReportRange.last7Days() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return ReportRange(start: end.subtract(const Duration(days: 7)), end: end);
  }

  factory ReportRange.thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return ReportRange(start: start, end: end);
  }

  int get days => end.difference(start).inDays.clamp(1, 366);

  String get label {
    final formatter = DateFormat('dd/MM/yyyy');
    return '${formatter.format(start)} — '
        '${formatter.format(end.subtract(const Duration(days: 1)))}';
  }

  @override
  bool operator ==(Object other) {
    return other is ReportRange && other.start == start && other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

class ReportSummary {
  const ReportSummary({
    required this.salesCount,
    required this.totalUsd,
    required this.totalBs,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.cost,
  });

  final int salesCount;
  final double totalUsd;
  final double totalBs;
  final double subtotal;
  final double tax;
  final double discount;
  final double cost;

  double get profit => subtotal - discount - cost;
  double get averageTicket =>
      salesCount == 0 ? 0 : totalUsd / salesCount;
}

class ReportMethodTotal {
  const ReportMethodTotal({
    required this.method,
    required this.totalUsd,
    required this.count,
  });

  final String method;
  final double totalUsd;
  final int count;
}

class ReportProductTotal {
  const ReportProductTotal({
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.profit,
  });

  final String name;
  final int quantity;
  final double revenue;
  final double profit;
}

class ReportDailyTotal {
  const ReportDailyTotal({
    required this.date,
    required this.totalUsd,
    required this.count,
  });

  final DateTime date;
  final double totalUsd;
  final int count;
}

class ReportsData {
  const ReportsData({
    required this.range,
    required this.summary,
    required this.byMethod,
    required this.topProducts,
    required this.daily,
  });

  final ReportRange range;
  final ReportSummary summary;
  final List<ReportMethodTotal> byMethod;
  final List<ReportProductTotal> topProducts;
  final List<ReportDailyTotal> daily;
}
