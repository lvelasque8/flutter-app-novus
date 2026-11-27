import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../features/cash/models/cash_session.dart';
import '../../shared/widgets/atoms/app_badge.dart';
import '../../shared/widgets/atoms/app_card.dart';
import '../../shared/widgets/atoms/app_text.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_common.dart';

class AdminCashPage extends StatelessWidget {
  const AdminCashPage({super.key, required this.data});

  final AdminData data;

  @override
  Widget build(BuildContext context) {
    final sessions = data.cashSessions;
    final open = sessions.where((session) => session.isOpen).toList();
    final lastClosed = sessions.where((session) => !session.isOpen).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AdminSectionHeader(
          title: 'Caja',
          subtitle: open.isEmpty
              ? 'Sin turno abierto'
              : 'Turno abierto desde ${Money.dateTime(open.first.openedAt)}',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (sessions.isEmpty)
          const AppCard(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: AdminEmpty(
              message: 'Todavía no hay turnos de caja',
              icon: Icons.point_of_sale_outlined,
            ),
          )
        else ...[
          if (open.isNotEmpty) ...[
            for (final session in open) _CashCard(session: session),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (lastClosed.isNotEmpty) ...[
            const AdminSectionHeader(
              title: 'Turnos cerrados',
              subtitle: 'Últimos 100',
            ),
            const SizedBox(height: AppSpacing.md),
            for (final session in lastClosed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _CashCard(session: session),
              ),
          ],
        ],
      ],
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.session});

  final CashSession session;

  @override
  Widget build(BuildContext context) {
    final differenceBs = session.differenceBs ?? 0;
    final differenceUsd = session.differenceUsd ?? 0;

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
                      'Turno del ${Money.dateTime(session.openedAt)}',
                      variant: AppTextVariant.titleSmall,
                    ),
                    if (session.closedAt != null)
                      AppText(
                        'Cerrado ${Money.dateTime(session.closedAt!)}',
                        variant: AppTextVariant.caption,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ),
              AppBadge(
                session.isOpen ? 'Abierta' : 'Cerrada',
                variant: session.isOpen
                    ? AppBadgeVariant.success
                    : AppBadgeVariant.outline,
                size: AppBadgeSize.small,
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 640;
              final items = <Widget>[
                _CashValue(
                  label: 'Fondo',
                  usd: Money.usd(session.openingUsd),
                  bs: Money.bs(session.openingBs),
                ),
                _CashValue(
                  label: 'Esperado',
                  usd: session.expectedUsd == null
                      ? '—'
                      : Money.usd(session.expectedUsd!),
                  bs: session.expectedBs == null
                      ? '—'
                      : Money.bs(session.expectedBs!),
                ),
                _CashValue(
                  label: 'Contado',
                  usd: session.countedUsd == null
                      ? '—'
                      : Money.usd(session.countedUsd!),
                  bs: session.countedBs == null
                      ? '—'
                      : Money.bs(session.countedBs!),
                ),
                _CashValue(
                  label: 'Diferencia',
                  usd: session.differenceUsd == null
                      ? '—'
                      : Money.usd(differenceUsd),
                  bs: session.differenceBs == null
                      ? '—'
                      : Money.bs(differenceBs),
                  color: differenceUsd.abs() < 0.005 &&
                          differenceBs.abs() < 0.005
                      ? AppColors.success
                      : AppColors.error,
                ),
              ];
              if (!wide) {
                return Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.md,
                  children: items,
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in items) Expanded(child: item),
                ],
              );
            },
          ),
          if (session.notes != null && session.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppText(
              'Nota: ${session.notes}',
              variant: AppTextVariant.caption,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _CashValue extends StatelessWidget {
  const _CashValue({
    required this.label,
    required this.usd,
    required this.bs,
    this.color,
  });

  final String label;
  final String usd;
  final String bs;
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
          usd,
          variant: AppTextVariant.titleSmall,
          color: color,
        ),
        AppText(
          bs,
          variant: AppTextVariant.caption,
          color: color ?? AppColors.textHint,
        ),
      ],
    );
  }
}
