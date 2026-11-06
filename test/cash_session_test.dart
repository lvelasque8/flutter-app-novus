import 'package:flutter_test/flutter_test.dart';
import 'package:novus/features/cash/models/cash_session.dart';

void main() {
  test('CashSession sobrevive el viaje a mapa y vuelta', () {
    final session = CashSession(
      id: 'abc',
      openedAt: DateTime(2026, 11, 6, 9),
      openingBs: 100,
      openingUsd: 5,
      status: 'abierta',
      notes: 'Turno mañana',
    );

    final restored = CashSession.fromMap(session.toMap());

    expect(restored.id, 'abc');
    expect(restored.openingBs, 100);
    expect(restored.openingUsd, 5);
    expect(restored.isOpen, isTrue);
    expect(restored.notes, 'Turno mañana');
  });

  test('El resumen calcula el efectivo esperado', () {
    final session = CashSession(
      id: 'abc',
      openedAt: DateTime(2026, 11, 6),
      openingBs: 100,
      openingUsd: 5,
      status: 'abierta',
    );

    final summary = CashSessionSummary(
      session: session,
      salesCount: 3,
      salesTotalUsd: 50,
      salesTotalBs: 1800,
      salesTax: 7,
      salesDiscount: 2,
      salesByMethod: {
        'efectivo_bs': 20,
        'efectivo_usd': 30,
      },
      abonosByMethod: {
        'efectivo_bs': 10,
        'efectivo_usd': 2,
      },
      expectedBs: 150,
      expectedUsd: 37,
    );

    expect(summary.cashSalesUsd, 30);
    expect(summary.cashSalesBs, 20);
    expect(summary.cashAbonosUsd, 2);
    expect(summary.cashAbonosBs, 10);
    expect(summary.expectedBs, 150);
    expect(summary.expectedUsd, 37);
  });
}
