import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../../shared/widgets/atoms/app_text_field.dart';
import '../../cash/providers/cash_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../sales/models/sale.dart';
import '../../sales/providers/sale_providers.dart';
import '../models/account.dart';
import '../providers/account_providers.dart';

class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerByIdProvider(customerId));
    final accountsAsync = ref.watch(customerAccountsProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: Text(customerAsync.valueOrNull?.name ?? 'Cuenta'),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('No se pudo cargar la cuenta: $error'),
            ),
            data: (accounts) {
              final customer = customerAsync.valueOrNull;
              final total =
                  accounts.fold<double>(0, (sum, account) => sum + account.total);
              final paid =
                  accounts.fold<double>(0, (sum, account) => sum + account.paid);
              final balance = (total - paid).clamp(0, double.infinity);

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.primaryContainer,
                              child: Text(
                                customer?.name.isNotEmpty == true
                                    ? customer!.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    customer?.name ?? 'Cliente',
                                    variant: AppTextVariant.titleLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  AppText(
                                    [
                                      if (customer?.document.isNotEmpty ==
                                          true)
                                        customer!.document,
                                      if (customer?.phone.isNotEmpty == true)
                                        customer!.phone,
                                    ].join(' · '),
                                    variant: AppTextVariant.bodySmall,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            AppBadge(
                              balance > 0
                                  ? 'Debe ${Money.usd(balance)}'
                                  : 'Al día',
                              variant: balance > 0
                                  ? AppBadgeVariant.warning
                                  : AppBadgeVariant.success,
                            ),
                          ],
                        ),
                        const Divider(height: AppSpacing.xl2),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: 'Total fiado',
                                value: Money.usd(total),
                              ),
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: 'Abonado',
                                value: Money.usd(paid),
                              ),
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: 'Saldo',
                                value: Money.usd(balance),
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (accounts.isEmpty)
                    const AppCard(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: AppText(
                          'Este cliente no tiene cuentas por cobrar.',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...accounts.map(
                      (account) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _AccountCard(
                          account: account,
                          customerId: customerId,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          variant: AppTextVariant.caption,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 2),
        AppText(
          value,
          variant: AppTextVariant.titleMedium,
          color: color,
        ),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account, required this.customerId});

  final Account account;
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(accountPaymentsProvider(account.id));

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Cuenta del ${Money.date(account.createdAt)}',
                      variant: AppTextVariant.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      'Total ${Money.usd(account.total)} · '
                      'Abonado ${Money.usd(account.paid)}',
                      variant: AppTextVariant.caption,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              AppBadge(
                account.isPaid
                    ? 'Pagada'
                    : 'Saldo ${Money.usd(account.balance)}',
                variant: account.isPaid
                    ? AppBadgeVariant.success
                    : AppBadgeVariant.warning,
                size: AppBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (!account.isPaid)
                AppButton(
                  'Registrar abono',
                  icon: Icons.add_card,
                  size: AppButtonSize.small,
                  onPressed: () => _showAbono(context, ref),
                ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () => _showPayments(context, payments.valueOrNull),
                child: const Text('Ver abonos'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAbono(BuildContext context, WidgetRef ref) async {
    final data = await showDialog<_AbonoData>(
      context: context,
      builder: (context) => _AbonoDialog(balance: account.balance),
    );
    if (data == null) return;

    try {
      await ref.read(accountRepositoryProvider).addPayment(
            accountId: account.id,
            amount: data.amount,
            method: data.method,
            note: data.note,
          );
      ref.invalidate(accountsProvider);
      ref.invalidate(customerAccountsProvider(customerId));
      ref.invalidate(accountPaymentsProvider(account.id));
      ref.invalidate(receivableTotalProvider);
      ref.invalidate(openAccountsCountProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(salesProvider);
      ref.invalidate(todayTotalProvider);
      ref.invalidate(todayCountProvider);
      ref.invalidate(cashSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abono registrado')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo registrar: $error')),
        );
      }
    }
  }

  void _showPayments(BuildContext context, List<AccountPayment>? payments) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abonos registrados'),
        content: SizedBox(
          width: 460,
          child: payments == null || payments.isEmpty
              ? const Text('Todavía no hay abonos.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: payments.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    return ListTile(
                      dense: true,
                      title: Text(Money.usd(payment.amount)),
                      subtitle: Text(
                        '${Money.dateTime(payment.createdAt)} · '
                        '${payment.method}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _AbonoData {
  const _AbonoData({
    required this.amount,
    required this.method,
    required this.note,
  });

  final double amount;
  final String method;
  final String note;
}

class _AbonoDialog extends StatefulWidget {
  const _AbonoDialog({required this.balance});

  final double balance;

  @override
  State<_AbonoDialog> createState() => _AbonoDialogState();
}

class _AbonoDialogState extends State<_AbonoDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _method = 'efectivo_bs';

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = Money.parse(_amount.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un monto válido')),
      );
      return;
    }
    if (amount > widget.balance + 0.005) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El abono no puede superar el saldo de ${Money.usd(widget.balance)}',
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _AbonoData(
        amount: amount,
        method: _method,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Registrar abono'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Saldo pendiente: ${Money.usd(widget.balance)}',
              variant: AppTextVariant.bodyMedium,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Monto (USD)',
              hint: '0,00',
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppText(
              'Forma de pago',
              variant: AppTextVariant.labelMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                PaymentMethods.efectivoBs,
                PaymentMethods.efectivoUsd,
                PaymentMethods.pagoMovil,
                PaymentMethods.transferencia,
              ].map((method) {
                final selected = _method == method;
                return ChoiceChip(
                  label: Text(PaymentMethods.label(method)),
                  selected: selected,
                  labelStyle: TextStyle(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _method = method),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nota (opcional)',
              controller: _note,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        AppButton('Guardar abono', onPressed: _confirm),
      ],
    );
  }
}
