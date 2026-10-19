import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/widgets/feedback/error_banner.dart';
import '../widgets/auth_layout.dart';

enum AuthMode { signIn, signUp }

/// Entrada do app: e-mail e senha, ou a conta Google.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  /// O cartão troca para o pedido de link de nova senha.
  bool _forgot = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  bool get _isSignUp => _mode == AuthMode.signUp;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _mode = _isSignUp ? AuthMode.signIn : AuthMode.signUp;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      // Lido antes do `await`: a conta nasce logada, o router sai desta
      // tela e o `ref` de um widget descartado lança.
      final users = ref.read(userRepositoryProvider);
      if (_isSignUp) {
        final name = _nameController.text.trim();
        final user = await auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: name,
        );

        // A conta nasce logada, então `currentUserProvider` cria o espelho
        // antes de o Auth receber o nome — com o nome tirado do e-mail.
        // Aqui o nome escolhido entra no lugar dele (a ordem entre as duas
        // escritas é garantida pela fila do UserRepository).
        if (name.isNotEmpty) {
          await users.updateProfile(user.uid, displayName: name);
        }
      } else {
        await auth.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      // Daqui não navegamos: o router observa o Firebase Auth, e o
      // espelho em `users/{uid}` é criado por currentUserProvider.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Algo deu errado. Tente de novo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // Como no e-mail e senha: quem navega é o router.
    } on AuthCancelled {
      // Fechou a janela do Google. Nada a avisar.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Algo deu errado. Tente de novo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setForgot(bool forgot) {
    setState(() {
      _forgot = forgot;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: AnimatedSize(
        duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          child: _forgot
              ? _ForgotPasswordForm(
                  key: const ValueKey('forgot'),
                  emailController: _emailController,
                  onBack: () => _setForgot(false),
                )
              : KeyedSubtree(key: const ValueKey('login'), child: _buildForm(context)),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isSignUp ? 'Criar conta' : 'Entrar',
              style: context.text.headlineSmall,
            ),
            Gap.vXl,

            if (_isSignUp) ...[
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Seu nome',
                  hintText: 'Nome e sobrenome',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Diga seu nome'
                    : null,
              ),
              Gap.vLg,
            ],

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-mail',
                hintText: 'voce@email.com',
                prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Informe seu e-mail';
                final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                return ok ? null : 'E-mail inválido';
              },
            ),
            Gap.vLg,

            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: [
                _isSignUp ? AutofillHints.newPassword : AutofillHints.password
              ],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                ),
                helperText: _isSignUp ? 'Mínimo de 6 caracteres' : null,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe sua senha';
                if (_isSignUp && v.length < 6) {
                  return 'A senha precisa ter ao menos 6 caracteres';
                }
                return null;
              },
            ),

            if (!_isSignUp) ...[
              Gap.vMd,
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : () => _setForgot(true),
                  child: const Text('Esqueci minha senha'),
                ),
              ),
            ],

            if (_error != null) ...[
              Gap.vMd,
              ErrorBanner(message: _error!),
            ],

            Gap.vLg,
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.onPrimary,
                      ),
                    )
                  : Text(_isSignUp ? 'Criar conta' : 'Entrar'),
            ),
            Gap.vLg,
            const _OrDivider(),
            Gap.vLg,
            _GoogleButton(onPressed: _loading ? null : _signInWithGoogle),
            Gap.vMd,
            // `Wrap`, não `Row`: a pergunta e o botão passam
            // dos 264px do cartão em tela estreita, e mais
            // ainda com a fonte aumentada no navegador.
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              // Sem isto o fundo do botão, no hover, encosta na pergunta.
              spacing: Gap.sm,
              children: [
                Text(
                  _isSignUp ? 'Já tem conta?' : 'Ainda não tem conta?',
                  style: context.text.bodySmall,
                ),
                TextButton(
                  onPressed: _loading ? null : _switchMode,
                  child: Text(_isSignUp ? 'Entrar' : 'Criar agora'),
                ),
              ],
            ),
          ],
        ),
      );
  }
}

/// Só o e-mail e o botão de enviar. Depois do envio, o cartão vira a
/// confirmação — com o endereço à vista, para a pessoa conferir se digitou
/// certo.
///
/// O e-mail é o mesmo controlador do login: o que se digitou lá vem
/// preenchido aqui, e volta junto.
class _ForgotPasswordForm extends ConsumerStatefulWidget {
  const _ForgotPasswordForm({
    super.key,
    required this.emailController,
    required this.onBack,
  });

  final TextEditingController emailController;
  final VoidCallback onBack;

  @override
  ConsumerState<_ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends ConsumerState<_ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();

  bool _sending = false;
  String? _sentTo;
  String? _error;

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final email = widget.emailController.text.trim();
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) setState(() => _sentTo = email);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Algo deu errado. Tente de novo.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    if (sentTo != null) return _buildSent(context, sentTo);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Esqueci minha senha', style: context.text.headlineSmall),
          Gap.vXs,
          Text(
            'Digite o e-mail da sua conta e enviamos um link para criar uma senha nova.',
            style: context.text.bodySmall,
          ),
          Gap.vXl,
          TextFormField(
            controller: widget.emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              labelText: 'E-mail',
              hintText: 'voce@email.com',
              prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Informe seu e-mail';
              final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
              return ok ? null : 'E-mail inválido';
            },
          ),
          if (_error != null) ...[
            Gap.vLg,
            ErrorBanner(message: _error!),
          ],
          Gap.vXl,
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onPrimary,
                    ),
                  )
                : const Text('Enviar link'),
          ),
          Gap.vMd,
          TextButton(
            onPressed: _sending ? null : widget.onBack,
            child: const Text('Voltar para o login'),
          ),
        ],
      ),
    );
  }

  Widget _buildSent(BuildContext context, String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mark_email_read_rounded, size: 40, color: context.colors.primary),
        Gap.vLg,
        Text(
          'Confira seu e-mail',
          style: context.text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        Gap.vSm,
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Se existir uma conta com '),
              TextSpan(
                text: email,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(
                text: ', o link para criar a senha nova chega em instantes. '
                    'Olhe também a caixa de spam.',
              ),
            ],
          ),
          style: context.text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        Gap.vXl,
        FilledButton(
          onPressed: widget.onBack,
          child: const Text('Voltar para o login'),
        ),
        Gap.vSm,
        TextButton(
          onPressed: () => setState(() => _sentTo = null),
          child: const Text('Não recebi — enviar de novo'),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          child: Text('ou', style: context.text.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// O botão "Sign in with Google" nas cores e na fonte das diretrizes de
/// marca do Google: fundo branco (ou quase preto no tema escuro), borda
/// cinza, "G" colorido à esquerda e Roboto Medium. Desenhado em vez de
/// imagem para poder esticar até a largura do cartão sem deformar.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF131314) : Colors.white,
          foregroundColor: dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
          disabledForegroundColor:
              dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
          side: BorderSide(
            color: dark ? const Color(0xFF8E918F) : const Color(0xFF747775),
          ),
          textStyle: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/icons/google.svg', width: 18, height: 18),
            Gap.hMd,
            const Flexible(
              child: Text('Sign in with Google', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
