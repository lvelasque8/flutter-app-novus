import 'package:flutter_test/flutter_test.dart';
import 'package:novus/core/utils/texto_plural.dart';

void main() {
  group('TextoPlural.de', () {
    test('usa singular con 1', () {
      expect(TextoPlural.de(1, 'venta', 'ventas'), '1 venta');
      expect(TextoPlural.de(1, 'unidad', 'unidades'), '1 unidad');
      expect(
        TextoPlural.de(1, 'cuenta abierta', 'cuentas abiertas'),
        '1 cuenta abierta',
      );
    });

    test('usa plural con 0 y con más de 1', () {
      expect(TextoPlural.de(0, 'venta', 'ventas'), '0 ventas');
      expect(TextoPlural.de(4, 'venta', 'ventas'), '4 ventas');
      expect(TextoPlural.de(12, 'unidad', 'unidades'), '12 unidades');
    });
  });
}
