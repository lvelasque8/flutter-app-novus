import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../../shared/widgets/atoms/app_text_field.dart';
import '../../accounts/models/account.dart';
import '../../accounts/widgets/customer_picker_dialog.dart';
import '../models/sale.dart';

class PaymentSelection {
  const PaymentSelection({
    required this.method,
    required this.reference,
    required this.customer,
  });

  final String method;
  final String reference;
  final Customer? customer;
}

Future<PaymentSelection?> showPaymentDialog(
  BuildContext context, {
  required double total,
  required double rate,
  Customer? customer,
}) {
  return showDialog<PaymentSelection>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _PaymentDialog(
      total: total,
      rate: rate,
      initialCustomer: customer,
    ),
  );
}

class _PaymentDialog extends ConsumerStatefulWidget {
  const _PaymentDialog({
    required this.total,
    required this.rate,
    this.initialCustomer,
  });

  final double total;
  final double rate;
  final Customer? initialCustomer;

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  late String _method;
  late Customer? _customer;
  final _reference = TextEditingController();

  @override
  void initState() {
    super.initState();
    _method = widget.rate > 0
        ? PaymentMethods.efectivoBs
        : PaymentMethods.efectivoUsd;
    _customer = widget.initialCustomer;
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  IconData _iconFor(String method) {
    switch (method) {
      case PaymentMethods.efectivoBs:
      case PaymentMethods.efectivoUsd:
        return Icons.payments_outlined;
      case PaymentMethods.pagoMovil:
        return Icons.phone_android;
      case PaymentMethods.transferencia:
        return Icons.account_balance_outlined;
      case PaymentMethods.puntoVenta:
        return Icons.point_of_sale_outlined;
      case PaymentMethods.fiado:
        return Icons.receipt_long_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  void _confirm() {
    if (PaymentMethods.isCredit(_method) && _customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona el cliente para registrar el fiado'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      PaymentSelection(
        method: _method,
        reference: _reference.text.trim(),
        customer: _customer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Cobrar venta'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'Total a cobrar',
                      variant: AppTextVariant.labelMedium,
                      color: AppColors.onPrimaryContainer,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppText(
                      Money.usd(widget.total),
                      variant: AppTextVariant.headlineSmall,
                      color: AppColors.onPrimaryContainer,
                    ),
                    if (widget.rate > 0)
                      AppText(
                        Money.bs(widget.total * widget.rate),
                        variant: AppTextVariant.titleMedium,
                        color: AppColors.onPrimaryContainer,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppText(
                'Forma de pago',
                variant: AppTextVariant.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: PaymentMethods.all.map((method) {
                  final selected = _method == method;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => _method = method),
                    avatar: Icon(
                      _iconFor(method),
                      size: 18,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    label: Text(PaymentMethods.label(method)),
                  );
                }).toList(),
              ),
              if (PaymentMethods.isCredit(_method)) ...[
                const SizedBox(height: AppSpacing.lg),
                const AppText(
                  'Cliente del fiado',
                  variant: AppTextVariant.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: () async {
                    final selected = await showCustomerPicker(context);
                    if (selected != null) {
                      setState(() => _customer = selected);
                    }
                  },
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.outline),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppText(
                            _customer?.name ?? 'Seleccionar cliente',
                            variant: AppTextVariant.bodyMedium,
                            color: _customer == null
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (PaymentMethods.requiresReference(_method)) ...[
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Referencia (opcional)',
                  hint: 'Número de referencia o teléfono',
                  controller: _reference,
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        AppButton(
          'Cobrar ${Money.usd(widget.total)}',
          icon: Icons.check_circle_outline,
          onPressed: _confirm,
        ),
      ],
    );
  }
}
