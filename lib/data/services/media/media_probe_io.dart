import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';

import 'local_media.dart';
import 'media_picker_io.dart';
import 'media_probe_types.dart';

export 'media_probe_types.dart';

/// Mede o arquivo e gera as versões reduzidas no celular.
///
/// A foto é decodificada pelo pacote `image` num isolate: ele aplica a
/// orientação do EXIF e não segura a tela enquanto trabalha. Do vídeo saem
/// só tamanho e duração; a capa fica para quando houver um plugin para
/// extrair quadro. Nunca lança: o que não deu para ler volta vazio.
Future<MediaProbe> probeMedia(LocalMedia media) async {
  try {
    return media.isVideo ? await _probeVideo(media) : await _probeImage(media);
  } catch (_) {
    return const MediaProbe();
  }
}

Future<MediaProbe> _probeImage(LocalMedia media) async {
  final result = await compute(_resize, await media.readAsBytes());
  if (result == null) return const MediaProbe();
  return MediaProbe(
    width: result.width,
    height: result.height,
    colorValue: result.color,
    display: result.display,
    thumb: result.thumb,
  );
}

typedef _Resized = ({int width, int height, int color, Uint8List display, Uint8List thumb});

_Resized? _resize(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final oriented = img.bakeOrientation(decoded);
  final display = _fit(oriented, displaySide);
  final thumb = _fit(display, thumbSide);
  final tiny = img.copyResize(thumb, width: 8, height: 8, interpolation: img.Interpolation.average);

  return (
    width: oriented.width,
    height: oriented.height,
    color: averageColor(tiny.getBytes(order: img.ChannelOrder.rgba)),
    display: img.encodeJpg(display, quality: 85),
    thumb: img.encodeJpg(thumb, quality: 78),
  );
}

img.Image _fit(img.Image image, int maxSide) {
  if (image.width <= maxSide && image.height <= maxSide) return image;
  return image.width >= image.height
      ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
      : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
}

Future<MediaProbe> _probeVideo(LocalMedia media) async {
  if (media is! FileLocalMedia) return const MediaProbe();

  final controller = VideoPlayerController.file(File(media.path));
  try {
    await controller.initialize().timeout(const Duration(seconds: 15));
    final size = controller.value.size;
    return MediaProbe(
      width: size.width > 0 ? size.width.round() : null,
      height: size.height > 0 ? size.height.round() : null,
      duration: controller.value.duration,
    );
  } finally {
    await controller.dispose();
  }
}
