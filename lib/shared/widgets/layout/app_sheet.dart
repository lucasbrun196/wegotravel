import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';
import '../feedback/loading_shimmer.dart';

/// Formulário adaptativo: sobe como bottom sheet no celular e aparece
/// como diálogo centralizado no desktop. Mesmo conteúdo nos dois.
///
/// O conteúdo é reembrulhado no `ProviderContainer` de quem abriu.
/// Diálogos e bottom sheets são montados no overlay do Navigator raiz,
/// ou seja, **fora** do `ProviderScope` que a TripScope cria — sem isso,
/// qualquer formulário aberto dentro de uma viagem perderia o
/// [currentTripIdProvider] e falharia ao salvar.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
  double maxWidth = 560,
}) {
  final container = ProviderScope.containerOf(context);
  final isCompact = context.isMobile;

  Widget scoped(Widget child) =>
      UncontrolledProviderScope(container: container, child: child);

  if (isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => scoped(
        Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: _SheetBody(title: title, subtitle: subtitle, child: builder(context)),
        ),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (context) => scoped(
      Dialog(
        // Sem isto o rodapé do `SheetActions`, que pinta um fundo sólido
        // até a borda, cobre os dois cantos de baixo do diálogo — que
        // aparecem arredondados em cima e quadrados embaixo.
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(Gap.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: _SheetBody(
            title: title,
            subtitle: subtitle,
            showClose: true,
            child: builder(context),
          ),
        ),
      ),
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.child,
    this.subtitle,
    this.showClose = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // O corpo já traz folga no topo para o label flutuante do
          // primeiro campo; aqui fechamos com um respiro menor.
          padding: EdgeInsets.fromLTRB(Gap.xl, showClose ? Gap.xl : Gap.sm, Gap.md, Gap.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: context.text.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      Gap.vXs,
                      Text(
                        subtitle!,
                        style: context.text.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (showClose)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Fechar',
                ),
            ],
          ),
        ),
        Flexible(child: child),
      ],
    );
  }
}

/// Rodapé fixo de formulário, com ação primária à direita.
class SheetActions extends StatelessWidget {
  const SheetActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.isLoading = false,
    this.destructive = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool isLoading;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryLabel == null
        ? null
        : OutlinedButton(
            // O padding do tema é generoso para botões soltos; aqui
            // o botão é estreito e a palavra quebrava em duas linhas.
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            ),
            onPressed: isLoading ? null : onSecondary,
            child: Text(
              secondaryLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );

    final fill = destructive ? context.colors.error : context.action;
    final onFill = destructive ? context.colors.onError : context.onAction;
    final primary = FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        backgroundColor: destructive ? context.colors.error : null,
        // Salvando, o botão segue na cor dele: quem some é o rótulo, que
        // vira esqueleto.
        disabledBackgroundColor: isLoading ? fill : null,
      ),
      onPressed: isLoading ? null : onPrimary,
      child: isLoading
          ? ButtonSkeleton(color: onFill)
          : Text(
              primaryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.outline)),
      ),
      // Lado a lado em 320px o botão secundário fica com ~60px e "Cancelar"
      // vira "Cancela…". Em tela estreita eles empilham, o primário em cima.
      child: context.isNarrow && secondary != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [primary, Gap.vSm, secondary],
            )
          : Row(
              children: [
                if (secondary != null) ...[
                  Expanded(child: secondary),
                  Gap.hMd,
                ],
                Expanded(flex: 2, child: primary),
              ],
            ),
    );
  }
}
