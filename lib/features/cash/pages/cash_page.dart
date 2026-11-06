import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../../shared/widgets/atoms/app_text_field.dart';
import '../../sales/models/sale.dart';
import '../models/cash_session.dart';
import '../providers/cash_providers.dart';

class CashPage extends ConsumerStatefulWidget {
  const CashPage({super.key});

  @override
  ConsumerState<CashPage> createState() => _CashPageState();
}

class _CashPageState extends ConsumerState<CashPage> {
  final _openingBs = TextEditingController();
  final _openingUsd = TextEditingController();
  final _notes = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _openingBs.dispose();
    _openingUsd.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() => _working = true);
    try {
      await ref.read(cashRepositoryProvider).openSession(
            openingBs: Money.parse(_openingBs.text),
            openingUsd: Money.parse(_openingUsd.text),
            notes: _notes.text.trim(),
          );
      _openingBs.clear();
      _openingUsd.clear();
      _notes.clear();
      ref.invalidate(openCashSessionProvider);
      ref.invalidate(cashSummaryProvider);
      ref.invalidate(cashHistoryProvider);
      if (mounted) _show('Caja abierta');
    } catch (error) {
      if (mounted) _show('$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _close(CashSessionSummary summary) async {
    final data = await showDialog<_CloseData>(
      context: context,
      builder: (context) => _CloseDialog(summary: summary),
    );
    if (data == null) return;

    setState(() => _working = true);
    try {
      final closed = await ref.read(cashRepositoryProvider).closeSession(
            countedBs: data.countedBs,
            countedUsd: data.countedUsd,
            notes: data.notes,
          );
      ref.invalidate(openCashSessionProvider);
      ref.invalidate(cashSummaryProvider);
      ref.invalidate(cashHistoryProvider);
      if (mounted) {
        await _showCloseResult(closed);
      }
    } catch (error) {
      if (mounted) _show('$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showCloseResult(CashSession session) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Caja cerrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultRow(
              label: 'Diferencia en bolívares',
              value: Money.bs(session.differenceBs ?? 0),
              isGood: (session.differenceBs ?? 0) >= 0,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ResultRow(
              label: 'Diferencia en dólares',
              value: Money.usd(session.differenceUsd ?? 0),
              isGood: (session.differenceUsd ?? 0) >= 0,
            ),
            const SizedBox(height: AppSpacing.md),
            const AppText(
              'El cierre queda guardado en el historial de caja.',
              variant: AppTextVariant.caption,
              color: AppColors.textSecondary,
            ),
          ],
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

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(openCashSessionProvider);
    final summaryAsync = ref.watch(cashSummaryProvider);
    final history = ref.watch(cashHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja'),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: sessionAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('No se pudo cargar la caja: $error'),
            ),
            data: (session) {
              if (session == null) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _buildOpenCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildHistory(history.valueOrNull ?? []),
                  ],
                );
              }

              final summary = summaryAsync.valueOrNull;
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _buildOpenSessionCard(session, summary),
                  const SizedBox(height: AppSpacing.lg),
                  _buildHistory(history.valueOrNull ?? []),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOpenCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.point_of_sale_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Abrir caja',
                      variant: AppTextVariant.titleLarge,
                    ),
                    AppText(
                      'Registra el fondo con el que empiezas el turno.',
                      variant: AppTextVariant.bodySmall,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Fondo inicial en Bs',
                  hint: '0,00',
                  controller: _openingBs,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  label: 'Fondo inicial en USD',
                  hint: '0,00',
                  controller: _openingUsd,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Nota (opcional)',
            controller: _notes,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              'Abrir caja',
              icon: Icons.lock_open_outlined,
              loading: _working,
              onPressed: _working ? null : _open,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenSessionCard(
    CashSession session,
    CashSessionSummary? summary,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Caja abierta',
                      variant: AppTextVariant.titleLarge,
                    ),
                  ],
                ),
              ),
              const AppBadge(
                'Turno en curso',
                variant: AppBadgeVariant.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            'Desde ${Money.dateTime(session.openedAt)}',
            variant: AppTextVariant.bodySmall,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (summary == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _MoneyCard(
                  label: 'Ventas del turno',
                  value: Money.usd(summary.salesTotalUsd),
                  detail: '${summary.salesCount} ventas · '
                      '${Money.bs(summary.salesTotalBs)}',
                ),
                _MoneyCard(
                  label: 'Efectivo esperado Bs',
                  value: Money.bs(summary.expectedBs),
                  detail: 'Fondo ${Money.bs(session.openingBs)} + ventas',
                ),
                _MoneyCard(
                  label: 'Efectivo esperado USD',
                  value: Money.usd(summary.expectedUsd),
                  detail: 'Fondo ${Money.usd(session.openingUsd)} + ventas',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppText(
              'Cobros del turno',
              variant: AppTextVariant.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (summary.salesByMethod.isEmpty)
              const AppText(
                'Todavía no hay ventas en este turno.',
                variant: AppTextVariant.bodySmall,
                color: AppColors.textSecondary,
              )
            else
              ...summary.salesByMethod.entries.map(
                (entry) => _MethodRow(
                  method: entry.key,
                  amount: entry.value,
                  count: 0,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                'Cerrar caja',
                variant: AppButtonVariant.danger,
                icon: Icons.lock_outline,
                loading: _working,
                onPressed: _working ? null : () => _close(summary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistory(List<CashSession> sessions) {
    final closed = sessions.where((session) => !session.isOpen).toList();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Historial de cierres',
            variant: AppTextVariant.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          if (closed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: AppText(
                'Todavía no hay cierres de caja.',
                variant: AppTextVariant.bodySmall,
                color: AppColors.textSecondary,
              ),
            )
          else
            ...closed.map(
              (session) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            Money.dateTime(session.closedAt ??
                                session.openedAt),
                            variant: AppTextVariant.bodyMedium,
                          ),
                          AppText(
                            'Esperado ${Money.usd(session.expectedUsd ?? 0)} · '
                            'Contado ${Money.usd(session.countedUsd ?? 0)}',
                            variant: AppTextVariant.caption,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppText(
                          Money.usd(session.differenceUsd ?? 0),
                          variant: AppTextVariant.titleSmall,
                          color: (session.differenceUsd ?? 0) >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const AppText(
                          'diferencia USD',
                          variant: AppTextVariant.caption,
                          color: AppColors.textHint,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            variant: AppTextVariant.caption,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 4),
          AppText(value, variant: AppTextVariant.titleLarge),
          const SizedBox(height: 2),
          AppText(
            detail,
            variant: AppTextVariant.caption,
            color: AppColors.textHint,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.amount,
    required this.count,
  });

  final String method;
  final double amount;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              PaymentMethods.label(method),
              variant: AppTextVariant.bodySmall,
            ),
          ),
          AppText(
            Money.usd(amount),
            variant: AppTextVariant.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.isGood,
  });

  final String label;
  final String value;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            color: isGood ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CloseData {
  const _CloseData({
    required this.countedBs,
    required this.countedUsd,
    required this.notes,
  });

  final double countedBs;
  final double countedUsd;
  final String notes;
}

class _CloseDialog extends StatefulWidget {
  const _CloseDialog({required this.summary});

  final CashSessionSummary summary;

  @override
  State<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<_CloseDialog> {
  final _bs = TextEditingController();
  final _usd = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _bs.dispose();
    _usd.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Cerrar caja'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Efectivo esperado: ${Money.bs(widget.summary.expectedBs)} y '
              '${Money.usd(widget.summary.expectedUsd)}',
              variant: AppTextVariant.bodySmall,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Efectivo contado en Bs',
              hint: '0,00',
              controller: _bs,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Efectivo contado en USD',
              hint: '0,00',
              controller: _usd,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nota (opcional)',
              controller: _notes,
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
        AppButton(
          'Cerrar caja',
          onPressed: () => Navigator.pop(
            context,
            _CloseData(
              countedBs: Money.parse(_bs.text),
              countedUsd: Money.parse(_usd.text),
              notes: _notes.text.trim(),
            ),
          ),
        ),
      ],
    );
  }
}
