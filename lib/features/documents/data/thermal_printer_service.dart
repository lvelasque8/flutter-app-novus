import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/database/app_database.dart';
import '../../sales/models/sale.dart';
import '../../settings/models/business_settings.dart';

/// Configuración de la impresora térmica guardada en el dispositivo.
class PrinterSettings {
  const PrinterSettings({
    this.name = '',
    this.address = '',
    this.paperMm = 58,
  });

  final String name;

  /// Dirección MAC del Bluetooth.
  final String address;

  /// Ancho del papel: 58 o 80 mm.
  final int paperMm;

  bool get isConfigured => address.trim().isNotEmpty;

  PrinterSettings copyWith({
    String? name,
    String? address,
    int? paperMm,
  }) {
    return PrinterSettings(
      name: name ?? this.name,
      address: address ?? this.address,
      paperMm: paperMm ?? this.paperMm,
    );
  }
}

/// Impresión directa en impresoras térmicas Bluetooth (ESC/POS).
class ThermalPrinterService {
  static const _keyName = 'printer_name';
  static const _keyAddress = 'printer_address';
  static const _keyPaper = 'printer_paper_mm';

  /// Impresoras Bluetooth ya emparejadas en el teléfono/tablet.
  Future<List<BluetoothInfo>> pairedDevices() {
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> isBluetoothOn() => PrintBluetoothThermal.bluetoothEnabled;

  Future<bool> ensurePermission() async {
    try {
      // Este getter solicita los permisos de Bluetooth en Android 12+.
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  Future<PrinterSettings> load() async {
    final name = await AppDatabase.instance.getSetting(_keyName);
    final address = await AppDatabase.instance.getSetting(_keyAddress);
    final paper =
        int.tryParse(await AppDatabase.instance.getSetting(_keyPaper)) ?? 58;
    return PrinterSettings(
      name: name,
      address: address,
      paperMm: paper == 80 ? 80 : 58,
    );
  }

  Future<void> save(PrinterSettings printer) async {
    await AppDatabase.instance.setSettings({
      _keyName: printer.name,
      _keyAddress: printer.address,
      _keyPaper: printer.paperMm.toString(),
    });
  }

  Future<bool> connect(String address) async {
    if (address.trim().isEmpty) return false;
    if (await PrintBluetoothThermal.connectionStatus) {
      // Ya hay una conexión abierta; se reutiliza.
      return true;
    }
    return PrintBluetoothThermal.connect(macPrinterAddress: address);
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {
      // Sin conexión activa: nada que hacer.
    }
  }

  /// Imprime el ticket de una venta. Lanza una excepción con un mensaje
  /// entendible si algo falla.
  Future<void> printSale({
    required Sale sale,
    required BusinessSettings settings,
    required PrinterSettings printer,
  }) async {
    if (!printer.isConfigured) {
      throw Exception('Primero configura la impresora en Ajustes');
    }
    final bytes = await buildSaleTicket(
      sale: sale,
      settings: settings,
      printer: printer,
    );
    await _send(printer.address, bytes);
  }

  /// Imprime un ticket de prueba con los datos del negocio.
  Future<void> printTest({
    required BusinessSettings settings,
    required PrinterSettings printer,
  }) async {
    if (!printer.isConfigured) {
      throw Exception('Primero configura la impresora en Ajustes');
    }
    final bytes = await buildTestTicket(
      settings: settings,
      printer: printer,
    );
    await _send(printer.address, bytes);
  }

  Future<void> _send(String address, List<int> bytes) async {
    if (!await ensurePermission()) {
      throw Exception(
        'Novus necesita permiso de Bluetooth. Actívalo en Ajustes de Android.',
      );
    }
    if (!await isBluetoothOn()) {
      throw Exception('Activa el Bluetooth de la tablet');
    }
    if (!await connect(address)) {
      throw Exception(
        'No se pudo conectar a la impresora. Verifica que esté encendida '
        'y emparejada.',
      );
    }
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      throw Exception('La impresora no respondió. Intenta de nuevo.');
    }
  }

  Future<Generator> _generator(PrinterSettings printer) async {
    final profile = await CapabilityProfile.load();
    return Generator(
      printer.paperMm == 80 ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );
  }

  Future<List<int>> buildSaleTicket({
    required Sale sale,
    required BusinessSettings settings,
    required PrinterSettings printer,
  }) async {
    final generator = await _generator(printer);
    final rate = sale.rate > 0 ? sale.rate : settings.rateBs;
    final totalBs = sale.totalBs > 0 ? sale.totalBs : sale.total * rate;

    var bytes = <int>[];
    bytes += _header(generator, settings);
    bytes += generator.text(
      'NOTA DE ENTREGA',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      '${sale.number} · ${_date(sale.createdAt)}',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();
    bytes += generator.text(
      'Cliente: ${sale.customerName ?? 'Consumidor final'}',
    );
    bytes += generator.emptyLines(1);

    bytes += generator.row([
      PosColumn(
        text: 'Cant',
        width: 2,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'Producto',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'Total',
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);

    for (final item in sale.items) {
      bytes += generator.row([
        PosColumn(text: '${item.quantity}', width: 2),
        PosColumn(text: item.name, width: 6),
        PosColumn(
          text: _usd(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += _row(generator, 'Subtotal', _usd(sale.subtotal));
    if (sale.discount > 0) {
      bytes += _row(generator, 'Descuento', '-${_usd(sale.discount)}');
    }
    if (sale.tax > 0) {
      bytes += _row(
        generator,
        'IVA (${settings.ivaRate.toStringAsFixed(0)}%)',
        _usd(sale.tax),
      );
    }
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL USD',
        width: 7,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: _usd(sale.total),
        width: 5,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);
    if (rate > 0) {
      bytes += _row(generator, 'Tasa BCV', '${_number(rate)} Bs/USD');
      bytes += _row(generator, 'TOTAL Bs', '${_number(totalBs)} Bs');
    }

    bytes += generator.emptyLines(1);
    if (sale.payments.isEmpty) {
      bytes += generator.text(
        'Forma de pago: ${_paymentLabel(sale.paymentMethod)}',
      );
      if (sale.reference != null && sale.reference!.isNotEmpty) {
        bytes += generator.text('Referencia: ${sale.reference}');
      }
    } else {
      for (final payment in sale.payments) {
        bytes += generator.text(
          '${_paymentLabel(payment.method)}: ${_usd(payment.amount)}'
          '${payment.reference != null && payment.reference!.isNotEmpty ? ' · ${payment.reference}' : ''}',
        );
      }
    }

    bytes += generator.emptyLines(1);
    bytes += generator.hr();
    bytes += generator.text(
      'DOCUMENTO NO FISCAL',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Gracias por su compra',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();
    return bytes;
  }

  Future<List<int>> buildTestTicket({
    required BusinessSettings settings,
    required PrinterSettings printer,
  }) async {
    final generator = await _generator(printer);
    var bytes = <int>[];
    bytes += _header(generator, settings);
    bytes += generator.hr();
    bytes += generator.text(
      'PRUEBA DE IMPRESION',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.emptyLines(1);
    bytes += generator.text(
      'Si puedes leer este ticket, la impresora esta lista.',
    );
    bytes += generator.emptyLines(1);
    bytes += _row(generator, 'Papel', '${printer.paperMm} mm');
    bytes += _row(generator, 'Equipo', printer.name);
    bytes += _row(generator, 'Direccion', printer.address);
    bytes += _row(generator, 'Fecha', _date(DateTime.now()));
    bytes += generator.emptyLines(1);
    bytes += generator.text(
      'DOCUMENTO NO FISCAL',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();
    return bytes;
  }

  List<int> _header(Generator generator, BusinessSettings settings) {
    final styles = const PosStyles(
      align: PosAlign.center,
      bold: true,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
    );
    var bytes = <int>[];
    bytes += generator.text(settings.businessName.toUpperCase(),
        styles: styles);
    if (settings.rif.isNotEmpty) {
      bytes += generator.text(
        'RIF: ${settings.rif}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (settings.address.isNotEmpty) {
      bytes += generator.text(
        settings.address,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (settings.phone.isNotEmpty) {
      bytes += generator.text(
        'Tel: ${settings.phone}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.emptyLines(1);
    return bytes;
  }

  List<int> _row(Generator generator, String label, String value) {
    return generator.row([
      PosColumn(text: label, width: 6),
      PosColumn(
        text: value,
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }

  String _usd(double value) => '\$${value.toStringAsFixed(2)}';

  String _number(double value) => value.toStringAsFixed(2);

  String _date(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}

String _paymentLabel(String method) {
  switch (method) {
    case 'efectivo_bs':
      return 'Efectivo Bs';
    case 'efectivo_usd':
      return 'Efectivo USD';
    case 'pago_movil':
      return 'Pago Movil';
    case 'transferencia':
      return 'Transferencia';
    case 'punto_venta':
      return 'Punto de venta';
    case 'fiado':
      return 'Fiado';
    case 'mixto':
      return 'Pago mixto';
    default:
      return method;
  }
}
