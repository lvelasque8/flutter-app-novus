import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../sales/models/sale.dart';
import '../settings/models/business_settings.dart';

/// Genera una nota de entrega / recibo no fiscal y abre el diálogo de impresión.
Future<void> printSaleReceipt({
  required Sale sale,
  required BusinessSettings settings,
}) async {
  final document = pw.Document();
  final rate = sale.rate > 0 ? sale.rate : settings.rateBs;
  final totalBs = sale.totalBs > 0 ? sale.totalBs : sale.total * rate;

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat(
        80 * PdfPageFormat.mm,
        297 * PdfPageFormat.mm,
      ),
      margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      build: (context) => [
        pw.Center(
          child: pw.Text(
            settings.businessName.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        if (settings.rif.isNotEmpty)
          pw.Center(
            child: pw.Text(
              'RIF: ${settings.rif}',
              style: pw.TextStyle(fontSize: 8),
            ),
          ),
        if (settings.address.isNotEmpty)
          pw.Center(
            child: pw.Text(
              settings.address,
              style: pw.TextStyle(fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (settings.phone.isNotEmpty)
          pw.Center(
            child: pw.Text(
              'Tel: ${settings.phone}',
              style: pw.TextStyle(fontSize: 7),
            ),
          ),
        pw.SizedBox(height: 8),
        pw.Divider(),
        pw.Center(
          child: pw.Text(
            'NOTA DE ENTREGA',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            '${sale.number} · ${_formatDate(sale.createdAt)}',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Divider(),
        pw.Text(
          'Cliente: ${sale.customerName ?? 'Consumidor final'}',
          style: pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.symmetric(
            inside: const pw.BorderSide(width: 0.3),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              children: [
                _cell('Cant', bold: true),
                _cell('Producto', bold: true),
                _cell('Precio', bold: true, alignRight: true),
                _cell('Total', bold: true, alignRight: true),
              ],
            ),
            ...sale.items.map(
              (item) => pw.TableRow(
                children: [
                  _cell('${item.quantity}'),
                  _cell(item.name),
                  _cell(_usd(item.price), alignRight: true),
                  _cell(_usd(item.subtotal), alignRight: true),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        _row('Subtotal', _usd(sale.subtotal)),
        if (sale.discount > 0)
          _row('Descuento', '-${_usd(sale.discount)}'),
        _row('IVA (${settings.ivaRate.toStringAsFixed(0)}%)', _usd(sale.tax)),
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'TOTAL USD',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              _usd(sale.total),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        if (rate > 0) ...[
          pw.SizedBox(height: 2),
          _row('Tasa BCV', 'Bs ${_number(rate)} / USD'),
          _row('TOTAL Bs', 'Bs ${_number(totalBs)}'),
        ],
        pw.SizedBox(height: 6),
        _row('Forma de pago', paymentLabel(sale.paymentMethod)),
        if (sale.payments.isEmpty) ...[
          if (sale.reference != null && sale.reference!.isNotEmpty)
            _row('Referencia', sale.reference!),
        ] else ...[
          ...sale.payments.map(
            (payment) => _row(
              paymentLabel(payment.method),
              '${_usd(payment.amount)}'
                  '${payment.reference != null && payment.reference!.isNotEmpty ? ' · ${payment.reference}' : ''}',
            ),
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Divider(),
        pw.Center(
          child: pw.Text(
            'DOCUMENTO NO FISCAL',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'Gracias por su compra',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => document.save(),
    name: 'nota-${sale.number}.pdf',
  );
}

String paymentLabel(String method) {
  switch (method) {
    case 'efectivo_bs':
      return 'Efectivo Bs';
    case 'efectivo_usd':
      return 'Efectivo USD';
    case 'pago_movil':
      return 'Pago Móvil';
    case 'transferencia':
      return 'Transferencia';
    case 'punto_venta':
      return 'Punto de venta';
    case 'fiado':
      return 'Fiado (cuenta por cobrar)';
    case 'mixto':
      return 'Pago mixto';
    default:
      return method;
  }
}

pw.Widget _cell(String text, {bool bold = false, bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
    child: pw.Text(
      text,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _row(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8)),
        pw.Text(value, style: pw.TextStyle(fontSize: 8)),
      ],
    ),
  );
}

String _usd(double value) => '\$ ${value.toStringAsFixed(2)}';

String _number(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  return '$whole,${parts.last}';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} $hour:$minute';
}
