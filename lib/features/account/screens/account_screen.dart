import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/trip.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/widgets/cards/glass_card.dart';
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/feedback/error_banner.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../../../shared/widgets/inputs/theme_mode_picker.dart';
import '../../../shared/widgets/layout/app_page.dart';
import '../../../shared/widgets/layout/app_sheet.dart';

/// Conta da pessoa logada: perfil, senha, aparência e exclusão do cadastro.
///
/// Vive fora do escopo de viagem — quem ainda não entrou em nenhuma
/// também precisa conseguir editar o próprio nome.
///
/// No desktop é uma página de configurações de web: a ilustração da praia
/// ao fundo, o perfil em destaque por cima dela e, embaixo, duas colunas —
/// o que se ajusta à esquerda, sessão e exclusão à direita. Abaixo disso
/// tudo empilha numa coluna só.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final hasPassword = ref.read(authServiceProvider).hasPassword;

    final settings = [
      _SecurityCard(user: user, hasPassword: hasPassword, onSendResetLink: _sendResetLink),
      const _AppearanceCard(),
    ];
    final session = [
      const _SessionCard(),
      const _DangerCard(),
    ];

    final page = AppPage(
      title: 'Sua conta',
      subtitle: 'Perfil, segurança e preferências',
      leading: IconButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(Routes.trips),
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Voltar',
      ),
      children: [
        // Deixa a praia aparecer entre o título e o cartão de perfil.
        SizedBox(height: context.isMobile ? 110 : 200),
        if (user == null)
          const ShimmerBox(height: 280, borderRadius: Radii.brXl)
        else
          _ProfileHero(
            user: user,
            hasPassword: hasPassword,
            onEdit: () => _editProfile(context, user),
          ),
        Gap.vXl,
        if (context.isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _Stack(children: settings)),
              Gap.hXl,
              Expanded(flex: 2, child: _Stack(children: session)),
            ],
          )
        else
          _Stack(children: [...settings, ...session]),
      ],
    );

    // O fundo fica parado e a página rola por cima dele.
    return ColoredBox(
      color: context.theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: context.isMobile ? 360 : 540,
            child: const _Backdrop(),
          ),
          Positioned.fill(child: page),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, AppUser user) => showAppSheet(
        context: context,
        title: 'Seu perfil',
        subtitle: 'Vale para todas as suas viagens',
        builder: (_) => _ProfileSheet(user: user),
      );

  static Future<void> _sendResetLink(
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

/// Cartões um embaixo do outro, com o respiro padrão entre eles.
class _Stack extends StatelessWidget {
  const _Stack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) Gap.vXl,
          child,
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Perfil
// ---------------------------------------------------------------------------

/// O cartão de abertura: avatar grande, nome, e os números da pessoa no
/// app.
class _ProfileHero extends ConsumerWidget {
  const _ProfileHero({
    required this.user,
    required this.hasPassword,
    required this.onEdit,
  });

  final AppUser user;
  final bool hasPassword;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mobile = context.isMobile;
    final avatarSize = mobile ? 80.0 : 96.0;

    final trips = ref.watch(myTripsProvider).valueOrNull;
    final adminCount = trips?.where((t) => t.isAdmin(user.uid)).length ?? 0;
    final name = user.displayName.isEmpty
        ? AppUser.nameFromEmail(user.email)
        : user.displayName;

    final facts = [
      if (trips != null)
        _Fact(
          icon: Icons.luggage_outlined,
          label: switch (trips.length) {
            0 => 'Nenhuma viagem ainda',
            1 => '1 viagem',
            final n => '$n viagens',
          },
        ),
      if (adminCount > 0)
        _Fact(
          icon: Icons.star_outline_rounded,
          label: adminCount == 1 ? 'Organiza 1' : 'Organiza $adminCount',
        ),
      if (user.createdAt != null)
        _Fact(
          icon: Icons.calendar_today_outlined,
          label: 'Desde ${Fmt.monthYear(user.createdAt!)}',
        ),
      _Fact(
        icon: hasPassword ? Icons.alternate_email_rounded : Icons.g_mobiledata_rounded,
        label: hasPassword ? 'Entra com e-mail e senha' : 'Entra com Google',
      ),
    ];

    final identity = Column(
      crossAxisAlignment: mobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: mobile ? context.text.headlineSmall : context.text.headlineMedium,
          textAlign: mobile ? TextAlign.center : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Gap.vXs,
        Text(
          user.email,
          style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final editButton = OutlinedButton.icon(
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Editar perfil'),
    );

    final avatar = InitialsAvatar(initials: user.initials, size: avatarSize);

    return GlassCard(
      padding: EdgeInsets.all(mobile ? Gap.lg : Gap.xl),
      borderRadius: Radii.brXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mobile) ...[
            Center(child: avatar),
            Gap.vMd,
            identity,
          ] else
            Row(
              children: [
                avatar,
                Gap.hXl,
                Expanded(child: identity),
                Gap.hLg,
                editButton,
              ],
            ),
          Gap.vLg,
          Wrap(
            alignment: mobile ? WrapAlignment.center : WrapAlignment.start,
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: facts,
          ),
          if (mobile) ...[Gap.vLg, editButton],
        ],
      ),
    );
  }
}

/// A praia ilustrada no alto da página, que se dissolve na cor de fundo
/// antes dos cartões de configuração. Vai espelhada: assim os coqueiros
/// ficam à direita e o título, à esquerda, cai sobre o céu limpo. No tema
/// escuro leva um véu da cor de fundo, senão o título claro some no céu
/// claro. Decorativa: fica fora da árvore de acessibilidade.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final bg = context.theme.scaffoldBackgroundColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.flip(
          flipX: true,
          child: Image.asset(
            'assets/images/account_cover.jpg',
            fit: BoxFit.cover,
            // Puxa para baixo: o horizonte com o sol precisa sobrar acima
            // do cartão de perfil; a areia some no esmaecido.
            alignment: const Alignment(0, 0.6),
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.6, 1],
              colors: [
                bg.withValues(alpha: context.isDark ? 0.55 : 0),
                bg.withValues(alpha: context.isDark ? 0.6 : 0.05),
                bg,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Uma pílula com ícone: "3 viagens", "Desde março de 2025".
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkChip : AppColors.chip,
        borderRadius: Radii.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.colors.onSurfaceVariant),
          Gap.hXs,
          Text(label, style: context.text.labelMedium),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cartões de configuração
// ---------------------------------------------------------------------------

/// Um grupo de configurações: título e linha de apoio no topo, e as
/// linhas separadas por divisórias — o formato das páginas de
/// configuração na web.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.children,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  /// Tinge a borda e o título de vermelho: a zona de risco.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderColor: danger ? AppColors.danger.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleMedium?.copyWith(
                    color: danger ? AppColors.danger : null,
                  ),
                ),
                Gap.vXs,
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          for (final child in children) ...[
            const Divider(height: 1),
            child,
          ],
        ],
      ),
    );
  }
}

/// Ícone, título, explicação e a ação à direita. No celular a ação desce
/// para baixo do texto: lado a lado o texto ficaria espremido.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    final tint = danger ? AppColors.danger : context.colors.primary;

    final iconTile = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: context.isDark ? 0.18 : 0.10),
        borderRadius: Radii.brMd,
      ),
      child: Icon(icon, size: 20, color: tint),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: context.text.titleSmall),
        Gap.vXs,
        Text(description, style: context.text.bodySmall),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? Gap.lg : Gap.xl,
        vertical: Gap.lg,
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [iconTile, Gap.hMd, Expanded(child: text)],
                ),
                if (action != null) ...[Gap.vMd, action!],
              ],
            )
          : Row(
              children: [
                iconTile,
                Gap.hLg,
                Expanded(child: text),
                if (action != null) ...[Gap.hXl, action!],
              ],
            ),
    );
  }
}

class _SecurityCard extends ConsumerWidget {
  const _SecurityCard({
    required this.user,
    required this.hasPassword,
    required this.onSendResetLink,
  });

  final AppUser? user;
  final bool hasPassword;
  final Future<void> Function(BuildContext, WidgetRef, String) onSendResetLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = user?.email;

    return _SettingsCard(
      title: 'Segurança',
      subtitle: hasPassword
          ? 'Você entra com o seu e-mail, que não muda por aqui'
          : 'Como você entra no app',
      children: [
        // Conta só do Google: não há senha para trocar nem redefinir.
        if (!hasPassword)
          const _SettingsRow(
            icon: Icons.verified_user_outlined,
            title: 'Conta Google',
            description: 'Você entra com a conta Google deste e-mail. '
                'A senha é cuidada pelo Google.',
          )
        else ...[
          _SettingsRow(
            icon: Icons.password_rounded,
            title: 'Senha',
            description: 'Confirme a senha atual para escolher uma nova.',
            action: OutlinedButton(
              onPressed: () => showAppSheet(
                context: context,
                title: 'Trocar senha',
                subtitle: 'Confirme a senha atual para mudar',
                builder: (_) => const _PasswordSheet(),
              ),
              child: const Text('Trocar senha'),
            ),
          ),
          if (email != null)
            _SettingsRow(
              icon: Icons.mark_email_unread_outlined,
              title: 'Esqueceu a senha?',
              description: 'Receba no seu e-mail um link para criar uma senha nova.',
              action: TextButton(
                onPressed: () => onSendResetLink(context, ref, email),
                child: const Text('Enviar link'),
              ),
            ),
        ],
      ],
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsCard(
      title: 'Aparência',
      subtitle: 'Vale só para este aparelho',
      children: [
        _SettingsRow(
          icon: Icons.palette_outlined,
          title: 'Tema',
          description: '"Sistema" acompanha o claro ou escuro do aparelho.',
          action: ThemeModePicker(
            value: ref.watch(themeModeProvider),
            onChanged: ref.read(themeModeProvider.notifier).set,
          ),
        ),
      ],
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsCard(
      title: 'Sessão',
      subtitle: 'Este navegador',
      children: [
        _SettingsRow(
          icon: Icons.logout_rounded,
          title: 'Sair da conta',
          description: 'Suas viagens continuam salvas. É só entrar de novo.',
          action: OutlinedButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            child: const Text('Sair'),
          ),
        ),
      ],
    );
  }
}

class _DangerCard extends StatelessWidget {
  const _DangerCard();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Zona de risco',
      subtitle: 'Não dá para desfazer',
      danger: true,
      children: [
        _SettingsRow(
          icon: Icons.person_remove_outlined,
          title: 'Excluir minha conta',
          description: 'Apaga seu cadastro e tira você de todas as viagens.',
          danger: true,
          action: OutlinedButton(
            onPressed: () => showAppSheet(
              context: context,
              title: 'Excluir sua conta',
              subtitle: 'Isso não pode ser desfeito',
              builder: (_) => const _DeleteAccountSheet(),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            child: const Text('Excluir conta'),
          ),
        ),
      ],
    );
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
