import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/feedback/error_banner.dart';
import '../widgets/auth_layout.dart';

/// Onde cai o link do e-mail de "esqueci minha senha".
///
/// O Firebase manda o link para a raiz do app com `?mode=resetPassword&
/// oobCode=...` (ver `ResetLink`), e o router traz para cá. A tela confere
/// o código antes de mostrar o formulário: link vencido ou já usado vira
/// uma explicação, não um formulário que falha só no fim.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late final Future<String> _email =
      ref.read(authServiceProvider).verifyPasswordResetCode(widget.code);

  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save(String email) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final auth = ref.read(authServiceProvider);
    try {
      await auth.confirmPasswordReset(
        code: widget.code,
        newPassword: _passwordController.text,
      );
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
      return;
    }

    // Já entra com a senha nova: pedir para digitá-la de novo logo depois
    // de criá-la seria só atrito. Se o login falhar por qualquer motivo, a
    // senha já está trocada — basta mandar para a tela de login.
    try {
      await auth.signIn(email: email, password: _passwordController.text);
      if (mounted) {
        AppToast.success('Senha alterada', icon: Icons.check_circle_rounded);
        context.go(Routes.trips);
      }
    } on AuthFailure {
      if (mounted) {
        AppToast.success('Senha alterada. Entre com a senha nova.',
            icon: Icons.check_circle_rounded);
        context.go(Routes.auth);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      illustrated: false,
      child: FutureBuilder<String>(
        future: _email,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: Gap.xxl),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return _InvalidLink(
              message: error is AuthFailure
                  ? error.message
                  : 'Não deu para conferir o link. Tente de novo.',
            );
          }
          return _buildForm(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, String email) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Nova senha', style: context.text.headlineLarge),
          Gap.vXs,
          Text(
            'Para a conta $email',
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          Gap.vXl,
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            autofocus: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Nova senha',
              helperText: 'Mínimo de 6 caracteres',
              prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe a nova senha';
              if (v.length < 6) return 'A senha precisa ter ao menos 6 caracteres';
              return null;
            },
          ),
          Gap.vLg,
          TextFormField(
            controller: _confirmController,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(email),
            decoration: const InputDecoration(
              labelText: 'Repita a nova senha',
              prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
            ),
            validator: (v) =>
                v == _passwordController.text ? null : 'As senhas não são iguais',
          ),
          if (_error != null) ...[
            Gap.vLg,
            ErrorBanner(message: _error!),
          ],
          Gap.vXl,
          FilledButton(
            onPressed: _saving ? null : () => _save(email),
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onPrimary,
                    ),
                  )
                : const Text('Salvar e entrar'),
          ),
        ],
      ),
    );
  }
}

/// Link vencido, já usado ou cortado no meio pelo cliente de e-mail.
class _InvalidLink extends StatelessWidget {
  const _InvalidLink({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Link inválido', style: context.text.headlineLarge),
        Gap.vLg,
        ErrorBanner(message: message),
        Gap.vXl,
        FilledButton(
          onPressed: () => context.go(Routes.auth),
          child: const Text('Voltar para o login'),
        ),
      ],
    );
  }
}
