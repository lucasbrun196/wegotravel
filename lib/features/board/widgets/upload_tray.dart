import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import '../controllers/board_uploads.dart';

/// O andamento dos envios da viagem: a barra com o progresso de tudo e,
/// aberta, a lista arquivo por arquivo — com cancelar e tentar de novo.
///
/// Some sozinha quando tudo termina bem; com falha, fica até a pessoa
/// resolver ou fechar.
class UploadTray extends ConsumerStatefulWidget {
  const UploadTray({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<UploadTray> createState() => _UploadTrayState();
}

class _UploadTrayState extends ConsumerState<UploadTray> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final uploads =
        ref.watch(boardUploadsProvider).where((u) => u.tripId == widget.tripId).toList();
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: uploads.isEmpty
          ? const SizedBox.shrink(key: ValueKey('vazio'))
          : _card(context, uploads, duration),
    );
  }

  Widget _card(BuildContext context, List<BoardUpload> uploads, Duration duration) {
    final controller = ref.read(boardUploadsProvider.notifier);
    final pending = uploads.where((u) => u.isPending).length;
    final failed = uploads.where((u) => u.stage == UploadStage.failed).length;
    final finished = uploads.length - pending;

    // Cada arquivo pesa igual na barra: o que terminou conta inteiro, o que
    // está subindo conta o quanto subiu.
    final progress = uploads.fold<double>(
          0,
          (sum, u) => sum + (u.isPending ? (u.progress ?? 0) : 1),
        ) /
        uploads.length;

    final title = pending > 0
        ? 'Enviando ${finished + 1} de ${uploads.length}'
        : failed > 0
            ? (failed == 1 ? '1 envio falhou' : '$failed envios falharam')
            : 'Tudo no mural';

    return Material(
      key: const ValueKey('bandeja'),
      color: context.colors.surface,
      elevation: 0,
      borderRadius: Radii.brLg,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: Radii.brLg,
          border: Border.all(color: context.colors.outline),
          boxShadow: AppColors.float(dark: context.isDark),
        ),
        child: AnimatedSize(
          duration: duration,
          curve: Motion.enter,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.xs, Gap.sm),
                  child: Row(
                    children: [
                      _Ring(pending: pending > 0, failed: failed > 0),
                      Gap.hMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: context.text.titleSmall?.copyWith(
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (pending > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: Gap.xs, right: Gap.sm),
                                child: ShimmerProgress(
                                  value: progress == 0 ? null : progress,
                                  height: 3,
                                ),
                              ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: duration,
                        curve: Motion.spring,
                        child: Icon(Icons.expand_less_rounded, color: context.colors.onSurfaceVariant),
                      ),
                      if (pending == 0)
                        IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => controller.clearFinished(widget.tripId),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        )
                      else
                        Gap.hSm,
                    ],
                  ),
                ),
              ),
              if (_open) ...[
                const Divider(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 264),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                    itemCount: uploads.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, i) => _Row(
                      upload: uploads[i],
                      onCancel: () => controller.cancel(uploads[i].id),
                      onRetry: () => controller.retry(uploads[i].id),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.pending, required this.failed});

  final bool pending;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;
    return SizedBox(
      width: 28,
      height: 28,
      child: AnimatedSwitcher(
        duration: duration,
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        // Enviando, um círculo em esqueleto; a medida fica na barra ao lado.
        child: pending
            ? ShimmerBox(
                key: const ValueKey('enviando'),
                circle: true,
                height: 26,
                baseColor: context.colors.primary.withValues(alpha: 0.22),
                highlightColor: context.colors.primary.withValues(alpha: 0.65),
              )
            : Icon(
                failed ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                key: ValueKey(failed),
                size: 26,
                color: failed ? context.debt : context.success,
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.upload, required this.onCancel, required this.onRetry});

  final BoardUpload upload;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final media = upload.media;
    final preview = media.preview;
    final muted = context.colors.onSurfaceVariant;

    final (status, statusColor) = switch (upload.stage) {
      UploadStage.waiting => ('Na fila', muted),
      UploadStage.preparing => ('Preparando', muted),
      UploadStage.sending => (
          upload.progress == null ? 'Enviando' : Fmt.percent(upload.progress!),
          context.colors.primary,
        ),
      UploadStage.done => ('No mural', context.success),
      UploadStage.failed => (upload.error ?? 'O envio falhou', context.debt),
      UploadStage.cancelled => ('Cancelado', muted),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.xs, Gap.xs),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: Radii.brSm,
            child: SizedBox(
              width: 40,
              height: 40,
              child: ColoredBox(
                color: context.colors.surfaceContainerHigh,
                child: preview == null
                    ? Icon(Icons.videocam_outlined, size: 18, color: muted)
                    : Image(
                        image: ResizeImage(preview, width: 96),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(Icons.image_outlined, size: 18, color: muted),
                      ),
              ),
            ),
          ),
          Gap.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(media.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                const SizedBox(height: 2),
                if (upload.stage == UploadStage.sending || upload.stage == UploadStage.preparing)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 4, right: Gap.md),
                    child: ClipRRect(
                      borderRadius: Radii.brPill,
                      child: ShimmerProgress(value: upload.progress, height: 3),
                    ),
                  ),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.numeric(size: 12, color: statusColor),
                ),
              ],
            ),
          ),
          switch (upload.stage) {
            UploadStage.failed => IconButton(
                tooltip: 'Tentar de novo',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            UploadStage.done => Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Icon(Icons.check_rounded, size: 18, color: context.success),
              ),
            UploadStage.cancelled => const SizedBox(width: 48),
            _ => IconButton(
                tooltip: 'Cancelar',
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
          },
        ],
      ),
    );
  }
}
