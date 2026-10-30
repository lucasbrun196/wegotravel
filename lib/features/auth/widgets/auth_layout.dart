import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/domain/brand_mark.dart';
import '../../../shared/widgets/effects/fade_slide_in.dart';

/// A moldura das telas de fora do app: login, cadastro e nova senha.
///
/// No computador a ilustração ocupa uma coluna inteira à esquerda e o
/// formulário fica solto sobre o papel, sem cartão. No celular a ilustração
/// vira o topo da tela e o formulário sobe por cima dela, como uma folha —
/// e rola, porque o teclado come metade da tela.
///
/// O login mostra o pôster do avião. A tela de nova senha mostra um
/// horizonte desenhado: cada ilustração aparece num lugar só do app.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child, this.illustrated = true});

  final Widget child;

  /// O pôster do avião (login) ou o horizonte desenhado (nova senha).
  final bool illustrated;

  @override
  Widget build(BuildContext context) {
    final cover = _Cover(illustrated: illustrated);

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: context.isMobile ? _buildMobile(context, cover) : _buildWide(context, cover),
    );
  }

  Widget _buildWide(BuildContext context, Widget cover) {
    final width = MediaQuery.sizeOf(context).width;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Larga demais, a ilustração amplia além do arquivo e borra.
        SizedBox(width: (width * 0.42).clamp(360.0, 620.0), child: cover),
        Expanded(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Gap.xxl, vertical: Gap.xxxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: FadeSlideIn(index: 2, child: child),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context, Widget cover) {
    final height = (MediaQuery.sizeOf(context).height * 0.36).clamp(220.0, 340.0);
    // A folha do formulário avança sobre a ilustração.
    const overlap = 28.0;

    return Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, height: height, child: cover),
        SingleChildScrollView(
          padding: EdgeInsets.only(top: height - overlap),
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height - height + overlap,
            ),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              Gap.xl,
              Gap.xl,
              Gap.xl,
              Gap.xl + MediaQuery.paddingOf(context).bottom,
            ),
            // No alto da folha, não no meio: um formulário curto (o do link
            // vencido) ficaria boiando com um vão em cima.
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeSlideIn(index: 2, child: child),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A ilustração com a marca por cima. Decorativa: fica fora da árvore de
/// acessibilidade, menos o nome do app.
///
/// Entra aproximando de leve e assentando, uma vez, quando a tela abre — o
/// único movimento de abertura da tela.
class _Cover extends StatelessWidget {
  const _Cover({required this.illustrated});

  final bool illustrated;

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: context.reduceMotion ? 1 : 1.06, end: 1),
            duration: const Duration(milliseconds: 1600),
            curve: Motion.enter,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: ColorFiltered(
              // No escuro, o mesmo véu azul-noite das outras ilustrações.
              colorFilter: ColorFilter.mode(
                AppColors.darkBackground.withValues(alpha: context.isDark ? 0.18 : 0),
                BlendMode.srcATop,
              ),
              child: illustrated
                  ? Image.asset(
                      'assets/images/cover_airplane.jpg',
                      fit: BoxFit.cover,
                      // O avião e o sol ficam no terço de cima: no celular,
                      // onde a faixa é baixa, é deles que a imagem não abre mão.
                      alignment: mobile ? const Alignment(0, -0.35) : Alignment.center,
                      filterQuality: FilterQuality.medium,
                      excludeFromSemantics: true,
                    )
                  : const CustomPaint(painter: _HorizonPainter()),
            ),
          ),
          // Véu curto no alto, só onde a marca fica, para o branco ler sobre
          // o céu claro.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment(0, -0.45),
                colors: [Color(0x5214283B), Color(0x0014283B)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(mobile ? Gap.xl : Gap.xxl),
              child: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandMark(size: mobile ? 22 : 26, color: Colors.white),
                    if (!mobile) ...[
                      Gap.vSm,
                      Text(
                        'Roteiro, contas e fotos da viagem',
                        style: context.text.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O horizonte desenhado da tela de nova senha: céu, nuvens, o sol meio
/// posto e o reflexo dele no mar. Mesmas cores chapadas das ilustrações.
class _HorizonPainter extends CustomPainter {
  const _HorizonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.62;

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF7FB2E5));

    // Nuvens: cápsulas creme, como as dos pôsteres.
    final cloud = Paint()..color = AppColors.sand;
    void capsule(double x, double y, double len, double thick) => canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, len, thick), Radius.circular(thick / 2)),
          cloud,
        );
    capsule(w * 0.08, h * 0.22, w * 0.34, h * 0.035);
    capsule(w * 0.18, h * 0.27, w * 0.22, h * 0.03);
    capsule(w * 0.58, h * 0.36, w * 0.30, h * 0.03);

    final radius = w * 0.24;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, w, horizon));
    canvas.drawCircle(Offset(w * 0.6, horizon), radius, Paint()..color = AppColors.sun);
    canvas.restore();

    canvas.drawRect(Rect.fromLTRB(0, horizon, w, h), Paint()..color = AppColors.deepSea);
    canvas.drawRect(
      Rect.fromLTRB(0, horizon + (h - horizon) * 0.45, w, h),
      Paint()..color = AppColors.night,
    );

    final glint = Paint()
      ..color = AppColors.sun.withValues(alpha: 0.8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h * 0.012;
    for (final (i, frac) in [0.7, 0.5, 0.32].indexed) {
      final y = horizon + (h - horizon) * (0.12 + i * 0.13);
      final half = radius * frac;
      canvas.drawLine(Offset(w * 0.6 - half, y), Offset(w * 0.6 + half, y), glint);
    }
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => false;
}
