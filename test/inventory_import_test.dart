import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novus/features/products/data/inventory_import.dart';

Uint8List _workbook(List<List<CellValue?>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  for (final row in rows) {
    sheet.appendRow(row);
  }
  return Uint8List.fromList(excel.save()!);
}

CellValue? _text(String? value) =>
    value == null ? null : TextCellValue(value);

void main() {
  final service = InventoryImportService();

  group('InventoryImportService.parse', () {
    test('lee encabezados con acentos y en otro orden', () {
      final bytes = _workbook([
        [
          _text('Categoría'),
          _text('Nombre'),
          _text('Precio'),
          _text('Stock'),
          _text('Código de barras'),
        ],
        [
          _text('Alimentos'),
          _text('Café molido 250 g'),
          _text('3,50'),
          IntCellValue(12),
          _text('7591234567890'),
        ],
      ]);

      final preview = service.parse(bytes);
      expect(preview.validCount, 1);
      expect(preview.errorCount, 0);

      final row = preview.valid.first;
      expect(row.name, 'Café molido 250 g');
      expect(row.category, 'Alimentos');
      expect(row.price, 3.5);
      expect(row.stock, 12);
      expect(row.barcode, '7591234567890');
    });

    test('detecta filas inválidas y duplicados', () {
      final bytes = _workbook([
        [
          _text('Nombre'),
          _text('Precio'),
          _text('Stock'),
          _text('SKU'),
        ],
        [_text(null), _text('1'), _text('2'), _text(null)],
        [_text('Producto A'), _text('abc'), _text('2'), _text('A-1')],
        [_text('Producto A'), _text('2'), _text('1,5'), _text('A-1')],
        [_text('Producto B'), _text('2'), _text('3'), _text('B-1')],
      ]);

      final preview = service.parse(bytes);
      expect(preview.validCount, 1);
      expect(preview.errorCount, 3);
      expect(
        preview.invalid.map((row) => row.error).join(' '),
        contains('Falta el nombre'),
      );
      expect(
        preview.invalid.map((row) => row.error).join(' '),
        contains('Precio inválido'),
      );
      expect(
        preview.invalid.map((row) => row.error).join(' '),
        contains('Stock inválido'),
      );
    });

    test('detecta duplicados por código de barras', () {
      final bytes = _workbook([
        [_text('Nombre'), _text('Código de barras')],
        [_text('Uno'), _text('123')],
        [_text('Dos'), _text('123')],
      ]);

      final preview = service.parse(bytes);
      expect(preview.validCount, 1);
      expect(preview.errorCount, 1);
      expect(preview.invalid.first.error, contains('Duplicado'));
    });

    test('exige la columna Nombre', () {
      final bytes = _workbook([
        [_text('Producto X'), _text('Precio')],
      ]);

      expect(
        () => service.parse(bytes),
        throwsA(
          isA<InventoryImportException>().having(
            (error) => error.message,
            'message',
            contains('Nombre'),
          ),
        ),
      );
    });
  });

  group('InventoryImportService.buildTemplate', () {
    test('la plantilla se puede volver a leer', () {
      final bytes = service.buildTemplate();
      final preview = service.parse(bytes);

      expect(preview.validCount, 3);
      expect(preview.errorCount, 0);
      expect(preview.rows.first.name, 'Café molido 250 g');
      expect(preview.rows.first.price, 3.5);
      expect(preview.rows.first.taxExempt, isFalse);
    });
  });
}
