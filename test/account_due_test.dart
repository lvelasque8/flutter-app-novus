import 'package:flutter_test/flutter_test.dart';
import 'package:novus/features/accounts/models/account.dart';

Account _account({
  DateTime? dueDate,
  double total = 10,
  double paid = 0,
  String status = 'pendiente',
}) {
  return Account(
    id: 'a1',
    customerId: 'c1',
    saleId: 's1',
    total: total,
    paid: paid,
    status: status,
    createdAt: DateTime(2026, 11, 1),
    dueDate: dueDate,
  );
}

void main() {
  final now = DateTime(2026, 11, 25);

  group('Account vencimiento', () {
    test('sin fecha no vence', () {
      final account = _account();
      expect(account.daysUntilDueAt(now), isNull);
      expect(account.isOverdueAt(now), isFalse);
      expect(account.isDueSoonAt(now), isFalse);
    });

    test('detecta vencida y cuenta los días', () {
      final account = _account(dueDate: DateTime(2026, 11, 20));
      expect(account.daysUntilDueAt(now), -5);
      expect(account.isOverdueAt(now), isTrue);
      expect(account.overdueDaysAt(now), 5);
      expect(account.isDueSoonAt(now), isFalse);
    });

    test('detecta vence hoy y por vencer', () {
      final today = _account(dueDate: DateTime(2026, 11, 25));
      expect(today.daysUntilDueAt(now), 0);
      expect(today.isOverdueAt(now), isFalse);
      expect(today.isDueSoonAt(now), isTrue);

      final soon = _account(dueDate: DateTime(2026, 11, 28));
      expect(soon.daysUntilDueAt(now), 3);
      expect(soon.isDueSoonAt(now), isTrue);

      final later = _account(dueDate: DateTime(2026, 11, 29));
      expect(later.isDueSoonAt(now), isFalse);
    });

    test('una cuenta pagada no se considera vencida', () {
      final account = _account(
        dueDate: DateTime(2026, 11, 1),
        total: 10,
        paid: 10,
        status: 'pagada',
      );
      expect(account.isPaid, isTrue);
      expect(account.isOverdueAt(now), isFalse);
      expect(account.isDueSoonAt(now), isFalse);
    });
  });
}
