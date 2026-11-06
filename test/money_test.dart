import 'package:flutter_test/flutter_test.dart';
import 'package:novus/core/utils/money.dart';

void main() {
  group('Money.parse', () {
    test('interpreta coma decimal venezolana', () {
      expect(Money.parse('36,50'), closeTo(36.50, 0.001));
    });

    test('interpreta punto decimal', () {
      expect(Money.parse('36.50'), closeTo(36.50, 0.001));
    });

    test('interpreta separador de miles y coma decimal', () {
      expect(Money.parse('1.234,56'), closeTo(1234.56, 0.001));
    });

    test('ignora símbolos de moneda', () {
      expect(Money.parse(r'$ 10,00'), closeTo(10, 0.001));
      expect(Money.parse('Bs 25,75'), closeTo(25.75, 0.001));
    });

    test('devuelve cero para texto inválido', () {
      expect(Money.parse('abc'), 0);
    });
  });

  group('Money.parseInt', () {
    test('extrae enteros', () {
      expect(Money.parseInt('12 uds'), 12);
    });
  });
}
