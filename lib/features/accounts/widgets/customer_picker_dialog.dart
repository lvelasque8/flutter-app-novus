import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_search_field.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../models/account.dart';
import '../providers/account_providers.dart';
import 'customer_form_dialog.dart';

Future<Customer?> showCustomerPicker(BuildContext context) {
  return showDialog<Customer?>(
    context: context,
    builder: (context) => const _CustomerPickerDialog(),
  );
}

class _CustomerPickerDialog extends ConsumerStatefulWidget {
  const _CustomerPickerDialog();

  @override
  ConsumerState<_CustomerPickerDialog> createState() =>
      _CustomerPickerDialogState();
}

class _CustomerPickerDialogState
    extends ConsumerState<_CustomerPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);

    return AlertDialog(
      title: const Text('Seleccionar cliente'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    hint: 'Buscar cliente...',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: 'Nuevo cliente',
                  onPressed: () async {
                    final created =
                        await showCustomerFormDialog(context);
                    if (created != null && context.mounted) {
                      Navigator.pop(context, created);
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: customers.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text('Error: $error'),
                ),
                data: (items) {
                  final filtered = _query.isEmpty
                      ? items
                      : items.where((customer) {
                          final query = _query.toLowerCase();
                          return customer.name.toLowerCase().contains(query) ||
                              customer.document
                                  .toLowerCase()
                                  .contains(query) ||
                              customer.phone.toLowerCase().contains(query);
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const AppText(
                            'No hay clientes',
                            variant: AppTextVariant.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            'Crear cliente',
                            icon: Icons.person_add_alt_1,
                            onPressed: () async {
                              final created =
                                  await showCustomerFormDialog(context);
                              if (created != null && context.mounted) {
                                Navigator.pop(context, created);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
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
                            if (customer.document.isNotEmpty)
                              customer.document,
                            if (customer.phone.isNotEmpty) customer.phone,
                          ].join(' · '),
                        ),
                        onTap: () => Navigator.pop(context, customer),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
