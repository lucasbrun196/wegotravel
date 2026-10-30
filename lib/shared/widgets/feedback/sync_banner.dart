import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/services/sync_status_service.dart';

/// Faixa no topo avisando que o app está offline, ou que uma alteração
/// ainda não subiu.
///
/// Embrulha a aplicação inteira — e não cada tela — porque o estado é da
/// sessão, não da página: vale igual na lista de viagens e dentro de uma.
///
/// Empurra o conteúdo para baixo em vez de flutuar sobre ele. Uma faixa
/// sobreposta cobriria justamente o cabeçalho da página, e em viagem a
/// informação "isto aqui pode estar velho" vale o deslocamento.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).valueOrNull;

    return Column(
      children: [
        AnimatedSize(
          duration: Motion.fast,
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: status == null || status == SyncStatus.online
              // Largura cheia mesmo vazio: sem isso a faixa "nasce"
              // estreita e cresce para os lados ao aparecer.
              ? const SizedBox(width: double.infinity)
              : _Bar(status: status),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final offline = status == SyncStatus.offline;
    final color = offline ? AppColors.warning : context.colors.onSurfaceVariant;

    return Material(
      color: color.withValues(alpha: 0.08),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                offline ? Icons.cloud_off_rounded : Icons.cloud_sync_rounded,
                size: 15,
                color: color,
              ),
              Gap.hSm,
              // Encolhe em vez de estourar: a faixa vive em qualquer
              // largura, inclusive na de um celular pequeno.
              Flexible(
                child: Text(
                  offline
                      ? 'Sem conexão. Mostrando o que já estava salvo'
                      : 'Enviando as alterações…',
                  style: context.text.labelMedium?.copyWith(color: context.colors.onSurface),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
