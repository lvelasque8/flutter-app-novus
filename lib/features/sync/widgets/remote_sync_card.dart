import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../pages/remote_sync_page.dart';
import '../providers/remote_sync_providers.dart';

class RemoteSyncCard extends ConsumerWidget {
  const RemoteSyncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(remoteSyncControllerProvider);
    final pending = state.pending;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Panel remoto',
                  variant: AppTextVariant.titleLarge,
                ),
              ),
              AppBadge(
                state.signedIn ? 'Conectado' : 'Sin conectar',
                variant: state.signedIn
                    ? AppBadgeVariant.success
                    : AppBadgeVariant.outline,
                size: AppBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            state.signedIn
                ? 'Consulta ventas, cuentas, inventario y caja desde tu '
                      'teléfono o computadora. Última subida: '
                      '${state.lastSyncAt == null ? 'pendiente' : Money.dateTime(state.lastSyncAt!)}'
                      '${pending == 0 ? '.' : ' · $pending por subir.'}'
                : 'Conecta la tablet para consultar el negocio desde el '
                      'panel web. La tablet sigue siendo la única que vende y '
                      'edita.',
            variant: AppTextVariant.bodySmall,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const RemoteSyncPage(),
                ),
              ),
              icon: Icon(
                state.signedIn
                    ? Icons.tune_outlined
                    : Icons.cloud_outlined,
                size: 18,
              ),
              label: Text(
                state.signedIn ? 'Ver estado' : 'Conectar panel remoto',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
