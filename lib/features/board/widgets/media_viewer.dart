import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/initials.dart';
import '../../../data/models/board_post.dart';
import '../../../data/services/media/media_export.dart' show savesToGallery;
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../controllers/board_actions.dart';
import 'board_image.dart';
import 'board_tile.dart';
import 'board_video_player.dart';
import 'caption_sheet.dart';

/// Abre a tela cheia do mural em [posts], começando por [index].
///
/// A rota vai para o Navigator raiz, para cobrir a barra de navegação, e
/// por isso sai do escopo da viagem: o `UncontrolledProviderScope` devolve
/// o container de quem abriu, como o `showAppSheet` faz com os formulários.
/// O tema é sempre o escuro — foto se vê no escuro, como no cinema.
Future<void> openMediaViewer(
  BuildContext context, {
  required List<BoardPost> posts,
  required int index,
}) {
  final container = ProviderScope.containerOf(context);
  final still = context.reduceMotion;

  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: still ? Duration.zero : Motion.slow,
      reverseTransitionDuration: still ? Duration.zero : Motion.normal,
      pageBuilder: (context, _, _) => UncontrolledProviderScope(
        container: container,
        child: Theme(
          data: AppTheme.dark,
          child: MediaViewer(posts: posts, initialIndex: index),
        ),
      ),
      // A rota não anima sozinha: o fundo e os controles aparecem com a
      // animação dela, e a foto voa do quadro com o `Hero`.
      transitionsBuilder: (context, animation, _, child) => child,
    ),
  );
}

/// A tela cheia: as fotos lado a lado para passar com o dedo ou as setas.
///
/// O fundo é o azul da noite tingido pela cor média da foto aberta, e muda
/// devagar a cada foto — a sala acompanha o que está na tela. Arrastar
/// para baixo fecha, com a foto encolhendo de volta para o quadro.
class MediaViewer extends ConsumerStatefulWidget {
  const MediaViewer({super.key, required this.posts, required this.initialIndex});

  final List<BoardPost> posts;
  final int initialIndex;

  @override
  ConsumerState<MediaViewer> createState() => _MediaViewerState();
}

/// Quanto tempo cada foto fica na tela na apresentação.
const _slideDuration = Duration(seconds: 5);

/// Arrastar além disso (ou rápido assim) fecha a tela cheia.
const _dismissDistance = 110.0;
const _dismissVelocity = 900.0;

class _MediaViewerState extends ConsumerState<MediaViewer> with TickerProviderStateMixin {
  late List<BoardPost> _posts = widget.posts;
  late int _index = widget.initialIndex.clamp(0, widget.posts.length - 1);
  late final _pages = PageController(initialPage: _index);
  final _focus = FocusNode(debugLabel: 'Tela cheia do mural');

  /// A barra de espaço do teclado, para o vídeo da frente.
  final _playPause = ValueNotifier<int>(0);

  /// O player do vídeo da frente, quando há um pronto.
  final _video = ValueNotifier<VideoPlayerController?>(null);

  bool _chrome = true;
  bool _zoomed = false;
  _Busy? _busy;

  double _drag = 0;
  double _settleFrom = 0;
  late final AnimationController _settle = AnimationController(vsync: this, duration: Motion.normal)
    ..addListener(
      () => setState(() => _drag = _settleFrom * (1 - Motion.enter.transform(_settle.value))),
    );

  bool _slideshow = false;
  late final AnimationController _slide = AnimationController(vsync: this, duration: _slideDuration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _advance();
    });

  BoardPost get _current => _posts[_index];

  /// A foto grande e o vídeo aparecem depois que o voo do quadro começou e
  /// somem logo no início da volta. Sem isto, ao fechar, a versão grande
  /// ficaria parada no lugar enquanto a miniatura voava de volta.
  CurvedAnimation? _pageFade;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageFade ??= CurvedAnimation(
      parent: ModalRoute.of(context)!.animation!,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pageFade?.dispose();
    _pages.dispose();
    _focus.dispose();
    _playPause.dispose();
    _video.dispose();
    _settle.dispose();
    _slide.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Navegação
  // ------------------------------------------------------------------

  void _go(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= _posts.length) return;
    if (context.reduceMotion) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(target, duration: Motion.slow, curve: Motion.enter);
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      _zoomed = false;
    });
    _video.value = null;
    if (_slideshow) _restartSlide();
  }

  void _close() => Navigator.of(context).maybePop();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      _go(1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
    } else if (key == LogicalKeyboardKey.escape) {
      _close();
    } else if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
      if (_current.isVideo) {
        _playPause.value++;
      } else {
        _toggleSlideshow();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------------
  // Apresentação
  // ------------------------------------------------------------------

  void _toggleSlideshow() {
    setState(() {
      _slideshow = !_slideshow;
      // Na apresentação a foto ocupa a tela; um toque traz os controles.
      if (_slideshow) _chrome = false;
    });
    if (_slideshow) {
      _restartSlide();
    } else {
      _slide.stop();
      _slide.value = 0;
    }
  }

  /// Foto conta o tempo; vídeo toca até o fim e então segue.
  void _restartSlide() {
    _slide.stop();
    _slide.value = 0;
    if (!_current.isVideo) _slide.forward();
  }

  void _advance() {
    if (!_slideshow) return;
    if (_index >= _posts.length - 1) {
      setState(() {
        _slideshow = false;
        _chrome = true;
      });
      _slide.value = 0;
      return;
    }
    _go(1);
  }

  // ------------------------------------------------------------------
  // Arrastar para fechar
  // ------------------------------------------------------------------

  void _dragStart(DragStartDetails _) => _settle.stop();

  void _dragUpdate(DragUpdateDetails details) => setState(() => _drag += details.delta.dy);

  void _dragEnd(DragEndDetails details) {
    if (_drag.abs() > _dismissDistance ||
        details.velocity.pixelsPerSecond.dy.abs() > _dismissVelocity) {
      _close();
      return;
    }
    _settleFrom = _drag;
    if (context.reduceMotion) {
      setState(() => _drag = 0);
    } else {
      _settle.forward(from: 0);
    }
  }

  // ------------------------------------------------------------------
  // Ações
  // ------------------------------------------------------------------

  Future<void> _run(_Busy kind, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = kind);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// O mural mudou enquanto a tela cheia estava aberta: legenda editada,
  /// post excluído (aqui ou por outra pessoa). Excluído o da frente, fica o
  /// vizinho; sem nenhum, a tela fecha.
  void _sync(List<BoardPost> fresh) {
    final byId = {for (final p in fresh) p.id: p};
    final kept = [for (final p in _posts) ?byId[p.id]];
    if (kept.isEmpty) {
      _close();
      return;
    }

    final currentId = _current.id;
    var index = kept.indexWhere((p) => p.id == currentId);
    if (index < 0) index = math.min(_index, kept.length - 1);

    setState(() {
      _posts = kept;
      _index = index;
    });
    if (_pages.hasClients && _pages.page?.round() != index) _pages.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(boardPostsProvider, (_, next) {
      if (next.valueOrNull case final fresh?) _sync(fresh);
    });

    final route = ModalRoute.of(context)!;
    final appear = route.animation!;
    final size = MediaQuery.sizeOf(context);
    final post = _current;
    final pulled = (_drag.abs() / (size.height * 0.5)).clamp(0.0, 1.0);
    final chrome = _chrome && _drag == 0;
    final still = context.reduceMotion;

    final stage = Color.alphaBlend(
      (post.color ?? AppColors.nightRaised).withValues(alpha: 0.22),
      AppColors.darkBackground,
    );

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // O fundo: some junto com o arrasto, revelando o mural atrás.
            FadeTransition(
              opacity: appear,
              child: AnimatedContainer(
                duration: still ? Duration.zero : Motion.lazy,
                curve: Motion.smooth,
                color: stage.withValues(alpha: 1 - pulled * 0.9),
              ),
            ),

            GestureDetector(
              onVerticalDragStart: _zoomed ? null : _dragStart,
              onVerticalDragUpdate: _zoomed ? null : _dragUpdate,
              onVerticalDragEnd: _zoomed ? null : _dragEnd,
              child: FadeTransition(
                opacity: _pageFade!,
                child: Transform.translate(
                  offset: Offset(0, _drag),
                  child: Transform.scale(
                    scale: 1 - pulled * 0.18,
                    child: PhotoViewGestureDetectorScope(
                      axis: Axis.horizontal,
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: _posts.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, i) {
                          final item = _posts[i];
                          void toggle() => setState(() => _chrome = !_chrome);
                          return item.isVideo
                              ? _VideoPage(
                                  key: ValueKey(item.id),
                                  post: item,
                                  active: i == _index,
                                  autoplay: true,
                                  playPause: _playPause,
                                  onTap: toggle,
                                  onEnded: _slideshow ? _advance : null,
                                  onController: (c) {
                                    if (i == _index) _video.value = c;
                                  },
                                )
                              : _PhotoPage(
                                  key: ValueKey(item.id),
                                  post: item,
                                  onTap: toggle,
                                  onZoom: (zoomed) {
                                    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                                  },
                                );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Controles. Aparecem com a rota e somem no toque e no arrasto.
            _Chrome(
              visible: chrome,
              appear: appear,
              alignment: Alignment.topCenter,
              child: _TopBar(
                post: post,
                index: _index,
                total: _posts.length,
                busy: _busy,
                slideshow: _slideshow,
                slideProgress: _slide,
                onClose: _close,
                onSlideshow: _toggleSlideshow,
                onShare: () => _run(_Busy.share, () => sharePosts(context, ref, [post])),
                onDownload: () => _run(_Busy.download, () => downloadPosts(context, ref, [post])),
                onCaption: () => showCaptionSheet(context, post),
                onDelete: () => _run(_Busy.delete, () => deletePosts(context, ref, [post])),
              ),
            ),
            // A linha da apresentação fica mesmo com os controles escondidos.
            if (_slideshow)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _slide,
                  builder: (context, _) => LinearProgressIndicator(
                    value: post.isVideo ? null : _slide.value,
                    minHeight: 2,
                    color: AppColors.sun,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            _Chrome(
              visible: chrome,
              appear: appear,
              alignment: Alignment.bottomCenter,
              child: _BottomBar(
                post: post,
                posts: _posts,
                index: _index,
                video: _video,
                onSelect: (i) => _pages.jumpToPage(i),
              ),
            ),
            if (!context.isMobile) ...[
              _Arrow(visible: chrome && _index > 0, left: true, onTap: () => _go(-1)),
              _Arrow(
                visible: chrome && _index < _posts.length - 1,
                left: false,
                onTap: () => _go(1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Busy { share, download, delete }

// ---------------------------------------------------------------------------
// Páginas
// ---------------------------------------------------------------------------

/// O retângulo que a mídia ocupa na tela, sem cortar nada. É o tamanho do
/// `Hero`: a foto voa do quadro direto para ele.
Size _fittedSize(BoardPost post, Size box) =>
    applyBoxFit(BoxFit.contain, Size(post.aspectRatio, 1), box).destination;

/// Foto: a miniatura (já em cache, por isso aparece na hora) e, por cima,
/// a versão de tela cheia com zoom de pinça e de duplo toque.
class _PhotoPage extends ConsumerWidget {
  const _PhotoPage({super.key, required this.post, required this.onTap, required this.onZoom});

  final BoardPost post;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(mediaUrlProvider(post.viewPath)).valueOrNull;

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: SizedBox.fromSize(
              size: _fittedSize(post, constraints.biggest),
              child: Hero(
                tag: boardHeroTag(post),
                flightShuttleBuilder: boardHeroShuttle,
                child: BoardImage(path: post.gridPath, color: post.color),
              ),
            ),
          ),
          if (display != null)
            PhotoView(
              imageProvider: NetworkImage(display),
              backgroundDecoration: const BoxDecoration(color: Colors.transparent),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained * 4,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              // Enquanto a versão grande não chega, a miniatura de baixo
              // segura a tela.
              loadingBuilder: (_, _) => const SizedBox.shrink(),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
              onTapUp: (_, _, _) => onTap(),
              scaleStateChangedCallback: (state) => onZoom(state != PhotoViewScaleState.initial),
              semanticLabel: post.hasCaption ? post.caption : 'Foto',
            )
          else
            GestureDetector(behavior: HitTestBehavior.translucent, onTap: onTap),
        ],
      ),
    );
  }
}

/// Vídeo: a capa no lugar do `Hero` e o player por cima.
class _VideoPage extends StatelessWidget {
  const _VideoPage({
    super.key,
    required this.post,
    required this.active,
    required this.autoplay,
    required this.playPause,
    required this.onTap,
    required this.onController,
    this.onEnded,
  });

  final BoardPost post;
  final bool active;
  final bool autoplay;
  final Listenable playPause;
  final VoidCallback onTap;
  final VoidCallback? onEnded;
  final ValueChanged<VideoPlayerController?> onController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: SizedBox.fromSize(
              size: _fittedSize(post, constraints.biggest),
              child: Hero(
                tag: boardHeroTag(post),
                flightShuttleBuilder: boardHeroShuttle,
                child: BoardImage(
                  path: post.gridPath,
                  color: post.color,
                  isVideo: true,
                  iconSize: 40,
                ),
              ),
            ),
          ),
          BoardVideoPlayer(
            post: post,
            active: active,
            autoplay: autoplay,
            togglePlay: playPause,
            onTap: onTap,
            onEnded: onEnded,
            onController: onController,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controles
// ---------------------------------------------------------------------------

/// Uma camada de controles: aparece com a rota, some quando [visible] cai
/// e não recebe toque escondida.
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.visible,
    required this.appear,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final Animation<double> appear;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        ignoring: !visible,
        child: FadeTransition(
          opacity: appear,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: context.reduceMotion ? Duration.zero : Motion.normal,
            curve: Motion.smooth,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// O véu que garante leitura do texto sobre qualquer foto.
BoxDecoration _veil({required bool top}) => BoxDecoration(
  gradient: LinearGradient(
    begin: top ? Alignment.topCenter : Alignment.bottomCenter,
    end: top ? Alignment.bottomCenter : Alignment.topCenter,
    colors: [AppColors.darkBackground.withValues(alpha: 0.78), Colors.transparent],
  ),
);

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.post,
    required this.index,
    required this.total,
    required this.busy,
    required this.slideshow,
    required this.slideProgress,
    required this.onClose,
    required this.onSlideshow,
    required this.onShare,
    required this.onDownload,
    required this.onCaption,
    required this.onDelete,
  });

  final BoardPost post;
  final int index;
  final int total;
  final _Busy? busy;
  final bool slideshow;
  final Animation<double> slideProgress;
  final VoidCallback onClose;
  final VoidCallback onSlideshow;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onCaption;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(membersByIdProvider)[post.authorId];
    final uid = ref.watch(currentUidProvider);
    final canDelete = post.canDelete(uid, isAdmin: ref.watch(isTripAdminProvider));
    final canEdit = post.canEdit(uid);
    final name = member?.name ?? (post.authorName.isEmpty ? 'Ex-participante' : post.authorName);
    final narrow = context.isMobile;

    Widget action(_Busy kind, IconData icon, String tooltip, VoidCallback onPressed) => IconButton(
      tooltip: tooltip,
      onPressed: busy == null ? onPressed : null,
      icon: busy == kind
          ? const IconSkeleton(color: Colors.white)
          : Icon(icon, color: Colors.white),
    );

    return DecoratedBox(
      decoration: _veil(top: true),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.sm, Gap.xl),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Fechar',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              Gap.hXs,
              member != null
                  ? MemberAvatar(member: member, size: 32)
                  : InitialsAvatar(initials: initialsOf(name), size: 32),
              Gap.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${Fmt.dayMonth(post.takenAt)}, ${Fmt.time(post.takenAt)}',
                      style: AppTypography.numeric(size: 12.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (!narrow) ...[
                Text(
                  '${index + 1} de $total',
                  style: AppTypography.numeric(size: 13, color: Colors.white70),
                ),
                Gap.hMd,
              ],
              IconButton(
                tooltip: slideshow ? 'Parar a apresentação' : 'Passar sozinho',
                onPressed: onSlideshow,
                icon: Icon(
                  slideshow ? Icons.pause_circle_outline_rounded : Icons.slideshow_outlined,
                  color: slideshow ? AppColors.sun : Colors.white,
                ),
              ),
              action(_Busy.share, Icons.share_outlined, 'Compartilhar', onShare),
              action(
                _Busy.download,
                Icons.download_rounded,
                savesToGallery ? 'Salvar na galeria' : 'Baixar o original',
                onDownload,
              ),
              if (canEdit || canDelete)
                PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  enabled: busy == null,
                  onSelected: (value) => value == 'caption' ? onCaption() : onDelete(),
                  itemBuilder: (context) => [
                    if (canEdit)
                      PopupMenuItem(
                        value: 'caption',
                        child: Text(post.hasCaption ? 'Editar legenda' : 'Escrever legenda'),
                      ),
                    if (canDelete)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir', style: TextStyle(color: context.debt)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Embaixo: os controles do vídeo, a legenda e a tira de miniaturas.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.post,
    required this.posts,
    required this.index,
    required this.video,
    required this.onSelect,
  });

  final BoardPost post;
  final List<BoardPost> posts;
  final int index;
  final ValueListenable<VideoPlayerController?> video;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;

    return DecoratedBox(
      decoration: _veil(top: false),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: Gap.xxl, bottom: Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<VideoPlayerController?>(
                valueListenable: video,
                builder: (context, controller, _) => AnimatedSize(
                  duration: duration,
                  curve: Motion.enter,
                  child: controller == null || !post.isVideo
                      ? const SizedBox(width: double.infinity)
                      : VideoControlBar(controller: controller),
                ),
              ),
              AnimatedSwitcher(
                duration: duration,
                child: post.hasCaption
                    ? Padding(
                        key: ValueKey('caption-${post.id}-${post.caption}'),
                        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.md),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Text(
                              post.caption!.trim(),
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyLarge?.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    : SizedBox(key: ValueKey('none-${post.id}'), width: double.infinity),
              ),
              _Filmstrip(posts: posts, index: index, onSelect: onSelect),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tira de miniaturas: a foto aberta fica no meio, maior e com a borda
/// do sol — a cor do "agora" no app.
class _Filmstrip extends StatefulWidget {
  const _Filmstrip({required this.posts, required this.index, required this.onSelect});

  final List<BoardPost> posts;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  State<_Filmstrip> createState() => _FilmstripState();
}

class _FilmstripState extends State<_Filmstrip> {
  static const _extent = 52.0;
  late final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(animate: false));
  }

  @override
  void didUpdateWidget(_Filmstrip old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _center(animate: !context.reduceMotion);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _center({required bool animate}) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target = (widget.index * _extent + _extent / 2 - position.viewportDimension / 2).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if (animate) {
      _scroll.animateTo(target, duration: Motion.slow, curve: Motion.enter);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;
    if (widget.posts.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 60,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Poucas fotos ficam centralizadas, em vez de grudadas à esquerda.
          final content = widget.posts.length * _extent;
          final side = math.max(Gap.lg, (constraints.maxWidth - content) / 2);

          return ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            itemExtent: _extent,
            padding: EdgeInsets.symmetric(horizontal: side),
            itemCount: widget.posts.length,
            itemBuilder: (context, i) {
              final post = widget.posts[i];
              final current = i == widget.index;
              return Semantics(
                button: true,
                selected: current,
                label: '${post.isVideo ? 'Vídeo' : 'Foto'} ${i + 1} de ${widget.posts.length}',
                child: GestureDetector(
                  onTap: () => widget.onSelect(i),
                  child: Center(
                    child: AnimatedContainer(
                      duration: duration,
                      curve: Motion.spring,
                      width: current ? 48 : 40,
                      height: current ? 56 : 44,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: Radii.brSm,
                        color: current ? AppColors.sun : Colors.transparent,
                      ),
                      child: AnimatedOpacity(
                        duration: duration,
                        opacity: current ? 1 : 0.55,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(Radii.sm - 2)),
                          child: BoardImage(
                            path: post.gridPath,
                            color: post.color,
                            isVideo: post.isVideo,
                            iconSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// As setas laterais do computador.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.visible, required this.left, required this.onTap});

  final bool visible;
  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: context.reduceMotion ? Duration.zero : Motion.normal,
            child: IconButton.filled(
              tooltip: left ? 'Anterior' : 'Próxima',
              onPressed: onTap,
              style: IconButton.styleFrom(
                fixedSize: const Size(48, 48),
                shape: const CircleBorder(),
                backgroundColor: AppColors.night.withValues(alpha: 0.55),
                foregroundColor: Colors.white,
              ),
              icon: Icon(left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
