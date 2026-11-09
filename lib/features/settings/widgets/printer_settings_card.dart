import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../documents/data/thermal_printer_service.dart';
import '../models/business_settings.dart';

/// Configuración de la impresora térmica Bluetooth.
class PrinterSettingsCard extends StatefulWidget {
  const PrinterSettingsCard({super.key, required this.settings});

  final BusinessSettings settings;

  @override
  State<PrinterSettingsCard> createState() => _PrinterSettingsCardState();
}

class _PrinterSettingsCardState extends State<PrinterSettingsCard> {
  final _service = ThermalPrinterService();

  PrinterSettings _printer = const PrinterSettings();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final printer = await _service.load();
    if (!mounted) return;
    setState(() {
      _printer = printer;
      _loading = false;
    });
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickPrinter() async {
    setState(() => _busy = true);
    try {
      if (!await _service.ensurePermission()) {
        _show(
          'Novus necesita permiso de Bluetooth. Actívalo en Ajustes de '
          'Android → Aplicaciones → Novus → Permisos.',
        );
        return;
      }
      if (!await _service.isBluetoothOn()) {
        _show('Activa el Bluetooth de la tablet');
        return;
      }

      final devices = await _service.pairedDevices();
      if (!mounted) return;

      if (devices.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No hay impresoras emparejadas'),
            content: const Text(
              'Primero empareja la impresora desde los ajustes de Android:\n\n'
              'Ajustes → Bluetooth → Emparejar dispositivo.\n\n'
              'Luego vuelve aquí y elige la impresora.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        return;
      }

      final selected = await showDialog<PrinterSettings>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Elegir impresora'),
          children: [
            for (final device in devices)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(
                  context,
                  PrinterSettings(
                    name: device.name,
                    address: device.macAdress,
                    paperMm: _printer.paperMm,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.print_outlined, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name.isEmpty
                                ? 'Dispositivo sin nombre'
                                : device.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            device.macAdress,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

      if (selected == null) return;
      await _service.save(selected);
      if (!mounted) return;
      setState(() => _printer = selected);
      _show('Impresora guardada: ${selected.name}');
    } catch (error) {
      if (mounted) _show('No se pudo leer el Bluetooth: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePaper(int paperMm) async {
    final updated = _printer.copyWith(paperMm: paperMm);
    setState(() => _printer = updated);
    await _service.save(updated);
  }

  Future<void> _testPrint() async {
    setState(() => _busy = true);
    try {
      await _service.printTest(
        settings: widget.settings,
        printer: _printer,
      );
      if (mounted) _show('Ticket de prueba enviado');
    } catch (error) {
      if (mounted) {
        _show(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppCard(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Impresora térmica',
            variant: AppTextVariant.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppText(
            'Imprime el ticket directamente por Bluetooth. Empareja la '
            'impresora desde los ajustes de Android antes de elegirla aquí.',
            variant: AppTextVariant.bodySmall,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  _printer.isConfigured
                      ? Icons.print_outlined
                      : Icons.print_disabled_outlined,
                  color: _printer.isConfigured
                      ? AppColors.success
                      : AppColors.textHint,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        _printer.isConfigured
                            ? (_printer.name.isEmpty
                                ? 'Impresora configurada'
                                : _printer.name)
                            : 'Sin impresora configurada',
                        variant: AppTextVariant.titleSmall,
                      ),
                      if (_printer.isConfigured)
                        AppText(
                          _printer.address,
                          variant: AppTextVariant.caption,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _pickPrinter,
                  child: Text(
                    _printer.isConfigured ? 'Cambiar' : 'Elegir',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Ancho del papel',
                  variant: AppTextVariant.bodySmall,
                  color: AppColors.textSecondary,
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 58, label: Text('58 mm')),
                  ButtonSegment(value: 80, label: Text('80 mm')),
                ],
                selected: {_printer.paperMm},
                onSelectionChanged: (value) =>
                    _changePaper(value.first),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              'Imprimir prueba',
              variant: AppButtonVariant.secondary,
              icon: Icons.receipt_long_outlined,
              loading: _busy,
              onPressed:
                  !_printer.isConfigured || _busy ? null : _testPrint,
            ),
          ),
        ],
      ),
    );
  }
}
