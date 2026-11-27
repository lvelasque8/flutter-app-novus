import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../features/accounts/models/account.dart';
import '../../features/sales/models/sale.dart';
import '../../shared/widgets/atoms/app_badge.dart';
import '../../shared/widgets/atoms/app_card.dart';
import '../../shared/widgets/atoms/app_text.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_common.dart';

class AdminAccountsPage extends StatelessWidget {
  const AdminAccountsPage({super.key, required this.data});

  final AdminData data;

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    final total = data.receivable;
    final overdue = data.overdueAmount;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AdminSectionHeader(
          title: 'Cuentas por cobrar',
          subtitle: 'Saldos de los fiados abiertos',
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 640 ? 2 : 1;
            const spacing = AppSpacing.md;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: AdminStatCard(
                    label: 'Total por cobrar',
                    value: Money.usd(total),
                    detail:
                        '${data.openAccounts.length} ${data.openAccounts.length == 1 ? 'cuenta' : 'cuentas'}',
                    color: AppColors.tertiary,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminStatCard(
                    label: 'Vencido',
                    value: Money.usd(overdue),
                    detail: data.overdueCount == 0
                        ? 'Nada vencido'
                        : '${data.overdueCount} ${data.overdueCount == 1 ? 'cuenta' : 'cuentas'}',
                    color: overdue > 0 ? AppColors.error : AppColors.success,
                    icon: Icons.notifications_active_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: groups.isEmpty
              ? const AdminEmpty(
                  message: 'No hay fiados pendientes',
                  icon: Icons.task_alt,
                )
              : Column(
                  children: [
                    for (final group in groups)
                      _AccountRow(group: group, data: data),
                  ],
                ),
        ),
      ],
    );
  }

  List<_CustomerGroup> _groups() {
    final grouped = <String, List<Account>>{};
    for (final account in data.openAccounts) {
      grouped.putIfAbsent(account.customerId, () => []).add(account);
    }
    final groups = [
      for (final entry in grouped.entries)
        _CustomerGroup(
          customer: data.customerById(entry.key),
          customerId: entry.key,
          accounts: entry.value,
        ),
    ];
    groups.sort((a, b) {
      final aRank = a.isOverdue ? 0 : 1;
      final bRank = b.isOverdue ? 0 : 1;
      if (aRank != bRank) return aRank.compareTo(bRank);
      return b.balance.compareTo(a.balance);
    });
    return groups;
  }
}

class _CustomerGroup {
  _CustomerGroup({
    required this.customer,
    required this.customerId,
    required this.accounts,
  });

  final Customer? customer;
  final String customerId;
  final List<Account> accounts;

  String get name => customer?.name ?? 'Cliente $customerId';

  double get balance =>
      accounts.fold<double>(0, (sum, account) => sum + account.balance);

  bool get isOverdue => accounts.any((account) => account.isOverdue);

  int get overdueDays {
    var days = 0;
    for (final account in accounts) {
      if (account.overdueDays > days) days = account.overdueDays;
    }
    return days;
  }

  DateTime? get nextDue {
    DateTime? earliest;
    for (final account in accounts) {
      final due = account.dueDate;
      if (due == null) continue;
      if (earliest == null || due.isBefore(earliest)) earliest = due;
    }
    return earliest;
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.group, required this.data});

  final _CustomerGroup group;
  final AdminData data;

  @override
  Widget build(BuildContext context) {
    final due = group.nextDue;
    return InkWell(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: group.isOverdue
                  ? AppColors.errorContainer
                  : AppColors.tertiaryContainer,
              child: Text(
                group.name.isEmpty ? '?' : group.name[0].toUpperCase(),
                style: TextStyle(
                  color: group.isOverdue
                      ? AppColors.onErrorContainer
                      : AppColors.onTertiaryContainer,
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
                    group.name,
                    variant: AppTextVariant.titleSmall,
                  ),
                  AppText(
                    [
                      if (group.customer?.phone.isNotEmpty == true)
                        group.customer!.phone,
                      '${group.accounts.length} '
                          '${group.accounts.length == 1 ? 'cuenta' : 'cuentas'}',
                      if (due != null) 'vence ${Money.date(due)}',
                    ].join(' · '),
                    variant: AppTextVariant.caption,
                    color: group.isOverdue
                        ? AppColors.error
                        : AppColors.textSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (group.isOverdue)
              AppBadge(
                'Vencida ${group.overdueDays}d',
                variant: AppBadgeVariant.error,
                size: AppBadgeSize.small,
              ),
            const SizedBox(width: AppSpacing.md),
            AppText(
              Money.usd(group.balance),
              variant: AppTextVariant.titleSmall,
              color: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetail(BuildContext context) async {
    final payments = <Account, List<AccountPayment>>{
      for (final account in group.accounts)
        account: data.paymentsFor(account.id),
    };

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        group.name,
                        variant: AppTextVariant.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (group.customer?.phone.isNotEmpty == true)
                  AppText(
                    group.customer!.phone,
                    variant: AppTextVariant.bodySmall,
                    color: AppColors.textSecondary,
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        'Saldo total',
                        variant: AppTextVariant.titleSmall,
                      ),
                    ),
                    AppText(
                      Money.usd(group.balance),
                      variant: AppTextVariant.titleMedium,
                      color: AppColors.error,
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xl),
                for (final account in group.accounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                'Cuenta del '
                                '${Money.date(account.createdAt)}',
                                variant: AppTextVariant.titleSmall,
                              ),
                            ),
                            if (account.isOverdue)
                              AppBadge(
                                'Vencida ${account.overdueDays}d',
                                variant: AppBadgeVariant.error,
                                size: AppBadgeSize.small,
                              )
                            else
                              AppBadge(
                                'Saldo ${Money.usd(account.balance)}',
                                variant: AppBadgeVariant.warning,
                                size: AppBadgeSize.small,
                              ),
                          ],
                        ),
                        AppText(
                          'Total ${Money.usd(account.total)} · '
                          'Abonado ${Money.usd(account.paid)}'
                          '${account.dueDate == null ? '' : ' · Vence ${Money.date(account.dueDate!)}'}',
                          variant: AppTextVariant.caption,
                          color: AppColors.textSecondary,
                        ),
                        if (payments[account]!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          for (final payment in payments[account]!)
                            AppText(
                              '${Money.dateTime(payment.createdAt)} · '
                              '${PaymentMethods.label(payment.method)} '
                              '${Money.usd(payment.amount)}',
                              variant: AppTextVariant.caption,
                              color: AppColors.textHint,
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
