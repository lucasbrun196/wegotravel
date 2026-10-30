import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_tokens.dart';
import '../effects/fade_slide_in.dart';

/// Estrutura padrão de página: título, subtítulo, ação e conteúdo rolável
/// com largura limitada. Mantém o ritmo visual igual em todas as telas.
///
/// O cabeçalho e cada bloco de [children] entram em sequência, subindo e
/// aparecendo — a página se monta de cima para baixo em vez de surgir
/// inteira de uma vez.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
    this.action,
    this.header,
    this.floatingActionButton,
    this.backgroundColor,
    this.bottomSlivers = const [],
  });

  final String title;
  final String? subtitle;

  /// Antes do título — em geral um botão de voltar.
  final Widget? leading;
  final Widget? action;

  /// Substitui o cabeçalho padrão (título, subtítulo e ação) por um
  /// próprio, como o painel do Resumo.
  final Widget? header;

  /// Transparente por padrão, porque a página costuma viver dentro do
  /// `Scaffold` da casca da viagem. Telas montadas no Navigator raiz
  /// precisam pintar o próprio fundo.
  final Color? backgroundColor;
  final List<Widget> children;
  final List<Widget> bottomSlivers;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final topPad = context.isMobile ? Gap.md : Gap.xxl;

    final defaultHeader = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, Gap.hSm],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: context.isMobile ? context.text.headlineLarge : context.text.displaySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle != null) ...[
                Gap.vXs,
                Text(subtitle!, style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                )),
              ],
            ],
          ),
        ),
        if (action != null) ...[Gap.hMd, action!],
      ],
    );

    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ContentContainer(
                child: Padding(
                  padding: EdgeInsets.only(top: topPad, bottom: Gap.xl),
                  // Largura cheia: sem isto um cabeçalho próprio (o painel do
                  // Resumo) encolhe ao tamanho do texto e fica centralizado.
                  child: SizedBox(
                    width: double.infinity,
                    child: FadeSlideIn(child: header ?? defaultHeader),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ContentContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, child) in children.indexed)
                      // Espaçadores não precisam de animação — e contariam
                      // na sequência, atrasando o bloco seguinte à toa.
                      child is SizedBox && child.child == null
                          ? child
                          : FadeSlideIn(index: i + 1, child: child),
                  ],
                ),
              ),
            ),
            ...bottomSlivers,
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}
