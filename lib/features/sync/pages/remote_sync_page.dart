import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/remote_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../../shared/widgets/atoms/app_text_field.dart';
import '../providers/remote_sync_providers.dart';

class RemoteSyncPage extends ConsumerStatefulWidget {
  const RemoteSyncPage({super.key});

  @override
  ConsumerState<RemoteSyncPage> createState() => _RemoteSyncPageState();
}

class _RemoteSyncPageState extends ConsumerState<RemoteSyncPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _connecting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      _show('Escribe el correo y la contraseña');
      return;
    }

    setState(() => _connecting = true);
    final ok = await ref
        .read(remoteSyncControllerProvider.notifier)
        .signIn(email: email, password: _password.text);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (ok) {
      _password.clear();
      _show('Conectado. Los datos ya se están subiendo.');
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(remoteSyncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel remoto'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: state.signedIn
                        ? _buildConnected(state)
                        : _buildLogin(state),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogin(RemoteSyncState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Consultar el negocio desde el panel web',
          variant: AppTextVariant.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppText(
          'Conecta esta tablet con tu cuenta para ver ventas, cuentas por '
          'cobrar, inventario y caja desde el teléfono o la computadora. La '
          'tablet sigue siendo la única que vende y edita.',
          variant: AppTextVariant.bodySmall,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Correo',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Contraseña',
          controller: _password,
          obscureText: true,
          onSubmitted: (_) => _connect(),
        ),
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppText(
            state.error!,
            variant: AppTextVariant.bodySmall,
            color: AppColors.error,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            'Conectar',
            icon: Icons.cloud_upload_outlined,
            loading: _connecting || state.syncing,
            onPressed: _connecting || state.syncing ? null : _connect,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppText(
          'Los datos se guardan en tu proyecto de Supabase. El panel es de '
          'solo lectura.',
          variant: AppTextVariant.caption,
          color: AppColors.textHint,
        ),
      ],
    );
  }

  Widget _buildConnected(RemoteSyncState state) {
    final pending = state.pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_done_outlined, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: AppText(
                'Panel remoto conectado',
                variant: AppTextVariant.titleLarge,
              ),
            ),
            AppButton(
              'Sincronizar ahora',
              variant: AppButtonVariant.secondary,
              icon: Icons.sync,
              size: AppButtonSize.small,
              loading: state.syncing,
              onPressed: state.syncing
                  ? null
                  : () => ref
                        .read(remoteSyncControllerProvider.notifier)
                        .syncNow(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _StatusRow(label: 'Cuenta', value: state.email ?? '—'),
        _StatusRow(
          label: 'Última sincronización',
          value: state.lastSyncAt == null
              ? 'Todavía no se ha subido nada'
              : Money.dateTime(state.lastSyncAt!),
        ),
        _StatusRow(
          label: 'Cambios pendientes',
          value: pending == 0
              ? 'Todo al día'
              : '$pending ${pending == 1 ? 'cambio' : 'cambios'}',
        ),
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppText(
            state.error!,
            variant: AppTextVariant.bodySmall,
            color: AppColors.error,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (pending > 0)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: AppText(
              'Los cambios se reintentan solos cada 10 minutos y al abrir la '
              'app. También puedes usar “Sincronizar ahora”.',
              variant: AppTextVariant.caption,
              color: AppColors.textSecondary,
            ),
          ),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            if (RemoteConfig.panelUrl.isNotEmpty)
              AppButton(
                'Abrir panel',
                variant: AppButtonVariant.secondary,
                icon: Icons.open_in_new,
                onPressed: () => launchUrl(
                  Uri.parse(RemoteConfig.panelUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            TextButton(
              onPressed: () => _confirmDisconnect(state),
              child: const Text('Desconectar'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDisconnect(RemoteSyncState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desconectar el panel remoto'),
        content: const Text(
          'La tablet dejará de subir datos. Lo que ya está en el panel se '
          'mantiene hasta que vuelvas a conectar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(remoteSyncControllerProvider.notifier).signOut();
    if (mounted) {
      _show('Panel remoto desconectado');
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: AppText(
              label,
              variant: AppTextVariant.bodySmall,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: AppText(value, variant: AppTextVariant.bodyMedium),
          ),
        ],
      ),
    );
  }
}
