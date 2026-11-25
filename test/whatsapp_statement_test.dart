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

    test('incluye los datos de pago solo si están activados', () {
      final base = BusinessSettings.initial().copyWith(
        businessName: 'Kiosco De Oma',
        paymentBank: 'Banesco',
        paymentAccount: '0134-1234-56-7890123456',
        paymentHolder: 'Kiosco De Oma',
        paymentDocument: 'J-12345678',
        paymentMobilePhone: '0414-1234567',
        paymentNote: 'Envía el comprobante por aquí',
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

      final off = WhatsAppStatement.buildMessage(
        settings: base,
        customer: customer,
        accounts: const [],
        now: DateTime(2026, 11, 10),
      );
      expect(off, isNot(contains('Datos para pagar')));

      final on = WhatsAppStatement.buildMessage(
        settings: base.copyWith(paymentInfoEnabled: true),
        customer: customer,
        accounts: const [],
        now: DateTime(2026, 11, 10),
      );
      expect(on, contains('Datos para pagar:'));
      expect(on, contains('Banco: Banesco'));
      expect(on, contains('Cuenta: 0134-1234-56-7890123456'));
      expect(on, contains('Titular: Kiosco De Oma'));
      expect(on, contains('Cédula/RIF: J-12345678'));
      expect(on, contains('Pago Móvil: 0414-1234567'));
      expect(on, contains('Envía el comprobante por aquí'));
    });

    test('muestra el vencimiento y si está vencida', () {
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
        accounts: [
          Account(
            id: 'a1',
            customerId: 'c1',
            saleId: 's1',
            total: 10,
            paid: 0,
            status: 'pendiente',
            createdAt: DateTime(2026, 11, 1),
            dueDate: DateTime(2026, 11, 5),
          ),
        ],
        now: DateTime(2026, 11, 10),
      );

      expect(message, contains('Vencida hace 5 días'));
    });
  });

  group('WhatsAppStatement.buildReminder', () {
    test('incluye saldo, vencimiento y datos de pago', () {
      final settings = BusinessSettings.initial().copyWith(
        businessName: 'Kiosco De Oma',
        paymentInfoEnabled: true,
        paymentBank: 'Banesco',
        paymentMobilePhone: '0414-1234567',
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

      final message = WhatsAppStatement.buildReminder(
        settings: settings,
        customer: customer,
        accounts: [
          Account(
            id: 'a1',
            customerId: 'c1',
            saleId: 's1',
            total: 20,
            paid: 5,
            status: 'pendiente',
            createdAt: DateTime(2026, 11, 1),
            dueDate: DateTime(2026, 11, 9),
          ),
        ],
        now: DateTime(2026, 11, 10),
      );

      expect(message, contains('Recordatorio de pago'));
      expect(message, contains('Hola Maria Perez'));
      expect(message, contains('Saldo: \$15.00'));
      expect(message, contains('vencida hace 1 día'));
      expect(message, contains('Datos para pagar:'));
      expect(message, contains('Pago Móvil: 0414-1234567'));
    });
  });
}
