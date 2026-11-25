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
import '../../settings/models/business_settings.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/whatsapp_statement.dart';
import '../models/account.dart';
import '../providers/account_providers.dart';
import '../widgets/customer_form_dialog.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(accountsTabProvider);
    final accounts = ref.watch(accountsProvider);
    final customers = ref.watch(customersProvider);
    final collection = ref.watch(collectionProvider);

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
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.notifications_active_outlined),
                    label: Text('Cobranza'),
                  ),
                ],
                selected: {tab},
                onSelectionChanged: (value) =>
                    ref.read(accountsTabProvider.notifier).state = value.first,
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
          child: switch (tab) {
            1 => _buildCustomers(customers, accounts),
            2 => _buildCollection(collection),
            _ => _buildDebtors(accounts),
          },
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
        final overdue = items.where((item) => item.isOverdue).length;
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
                          if (overdue > 0) ...[
                            AppBadge(
                              '$overdue ${overdue == 1 ? 'vencida' : 'vencidas'}',
                              variant: AppBadgeVariant.error,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
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

  Widget _buildCollection(AsyncValue<List<CollectionGroup>> collection) {
    return collection.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('No se pudo cargar la cobranza: $error'),
      ),
      data: (groups) {
        final total = groups.fold<double>(0, (sum, g) => sum + g.balance);
        final overdueGroups = groups.where((g) => g.isOverdue).toList();
        final dueSoonGroups = groups.where((g) => g.isDueSoon).toList();
        final overdueTotal = overdueGroups.fold<double>(
          0,
          (sum, g) => sum + g.balance,
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _CollectionStat(
                    label: 'Vencidas',
                    value: Money.usd(overdueTotal),
                    detail: TextoPlural.de(
                      overdueGroups.length,
                      'cliente vencido',
                      'clientes vencidos',
                    ),
                    color: AppColors.error,
                  ),
                  _CollectionStat(
                    label: 'Por vencer (3 días)',
                    value: Money.usd(
                      dueSoonGroups.fold<double>(
                        0,
                        (sum, g) => sum + g.balance,
                      ),
                    ),
                    detail: TextoPlural.de(
                      dueSoonGroups.length,
                      'cliente por vencer',
                      'clientes por vencer',
                    ),
                    color: AppColors.warning,
                  ),
                  _CollectionStat(
                    label: 'Total en cobranza',
                    value: Money.usd(total),
                    detail: TextoPlural.de(
                      groups.length,
                      'cliente',
                      'clientes',
                    ),
                    color: AppColors.tertiary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: groups.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 56,
                            color: AppColors.success,
                          ),
                          SizedBox(height: AppSpacing.md),
                          AppText(
                            'No hay nada por cobrar',
                            variant: AppTextVariant.titleMedium,
                          ),
                          SizedBox(height: AppSpacing.xs),
                          AppText(
                            'Las cuentas vencidas aparecerán aquí.',
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
                      itemCount: groups.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return _CollectionRow(
                          group: group,
                          onTap: () => context.push(
                            '/cuenta/${group.customer.id}',
                          ),
                          onRemind: () => _remind(group),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _remind(CollectionGroup group) async {
    if (group.customer.phone.trim().isEmpty) {
      _showSnack(
        'Agrega el teléfono de ${group.customer.name} para recordarle',
      );
      return;
    }

    final settings =
        ref.read(settingsProvider).valueOrNull ?? BusinessSettings.initial();
    final message = WhatsAppStatement.buildReminder(
      settings: settings,
      customer: group.customer,
      accounts: group.accounts,
    );
    final opened = await WhatsAppStatement.open(
      phone: group.customer.phone,
      message: message,
    );

    if (!opened) {
      _showSnack('No se pudo abrir WhatsApp. Verifica que esté instalado.');
      return;
    }

    final repository = ref.read(accountRepositoryProvider);
    for (final account in group.accounts) {
      await repository.markReminder(account.id);
    }
    ref.invalidate(collectionProvider);
    ref.invalidate(customerAccountsProvider(group.customer.id));
    _showSnack('Recordatorio preparado para ${group.customer.name}');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

class _CollectionStat extends StatelessWidget {
  const _CollectionStat({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              label,
              variant: AppTextVariant.caption,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppText(
              value,
              variant: AppTextVariant.titleLarge,
              color: color,
            ),
            const SizedBox(height: 2),
            AppText(
              detail,
              variant: AppTextVariant.caption,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.group,
    required this.onTap,
    required this.onRemind,
  });

  final CollectionGroup group;
  final VoidCallback onTap;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final due = group.dueDate;
    final now = DateTime.now();
    String status;
    Color statusColor;
    if (group.isOverdue) {
      status = 'Vencida hace '
          '${group.overdueDays} ${group.overdueDays == 1 ? 'día' : 'días'}';
      statusColor = AppColors.error;
    } else if (due == null) {
      status = 'Sin vencimiento';
      statusColor = AppColors.textSecondary;
    } else {
      final days = DateTime(due.year, due.month, due.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      if (days == 0) {
        status = 'Vence hoy';
        statusColor = AppColors.warning;
      } else {
        status = 'Vence en $days ${days == 1 ? 'día' : 'días'} '
            '(${Money.date(due)})';
        statusColor = AppColors.textSecondary;
      }
    }

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
              backgroundColor: group.isOverdue
                  ? AppColors.errorContainer
                  : AppColors.tertiaryContainer,
              child: Text(
                group.customer.name.isEmpty
                    ? '?'
                    : group.customer.name[0].toUpperCase(),
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
                    group.customer.name,
                    variant: AppTextVariant.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    status,
                    variant: AppTextVariant.caption,
                    color: statusColor,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  Money.usd(group.balance),
                  variant: AppTextVariant.titleSmall,
                  color: AppColors.error,
                ),
                AppText(
                  TextoPlural.de(
                    group.openAccounts,
                    'cuenta',
                    'cuentas',
                  ),
                  variant: AppTextVariant.caption,
                  color: AppColors.textHint,
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: 'Recordar por WhatsApp',
              onPressed: onRemind,
              icon: const Icon(
                Icons.chat_outlined,
                color: AppColors.primary,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
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
                  Row(
                    children: [
                      Flexible(
                        child: AppText(
                          summary.customer.name,
                          variant: AppTextVariant.titleSmall,
                        ),
                      ),
                      if (summary.isOverdue) ...[
                        const SizedBox(width: AppSpacing.sm),
                        AppBadge(
                          'Vencida ${summary.overdueDays}d',
                          variant: AppBadgeVariant.error,
                          size: AppBadgeSize.small,
                        ),
                      ],
                    ],
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
