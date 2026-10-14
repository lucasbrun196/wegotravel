import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/trip.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/widgets/cards/glass_card.dart';
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/feedback/error_banner.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../../../shared/widgets/layout/app_page.dart';
import '../../../shared/widgets/layout/app_sheet.dart';
import '../../../shared/widgets/layout/section_header.dart';

/// Conta da pessoa logada: perfil, senha e exclusão do cadastro.
///
/// Vive fora do escopo de viagem — quem ainda não entrou em nenhuma
/// também precisa conseguir editar o próprio nome.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final hasPassword = ref.read(authServiceProvider).hasPassword;

    return AppPage(
      title: 'Sua conta',
      backgroundColor: context.theme.scaffoldBackgroundColor,
      leading: IconButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(Routes.trips),
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Voltar',
      ),
      children: [
        // ---------------- Perfil ----------------
        SectionHeader(
          title: 'Perfil',
          actionLabel: user == null ? null : 'Editar',
          onAction: user == null ? null : () => _editProfile(context, user),
        ),
        if (user == null)
          const ShimmerBox(height: 110, borderRadius: Radii.brLg)
        else
          GlassCard(
            child: Row(
              children: [
                InitialsAvatar(initials: user.initials, size: 40),
                Gap.hLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.displayName.isEmpty
                            ? AppUser.nameFromEmail(user.email)
                            : user.displayName,
                        style: context.text.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email,
                        style: context.text.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Gap.vXs,
                      Text(
                        hasPassword
                            ? 'O e-mail é o login e não muda aqui.'
                            : 'Você entra com a conta Google deste e-mail.',
                        style: context.text.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // ---------------- Segurança ----------------
        // Conta só do Google: não há senha para trocar nem redefinir.
        if (hasPassword) ...[
          Gap.vXl,
          const SectionHeader(title: 'Segurança'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showAppSheet(
                    context: context,
                    title: 'Trocar senha',
                    subtitle: 'Confirme a senha atual para mudar',
                    builder: (_) => const _PasswordSheet(),
                  ),
                  icon: const Icon(Icons.password, size: 18),
                  label: const Text('Trocar senha'),
                ),
                if (user != null) ...[
                  Gap.vSm,
                  TextButton(
                    onPressed: () => _sendResetLink(context, ref, user.email),
                    child: const Text('Receber link de redefinição por e-mail'),
                  ),
                ],
              ],
            ),
          ),
        ],

        // ---------------- Sessão ----------------
        Gap.vXl,
        const SectionHeader(title: 'Sessão'),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sair da conta'),
              ),
            ],
          ),
        ),

        // ---------------- Zona de risco ----------------
        Gap.vXl,
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Excluir a conta apaga seu cadastro e tira você de todas as '
                'viagens. Não dá para desfazer.',
                style: context.text.bodySmall,
              ),
              Gap.vMd,
              OutlinedButton.icon(
                onPressed: () => showAppSheet(
                  context: context,
                  title: 'Excluir sua conta',
                  subtitle: 'Isso não pode ser desfeito',
                  builder: (_) => const _DeleteAccountSheet(),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                icon: const Icon(Icons.person_remove_outlined, size: 18),
                label: const Text('Excluir minha conta'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext context, AppUser user) => showAppSheet(
        context: context,
        title: 'Seu perfil',
        subtitle: 'Vale para todas as suas viagens',
        builder: (_) => _ProfileSheet(user: user),
      );

  Future<void> _sendResetLink(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (context.mounted) {
        AppToast.success(
          'Link de redefinição enviado para $email',
          icon: Icons.mark_email_read_rounded,
        );
      }
    } on AuthFailure catch (e) {
      if (context.mounted) AppToast.error(e.message);
    }
  }
}

/// Nome do perfil, propagado para todas as viagens.
class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet({required this.user});

  final AppUser user;

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    try {
      final uid = widget.user.uid;
      await ref
          .read(userRepositoryProvider)
          .updateProfile(uid, displayName: name);

      // O Auth também guarda o nome, e é dele que `syncFromAuth` parte
      // no próximo login: sem isto o nome antigo voltaria sozinho.
      await ref.read(authServiceProvider).currentUser?.updateDisplayName(name);

      await ref
          .read(tripRepositoryProvider)
          .syncMemberProfile(uid: uid, name: name);

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success('Perfil atualizado', icon: Icons.check_circle_rounded);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não deu para salvar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Seu nome',
                      hintText: 'Nome e sobrenome',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Diga seu nome' : null,
                  ),
                  if (_error != null) ...[
                    Gap.vLg,
                    ErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
          ),
        ),
        SheetActions(
          primaryLabel: 'Salvar',
          onPrimary: _save,
          secondaryLabel: 'Cancelar',
          onSecondary: () => Navigator.of(context).pop(),
          isLoading: _saving,
        ),
      ],
    );
  }
}

/// Senha atual, nova e confirmação.
class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      await auth.reauthenticate(_currentController.text);
      await auth.updatePassword(_newController.text);

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success('Senha alterada', icon: Icons.check_circle_rounded);
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Algo deu errado. Tente de novo.';
        });
      }
    }
  }

  Widget _visibilityToggle() => IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
        ),
        tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _currentController,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Senha atual',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: _visibilityToggle(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Informe sua senha atual' : null,
                  ),
                  Gap.vLg,
                  TextFormField(
                    controller: _newController,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Nova senha',
                      helperText: 'Mínimo de 6 caracteres',
                      prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe a nova senha';
                      if (v.length < 6) {
                        return 'A senha precisa ter ao menos 6 caracteres';
                      }
                      if (v == _currentController.text) {
                        return 'A nova senha é igual à atual';
                      }
                      return null;
                    },
                  ),
                  Gap.vLg,
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscure,
                    onFieldSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      labelText: 'Repita a nova senha',
                      prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
                    ),
                    validator: (v) =>
                        v == _newController.text ? null : 'As senhas não são iguais',
                  ),
                  if (_error != null) ...[
                    Gap.vLg,
                    ErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
          ),
        ),
        SheetActions(
          primaryLabel: 'Salvar',
          onPrimary: _save,
          secondaryLabel: 'Cancelar',
          onSecondary: () => Navigator.of(context).pop(),
          isLoading: _saving,
        ),
      ],
    );
  }
}

/// Exclusão do cadastro.
///
/// Sem Cloud Functions a limpeza é feita aqui, e precisa acontecer antes
/// de apagar a conta do Auth — depois disso não há mais permissão para
/// escrever no Firestore.
class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  Future<List<Trip>>? _trips;
  late final bool _hasPassword = ref.read(authServiceProvider).hasPassword;
  bool _obscure = true;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final uid = ref.read(currentUidProvider);
    if (uid != null) _trips = ref.read(tripRepositoryProvider).myTripsOnce(uid);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete(List<Trip> trips) async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      // Quem só tem Google confirma escolhendo a conta de novo.
      await (_hasPassword
          ? auth.reauthenticate(_passwordController.text)
          : auth.reauthenticateWithGoogle());

      final tripRepo = ref.read(tripRepositoryProvider);
      for (final trip in trips) {
        await tripRepo.removeMember(trip.id, uid);
      }
      await ref.read(userRepositoryProvider).deleteUser(uid);
      await auth.deleteAccount();

      // Sem navegar: o `authStateProvider` cai para nulo e o router
      // leva sozinho para a tela de login.
    } on AuthCancelled {
      if (mounted) setState(() => _deleting = false);
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = 'Não deu para excluir a conta: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);

    return FutureBuilder<List<Trip>>(
      future: _trips,
      builder: (context, snapshot) {
        if (_trips == null || snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xxl),
            child: ShimmerBox(height: 120, borderRadius: Radii.brLg),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xxl),
            child: ErrorBanner(
              message: 'Não deu para conferir suas viagens: ${snapshot.error}',
            ),
          );
        }

        final trips = snapshot.data ?? const <Trip>[];
        final adminOf = trips.where((t) => t.isAdmin(uid)).toList();

        return adminOf.isEmpty
            ? _form(trips)
            : _blockedByAdminTrips(adminOf);
      },
    );
  }

  /// Não existe passar a viagem para outra pessoa: apagar o admin
  /// deixaria a viagem sem quem gerencia os participantes.
  Widget _blockedByAdminTrips(List<Trip> trips) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ErrorBanner(
                  message: 'Você administra viagens que ficariam sem dono. '
                      'Exclua cada uma antes de apagar sua conta.',
                ),
                Gap.vLg,
                for (final trip in trips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: Row(
                      children: [
                        const Icon(Icons.luggage_rounded, size: 18),
                        Gap.hMd,
                        Expanded(
                          child: Text(
                            trip.name,
                            style: context.text.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Gap.vMd,
                Text(
                  'Em cada viagem: aba Viagem → Excluir viagem.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ),
        SheetActions(
          primaryLabel: 'Entendi',
          onPrimary: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _form(List<Trip> trips) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    trips.isEmpty
                        ? 'Seu cadastro será apagado e você precisará criar '
                            'uma conta nova para voltar.'
                        : 'Você sai de ${trips.length} '
                            '${trips.length == 1 ? "viagem" : "viagens"} e seu '
                            'cadastro é apagado. As contas e cotas em que você '
                            'aparece continuam registradas para a turma.',
                    style: context.text.bodyMedium,
                  ),
                  if (_hasPassword) ...[
                    Gap.vXl,
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Senha atual',
                        helperText: 'Para confirmar que é você',
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
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                    ),
                  ] else ...[
                    Gap.vMd,
                    Text(
                      'Para confirmar que é você, o Google vai pedir que '
                      'escolha sua conta de novo.',
                      style: context.text.bodySmall,
                    ),
                  ],
                  if (_error != null) ...[
                    Gap.vLg,
                    ErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
          ),
        ),
        SheetActions(
          primaryLabel: 'Excluir conta',
          onPrimary: () => _delete(trips),
          secondaryLabel: 'Cancelar',
          onSecondary: () => Navigator.of(context).pop(),
          isLoading: _deleting,
          destructive: true,
        ),
      ],
    );
  }
}
