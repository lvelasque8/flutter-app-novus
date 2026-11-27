import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/atoms/app_button.dart';
import '../../shared/widgets/atoms/app_card.dart';
import '../../shared/widgets/atoms/app_text.dart';
import '../../shared/widgets/atoms/app_text_field.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Escribe el correo y la contraseña');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message.contains('Invalid login')
            ? 'Correo o contraseña incorrectos'
            : error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo conectar: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'N',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const AppText(
                  'Novus',
                  variant: AppTextVariant.headlineSmall,
                ),
                const SizedBox(height: 2),
                const AppText(
                  'Panel de consulta',
                  variant: AppTextVariant.bodySmall,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'Entrar',
                        variant: AppTextVariant.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const AppText(
                        'Usa la misma cuenta con la que conectaste la tablet.',
                        variant: AppTextVariant.bodySmall,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'Correo',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofocus: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Contraseña',
                        controller: _password,
                        obscureText: true,
                        onSubmitted: (_) => _signIn(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppText(
                          _error!,
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.error,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          'Entrar',
                          loading: _loading,
                          onPressed: _loading ? null : _signIn,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const AppText(
                  'Solo consulta. Para vender o editar, usa la tablet.',
                  variant: AppTextVariant.caption,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
