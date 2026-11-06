import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class PaymentLine {
  const PaymentLine({
    required this.method,
    required this.amount,
    required this.reference,
  });

  final String method;
  final double amount;
  final String reference;
}

class PaymentSelection {
  const PaymentSelection({
    required this.lines,
    required this.customer,
  });

  final List<PaymentLine> lines;
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
  late final List<_PaymentLineState> _lines;
  late Customer? _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.initialCustomer;
    final method = widget.rate > 0
        ? PaymentMethods.efectivoBs
        : PaymentMethods.efectivoUsd;
    _lines = [
      _PaymentLineState(
        method: method,
        amount: widget.total.toStringAsFixed(2),
      ),
    ];
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _assigned {
    return _lines.fold<double>(
      0,
      (sum, line) => sum + Money.parse(line.amount.text),
    );
  }

  double get _remaining => widget.total - _assigned;
  bool get _balanced => _remaining.abs() <= 0.009;
  bool get _hasCredit =>
      _lines.any((line) => PaymentMethods.isCredit(line.method));

  void _addLine() {
    final method = widget.rate > 0
        ? PaymentMethods.efectivoBs
        : PaymentMethods.efectivoUsd;
    final remaining = _remaining > 0 ? _remaining : 0.0;
    setState(() {
      _lines.add(
        _PaymentLineState(
          method: method,
          amount: remaining > 0 ? remaining.toStringAsFixed(2) : '',
        ),
      );
    });
  }

  void _addCreditRemaining() {
    if (_remaining <= 0) return;
    setState(() {
      _lines.add(
        _PaymentLineState(
          method: PaymentMethods.fiado,
          amount: _remaining.toStringAsFixed(2),
        ),
      );
    });
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    setState(() {
      _lines.removeAt(index).dispose();
    });
  }

  void _confirm() {
    if (!_balanced) return;
    if (_hasCredit && _customer == null) return;

    final lines = _lines
        .map(
          (line) => PaymentLine(
            method: line.method,
            amount: Money.parse(line.amount.text),
            reference: line.reference.text.trim(),
          ),
        )
        .where((line) => line.amount > 0)
        .toList();

    Navigator.pop(
      context,
      PaymentSelection(lines: lines, customer: _customer),
    );
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

  @override
  Widget build(BuildContext context) {
    final canConfirm = _balanced && (!_hasCredit || _customer != null);

    return AlertDialog(
      scrollable: true,
      title: const Text('Cobrar venta'),
      content: SizedBox(
        width: 580,
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
            Row(
              children: [
                const Expanded(
                  child: AppText(
                    'Pagos',
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar método'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...List.generate(_lines.length, (index) {
              return _buildLine(index);
            }),
            if (_remaining > 0.009) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      'Falta por asignar: ${Money.usd(_remaining)}',
                      variant: AppTextVariant.bodySmall,
                      color: AppColors.warning,
                    ),
                  ),
                  TextButton(
                    onPressed: _addCreditRemaining,
                    child: const Text('Dejar resto fiado'),
                  ),
                ],
              ),
            ],
            if (_remaining < -0.009)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: AppText(
                  'Los pagos exceden el total en ${Money.usd(-_remaining)}',
                  variant: AppTextVariant.bodySmall,
                  color: AppColors.error,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppText(
                    'Asignado: ${Money.usd(_assigned)}',
                    variant: AppTextVariant.bodySmall,
                    color: AppColors.textSecondary,
                  ),
                ),
                AppText(
                  _balanced
                      ? 'Completo'
                      : (_remaining > 0 ? 'Falta ${Money.usd(_remaining)}' : 'Excede'),
                  variant: AppTextVariant.bodySmall,
                  color: _balanced ? AppColors.success : AppColors.warning,
                ),
              ],
            ),
            if (_hasCredit) ...[
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
          ],
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
          enabled: canConfirm,
          onPressed: canConfirm ? _confirm : null,
        ),
      ],
    );
  }

  Widget _buildLine(int index) {
    final line = _lines[index];
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _iconFor(line.method),
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: line.method,
                    items: PaymentMethods.all
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(PaymentMethods.label(method)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        line.method = value;
                        if (line.method == PaymentMethods.fiado &&
                            _customer == null) {
                          // El cliente se elige más abajo.
                        }
                      });
                    },
                  ),
                ),
              ),
              if (_lines.length > 1)
                IconButton(
                  tooltip: 'Quitar pago',
                  onPressed: () => _removeLine(index),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Monto (USD)',
            hint: '0,00',
            controller: line.amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => setState(() {}),
          ),
          if (PaymentMethods.requiresReference(line.method)) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Referencia (opcional)',
              hint: 'Número de referencia',
              controller: line.reference,
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentLineState {
  _PaymentLineState({required this.method, required String amount})
      : amount = TextEditingController(text: amount),
        reference = TextEditingController();

  String method;
  final TextEditingController amount;
  final TextEditingController reference;

  void dispose() {
    amount.dispose();
    reference.dispose();
  }
}
