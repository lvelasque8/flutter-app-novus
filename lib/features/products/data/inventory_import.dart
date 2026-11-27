import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

/// Una fila leída del Excel, ya normalizada.
class InventoryImportRow {
  const InventoryImportRow({
    required this.line,
    this.name,
    this.category,
    this.barcode,
    this.sku,
    this.price,
    this.cost,
    this.stock,
    this.minStock,
    this.taxExempt,
    this.error,
  });

  /// Número de fila en el Excel (incluye el encabezado).
  final int line;
  final String? name;
  final String? category;
  final String? barcode;
  final String? sku;
  final double? price;
  final double? cost;
  final int? stock;
  final int? minStock;
  final bool? taxExempt;
  final String? error;

  bool get isValid => error == null;
}

class InventoryImportPreview {
  const InventoryImportPreview(this.rows);

  final List<InventoryImportRow> rows;

  List<InventoryImportRow> get valid =>
      rows.where((row) => row.isValid).toList();

  List<InventoryImportRow> get invalid =>
      rows.where((row) => !row.isValid).toList();

  int get validCount => valid.length;
  int get errorCount => rows.length - validCount;
}

class InventoryImportException implements Exception {
  const InventoryImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lee el Excel del inventario y arma la plantilla de ejemplo.
class InventoryImportService {
  static const List<String> columns = [
    'Nombre',
    'Categoría',
    'Código de barras',
    'SKU',
    'Precio',
    'Costo',
    'Stock',
    'Stock mínimo',
    'Exento de IVA',
  ];

  static const Map<String, String> _aliases = {
    'nombre': 'name',
    'producto': 'name',
    'nombre del producto': 'name',
    'descripcion': 'name',
    'categoria': 'category',
    'rubro': 'category',
    'codigo de barras': 'barcode',
    'codigo de barra': 'barcode',
    'barras': 'barcode',
    'ean': 'barcode',
    'upc': 'barcode',
    'sku': 'sku',
    'codigo interno': 'sku',
    'codigo': 'sku',
    'precio': 'price',
    'precio usd': 'price',
    'precio de venta': 'price',
    'pvp': 'price',
    'costo': 'cost',
    'costo usd': 'cost',
    'costo de compra': 'cost',
    'stock': 'stock',
    'cantidad': 'stock',
    'existencia': 'stock',
    'existencias': 'stock',
    'stock minimo': 'minStock',
    'minimo': 'minStock',
    'stock min': 'minStock',
    'exento': 'taxExempt',
    'exento de iva': 'taxExempt',
    'iva exento': 'taxExempt',
    'exento iva': 'taxExempt',
  };

  InventoryImportPreview parse(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const InventoryImportException('El archivo está vacío');
    }

    late final Excel excel;
    try {
      excel = _decode(bytes);
    } catch (_) {
      throw const InventoryImportException(
        'No se pudo leer el archivo. Debe ser un Excel .xlsx',
      );
    }

    if (excel.tables.isEmpty) {
      throw const InventoryImportException('El archivo no tiene hojas');
    }

    Sheet? sheet;
    var headerIndex = -1;
    var mapping = <String, int>{};

    for (final candidate in excel.tables.values) {
      final rows = candidate.rows;
      final limit = rows.length < 15 ? rows.length : 15;
      for (var i = 0; i < limit; i++) {
        final found = _mapHeader(rows[i]);
        if (found.containsKey('name')) {
          sheet = candidate;
          headerIndex = i;
          mapping = found;
          break;
        }
      }
      if (sheet != null) break;
    }

    if (sheet == null) {
      throw const InventoryImportException(
        'No se encontró la columna "Nombre". Usa la plantilla de Novus.',
      );
    }

    final rows = sheet.rows;

    final result = <InventoryImportRow>[];
    final seen = <String, int>{};

    for (var i = headerIndex + 1; i < rows.length; i++) {
      final cells = rows[i];
      if (cells.isEmpty) continue;

      String? value(String field) {
        final index = mapping[field];
        if (index == null || index >= cells.length) return null;
        final text = _cellText(cells[index]).trim();
        return text.isEmpty ? null : text;
      }

      final name = value('name');
      final category = value('category');
      final barcode = value('barcode');
      final sku = value('sku');
      final priceText = value('price');
      final costText = value('cost');
      final stockText = value('stock');
      final minStockText = value('minStock');
      final taxText = value('taxExempt');

      if (name == null &&
          category == null &&
          barcode == null &&
          sku == null &&
          priceText == null &&
          costText == null &&
          stockText == null &&
          minStockText == null &&
          taxText == null) {
        continue;
      }

      String? error;
      if (name == null && barcode == null && sku == null) {
        error = 'Falta el nombre o un código para identificarlo';
      }

      final price = _parseDecimal(priceText);
      if (priceText != null && price == null) {
        error ??= 'Precio inválido';
      }
      final cost = _parseDecimal(costText);
      if (costText != null && cost == null) {
        error ??= 'Costo inválido';
      }
      final stock = _parseInteger(stockText);
      if (stockText != null && stock == null) {
        error ??= 'Stock inválido (usa un número entero)';
      }
      final minStock = _parseInteger(minStockText);
      if (minStockText != null && minStock == null) {
        error ??= 'Stock mínimo inválido';
      }

      final key = _rowKey(barcode, sku, name);
      if (key != null) {
        final previous = seen[key];
        if (previous != null) {
          error ??= 'Duplicado en el archivo (fila $previous)';
        } else {
          seen[key] = i + 1;
        }
      }

      result.add(
        InventoryImportRow(
          line: i + 1,
          name: name,
          category: category,
          barcode: barcode,
          sku: sku,
          price: price,
          cost: cost,
          stock: stock,
          minStock: minStock,
          taxExempt: _parseBool(taxText),
          error: error,
        ),
      );
    }

    if (result.isEmpty) {
      throw const InventoryImportException(
        'La hoja no tiene filas de productos debajo del encabezado',
      );
    }

    return InventoryImportPreview(result);
  }

  /// Decodifica el Excel; si trae formatos de celda con identificadores
  /// reservados, limpia `styles.xml` y reintenta.
  Excel _decode(Uint8List bytes) {
    try {
      return Excel.decodeBytes(bytes);
    } catch (_) {
      final sanitized = _sanitizeStyles(bytes);
      if (sanitized == null) rethrow;
      return Excel.decodeBytes(sanitized);
    }
  }

  Uint8List? _sanitizeStyles(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? styles;
      for (final file in archive.files) {
        if (file.name == 'xl/styles.xml') {
          styles = file;
          break;
        }
      }
      if (styles == null) return null;

      final content = utf8.decode(
        List<int>.from(styles.content as List),
        allowMalformed: true,
      );
      final cleaned = content.replaceAllMapped(
        RegExp(r'<numFmt\b[^>]*/>'),
        (match) {
          final value = match.group(0)!;
          final id = int.tryParse(
            RegExp(r'numFmtId="(\d+)"').firstMatch(value)?.group(1) ?? '',
          );
          return (id != null && id < 164) ? '' : value;
        },
      );
      if (cleaned == content) return null;

      final encoded = Uint8List.fromList(utf8.encode(cleaned));
      final rebuilt = Archive();
      for (final file in archive.files) {
        if (file.name == 'xl/styles.xml') continue;
        rebuilt.addFile(file);
      }
      rebuilt.addFile(
        ArchiveFile('xl/styles.xml', encoded.length, encoded),
      );
      final zipped = ZipEncoder().encode(rebuilt);
      if (zipped == null) return null;
      return Uint8List.fromList(zipped);
    } catch (_) {
      return null;
    }
  }

  Map<String, int> _mapHeader(List<Data?> cells) {    final mapping = <String, int>{};
    for (var i = 0; i < cells.length; i++) {
      final text = _normalize(_cellText(cells[i]));
      if (text.isEmpty) continue;
      final field = _aliases[text];
      if (field != null && !mapping.containsKey(field)) {
        mapping[field] = i;
      }
    }
    return mapping;
  }

  String _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    if (value is TextCellValue) return value.value.text ?? '';
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value ? 'Sí' : 'No';
    if (value is FormulaCellValue) return value.formula;
    return value.toString();
  }

  String _normalize(String value) {
    var text = value.toLowerCase().trim();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    replacements.forEach((key, letter) {
      text = text.replaceAll(key, letter);
    });
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  double? _parseDecimal(String? raw) {
    if (raw == null) return null;
    var text = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (text.isEmpty) return null;
    final negative = text.startsWith('-');
    text = text.replaceAll('-', '');
    if (text.contains(',') && text.contains('.')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else if (text.contains(',')) {
      text = text.replaceAll(',', '.');
    }
    final value = double.tryParse(text);
    if (value == null) return null;
    return negative ? null : value;
  }

  int? _parseInteger(String? raw) {
    if (raw == null) return null;
    final text = raw.trim().replaceAll(' ', '');
    if (text.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(text)) return int.tryParse(text);
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(text)) {
      return int.tryParse(text.replaceAll('.', ''));
    }
    return null;
  }

  bool? _parseBool(String? raw) {
    if (raw == null) return null;
    final text = _normalize(raw);
    if (text.isEmpty) return null;
    if (const ['si', 's', '1', 'x', 'true', 'yes', 'exento'].contains(text)) {
      return true;
    }
    if (const ['no', 'n', '0', 'false'].contains(text)) return false;
    return null;
  }

  String? _rowKey(String? barcode, String? sku, String? name) {
    if (barcode != null && barcode.isNotEmpty) {
      return 'barcode:${barcode.toLowerCase()}';
    }
    if (sku != null && sku.isNotEmpty) return 'sku:${sku.toLowerCase()}';
    if (name != null && name.isNotEmpty) return 'name:${name.toLowerCase()}';
    return null;
  }

  /// Genera la plantilla `.xlsx` con encabezados y ejemplos.
  Uint8List buildTemplate() {
    final excel = Excel.createExcel();
    final sheet = excel['Inventario'];
    excel.setDefaultSheet('Inventario');
    excel.delete('Sheet1');

    sheet.appendRow([
      for (final column in columns) TextCellValue(column),
    ]);

    final examples = [
      ['Café molido 250 g', 'Alimentos', '7591234567890', 'ALI-0001', 3.50, 2.10, 12, 3, 'No'],
      ['Agua mineral 600 ml', 'Bebidas', '', 'BEB-0001', 1.00, 0.45, 24, 6, 'No'],
      ['Queso blanco 500 g', 'Lácteos', '', '', 4.50, 3.20, 8, 2, 'Sí'],
    ];

    for (final row in examples) {
      sheet.appendRow([
        TextCellValue(row[0] as String),
        TextCellValue(row[1] as String),
        TextCellValue(row[2] as String),
        TextCellValue(row[3] as String),
        DoubleCellValue(row[4] as double),
        DoubleCellValue(row[5] as double),
        IntCellValue(row[6] as int),
        IntCellValue(row[7] as int),
        TextCellValue(row[8] as String),
      ]);
    }

    final help = excel['Instrucciones'];
    for (final line in const [
      'Cómo usar esta plantilla',
      '',
      '1. Escribe un producto por fila debajo de los ejemplos.',
      '2. "Nombre" es obligatorio para productos nuevos.',
      '3. Para actualizar un producto existente basta con el código de barras, el SKU o el nombre.',
      '4. Si dejas Precio, Costo o Stock vacíos, ese dato no se modifica.',
      '5. Stock debe ser un número entero. No uses decimales.',
      '6. En "Exento de IVA" escribe Sí o No.',
      '7. Puedes borrar las filas de ejemplo antes de importar.',
      '8. Guarda el archivo como Excel (.xlsx).',
    ]) {
      help.appendRow([TextCellValue(line)]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw const InventoryImportException(
        'No se pudo generar la plantilla',
      );
    }
    return Uint8List.fromList(bytes);
  }
}
