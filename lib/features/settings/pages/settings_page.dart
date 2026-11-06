import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../../shared/widgets/atoms/app_text_field.dart';
import '../../accounts/providers/account_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../sales/providers/sale_providers.dart';
import '../data/settings_repository.dart';
import '../models/business_settings.dart';
import '../providers/settings_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _name = TextEditingController();
  final _rif = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _rate = TextEditingController();
  final _iva = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _rif.dispose();
    _phone.dispose();
    _address.dispose();
    _rate.dispose();
    _iva.dispose();
    super.dispose();
  }

  void _fill(BusinessSettings settings) {
    if (_loaded) return;
    _loaded = true;
    _name.text = settings.businessName;
    _rif.text = settings.rif;
    _phone.text = settings.phone;
    _address.text = settings.address;
    _rate.text = settings.rateBs > 0
        ? settings.rateBs.toStringAsFixed(2)
        : '';
    _iva.text = settings.ivaRate.toStringAsFixed(0);
  }

  Future<void> _save(BusinessSettings current) async {
    final name = _name.text.trim();
    final rate = Money.parse(_rate.text);
    if (name.isEmpty) {
      _show('Escribe el nombre del negocio');
      return;
    }
    if (rate <= 0) {
      _show('La tasa debe ser mayor que cero');
      return;
    }

    setState(() => _saving = true);
    try {
      await SettingsRepository().save(
        current.copyWith(
          businessName: name,
          rif: _rif.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          rateBs: rate,
          ivaRate: Money.parse(_iva.text).clamp(0, 100),
        ),
      );
      ref.invalidate(settingsProvider);
      if (mounted) _show('Ajustes guardados');
    } catch (error) {
      if (mounted) _show('No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar datos del negocio'),
        content: const Text(
          'Se eliminarán todas las ventas, productos, clientes y cuentas por '
          'cobrar de este dispositivo. La configuración del negocio se '
          'mantiene. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, borrar todo'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AppDatabase.instance.clearBusinessData();
    ref.invalidate(productsProvider);
    ref.invalidate(salesProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(todayTotalProvider);
    ref.invalidate(todayCountProvider);
    if (mounted) _show('Datos borrados');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        centerTitle: false,
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (value) {
          _fill(value);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'Datos del negocio',
                            variant: AppTextVariant.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            label: 'Nombre del negocio',
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'RIF',
                                  controller: _rif,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppTextField(
                                  label: 'Teléfono',
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            label: 'Dirección',
                            controller: _address,
                            textCapitalization:
                                TextCapitalization.sentences,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'Tasa BCV (Bs por USD)',
                                  controller: _rate,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppTextField(
                                  label: 'IVA (%)',
                                  controller: _iva,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              'Guardar cambios',
                              icon: Icons.save_outlined,
                              loading: _saving,
                              onPressed: _saving ? null : () => _save(value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'Datos y respaldo',
                            variant: AppTextVariant.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const AppText(
                            'Novus guarda todo en este dispositivo. '
                            'En una próxima versión podrás exportar un respaldo '
                            'para moverlo a otra tablet.',
                            variant: AppTextVariant.bodySmall,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              'Borrar ventas, productos y clientes',
                              variant: AppButtonVariant.danger,
                              icon: Icons.delete_forever_outlined,
                              onPressed: _confirmClear,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: AppText(
                        'Novus 1.0.0 · Control de inventario y ventas\n'
                        'Documentos no fiscales',
                        variant: AppTextVariant.caption,
                        color: AppColors.textHint,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
