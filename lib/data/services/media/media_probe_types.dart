import 'dart:typed_data';

/// Maior lado da versão de tela cheia: nítida num monitor grande, e um
/// quinto do peso do original de um celular.
const displaySide = 2048;

/// Maior lado da miniatura da grade. Uma coluna do mural tem até ~400px; a
/// 2x, isso pede 800.
const thumbSide = 800;

/// O que o app descobre de um arquivo antes de postar: tamanho, duração,
/// a cor média e as versões reduzidas em JPEG.
///
/// Tudo é opcional. Um formato que o aparelho não sabe abrir (HEIC no
/// Chrome, vídeo HEVC) chega aqui vazio e é postado mesmo assim, só que sem
/// miniatura.
class MediaProbe {
  const MediaProbe({
    this.width,
    this.height,
    this.duration,
    this.colorValue,
    this.thumb,
    this.display,
  });

  final int? width;
  final int? height;
  final Duration? duration;
  final int? colorValue;
  final Uint8List? thumb;
  final Uint8List? display;
}

/// A cor média de pixels RGBA, opaca. Serve de fundo do quadro enquanto a
/// foto carrega.
int averageColor(List<int> rgba) {
  var r = 0, g = 0, b = 0, n = 0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    r += rgba[i];
    g += rgba[i + 1];
    b += rgba[i + 2];
    n++;
  }
  if (n == 0) return 0xFF808080;
  return 0xFF000000 | ((r ~/ n) << 16) | ((g ~/ n) << 8) | (b ~/ n);
}
