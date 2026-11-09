import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_text_field.dart';
import '../models/account.dart';
import '../providers/account_providers.dart';

Future<Customer?> showCustomerFormDialog(
  BuildContext context, {
  Customer? customer,
}) {
  return showDialog<Customer?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CustomerFormDialog(customer: customer),
  );
}

class _CustomerFormDialog extends ConsumerStatefulWidget {
  const _CustomerFormDialog({this.customer});

  final Customer? customer;

  @override
  ConsumerState<_CustomerFormDialog> createState() =>
      _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<_CustomerFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _document;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _creditLimit;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer?.name ?? '');
    _document =
        TextEditingController(text: widget.customer?.document ?? '');
    _phone = TextEditingController(text: widget.customer?.phone ?? '');
    _address = TextEditingController(text: widget.customer?.address ?? '');
    _creditLimit = TextEditingController(
      text: (widget.customer?.creditLimit ?? 0) > 0
          ? widget.customer!.creditLimit.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    _phone.dispose();
    _address.dispose();
    _creditLimit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Escribe el nombre del cliente');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    final repo = ref.read(accountRepositoryProvider);
    try {
      Customer saved;
      final creditLimit = Money.parse(_creditLimit.text);
      if (widget.customer != null) {
        saved = Customer(
          id: widget.customer!.id,
          name: name,
          document: _document.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          notes: widget.customer!.notes,
          createdAt: widget.customer!.createdAt,
          creditLimit: creditLimit,
        );
        await repo.updateCustomer(saved);
      } else {
        saved = await repo.createCustomer(
          name: name,
          document: _document.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          creditLimit: creditLimit,
        );
      }
      ref.invalidate(customersProvider);
      ref.invalidate(accountsProvider);
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        setState(() => _errorMessage = message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.customer == null ? 'Nuevo cliente' : 'Editar cliente',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Nombre *',
                hint: 'Nombre y apellido o razón social',
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Cédula o RIF',
                hint: 'V-12345678 / J-12345678-9',
                controller: _document,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Teléfono',
                hint: '0412-1234567',
                controller: _phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Dirección',
                hint: 'Opcional',
                controller: _address,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Límite de crédito (USD)',
                hint: '0,00',
                helperText: 'Máximo que puede deber. Deja 0 para sin límite.',
                controller: _creditLimit,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        AppButton(
          'Guardar',
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
