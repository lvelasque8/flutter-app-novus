import 'package:flutter_test/flutter_test.dart';
import 'package:novus/features/sales/data/sale_repository.dart';

void main() {
  group('SaleRepository.refundForLine', () {
    test('incluye IVA de forma proporcional', () {
      final refund = SaleRepository.refundForLine(
        price: 10,
        quantity: 1,
        saleSubtotal: 100,
        saleTotal: 116,
      );
      expect(refund, 11.6);
    });

    test('respeta descuentos', () {
      final refund = SaleRepository.refundForLine(
        price: 10,
        quantity: 2,
        saleSubtotal: 100,
        saleTotal: 90,
      );
      expect(refund, 18);
    });

    test('redondea a dos decimales', () {
      final refund = SaleRepository.refundForLine(
        price: 3.33,
        quantity: 1,
        saleSubtotal: 10,
        saleTotal: 11.6,
      );
      expect(refund, 3.86);
    });

    test('devuelve cero sin venta o sin cantidad', () {
      expect(
        SaleRepository.refundForLine(
          price: 10,
          quantity: 1,
          saleSubtotal: 0,
          saleTotal: 0,
        ),
        0,
      );
      expect(
        SaleRepository.refundForLine(
          price: 10,
          quantity: 0,
          saleSubtotal: 100,
          saleTotal: 116,
        ),
        0,
      );
    });
  });
}
