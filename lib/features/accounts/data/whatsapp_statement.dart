import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/money.dart';
import '../../settings/models/business_settings.dart';
import '../models/account.dart';

/// Arma y abre el estado de cuenta de un cliente en WhatsApp.
class WhatsAppStatement {
  WhatsAppStatement._();

  /// Deja el teléfono en formato internacional.
  ///
  /// Ejemplos: `0412-1234567` → `584121234567`,
  /// `+58 412 1234567` → `584121234567`, `4121234567` → `584121234567`.
  static String normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('58')) return digits;
    if (digits.startsWith('0') && digits.length >= 11) {
      return '58${digits.substring(1)}';
    }
    if (digits.length == 10 && digits.startsWith('4')) {
      return '58$digits';
    }
    return digits;
  }

  /// Texto del estado de cuenta listo para enviar.
  static String buildMessage({
    required BusinessSettings settings,
    required Customer customer,
    required List<Account> accounts,
    DateTime? now,
  }) {
    final date = Money.date(now ?? DateTime.now());
    final total = accounts.fold<double>(0, (sum, a) => sum + a.total);
    final paid = accounts.fold<double>(0, (sum, a) => sum + a.paid);
    final balance = (total - paid).clamp(0, double.infinity);

    final buffer = StringBuffer()
      ..writeln('*${settings.businessName}*')
      ..writeln('Estado de cuenta')
      ..writeln()
      ..writeln('Cliente: ${customer.name}')
      ..writeln('Fecha: $date')
      ..writeln();

    if (accounts.isEmpty) {
      buffer.writeln('No tienes cuentas pendientes.');
    } else {
      buffer.writeln('Detalle:');
      for (final account in accounts) {
        buffer.writeln(
          '• ${Money.date(account.createdAt)} · '
          'Total ${Money.usd(account.total)} · '
          'Abonado ${Money.usd(account.paid)} · '
          'Saldo ${Money.usd(account.balance)}',
        );
      }
      buffer
        ..writeln()
        ..writeln('Total fiado: ${Money.usd(total)}')
        ..writeln('Total abonado: ${Money.usd(paid)}');
    }

    buffer
      ..writeln()
      ..writeln('*Saldo pendiente: ${Money.usd(balance)}*')
      ..writeln()
      ..write('Documento no fiscal');

    return buffer.toString();
  }

  /// Abre WhatsApp con el mensaje ya escrito para el cliente.
  static Future<bool> open({
    required String phone,
    required String message,
  }) async {
    final number = normalizePhone(phone);
    if (number.isEmpty) return false;

    final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
    );

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
