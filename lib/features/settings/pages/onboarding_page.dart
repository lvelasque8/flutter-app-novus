import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../../shared/widgets/atoms/app_text_field.dart';
import '../../rates/data/exchange_rate_service.dart';
import '../../rates/providers/rate_providers.dart';
import '../data/settings_repository.dart';
import '../models/business_settings.dart';
import '../providers/settings_providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, required this.settings});

  final BusinessSettings settings;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final TextEditingController _name;
  late final TextEditingController _rif;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _rate;
  late final TextEditingController _iva;
  bool _saving = false;
  bool _updatingRate = false;
  String _rateSource = 'manual';
  DateTime? _rateUpdatedAt;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.settings.businessName);
    _rif = TextEditingController(text: widget.settings.rif);
    _address = TextEditingController(text: widget.settings.address);
    _phone = TextEditingController(text: widget.settings.phone);
    _rate = TextEditingController(
      text: widget.settings.rateBs > 0
          ? widget.settings.rateBs.toStringAsFixed(2)
          : '',
    );
    _iva = TextEditingController(
      text: widget.settings.ivaRate.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _rif.dispose();
    _address.dispose();
    _phone.dispose();
    _rate.dispose();
    _iva.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _name.text.trim();
    final rate = Money.parse(_rate.text);
    final iva = Money.parse(_iva.text);

    if (name.isEmpty) {
      _showError('Escribe el nombre del negocio');
      return;
    }
    if (rate <= 0) {
      _showError('Indica la tasa de cambio en bolívares por dólar');
      return;
    }

    setState(() => _saving = true);
    try {
      await SettingsRepository().save(
        widget.settings.copyWith(
          businessName: name,
          rif: _rif.text.trim(),
          address: _address.text.trim(),
          phone: _phone.text.trim(),
          rateBs: rate,
          ivaRate: iva.clamp(0, 100),
          rateUpdatedAt: _rateUpdatedAt ?? DateTime.now(),
          rateSource: _rateSource,
          onboarded: true,
        ),
      );
      ref.invalidate(settingsProvider);
    } catch (error) {
      if (mounted) _showError('No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _fetchRate() async {
    setState(() => _updatingRate = true);
    try {
      final result = await ExchangeRateService().updateRate();
      _rate.text = result.rateBs.toStringAsFixed(2);
      _rateSource = result.source;
      _rateUpdatedAt = DateTime.now();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tasa ${result.sourceLabel}: ${Money.bs(result.rateBs)}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showError('No se pudo obtener la tasa: $error');
      }
    } finally {
      if (mounted) setState(() => _updatingRate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainer,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'N',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AppText(
                    'Bienvenido a Novus',
                    variant: AppTextVariant.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const AppText(
                    'Configuremos tu negocio para empezar a vender.',
                    variant: AppTextVariant.bodyLarge,
                    color: AppColors.textSecondary,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
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
                          label: 'Nombre del negocio *',
                          hint: 'Ej: Bodega La Esquina',
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'RIF',
                                hint: 'J-12345678-9',
                                controller: _rif,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: AppTextField(
                                label: 'Teléfono',
                                hint: '0412-1234567',
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'Dirección',
                          hint: 'Ciudad, calle, local',
                          controller: _address,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const AppText(
                          'Ventas y moneda',
                          variant: AppTextVariant.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const AppText(
                          'Los precios se guardan en dólares y se muestran '
                          'también en bolívares con la tasa del día.',
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'Tasa BCV (Bs por USD) *',
                                hint: 'Ej: 36,50',
                                controller: _rate,
                                onChanged: (_) {
                                  if (_rateSource != 'manual') {
                                    setState(() => _rateSource = 'manual');
                                  }
                                },
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
                                hint: '16',
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
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                _rateUpdatedAt == null
                                    ? 'Puedes escribirla manualmente o traerla '
                                        'del BCV si tienes internet.'
                                    : 'Tasa ${rateSourceLabel(_rateSource)} '
                                        'actualizada hoy.',
                                variant: AppTextVariant.caption,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TextButton.icon(
                              onPressed:
                                  _updatingRate ? null : _fetchRate,
                              icon: _updatingRate
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.cloud_download_outlined,
                                      size: 18,
                                    ),
                              label: Text(
                                _updatingRate
                                    ? 'Consultando...'
                                    : 'Obtener tasa BCV',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            'Comenzar a usar Novus',
                            icon: Icons.arrow_forward,
                            iconPosition: AppButtonIconPosition.end,
                            loading: _saving,
                            onPressed: _saving ? null : _start,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AppText(
                    'Los datos se guardan en este dispositivo. '
                    'No necesitas internet para vender.',
                    variant: AppTextVariant.caption,
                    color: AppColors.textHint,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
