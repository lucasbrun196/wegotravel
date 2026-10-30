import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip.dart';
import '../../../shared/widgets/domain/brand_mark.dart';
import '../../../shared/widgets/domain/member_avatar.dart';
import '../../../shared/widgets/domain/trip_countdown.dart';
import '../../../shared/widgets/effects/fade_slide_in.dart';
import '../../../shared/widgets/effects/theme_toggle.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../../../shared/widgets/inputs/add_button.dart';
import '../../../shared/widgets/media/parallax_image.dart';
import '../widgets/trip_form_sheet.dart';

/// Largura máxima da lista de viagens.
const _maxWidth = 980.0;

/// Lista das viagens em que a pessoa participa — a casa do app depois
/// do login.
///
/// No alto, a ilustração do mundo; embaixo, cada viagem como um bilhete,
/// com as datas e a contagem no canhoto.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(myTripsProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final mobile = context.isMobile;

    return Scaffold(
      body: Column(
        children: [
          const _HomeBar(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ContentContainer(
                      maxWidth: _maxWidth,
                      child: Padding(
                        padding: EdgeInsets.only(top: mobile ? Gap.sm : Gap.xl),
                        child: ClipRRect(
                          borderRadius: Radii.brXl,
                          child: SizedBox(
                            height: mobile ? 176 : 280,
                            // Puxada para cima: o avião e o globo são o que
                            // a faixa não pode cortar.
                            child: const ParallaxImage(
                              asset: 'assets/images/cover_world.jpg',
                              alignment: Alignment(0, -0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ContentContainer(
                      maxWidth: _maxWidth,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: mobile ? Gap.xl : Gap.xxl,
                          bottom: Gap.xl,
                        ),
                        child: FadeSlideIn(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        user == null ? 'Suas viagens' : 'Olá, ${user.shortName}',
                                        style: mobile
                                            ? context.text.headlineLarge
                                            : context.text.displaySmall,
                                      ),
                                    ),
                                    Gap.vXs,
                                    Text(
                                      'Escolha uma viagem ou crie uma nova.',
                                      style: context.text.bodyMedium?.copyWith(
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Gap.hMd,
                              AddButton(
                                label: 'Nova viagem',
                                onPressed: () => _createTrip(context, ref),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ContentContainer(
                      maxWidth: _maxWidth,
                      child: tripsAsync.when(
                        loading: () => const ShimmerList(itemCount: 3, itemHeight: 112),
                        error: (e, _) => ErrorView(
                          message: 'Não deu para carregar suas viagens',
                          details: '$e',
                          onRetry: () => ref.invalidate(myTripsProvider),
                        ),
                        data: (trips) => trips.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: Gap.lg),
                                child: EmptyState(
                                  icon: Icons.luggage_outlined,
                                  title: 'Nenhuma viagem ainda',
                                  message: 'Crie a primeira e adicione as pessoas pelo e-mail.',
                                  actionLabel: 'Criar viagem',
                                  onAction: () => _createTrip(context, ref),
                                ),
                              )
                            : _TicketGrid(trips: trips),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTrip(BuildContext context, WidgetRef ref) async {
    final id = await showTripForm(context);
    if (id != null && context.mounted) context.go('/viagem/$id/dashboard');
  }
}

/// A barra do alto da casa: a marca e a conta. Azul-noite a partir do
/// tablet, como a barra de dentro da viagem; no celular, da cor da página.
class _HomeBar extends StatelessWidget {
  const _HomeBar();

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    final onDark = !mobile;
    final background = mobile
        ? context.theme.scaffoldBackgroundColor
        : context.isDark
            ? AppColors.darkSurface
            : AppColors.night;

    return Material(
      color: background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: onDark && context.isDark
              ? Border(bottom: BorderSide(color: context.colors.outline))
              : null,
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: mobile ? 56 : 64,
            child: ContentContainer(
              maxWidth: _maxWidth,
              child: Row(
                children: [
                  BrandMark(
                    size: 19,
                    color: onDark ? Colors.white : null,
                    // Sobre a barra azul-noite, o selo clareia um tom para
                    // não sumir nela.
                    tile: onDark ? AppColors.nightRaised : null,
                  ),
                  const Spacer(),
                  Theme(
                    data: context.theme.copyWith(
                      iconButtonTheme: IconButtonThemeData(
                        style: IconButton.styleFrom(
                          foregroundColor: onDark ? const Color(0xFFA9BCCF) : null,
                          hoverColor: onDark ? Colors.white.withValues(alpha: 0.08) : null,
                        ),
                      ),
                    ),
                    child: const ThemeToggle(),
                  ),
                  Gap.hSm,
                  _AccountButton(onDark: onDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Os bilhetes em duas colunas quando cabem; numa só no celular. Os de uma
/// mesma linha ficam da mesma altura.
class _TicketGrid extends StatelessWidget {
  const _TicketGrid({required this.trips});

  final List<Trip> trips;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 760 ? 2 : 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < trips.length; i += perRow)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.lg),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = 0; j < perRow; j++) ...[
                        if (j > 0) Gap.hLg,
                        Expanded(
                          child: i + j < trips.length
                              ? FadeSlideIn(
                                  index: i + j + 1,
                                  child: _TripTicket(trip: trips[i + j]),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Uma viagem como bilhete: nome, destino e a turma à esquerda; no
/// canhoto, separado pelo picote, as datas e a contagem. Com a viagem em
/// andamento o canhoto ganha o amarelo do sol.
class _TripTicket extends ConsumerStatefulWidget {
  const _TripTicket({required this.trip});

  final Trip trip;

  @override
  ConsumerState<_TripTicket> createState() => _TripTicketState();
}

class _TripTicketState extends ConsumerState<_TripTicket> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isAdmin = trip.isAdmin(ref.watch(currentUidProvider));
    final muted = context.colors.onSurfaceVariant;
    final stubWidth = context.isNarrow ? 112.0 : 136.0;
    final lifted = _hovered && !context.reduceMotion;
    final people = trip.memberIds.length;

    final shape = _TicketBorder(
      stubWidth: stubWidth,
      side: BorderSide(
        color: lifted ? context.colors.primary.withValues(alpha: 0.5) : context.colors.outline,
      ),
    );

    final main = Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg + 2, Gap.lg, Gap.lg, Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            trip.name,
            style: context.text.titleLarge?.copyWith(fontSize: 17),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (trip.destination.isNotEmpty) ...[
            Gap.vXs,
            _IconLine(icon: Icons.place_outlined, text: trip.destination),
          ],
          Gap.vSm,
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _IconLine(
                icon: Icons.group_outlined,
                text: '$people ${people == 1 ? "pessoa" : "pessoas"}',
              ),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: Radii.brPill,
                  ),
                  child: Text(
                    'você organiza',
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    final stub = Container(
      width: stubWidth,
      color: trip.isOngoing ? context.sunSoft : null,
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.md, Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (trip.hasDates) ...[
            Text(
              Fmt.dayMonth(trip.startDate!),
              style: AppTypography.numeric(
                size: 16,
                weight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
            Text(
              'a ${Fmt.dayMonth(trip.endDate!)}',
              style: AppTypography.numeric(size: 13, color: muted),
            ),
            Gap.vSm,
          ],
          TripCountdown(trip: trip, style: context.text.labelSmall),
        ],
      ),
    );

    final ticket = AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.enter,
      transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
      child: Material(
        color: context.colors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        elevation: lifted ? 6 : 0,
        shadowColor: (context.isDark ? Colors.black : AppColors.night).withValues(alpha: 0.5),
        child: InkWell(
          customBorder: shape,
          onTap: () => context.go('/viagem/${trip.id}/dashboard'),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: main),
              _Perforation(color: context.colors.outline),
              stub,
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: [
        trip.name,
        if (trip.destination.isNotEmpty) trip.destination,
        ?tripCountdownLabel(trip),
      ].join(', '),
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (e) {
          if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = true);
        },
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _pressed && !context.reduceMotion ? 0.99 : 1,
          duration: Motion.instant,
          child: ticket,
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: muted),
        Gap.hXs,
        Flexible(
          child: Text(
            text,
            style: context.text.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// O picote entre o corpo do bilhete e o canhoto.
class _Perforation extends StatelessWidget {
  const _Perforation({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      child: CustomPaint(painter: _DashPainter(color)),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Começa e termina longe das mordidas do picote.
    const dash = 4.0, gap = 5.0, inset = _TicketBorder.notch + 6;
    for (var y = inset; y < size.height - inset; y += dash + gap) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, math.min(y + dash, size.height - inset)), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// O contorno de bilhete: retângulo de cantos redondos com duas mordidas
/// em meia-lua, em cima e embaixo, onde o canhoto se destaca.
class _TicketBorder extends ShapeBorder {
  const _TicketBorder({required this.stubWidth, this.side = BorderSide.none});

  /// Distância da mordida até a borda direita.
  final double stubWidth;
  final BorderSide side;

  static const notch = 9.0;
  static const radius = Radii.lg;

  Path _path(Rect rect) {
    final x = rect.right - stubWidth;
    const r = Radius.circular(radius);
    const n = Radius.circular(notch);

    return Path()
      ..moveTo(rect.left + radius, rect.top)
      ..lineTo(x - notch, rect.top)
      ..arcToPoint(Offset(x + notch, rect.top), radius: n, clockwise: false)
      ..lineTo(rect.right - radius, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + radius), radius: r)
      ..lineTo(rect.right, rect.bottom - radius)
      ..arcToPoint(Offset(rect.right - radius, rect.bottom), radius: r)
      ..lineTo(x + notch, rect.bottom)
      ..arcToPoint(Offset(x - notch, rect.bottom), radius: n, clockwise: false)
      ..lineTo(rect.left + radius, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - radius), radius: r)
      ..lineTo(rect.left, rect.top + radius)
      ..arcToPoint(Offset(rect.left + radius, rect.top), radius: r)
      ..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => _TicketBorder(stubWidth: stubWidth * t, side: side.scale(t));

  @override
  bool operator ==(Object other) =>
      other is _TicketBorder && other.stubWidth == stubWidth && other.side == side;

  @override
  int get hashCode => Object.hash(stubWidth, side);
}

/// Avatar com menu de conta e sair.
class _AccountButton extends ConsumerWidget {
  const _AccountButton({required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return PopupMenuButton<String>(
      tooltip: 'Sua conta',
      offset: const Offset(0, 48),
      onSelected: (value) async {
        if (value == 'conta') {
          context.push(Routes.account);
        } else if (value == 'sair') {
          await ref.read(authServiceProvider).signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user?.displayName ?? '', style: context.text.titleSmall),
              Text(user?.email ?? '', style: context.text.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'conta',
          child: Row(
            children: [
              Icon(Icons.manage_accounts_outlined, size: 18),
              SizedBox(width: Gap.md),
              Text('Minha conta'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'sair',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: Gap.md),
              Text('Sair'),
            ],
          ),
        ),
      ],
      // O `PopupMenuButton` embrulha o filho em um `InkWell`, que sem isto
      // desenha um quadrado atrás do avatar redondo.
      borderRadius: Radii.brPill,
      child: onDark
          ? InitialsAvatar(
              initials: user?.initials ?? '?',
              size: 34,
              background: AppColors.darkAction,
              foreground: AppColors.night,
            )
          : InitialsAvatar(initials: user?.initials ?? '?', size: 34),
    );
  }
}
