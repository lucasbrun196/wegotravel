import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/board_post.dart';
import '../../../data/services/media/local_media.dart';
import '../../../data/services/media/media_drop.dart';
import '../../../data/services/media/media_export.dart' show savesToGallery;
import '../../../data/services/media/media_picker.dart';
import '../../../shared/widgets/cards/glass_card.dart';
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/effects/fade_slide_in.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../../../shared/widgets/inputs/add_button.dart';
import '../../../shared/widgets/layout/app_page.dart';
import '../controllers/board_actions.dart';
import '../controllers/board_controllers.dart';
import '../controllers/board_uploads.dart';
import '../widgets/board_tile.dart';
import '../widgets/import_review_sheet.dart';
import '../widgets/media_viewer.dart';
import '../widgets/upload_tray.dart';
import 'camera_screen.dart';

/// O mural: as fotos e os vídeos da turma, separados pelo dia em que foram
/// feitos, em colunas que respeitam o formato de cada um.
///
/// Importar abre o seletor do aparelho (vários de uma vez, ou um só) e uma
/// revisão para legendar; a câmera tira na hora. No computador também dá
/// para arrastar os arquivos para a janela.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  /// Nulo fora do modo de seleção.
  Set<String>? _selection;
  bool _dropping = false;
  _BulkAction? _busy;

  /// Posts sendo excluídos agora: brilham em esqueleto até sumirem.
  Set<String> _deleting = const {};

  /// Revisão, câmera ou tela cheia por cima do mural. Arquivo solto nessa
  /// hora não abre uma segunda revisão.
  bool _covered = false;
  late final void Function() _stopDrops;

  /// Quando o mural apareceu com conteúdo. Só os quadros montados logo em
  /// seguida entram em sequência; os que surgem rolando a página aparecem
  /// direto, sem atraso.
  DateTime? _revealedAt;

  @override
  void initState() {
    super.initState();
    _stopDrops = listenForDroppedMedia(
      onHover: (hovering) {
        if (mounted) setState(() => _dropping = hovering && !_covered);
      },
      onDrop: _review,
    );
  }

  @override
  void dispose() {
    _stopDrops();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Postar
  // ------------------------------------------------------------------

  Future<void> _import() async {
    final files = await pickMedia();
    if (!mounted || files.isEmpty) return;
    await _review(files);
  }

  Future<void> _review(List<LocalMedia> files) async {
    if (_covered) {
      for (final file in files) {
        file.dispose();
      }
      return;
    }
    final accepted = acceptMedia(files);
    if (!mounted || accepted.isEmpty) return;
    final items = await _cover(() => showImportReview(context, accepted));
    if (items == null || items.isEmpty) return;
    _enqueue(items);
  }

  Future<void> _camera() async {
    final shots = await _cover(() => openBoardCamera(context));
    if (!mounted || shots.isEmpty) return;
    _enqueue([for (final shot in shots) (shot, null)]);
  }

  Future<T> _cover<T>(Future<T> Function() open) async {
    _covered = true;
    try {
      return await open();
    } finally {
      _covered = false;
    }
  }

  void _enqueue(List<(LocalMedia, String?)> items) {
    final member = ref.read(currentMemberProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    ref.read(boardUploadsProvider.notifier).enqueue(
          tripId: ref.read(currentTripIdProvider),
          authorName: member?.name ?? user?.displayName ?? '',
          items: items,
        );
  }

  // ------------------------------------------------------------------
  // Seleção
  // ------------------------------------------------------------------

  void _toggle(BoardPost post) {
    final selection = {...?_selection};
    if (!selection.remove(post.id)) selection.add(post.id);
    setState(() => _selection = selection);
  }

  Future<void> _bulk(_BulkAction action, List<BoardPost> posts) async {
    if (_busy != null || posts.isEmpty) return;
    setState(() => _busy = action);
    try {
      switch (action) {
        case _BulkAction.share:
          await sharePosts(context, ref, posts);
        case _BulkAction.download:
          await downloadPosts(context, ref, posts);
        case _BulkAction.delete:
          final deleted = await deletePosts(
            context,
            ref,
            posts,
            onDeleting: (ids) => setState(() => _deleting = ids),
          );
          if (deleted && mounted) setState(() => _selection = null);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = null;
          _deleting = const {};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(boardPostsProvider);
    final posts = postsAsync.valueOrNull ?? const <BoardPost>[];
    final days = ref.watch(boardDaysProvider);
    final filter = ref.watch(boardFilterProvider);
    final tripId = ref.watch(currentTripIdProvider);

    if (posts.isNotEmpty) _revealedAt ??= DateTime.now();

    final videos = posts.where((p) => p.isVideo).length;
    final photos = posts.length - videos;
    final shown = [for (final day in days) ...day.posts];
    final selection = _selection;
    final selected = selection == null ? const <BoardPost>[] : shown.where((p) => selection.contains(p.id)).toList();

    final page = AppPage(
      title: 'Mural',
      subtitle: posts.isEmpty ? null : mediaCountLabel(photos, videos),
      action: _HeaderActions(onImport: _import, onCamera: _camera),
      bottomSlivers: [
        if (days.isNotEmpty)
          _DaysSliver(
            days: days,
            selection: selection,
            deleting: _deleting,
            revealedAt: _revealedAt,
            onTap: (post) => selection != null
                ? _toggle(post)
                : _cover(() => openMediaViewer(context, posts: shown, index: shown.indexOf(post))),
            onLongPress: (post) => setState(() => _selection = {...?selection, post.id}),
          ),
      ],
      children: [
        postsAsync.when(
          loading: () => const _GridSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Não deu para carregar o mural',
            details: '$e',
            onRetry: () => ref.invalidate(boardPostsProvider),
          ),
          data: (posts) {
            if (posts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: Gap.xl),
                child: EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: 'Mural vazio',
                  message: 'As fotos e os vídeos da turma aparecem aqui, separados pelo dia em '
                      'que foram feitos.',
                  actionLabel: 'Importar do aparelho',
                  actionIcon: Icons.add_photo_alternate_outlined,
                  onAction: _import,
                  secondaryLabel: 'Abrir a câmera',
                  secondaryIcon: Icons.photo_camera_outlined,
                  onSecondary: _camera,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FilterBar(
                  filter: filter,
                  posts: posts,
                  selecting: selection != null,
                  onSelect: () => setState(() => _selection = selection == null ? <String>{} : null),
                  onSelectAll: () => setState(() => _selection = {for (final p in shown) p.id}),
                ),
                if (days.isEmpty) ...[
                  Gap.vLg,
                  _NothingMatches(filter: filter),
                ],
              ],
            );
          },
        ),
      ],
    );

    final bottom = context.isMobile ? Gap.md : Gap.xl;

    return Stack(
      children: [
        Positioned.fill(child: page),
        Positioned(
          left: Gap.lg,
          right: context.isMobile ? Gap.lg : null,
          bottom: bottom + (selection != null ? 72 : 0),
          child: SizedBox(
            width: context.isMobile ? null : 360,
            child: UploadTray(tripId: tripId),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          child: _SelectionBar(
            visible: selection != null,
            selected: selected,
            busy: _busy,
            onClose: () => setState(() => _selection = null),
            onShare: () => _bulk(_BulkAction.share, selected),
            onDownload: () => _bulk(_BulkAction.download, selected),
            onDelete: () => _bulk(_BulkAction.delete, selected),
          ),
        ),
        Positioned.fill(child: _DropOverlay(visible: _dropping)),
      ],
    );
  }
}

enum _BulkAction { share, download, delete }

// ---------------------------------------------------------------------------
// Cabeçalho e filtros
// ---------------------------------------------------------------------------

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.onImport, required this.onCamera});

  final VoidCallback onImport;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (context.isMobile)
          IconButton.outlined(
            tooltip: 'Tirar foto',
            onPressed: onCamera,
            style: IconButton.styleFrom(fixedSize: const Size(44, 44)),
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
          )
        else
          OutlinedButton.icon(
            onPressed: onCamera,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Câmera'),
          ),
        Gap.hSm,
        AddButton(label: 'Importar', onPressed: onImport),
      ],
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.filter,
    required this.posts,
    required this.selecting,
    required this.onSelect,
    required this.onSelectAll,
  });

  final BoardFilter filter;
  final List<BoardPost> posts;
  final bool selecting;
  final VoidCallback onSelect;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersByIdProvider);
    final authors = ref.watch(boardAuthorsProvider);
    void set(BoardFilter next) => ref.read(boardFilterProvider.notifier).state = next;

    final counts = {
      BoardKindFilter.all: posts.length,
      BoardKindFilter.photos: posts.where((p) => p.isPhoto).length,
      BoardKindFilter.videos: posts.where((p) => p.isVideo).length,
    };

    // Ordem do mural: quem postou mais primeiro.
    final people = authors.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final kind in BoardKindFilter.values)
              if (kind == BoardKindFilter.all || counts[kind]! > 0)
                ChoiceChip(
                  label: Text('${kind.label} ${counts[kind]}'),
                  selected: filter.kind == kind,
                  onSelected: (_) => set(filter.copyWith(kind: kind)),
                ),
            if (people.length > 1)
              for (final MapEntry(key: id, value: count) in people)
                ChoiceChip(
                  avatar: members[id] == null ? null : MemberAvatar(member: members[id]!, size: 22),
                  label: Text('${members[id]?.shortName ?? _authorName(id)} $count'),
                  selected: filter.authorId == id,
                  onSelected: (on) => set(on ? filter.copyWith(authorId: id) : filter.copyWith(clearAuthor: true)),
                ),
          ],
        ),
        Gap.vSm,
        Row(
          children: [
            TextButton.icon(
              onPressed: () => set(filter.copyWith(newestFirst: !filter.newestFirst)),
              icon: AnimatedRotation(
                turns: filter.newestFirst ? 0 : 0.5,
                duration: context.reduceMotion ? Duration.zero : Motion.normal,
                curve: Motion.spring,
                child: const Icon(Icons.south_rounded, size: 16),
              ),
              label: Text(filter.newestFirst ? 'Mais recentes primeiro' : 'Do começo da viagem'),
            ),
            const Spacer(),
            if (selecting)
              TextButton(onPressed: onSelectAll, child: const Text('Selecionar todos')),
            TextButton(
              onPressed: onSelect,
              child: Text(selecting ? 'Cancelar' : 'Selecionar'),
            ),
          ],
        ),
      ],
    );
  }

  String _authorName(String id) {
    for (final post in posts) {
      if (post.authorId == id && post.authorName.isNotEmpty) return post.authorName.split(' ').first;
    }
    return 'Ex-participante';
  }
}

class _NothingMatches extends ConsumerWidget {
  const _NothingMatches({required this.filter});

  final BoardFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = filter.authorId == null ? null : ref.watch(membersByIdProvider)[filter.authorId];
    final what = switch (filter.kind) {
      BoardKindFilter.videos => 'vídeo',
      BoardKindFilter.photos => 'foto',
      BoardKindFilter.all => 'nada',
    };

    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              author != null ? '${author.shortName} ainda não postou $what.' : 'Ninguém postou $what ainda.',
              style: context.text.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => ref.read(boardFilterProvider.notifier).state = const BoardFilter(),
            child: const Text('Ver tudo'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A grade
// ---------------------------------------------------------------------------

/// Os dias do mural. Cada dia é um grupo: o cabeçalho gruda no topo
/// enquanto as fotos dele passam, e é empurrado pelo do dia seguinte.
class _DaysSliver extends ConsumerWidget {
  const _DaysSliver({
    required this.days,
    required this.selection,
    required this.deleting,
    required this.revealedAt,
    required this.onTap,
    required this.onLongPress,
  });

  final List<BoardDay> days;
  final Set<String>? selection;
  final Set<String> deleting;
  final DateTime? revealedAt;
  final void Function(BoardPost) onTap;
  final void Function(BoardPost) onLongPress;

  /// Largura mínima de uma coluna: abaixo disso a foto vira selo.
  static const _minColumn = 220.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersByIdProvider);
    final gap = context.isMobile ? Gap.xs : Gap.sm;
    final gutter = responsiveValue(context, mobile: Gap.lg, tablet: Gap.xl, desktop: Gap.xxl);

    // Os quadros que montam logo que o mural aparece entram em sequência.
    final revealing = revealedAt != null &&
        DateTime.now().difference(revealedAt!) < const Duration(milliseconds: 900);
    var order = 0;

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // As mesmas margens do `ContentContainer`, que não serve para sliver.
        final width = constraints.crossAxisExtent;
        final side = math.max(gutter, (width - Breakpoints.contentMaxWidth) / 2 + gutter);
        final content = width - side * 2;
        final columns = ((content + gap) / (_minColumn + gap)).floor().clamp(2, 6);

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: side),
          sliver: SliverMainAxisGroup(
            slivers: [
              for (final (dayIndex, day) in days.indexed)
                SliverMainAxisGroup(
                  key: ValueKey(day.dayKey),
                  slivers: [
                    PinnedHeaderSliver(
                      child: FadeSlideIn(index: dayIndex + 1, child: _DayHeader(day: day)),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: Gap.xl),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: columns,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        childCount: day.posts.length,
                        itemBuilder: (context, i) {
                          final post = day.posts[i];
                          final tile = AspectRatio(
                            aspectRatio: post.tileAspectRatio,
                            child: BoardTile(
                              key: ValueKey(post.id),
                              post: post,
                              authorName: members[post.authorId]?.shortName,
                              selecting: selection != null,
                              selected: selection?.contains(post.id) ?? false,
                              busy: deleting.contains(post.id),
                              onTap: () => onTap(post),
                              onLongPress: () => onLongPress(post),
                            ),
                          );
                          return revealing ? FadeSlideIn(index: order++ + 2, child: tile) : tile;
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// "Dia 3", a data e os lugares do roteiro daquele dia — o mural e o
/// roteiro contam a mesma viagem.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final BoardDay day;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;
    final date = '${Fmt.weekdayShort(day.date)}, ${Fmt.dayMonth(day.date)}';
    // Fora da viagem (foto antiga, de antes da ida), o ano aparece quando
    // não é o corrente.
    final year = day.date.year == DateTime.now().year ? '' : ' de ${day.date.year}';
    final full = '${Fmt.weekday(day.date)}, ${Fmt.date(day.date)}$year';
    final title = day.tripDay != null ? 'Dia ${day.tripDay}' : capitalized(full);
    final places = day.places.length <= 3
        ? day.places.join(', ')
        : '${day.places.take(3).join(', ')} e mais ${day.places.length - 3}';

    return ColoredBox(
      // Grudado no topo, o cabeçalho cobre as fotos que passam por baixo.
      color: context.theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        title,
                        style: context.text.titleLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (day.tripDay != null) ...[
                        Gap.hSm,
                        Text(date, style: context.text.bodySmall),
                      ],
                      if (day.date.isToday) ...[
                        Gap.hSm,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 1),
                          decoration: BoxDecoration(color: context.sun, borderRadius: Radii.brPill),
                          child: Text(
                            'hoje',
                            style: context.text.labelSmall?.copyWith(
                              color: AppColors.night,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (places.isNotEmpty)
                    Text(
                      places,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                ],
              ),
            ),
            Gap.hMd,
            Text(
              mediaCountLabel(day.photoCount, day.videoCount),
              style: context.text.labelMedium?.copyWith(
                color: muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O esqueleto enquanto o mural carrega: colunas com quadros de alturas
/// diferentes, na forma do que vem.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  static const _heights = [
    [180.0, 120.0, 210.0],
    [130.0, 200.0, 150.0],
    [210.0, 140.0, 120.0],
    [150.0, 190.0, 160.0],
  ];

  @override
  Widget build(BuildContext context) {
    final columns = context.isMobile ? 2 : 4;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < columns; c++) ...[
          if (c > 0) Gap.hSm,
          Expanded(
            child: Column(
              children: [
                for (final h in _heights[c])
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: ShimmerBox(height: h, borderRadius: Radii.brMd),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seleção e arrastar arquivos
// ---------------------------------------------------------------------------

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.visible,
    required this.selected,
    required this.busy,
    required this.onClose,
    required this.onShare,
    required this.onDownload,
    required this.onDelete,
  });

  final bool visible;
  final List<BoardPost> selected;
  final _BulkAction? busy;
  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;
    final count = selected.length;
    final enabled = count > 0 && busy == null;

    Widget action(_BulkAction kind, IconData icon, String label, VoidCallback onPressed, {Color? color}) {
      final child = busy == kind
          ? IconSkeleton(color: color)
          : Icon(icon, size: 20, color: enabled ? color : null);
      return context.isMobile
          ? IconButton(tooltip: label, onPressed: enabled ? onPressed : null, icon: child)
          : TextButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: child,
              label: Text(label),
              style: TextButton.styleFrom(foregroundColor: color),
            );
    }

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1.4),
        duration: duration,
        curve: visible ? Motion.enter : Motion.exit,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              margin: const EdgeInsets.symmetric(horizontal: Gap.lg),
              padding: const EdgeInsets.symmetric(horizontal: Gap.xs, vertical: Gap.xs),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: Radii.brLg,
                border: Border.all(color: context.colors.outline),
                boxShadow: AppColors.float(dark: context.isDark),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Sair da seleção',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      count == 0 ? 'Escolha as fotos' : (count == 1 ? '1 escolhido' : '$count escolhidos'),
                      style: context.text.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  action(_BulkAction.share, Icons.share_outlined, 'Compartilhar', onShare),
                  action(
                    _BulkAction.download,
                    Icons.download_rounded,
                    savesToGallery ? 'Salvar' : 'Baixar',
                    onDownload,
                  ),
                  action(
                    _BulkAction.delete,
                    Icons.delete_outline_rounded,
                    'Excluir',
                    onDelete,
                    color: context.debt,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// O aviso de soltar: aparece quando um arquivo arrastado do computador
/// entra na janela.
class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final duration = context.reduceMotion ? Duration.zero : Motion.fast;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        child: AnimatedScale(
          scale: visible ? 1 : 0.98,
          duration: duration,
          curve: Motion.enter,
          child: Container(
            margin: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer.withValues(alpha: 0.97),
              borderRadius: Radii.brXl,
              border: Border.all(color: context.colors.primary, width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_download_outlined, size: 40, color: context.colors.primary),
                  Gap.vMd,
                  Text('Solte para postar no mural', style: context.text.headlineSmall),
                  Gap.vXs,
                  Text('Fotos e vídeos de até 150 MB', style: context.text.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
