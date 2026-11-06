import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/settings/pages/onboarding_page.dart';
import '../../features/settings/providers/settings_providers.dart';
import '../../shared/widgets/atoms/app_button.dart';
import '../../shared/widgets/atoms/app_text.dart';
import 'main_shell.dart';

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return settings.when(
      loading: () => const _SplashScreen(),
      error: (error, stack) => _ErrorScreen(
        message: error.toString(),
        onRetry: () => ref.invalidate(settingsProvider),
      ),
      data: (value) {
        if (!value.onboarded) {
          return OnboardingPage(settings: value);
        }
        return const MainShell();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NovusMark(size: 72),
            SizedBox(height: AppSpacing.lg),
            AppText(
              'Novus',
              variant: AppTextVariant.headlineMedium,
            ),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              const AppText(
                'No se pudo abrir la base de datos',
                variant: AppTextVariant.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppText(
                message,
                variant: AppTextVariant.bodySmall,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton('Reintentar', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

class _NovusMark extends StatelessWidget {
  const _NovusMark({this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        'N',
        style: TextStyle(
          color: AppColors.onPrimary,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
