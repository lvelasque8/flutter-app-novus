import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer?.name ?? '');
    _document =
        TextEditingController(text: widget.customer?.document ?? '');
    _phone = TextEditingController(text: widget.customer?.phone ?? '');
    _address = TextEditingController(text: widget.customer?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre del cliente')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(accountRepositoryProvider);
    try {
      Customer saved;
      if (widget.customer != null) {
        saved = Customer(
          id: widget.customer!.id,
          name: name,
          document: _document.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          notes: widget.customer!.notes,
          createdAt: widget.customer!.createdAt,
        );
        await repo.updateCustomer(saved);
      } else {
        saved = await repo.createCustomer(
          name: name,
          document: _document.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
        );
      }
      ref.invalidate(customersProvider);
      ref.invalidate(accountsProvider);
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $error')),
        );
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
