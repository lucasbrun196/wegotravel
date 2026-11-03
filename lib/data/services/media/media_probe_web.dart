import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'local_media.dart';
import 'media_picker_web.dart';
import 'media_probe_types.dart';

export 'media_probe_types.dart';

/// Mede o arquivo e gera as versões reduzidas com o próprio navegador.
///
/// Decodificar e reduzir uma foto de 12 MP em Dart levaria segundos com a
/// tela travada; o `createImageBitmap` e o canvas fazem isso nativamente,
/// já aplicando a orientação do EXIF. Nunca lança: o que não deu para
/// ler volta vazio.
Future<MediaProbe> probeMedia(LocalMedia media) async {
  try {
    final blob = await _blobOf(media);
    return media.isVideo ? await _probeVideo(blob) : await _probeImage(blob);
  } catch (_) {
    return const MediaProbe();
  }
}

Future<web.Blob> _blobOf(LocalMedia media) async {
  if (media is WebLocalMedia) return media.file;
  final bytes = await media.readAsBytes();
  return web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: media.mimeType));
}

Future<MediaProbe> _probeImage(web.Blob blob) async {
  final (source, width, height, release) = await _decode(blob);
  try {
    final display = _draw(source, width, height, displaySide);
    final thumb = _draw(display, display.width, display.height, thumbSide);
    return MediaProbe(
      width: width,
      height: height,
      colorValue: _averageColor(thumb),
      display: await _jpeg(display, 0.85),
      thumb: await _jpeg(thumb, 0.78),
    );
  } finally {
    release();
  }
}

/// `createImageBitmap` decodifica fora da thread principal. O Safari não
/// faz isso com HEIC, mas sabe mostrar o HEIC numa `<img>`: ela é o plano B.
Future<(web.CanvasImageSource, int, int, void Function())> _decode(web.Blob blob) async {
  try {
    final bitmap = await web.window.createImageBitmap(blob).toDart;
    return (bitmap, bitmap.width, bitmap.height, () => bitmap.close());
  } catch (_) {
    final url = web.URL.createObjectURL(blob);
    final image = web.HTMLImageElement()..src = url;
    try {
      await image.decode().toDart;
    } catch (_) {
      web.URL.revokeObjectURL(url);
      rethrow;
    }
    return (
      image,
      image.naturalWidth,
      image.naturalHeight,
      () => web.URL.revokeObjectURL(url),
    );
  }
}

Future<MediaProbe> _probeVideo(web.Blob blob) async {
  final url = web.URL.createObjectURL(blob);
  final video = web.HTMLVideoElement()
    ..muted = true
    ..playsInline = true
    ..preload = 'auto'
    ..src = url;

  try {
    await _event(video, 'loadedmetadata', const Duration(seconds: 15));
    final seconds = video.duration;
    final duration = seconds.isFinite && seconds > 0
        ? Duration(milliseconds: (seconds * 1000).round())
        : null;
    final width = video.videoWidth, height = video.videoHeight;

    // A capa é opcional: o navegador pode ler a duração de um codec que ele
    // não consegue tocar (HEVC no Chrome do Windows).
    try {
      await _event(video, 'loadeddata', const Duration(seconds: 15));
      // O primeiro quadro costuma ser preto, da abertura do vídeo.
      video.currentTime = duration == null ? 0 : math.min(1.0, seconds / 3);
      await _event(video, 'seeked', const Duration(seconds: 8));

      final display = _draw(video, width, height, 1280);
      final thumb = _draw(display, display.width, display.height, thumbSide);
      return MediaProbe(
        width: width,
        height: height,
        duration: duration,
        colorValue: _averageColor(thumb),
        display: await _jpeg(display, 0.82),
        thumb: await _jpeg(thumb, 0.78),
      );
    } catch (_) {
      return MediaProbe(
        width: width > 0 ? width : null,
        height: height > 0 ? height : null,
        duration: duration,
      );
    }
  } finally {
    video.removeAttribute('src');
    video.load();
    web.URL.revokeObjectURL(url);
  }
}

/// Desenha [source] num canvas com o maior lado limitado a [maxSide].
web.HTMLCanvasElement _draw(web.CanvasImageSource source, int width, int height, int maxSide) {
  final scale = math.min(1.0, maxSide / math.max(1, math.max(width, height)));
  final canvas = web.HTMLCanvasElement()
    ..width = math.max(1, (width * scale).round())
    ..height = math.max(1, (height * scale).round());
  canvas.context2D
    ..imageSmoothingEnabled = true
    ..imageSmoothingQuality = 'high'
    ..drawImage(source, 0, 0, canvas.width, canvas.height);
  return canvas;
}

Future<Uint8List?> _jpeg(web.HTMLCanvasElement canvas, double quality) {
  final done = Completer<Uint8List?>();
  canvas.toBlob(
    (web.Blob? blob) {
      if (blob == null) {
        done.complete(null);
        return;
      }
      blob.arrayBuffer().toDart.then(
            (buffer) => done.complete(buffer.toDart.asUint8List()),
            onError: (Object _) => done.complete(null),
          );
    }.toJS,
    'image/jpeg',
    quality.toJS,
  );
  return done.future;
}

int _averageColor(web.HTMLCanvasElement source) {
  final tiny = web.HTMLCanvasElement()
    ..width = 8
    ..height = 8;
  final context = tiny.context2D..drawImage(source, 0, 0, 8, 8);
  return averageColor(context.getImageData(0, 0, 8, 8).data.toDart);
}

/// Espera um evento de mídia. Um `error` no meio do caminho, ou o tempo
/// estourado, viram exceção.
Future<void> _event(web.EventTarget target, String type, Duration timeout) {
  final done = Completer<void>();
  final onEvent = (web.Event _) {
    if (!done.isCompleted) done.complete();
  }.toJS;
  final onError = (web.Event _) {
    if (!done.isCompleted) done.completeError(StateError('mídia ilegível ($type)'));
  }.toJS;

  target.addEventListener(type, onEvent);
  target.addEventListener('error', onError);
  return done.future.timeout(timeout).whenComplete(() {
    target.removeEventListener(type, onEvent);
    target.removeEventListener('error', onError);
  });
}
