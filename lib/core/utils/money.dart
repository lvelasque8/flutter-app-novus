import 'package:intl/intl.dart';

/// Formatos de moneda y números para Venezuela.
///
/// La aplicación maneja dos monedas: dólares (precio base) y bolívares
/// (calculados con la tasa configurada en Ajustes).
class Money {
  Money._();

  static final NumberFormat _usd = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 2,
  );

  static final NumberFormat _bs = NumberFormat.currency(
    locale: 'es_VE',
    symbol: 'Bs',
    decimalDigits: 2,
  );

  static final NumberFormat _decimal = NumberFormat('#,##0.00', 'es_VE');

  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _shortDate = DateFormat('dd/MM');

  static String usd(num value) => _usd.format(value);

  static String bs(num value) => _bs.format(value);

  static String decimal(num value) => _decimal.format(value);

  static String date(DateTime value) => _date.format(value.toLocal());

  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());

  static String shortDate(DateTime value) => _shortDate.format(value.toLocal());

  static double parse(String value) {
    var cleaned = value
        .replaceAll(' ', '')
        .replaceAll('Bs', '')
        .replaceAll(r'$', '');

    if (cleaned.contains(',') && cleaned.contains('.')) {
      // Formato venezolano: 1.234,56
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleaned.contains(',')) {
      // 1234,56
      cleaned = cleaned.replaceAll(',', '.');
    }
    // Si solo hay punto se interpreta como decimal (36.50).

    return double.tryParse(cleaned) ?? 0;
  }

  static int parseInt(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
  }
}
