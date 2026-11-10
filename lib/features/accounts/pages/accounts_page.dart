import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/texto_plural.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../models/account.dart';
import '../providers/account_providers.dart';
import '../widgets/customer_form_dialog.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final customers = ref.watch(customersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.receipt_long_outlined),
                    label: Text('Por cobrar'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.people_outline),
                    label: Text('Clientes'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (value) =>
                    setState(() => _tab = value.first),
              ),
              const Spacer(),
              AppButton(
                'Nuevo cliente',
                icon: Icons.person_add_alt_1,
                onPressed: () async {
                  final created = await showCustomerFormDialog(context);
                  if (created != null) {
                    ref.invalidate(customersProvider);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _tab == 0
              ? _buildDebtors(accounts)
              : _buildCustomers(customers, accounts),
        ),
      ],
    );
  }

  Widget _buildDebtors(AsyncValue<List<AccountSummary>> accounts) {
    return accounts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('No se pudieron cargar las cuentas: $error'),
      ),
      data: (items) {
        final total =
            items.fold<double>(0, (sum, item) => sum + item.balance);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppColors.tertiary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText(
                                'Total por cobrar',
                                variant: AppTextVariant.caption,
                                color: AppColors.textSecondary,
                              ),
                              AppText(
                                Money.usd(total),
                                variant: AppTextVariant.titleLarge,
                              ),
                            ],
                          ),
                          const Spacer(),
                          AppBadge(
                            '${items.length} clientes',
                            variant: AppBadgeVariant.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 56,
                            color: AppColors.success,
                          ),
                          SizedBox(height: AppSpacing.md),
                          AppText(
                            'No tienes cuentas pendientes',
                            variant: AppTextVariant.titleMedium,
                          ),
                          SizedBox(height: AppSpacing.xs),
                          AppText(
                            'Los fiados aparecerán aquí.',
                            variant: AppTextVariant.bodySmall,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _CustomerDebtRow(
                          summary: item,
                          onTap: () => context.push(
                            '/cuenta/${item.customer.id}',
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomers(
    AsyncValue<List<Customer>> customers,
    AsyncValue<List<AccountSummary>> accounts,
  ) {
    final balances = <String, double>{
      for (final item in accounts.valueOrNull ?? <AccountSummary>[])
        item.customer.id: item.balance,
    };

    return customers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('No se pudieron cargar los clientes: $error'),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: AppText(
              'Todavía no tienes clientes registrados',
              variant: AppTextVariant.titleMedium,
              color: AppColors.textSecondary,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final customer = items[index];
            final balance = balances[customer.id] ?? 0;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  customer.name.isEmpty
                      ? '?'
                      : customer.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(customer.name),
              subtitle: Text(
                [
                  if (customer.document.isNotEmpty) customer.document,
                  if (customer.phone.isNotEmpty) customer.phone,
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (balance > 0)
                    AppBadge(
                      Money.usd(balance),
                      variant: AppBadgeVariant.warning,
                    )
                  else
                    const AppBadge(
                      'Al día',
                      variant: AppBadgeVariant.success,
                      size: AppBadgeSize.small,
                    ),
                  IconButton(
                    tooltip: 'Editar cliente',
                    onPressed: () async {
                      final updated = await showCustomerFormDialog(
                        context,
                        customer: customer,
                      );
                      if (updated != null) {
                        ref.invalidate(customersProvider);
                        ref.invalidate(customerByIdProvider(customer.id));
                      }
                    },
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
              onTap: () => context.push('/cuenta/${customer.id}'),
            );
          },
        );
      },
    );
  }
}

class _CustomerDebtRow extends StatelessWidget {
  const _CustomerDebtRow({required this.summary, required this.onTap});

  final AccountSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.tertiaryContainer,
              child: Text(
                summary.customer.name.isEmpty
                    ? '?'
                    : summary.customer.name[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.onTertiaryContainer,
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
                    summary.customer.name,
                    variant: AppTextVariant.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    '${TextoPlural.de(summary.openAccounts, 'cuenta abierta', 'cuentas abiertas')}'
                    '${summary.customer.phone.isEmpty ? '' : ' · ${summary.customer.phone}'}',
                    variant: AppTextVariant.caption,
                    color: AppColors.textSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  Money.usd(summary.balance),
                  variant: AppTextVariant.titleSmall,
                  color: AppColors.error,
                ),
                const AppText(
                  'pendiente',
                  variant: AppTextVariant.caption,
                  color: AppColors.textHint,
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
