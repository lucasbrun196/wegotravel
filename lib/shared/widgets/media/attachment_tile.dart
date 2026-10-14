import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/attachment.dart';
import '../feedback/app_toast.dart';

/// Miniatura de um comprovante. Imagem mostra preview; PDF mostra ícone.
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb({
    super.key,
    required this.attachment,
    this.onDelete,
    this.size = 72,
  });

  final Attachment attachment;
  final VoidCallback? onDelete;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          borderRadius: Radii.brMd,
          onTap: () => openAttachment(context, attachment),
          child: Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHigh,
              borderRadius: Radii.brMd,
              border: Border.all(color: context.colors.outline),
            ),
            child: attachment.isImage
                ? CachedNetworkImage(
                    imageUrl: attachment.url,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 20),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        attachment.isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.insert_drive_file_rounded,
                        color: context.colors.primary,
                        size: 24,
                      ),
                      Gap.vXs,
                      Text(
                        Fmt.fileSize(attachment.sizeBytes),
                        style: context.text.labelSmall,
                      ),
                    ],
                  ),
          ),
        ),
        // Ação irreversível: o alvo precisa caber num polegar. Fica **dentro**
        // dos limites do thumb — em `top/right` negativos a área de toque
        // podia cair fora do pai e simplesmente não responder.
        if (onDelete != null)
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: context.colors.surface,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onDelete,
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Abre o comprovante.
///
/// É o único ponto do app com comportamento diferente por plataforma:
/// na Web o navegador já sabe exibir imagem e PDF em uma nova aba; no
/// celular o sistema escolhe o aplicativo adequado.
Future<void> openAttachment(BuildContext context, Attachment attachment) async {
  final uri = Uri.tryParse(attachment.url);
  if (uri == null) return;

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    AppToast.error('Não deu para abrir o arquivo');
  }
}

/// Linha de comprovantes com botão de adicionar.
class AttachmentStrip extends StatelessWidget {
  const AttachmentStrip({
    super.key,
    required this.attachments,
    this.onAdd,
    this.onDelete,
    this.uploading = false,
    this.progress,
    this.addLabel = 'Anexar',
  });

  final List<Attachment> attachments;
  final VoidCallback? onAdd;
  final void Function(Attachment)? onDelete;
  final bool uploading;
  final double? progress;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final attachment in attachments)
          AttachmentThumb(
            attachment: attachment,
            onDelete: onDelete == null ? null : () => onDelete!(attachment),
          ),
        if (uploading)
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHigh,
              borderRadius: Radii.brMd,
            ),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6, value: progress),
              ),
            ),
          ),
        if (onAdd != null && !uploading)
          InkWell(
            borderRadius: Radii.brMd,
            onTap: onAdd,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: Radii.brMd,
                border: Border.all(
                  color: context.colors.outline,
                  width: 1.4,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 20, color: context.colors.onSurfaceVariant),
                  Gap.vXs,
                  Text(addLabel, style: context.text.labelSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
