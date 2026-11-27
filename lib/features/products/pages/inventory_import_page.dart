import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_switch.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../sync/providers/remote_sync_providers.dart';
import '../data/inventory_import.dart';
import '../providers/product_providers.dart';

class InventoryImportPage extends ConsumerStatefulWidget {
  const InventoryImportPage({super.key});

  @override
  ConsumerState<InventoryImportPage> createState() =>
      _InventoryImportPageState();
}

class _InventoryImportPageState extends ConsumerState<InventoryImportPage> {
  final _service = InventoryImportService();

  InventoryImportPreview? _preview;
  String? _fileName;
  String? _error;
  bool _loading = false;
  bool _importing = false;
  bool _updateExisting = true;

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;

      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw const InventoryImportException('No se pudo leer el archivo');
      }

      final preview = _service.parse(bytes);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _fileName = file.name;
      });
    } on InventoryImportException catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _error = 'No se pudo abrir el Excel: $error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final bytes = await Future<Uint8List>.value(_service.buildTemplate());
      final directory = await getTemporaryDirectory();
      final file = File(
        p.join(directory.path, 'plantilla-inventario-novus.xlsx'),
      );
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Plantilla de inventario Novus',
        text: 'Plantilla para importar inventario desde Excel.',
      );
    } catch (error) {
      _show('No se pudo generar la plantilla: $error');
    }
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null) return;

    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(productRepositoryProvider)
          .importRows(
            preview.valid,
            updateExisting: _updateExisting,
          );

      ref.invalidate(productsProvider);
      ref.invalidate(activeProductsProvider);
      ref.invalidate(productSearchProvider);
      ref.invalidate(dashboardProvider);
      ref.read(remoteSyncControllerProvider.notifier).requestSync();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Importación completada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nuevos: ${result.created}'),
              Text('Actualizados: ${result.updated}'),
              if (result.unchanged > 0)
                Text('Sin cambios de stock: ${result.unchanged}'),
              if (result.skipped > 0)
                Text('Omitidos: ${result.skipped}'),
              Text('Ajustes de stock registrados: ${result.adjustments}'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar inventario'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'Inventario desde Excel',
                          variant: AppTextVariant.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const AppText(
                          'Sube un archivo .xlsx con tus productos. Los '
                          'existentes se actualizan por código de barras, SKU '
                          'o nombre; los nuevos se crean. El stock se ajusta '
                          'con su movimiento registrado.',
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            AppButton(
                              _loading ? 'Leyendo...' : 'Elegir Excel',
                              icon: Icons.upload_file_outlined,
                              loading: _loading,
                              onPressed: _loading ? null : _pickFile,
                            ),
                            AppButton(
                              'Descargar plantilla',
                              variant: AppButtonVariant.secondary,
                              icon: Icons.download_outlined,
                              onPressed: _downloadTemplate,
                            ),
                          ],
                        ),
                        if (_fileName != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AppText(
                                  _fileName!,
                                  variant: AppTextVariant.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppText(
                            _error!,
                            variant: AppTextVariant.bodySmall,
                            color: AppColors.error,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _PreviewCard(preview: preview),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSwitch(
                            label: 'Actualizar productos existentes',
                            value: _updateExisting,
                            onChanged: (value) =>
                                setState(() => _updateExisting = value),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppText(
                            _updateExisting
                                ? 'Las filas que coincidan con un producto '
                                      'actualizan precio, costo, stock y '
                                      'demás datos. Si un campo viene vacío, '
                                      'se conserva el actual.'
                                : 'Solo se crearán productos nuevos. Los que '
                                      'ya existen se omiten.',
                            variant: AppTextVariant.caption,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              preview.validCount == 1
                                  ? 'Importar 1 producto'
                                  : 'Importar ${preview.validCount} productos',
                              icon: Icons.cloud_upload_outlined,
                              loading: _importing,
                              onPressed:
                                  _importing || preview.validCount == 0
                                  ? null
                                  : _apply,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final InventoryImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final rows = preview.rows;
    final visible = rows.length > 80 ? rows.sublist(0, 80) : rows;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  'Vista previa',
                  variant: AppTextVariant.titleMedium,
                ),
              ),
              AppBadge(
                '${preview.validCount} listos',
                variant: AppBadgeVariant.success,
                size: AppBadgeSize.small,
              ),
              if (preview.errorCount > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  '${preview.errorCount} con error',
                  variant: AppBadgeVariant.error,
                  size: AppBadgeSize.small,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...visible.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: AppText(
                      '${row.line}',
                      variant: AppTextVariant.caption,
                      color: AppColors.textHint,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          row.name ?? '(sin nombre)',
                          variant: AppTextVariant.bodyMedium,
                        ),
                        AppText(
                          [
                            if (row.category != null) row.category!,
                            if (row.barcode != null) 'Código ${row.barcode}',
                            if (row.sku != null) 'SKU ${row.sku}',
                            if (row.price != null)
                              'Precio ${Money.usd(row.price!)}',
                            if (row.stock != null) 'Stock ${row.stock}',
                          ].join(' · '),
                          variant: AppTextVariant.caption,
                          color: AppColors.textSecondary,
                        ),
                        if (row.error != null)
                          AppText(
                            row.error!,
                            variant: AppTextVariant.caption,
                            color: AppColors.error,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (rows.length > visible.length) ...[
            const SizedBox(height: AppSpacing.sm),
            AppText(
              'Y ${rows.length - visible.length} filas más…',
              variant: AppTextVariant.caption,
              color: AppColors.textHint,
            ),
          ],
        ],
      ),
    );
  }
}
