import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/member.dart';
import '../../../shared/widgets/cards/glass_card.dart';
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../../../shared/widgets/inputs/theme_mode_picker.dart';
import '../../../shared/widgets/layout/app_page.dart';
import '../../../shared/widgets/layout/app_sheet.dart';
import '../../../shared/widgets/layout/section_header.dart';
import '../../trips/widgets/trip_form_sheet.dart';
import '../widgets/add_member_sheet.dart';

class TripSettingsScreen extends ConsumerWidget {
  const TripSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider).valueOrNull;
    final membersAsync = ref.watch(membersProvider);
    final isAdmin = ref.watch(isTripAdminProvider);
    final uid = ref.watch(currentUidProvider);

    return AppPage(
      title: 'Ajustes',
      children: [
        // ---------------- Dados da viagem ----------------
        SectionHeader(
          title: 'Dados da viagem',
          actionLabel: isAdmin ? 'Editar' : null,
          onAction: isAdmin && trip != null ? () => showTripForm(context, trip: trip) : null,
        ),
        if (trip == null)
          const ShimmerBox(height: 130, borderRadius: Radii.brLg)
        else
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Row(label: 'Nome', value: trip.name),
                const Divider(),
                _Row(
                  label: 'Destino',
                  value: trip.destination.isEmpty ? '—' : trip.destination,
                ),
                const Divider(),
                _Row(
                  label: 'Datas',
                  mono: true,
                  value: trip.hasDates
                      ? Fmt.dateRange(trip.startDate!, trip.endDate!)
                      : 'não definidas',
                ),
                const Divider(),
                _Row(
                  label: 'Orçamento',
                  mono: true,
                  value: trip.budgetCents == null ? '—' : Money.format(trip.budgetCents!),
                ),
              ],
            ),
          ),

        // ---------------- Participantes ----------------
        Gap.vXl,
        SectionHeader(
          title: 'Participantes',
          subtitle: isAdmin
              ? 'Você é o administrador desta viagem'
              : 'Só o administrador adiciona ou remove gente',
          trailing: isAdmin
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                  onPressed: () => showAddMemberSheet(
                    context,
                    nextOrder: membersAsync.valueOrNull?.length ?? 0,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                )
              : null,
        ),
        membersAsync.when(
          loading: () => const ShimmerList(itemCount: 2, itemHeight: 56),
          error: (e, _) => Text('Erro ao carregar: $e', style: context.text.bodySmall),
          data: (members) => GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  if (i > 0) const Divider(),
                  _MemberTile(
                    member: members[i],
                    isMe: members[i].id == uid,
                    canRemove: isAdmin && !members[i].isAdmin,
                  ),
                ],
              ],
            ),
          ),
        ),

        // ---------------- Aparência ----------------
        Gap.vXl,
        const SectionHeader(title: 'Aparência', subtitle: 'Vale só para este aparelho'),
        const _ThemePicker(),

        // ---------------- Sua conta ----------------
        Gap.vXl,
        const SectionHeader(title: 'Sua conta'),
        const _AccountCard(),

        // ---------------- Zona de risco ----------------
        Gap.vXl,
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go(Routes.trips),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Trocar de viagem'),
              ),
              Gap.vMd,
              if (isAdmin && trip != null)
                OutlinedButton.icon(
                  onPressed: () => _confirmDeleteTrip(context, ref, trip.name),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Excluir viagem'),
                )
              else if (uid != null)
                OutlinedButton.icon(
                  onPressed: () => _confirmLeave(context, ref, uid),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sair desta viagem'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteTrip(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir a viagem?'),
        content: Text(
          'Tudo de "$name" será apagado: roteiro, contas, cotas, comprovantes '
          'e mural. Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir tudo'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final tripId = ref.read(currentTripIdProvider);

    // Sai antes de apagar: a exclusão varre todas as subcoleções e o
    // documento some do stream no meio do caminho.
    context.go(Routes.trips);

    try {
      await ref.read(tripRepositoryProvider).deleteTrip(tripId);
      AppToast.success('Viagem excluída');
    } catch (e) {
      AppToast.error('Não deu para excluir a viagem: $e');
    }
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref, String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da viagem?'),
        content: const Text(
          'Você deixa de ver o roteiro, as contas e o mural. '
          'O administrador pode te adicionar de novo depois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ficar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final tripId = ref.read(currentTripIdProvider);
    context.go(Routes.trips);

    try {
      await ref.read(tripRepositoryProvider).removeMember(tripId, uid);
      AppToast.success('Você saiu da viagem');
    } catch (e) {
      AppToast.error('Não deu para sair: $e');
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;

  /// Datas e valores vão em mono, como no resto do app.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Text(label, style: context.text.bodySmall),
          Gap.hMd,
          // `Expanded` e não `Spacer` + `Flexible`: com os dois flexíveis
          // o espaço livre era dividido entre eles, e cada valor parava
          // num ponto diferente conforme o tamanho do texto. Assim todos
          // terminam na mesma margem.
          Expanded(
            child: Text(
              value,
              style: mono
                  ? AppTypography.mono(size: 13, color: context.colors.onSurface)
                  : context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canRemove,
  });

  final Member member;
  final bool isMe;
  final bool canRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: isMe ? () => _editSelf(context, ref) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        child: Row(
          children: [
            MemberAvatar(member: member, size: 32),
            Gap.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // `Wrap`: com as duas tags na mesma linha o nome ficava com
                  // ~65px e virava "Lu…". Aqui elas descem quando não cabem.
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        member.name,
                        style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (member.isAdmin) const _Tag(label: 'admin'),
                      if (isMe) const _Tag(label: 'você'),
                    ],
                  ),
                  Text(
                    member.email,
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (member.pixKey != null && member.pixKey!.isNotEmpty)
                    Text(
                      'PIX ${member.pixKey!}',
                      style: AppTypography.mono(size: 12, color: context.colors.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (isMe)
              Icon(Icons.edit_outlined, size: 16, color: context.colors.onSurfaceVariant),
            if (canRemove)
              IconButton(
                tooltip: 'Remover da viagem',
                onPressed: () => _confirmRemove(context, ref),
                icon: const Icon(Icons.person_remove_outlined, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSelf(BuildContext context, WidgetRef ref) =>
      showAppSheet(
        context: context,
        title: 'Seu perfil na viagem',
        subtitle: 'Nome e chave PIX nesta viagem',
        builder: (_) => _EditMemberSheet(member: member),
      );

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover ${member.shortName}?'),
        content: const Text(
          'A pessoa deixa de ver esta viagem. As contas e cotas dela continuam '
          'registradas — remova das contas antes, se for o caso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref
        .read(tripRepositoryProvider)
        .removeMember(ref.read(currentTripIdProvider), member.id);
    if (context.mounted) AppToast.success('${member.shortName} saiu da viagem');
  }
}

/// Nome e chave PIX — a chave aparece para quem vai te pagar.
class _EditMemberSheet extends ConsumerStatefulWidget {
  const _EditMemberSheet({required this.member});

  final Member member;

  @override
  ConsumerState<_EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends ConsumerState<_EditMemberSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _pixController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.name);
    _pixController = TextEditingController(text: widget.member.pixKey ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pixController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final member = widget.member.copyWith(
        name: _nameController.text.trim(),
        pixKey: _pixController.text.trim(),
      );
      await ref
          .read(tripRepositoryProvider)
          .updateMember(ref.read(currentTripIdProvider), member);
      await ref.read(userRepositoryProvider).updateProfile(
            member.id,
            displayName: member.name,
          );
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success('Perfil atualizado', icon: Icons.check_circle_rounded);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error('Não deu para salvar: $e');
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                Gap.vLg,
                TextField(
                  controller: _pixController,
                  decoration: const InputDecoration(
                    labelText: 'Chave PIX',
                    hintText: 'e-mail, telefone ou aleatória',
                    helperText: 'Aparece para quem for te pagar uma cota',
                    prefixIcon: Icon(Icons.pix_rounded, size: 20),
                  ),
                ),
              ],
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

class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return GlassCard(
      onTap: () => context.push(Routes.account),
      child: Row(
        children: [
          InitialsAvatar(initials: user?.initials ?? '?', size: 32),
          Gap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.displayName ?? '—',
                  style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  user?.email ?? '',
                  style: context.text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Perfil, senha e cadastro',
                  style: context.text.labelSmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: const Icon(Icons.logout, size: 18),
          ),
          Icon(Icons.chevron_right, color: context.colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: Radii.brSm,
        border: Border.all(color: context.colors.outline),
      ),
      child: Text(label, style: context.text.labelSmall?.copyWith(fontSize: 11)),
    );
  }
}

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ThemeModePicker(
        value: ref.watch(themeModeProvider),
        onChanged: ref.read(themeModeProvider.notifier).set,
      );
}
