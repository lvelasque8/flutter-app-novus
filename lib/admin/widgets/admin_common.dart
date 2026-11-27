import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/atoms/app_card.dart';
import '../../shared/widgets/atoms/app_text.dart';

enum AdminRange { today, week, month, all }

extension AdminRangeX on AdminRange {
  String get label {
    switch (this) {
      case AdminRange.today:
        return 'Hoy';
      case AdminRange.week:
        return '7 días';
      case AdminRange.month:
        return 'Este mes';
      case AdminRange.all:
        return 'Todo';
    }
  }

  bool contains(DateTime value, DateTime now) {
    switch (this) {
      case AdminRange.all:
        return true;
      case AdminRange.today:
        final start = DateTime(now.year, now.month, now.day);
        return !value.isBefore(start);
      case AdminRange.week:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        return !value.isBefore(start);
      case AdminRange.month:
        return value.year == now.year && value.month == now.month;
    }
  }
}

class AdminRangeSelector extends StatelessWidget {
  const AdminRangeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AdminRange value;
  final ValueChanged<AdminRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final range in AdminRange.values)
          ChoiceChip(
            label: Text(range.label),
            selected: value == range,
            onSelected: (_) => onChanged(range),
          ),
      ],
    );
  }
}

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.color = AppColors.primary,
    this.icon,
  });

  final String label;
  final String value;
  final String? detail;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: AppText(
                  label,
                  variant: AppTextVariant.caption,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            value,
            variant: AppTextVariant.titleLarge,
            color: color,
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            AppText(
              detail!,
              variant: AppTextVariant.caption,
              color: AppColors.textHint,
            ),
          ],
        ],
      ),
    );
  }
}

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(title, variant: AppTextVariant.titleMedium),
              if (subtitle != null)
                AppText(
                  subtitle!,
                  variant: AppTextVariant.caption,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AdminEmpty extends StatelessWidget {
  const AdminEmpty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.md),
            AppText(
              message,
              variant: AppTextVariant.bodySmall,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
