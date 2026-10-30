import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/domain/brand_mark.dart';

/// Mostrada enquanto o Firebase confere se existe uma sessão salva.
/// Segurar aqui evita o pisca de mandar para o login quem já está logado.
///
/// Repete a splash do `web/index.html` — o selo com o sol já nascido e a
/// barra fina —, para a troca de uma para a outra não aparecer. Quem anima
/// o sol nascendo é a do HTML, que aparece primeiro.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(),
            Gap.vXl,
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                minHeight: 2,
                borderRadius: Radii.brPill,
                backgroundColor: context.colors.surfaceContainerHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
