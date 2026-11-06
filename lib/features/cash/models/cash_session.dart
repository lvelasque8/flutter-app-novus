class CashSession {
  const CashSession({
    required this.id,
    required this.openedAt,
    required this.openingBs,
    required this.openingUsd,
    required this.status,
    this.closedAt,
    this.countedBs,
    this.countedUsd,
    this.expectedBs,
    this.expectedUsd,
    this.differenceBs,
    this.differenceUsd,
    this.notes,
  });

  final String id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingBs;
  final double openingUsd;
  final double? countedBs;
  final double? countedUsd;
  final double? expectedBs;
  final double? expectedUsd;
  final double? differenceBs;
  final double? differenceUsd;
  final String? notes;
  final String status;

  bool get isOpen => status == 'abierta';

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'opening_bs': openingBs,
      'opening_usd': openingUsd,
      'counted_bs': countedBs,
      'counted_usd': countedUsd,
      'expected_bs': expectedBs,
      'expected_usd': expectedUsd,
      'difference_bs': differenceBs,
      'difference_usd': differenceUsd,
      'notes': notes,
      'status': status,
    };
  }

  factory CashSession.fromMap(Map<String, Object?> map) {
    return CashSession(
      id: map['id'] as String,
      openedAt: DateTime.tryParse((map['opened_at'] as String?) ?? '') ??
          DateTime.now(),
      closedAt: DateTime.tryParse((map['closed_at'] as String?) ?? ''),
      openingBs: ((map['opening_bs'] as num?) ?? 0).toDouble(),
      openingUsd: ((map['opening_usd'] as num?) ?? 0).toDouble(),
      countedBs: (map['counted_bs'] as num?)?.toDouble(),
      countedUsd: (map['counted_usd'] as num?)?.toDouble(),
      expectedBs: (map['expected_bs'] as num?)?.toDouble(),
      expectedUsd: (map['expected_usd'] as num?)?.toDouble(),
      differenceBs: (map['difference_bs'] as num?)?.toDouble(),
      differenceUsd: (map['difference_usd'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      status: (map['status'] as String?) ?? 'abierta',
    );
  }
}

class CashSessionSummary {
  const CashSessionSummary({
    required this.session,
    required this.salesCount,
    required this.salesTotalUsd,
    required this.salesTotalBs,
    required this.salesTax,
    required this.salesDiscount,
    required this.salesByMethod,
    required this.abonosByMethod,
    required this.expectedBs,
    required this.expectedUsd,
  });

  final CashSession session;
  final int salesCount;
  final double salesTotalUsd;
  final double salesTotalBs;
  final double salesTax;
  final double salesDiscount;

  /// Montos en dólares por forma de pago.
  final Map<String, double> salesByMethod;

  /// Abonos en dólares por forma de pago.
  final Map<String, double> abonosByMethod;

  final double expectedBs;
  final double expectedUsd;

  double get cashSalesUsd => salesByMethod['efectivo_usd'] ?? 0;
  double get cashSalesBs => salesByMethod['efectivo_bs'] ?? 0;
  double get cashAbonosUsd => abonosByMethod['efectivo_usd'] ?? 0;
  double get cashAbonosBs => abonosByMethod['efectivo_bs'] ?? 0;
}
