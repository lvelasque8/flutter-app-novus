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

  /// Bloque con los datos de pago configurados en Ajustes.
  ///
  /// Devuelve una cadena vacía si el interruptor está apagado o si no hay
  /// ningún dato cargado.
  static String paymentBlock(BusinessSettings settings) {
    if (!settings.paymentInfoEnabled || !settings.hasPaymentInfo) {
      return '';
    }

    final lines = <String>[];
    if (settings.paymentBank.trim().isNotEmpty) {
      lines.add('Banco: ${settings.paymentBank.trim()}');
    }
    if (settings.paymentAccount.trim().isNotEmpty) {
      lines.add('Cuenta: ${settings.paymentAccount.trim()}');
    }
    if (settings.paymentHolder.trim().isNotEmpty) {
      lines.add('Titular: ${settings.paymentHolder.trim()}');
    }
    if (settings.paymentDocument.trim().isNotEmpty) {
      lines.add('Cédula/RIF: ${settings.paymentDocument.trim()}');
    }
    if (settings.paymentMobilePhone.trim().isNotEmpty) {
      lines.add('Pago Móvil: ${settings.paymentMobilePhone.trim()}');
    }
    if (settings.paymentNote.trim().isNotEmpty) {
      lines.add(settings.paymentNote.trim());
    }

    if (lines.isEmpty) return '';
    return '\nDatos para pagar:\n${lines.join('\n')}';
  }

  static String _dueLine(Account account, DateTime now) {
    final due = account.dueDate;
    if (due == null) return '';
    final days = account.daysUntilDueAt(now);
    if (days == null) return '';
    if (days < 0) {
      return ' · Vencida hace ${-days} ${-days == 1 ? 'día' : 'días'}';
    }
    if (days == 0) return ' · Vence hoy';
    return ' · Vence ${Money.date(due)}';
  }

  /// Texto del estado de cuenta listo para enviar.
  static String buildMessage({
    required BusinessSettings settings,
    required Customer customer,
    required List<Account> accounts,
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();
    final date = Money.date(moment);
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
          'Saldo ${Money.usd(account.balance)}'
          '${_dueLine(account, moment)}',
        );
      }
      buffer
        ..writeln()
        ..writeln('Total fiado: ${Money.usd(total)}')
        ..writeln('Total abonado: ${Money.usd(paid)}');
    }

    buffer
      ..writeln()
      ..writeln('*Saldo pendiente: ${Money.usd(balance)}*');

    final payments = paymentBlock(settings);
    if (payments.isNotEmpty) buffer.writeln(payments);

    buffer
      ..writeln()
      ..write('Documento no fiscal');

    return buffer.toString();
  }

  /// Recordatorio corto de cobranza para una o varias cuentas del cliente.
  static String buildReminder({
    required BusinessSettings settings,
    required Customer customer,
    required List<Account> accounts,
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();
    final balance = accounts
        .fold<double>(0, (sum, a) => sum + a.balance)
        .clamp(0, double.infinity);
    final dueDates = accounts
        .map((account) => account.dueDate)
        .whereType<DateTime>()
        .toList()
      ..sort();
    final due = dueDates.isEmpty ? null : dueDates.first;

    final buffer = StringBuffer()
      ..writeln('*${settings.businessName}*')
      ..writeln('Recordatorio de pago')
      ..writeln()
      ..writeln('Hola ${customer.name},')
      ..writeln('Te recordamos tu saldo pendiente.')
      ..writeln()
      ..writeln('*Saldo: ${Money.usd(balance)}*');

    if (due != null) {
      final days = DateTime(due.year, due.month, due.day)
          .difference(DateTime(moment.year, moment.month, moment.day))
          .inDays;
      if (days < 0) {
        buffer.writeln(
          'Vencimiento: ${Money.date(due)} '
          '(vencida hace ${-days} ${-days == 1 ? 'día' : 'días'})',
        );
      } else if (days == 0) {
        buffer.writeln('Vencimiento: hoy');
      } else {
        buffer.writeln('Vencimiento: ${Money.date(due)}');
      }
    }

    if (accounts.length == 1) {
      final account = accounts.first;
      buffer
        ..writeln()
        ..writeln(
          'Cuenta del ${Money.date(account.createdAt)}: '
          'total ${Money.usd(account.total)}, '
          'abonado ${Money.usd(account.paid)}.',
        );
    } else if (accounts.length > 1) {
      buffer
        ..writeln()
        ..writeln('Tienes ${accounts.length} cuentas abiertas:');
      for (final account in accounts) {
        buffer.writeln(
          '• ${Money.date(account.createdAt)} · '
          'Saldo ${Money.usd(account.balance)}'
          '${_dueLine(account, moment)}',
        );
      }
    }

    final payments = paymentBlock(settings);
    if (payments.isNotEmpty) buffer.writeln(payments);

    buffer
      ..writeln()
      ..writeln('Gracias por tu preferencia.')
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
