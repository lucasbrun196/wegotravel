import 'dart:typed_data';

/// Quantos bytes do começo do arquivo bastam para achar o EXIF: ele fica
/// no segmento APP1, que vem antes da imagem e tem no máximo 64 KB.
const exifHeadBytes = 128 * 1024;

/// A data em que a foto foi tirada, lida do EXIF de um JPEG.
///
/// É ela que põe a foto no dia certo do mural: quem posta tudo na volta da
/// viagem não pode ver a viagem inteira cair no mesmo dia. Usa a
/// `DateTimeOriginal` (o clique) e, sem ela, a `DateTimeDigitized` e a
/// `DateTime` da imagem.
///
/// O EXIF não tem fuso: a hora é a do relógio da câmera, e assim ela volta
/// como horário local. Arquivo sem EXIF, corrompido ou de outro formato
/// devolve `null` — nunca lança.
DateTime? exifTakenAt(Uint8List bytes) {
  try {
    return _scanJpeg(bytes);
  } on RangeError {
    return null;
  }
}

DateTime? _scanJpeg(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 4 || data.getUint16(0) != 0xFFD8) return null;

  var pos = 2;
  while (pos + 4 <= bytes.length) {
    if (bytes[pos] != 0xFF) return null;
    final marker = bytes[pos + 1];

    // Bytes de preenchimento entre segmentos.
    if (marker == 0xFF) {
      pos++;
      continue;
    }

    // Começo da imagem ou fim do arquivo: daqui em diante não há EXIF.
    if (marker == 0xDA || marker == 0xD9) return null;

    final length = data.getUint16(pos + 2);
    if (marker == 0xE1 && _isExifHeader(bytes, pos + 4)) {
      return _readTiff(bytes, pos + 10, pos + 2 + length);
    }
    pos += 2 + length;
  }
  return null;
}

/// "Exif" seguido de dois zeros.
bool _isExifHeader(Uint8List bytes, int at) =>
    at + 6 <= bytes.length &&
    bytes[at] == 0x45 &&
    bytes[at + 1] == 0x78 &&
    bytes[at + 2] == 0x69 &&
    bytes[at + 3] == 0x66 &&
    bytes[at + 4] == 0 &&
    bytes[at + 5] == 0;

const _tagExifIfd = 0x8769;
const _tagDateTime = 0x0132;
const _tagDateTimeOriginal = 0x9003;
const _tagDateTimeDigitized = 0x9004;

/// O bloco TIFF dentro do APP1. Todos os deslocamentos são relativos ao
/// começo dele, e a ordem dos bytes vem nos dois primeiros: `II` (Intel)
/// ou `MM` (Motorola).
DateTime? _readTiff(Uint8List bytes, int start, int end) {
  final limit = end < bytes.length ? end : bytes.length;
  final view = ByteData.sublistView(bytes, start, limit);

  final Endian endian;
  if (view.getUint16(0) == 0x4949) {
    endian = Endian.little;
  } else if (view.getUint16(0) == 0x4D4D) {
    endian = Endian.big;
  } else {
    return null;
  }
  if (view.getUint16(2, endian) != 42) return null;

  final ifd0 = _readIfd(view, view.getUint32(4, endian), endian);
  final exifOffset = ifd0[_tagExifIfd];
  final exif = exifOffset == null ? const <int, int>{} : _readIfd(view, exifOffset, endian);

  for (final offset in [
    exif[_tagDateTimeOriginal],
    exif[_tagDateTimeDigitized],
    ifd0[_tagDateTime],
  ]) {
    if (offset == null) continue;
    final date = _parseDate(view, offset);
    if (date != null) return date;
  }
  return null;
}

/// Tag → valor (ou deslocamento, para os que não cabem em 4 bytes).
Map<int, int> _readIfd(ByteData view, int offset, Endian endian) {
  final count = view.getUint16(offset, endian);
  return {
    for (var i = 0; i < count; i++)
      view.getUint16(offset + 2 + i * 12, endian):
          view.getUint32(offset + 2 + i * 12 + 8, endian),
  };
}

/// "AAAA:MM:DD HH:MM:SS", como o EXIF grava. Câmera sem relógio acertado
/// grava zeros ou um ano impossível: isso vale como "sem data".
DateTime? _parseDate(ByteData view, int offset) {
  if (offset + 19 > view.lengthInBytes) return null;
  final text = String.fromCharCodes([
    for (var i = 0; i < 19; i++) view.getUint8(offset + i),
  ]);

  final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$').firstMatch(text);
  if (match == null) return null;

  final [year, month, day, hour, minute, second] = [
    for (var g = 1; g <= 6; g++) int.parse(match.group(g)!),
  ];
  if (year < 1990 || month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (hour > 23 || minute > 59 || second > 59) return null;

  return DateTime(year, month, day, hour, minute, second);
}
