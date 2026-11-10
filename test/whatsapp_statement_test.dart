import 'package:flutter_test/flutter_test.dart';
import 'package:novus/features/accounts/data/whatsapp_statement.dart';
import 'package:novus/features/accounts/models/account.dart';
import 'package:novus/features/settings/models/business_settings.dart';

void main() {
  group('WhatsAppStatement.normalizePhone', () {
    test('convierte números venezolanos a formato internacional', () {
      expect(
        WhatsAppStatement.normalizePhone('0412-1234567'),
        '584121234567',
      );
      expect(
        WhatsAppStatement.normalizePhone('+58 412 1234567'),
        '584121234567',
      );
      expect(
        WhatsAppStatement.normalizePhone('4121234567'),
        '584121234567',
      );
      expect(
        WhatsAppStatement.normalizePhone('0058 412 1234567'),
        '584121234567',
      );
    });

    test('devuelve vacío si no hay dígitos', () {
      expect(WhatsAppStatement.normalizePhone(''), '');
      expect(WhatsAppStatement.normalizePhone('sin telefono'), '');
    });
  });

  group('WhatsAppStatement.buildMessage', () {
    test('incluye negocio, cliente y saldo pendiente', () {
      final settings = BusinessSettings.initial().copyWith(
        businessName: 'Kiosco De Oma',
      );
      final customer = Customer(
        id: 'c1',
        name: 'Maria Perez',
        document: '',
        phone: '0412-1234567',
        address: '',
        notes: '',
        createdAt: DateTime(2026, 11, 6),
      );
      final accounts = [
        Account(
          id: 'a1',
          customerId: 'c1',
          saleId: 's1',
          total: 10,
          paid: 4,
          status: 'pendiente',
          createdAt: DateTime(2026, 11, 6),
        ),
        Account(
          id: 'a2',
          customerId: 'c1',
          saleId: 's2',
          total: 2.5,
          paid: 0,
          status: 'pendiente',
          createdAt: DateTime(2026, 11, 7),
        ),
      ];

      final message = WhatsAppStatement.buildMessage(
        settings: settings,
        customer: customer,
        accounts: accounts,
        now: DateTime(2026, 11, 10),
      );

      expect(message, contains('Kiosco De Oma'));
      expect(message, contains('Cliente: Maria Perez'));
      expect(message, contains('Detalle:'));
      expect(message, contains('Saldo pendiente: \$8.50'));
      expect(message, contains('Documento no fiscal'));
    });

    test('avisa cuando no hay cuentas', () {
      final settings = BusinessSettings.initial();
      final customer = Customer(
        id: 'c1',
        name: 'Maria Perez',
        document: '',
        phone: '',
        address: '',
        notes: '',
        createdAt: DateTime(2026, 11, 6),
      );

      final message = WhatsAppStatement.buildMessage(
        settings: settings,
        customer: customer,
        accounts: const [],
      );

      expect(message, contains('No tienes cuentas pendientes'));
      expect(message, contains('Saldo pendiente: \$0.00'));
    });
  });
}
