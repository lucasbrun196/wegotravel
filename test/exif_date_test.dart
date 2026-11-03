import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:we_go_travel/core/utils/exif_date.dart';

/// Um JPEG mínimo: o marcador de início, o APP1 com o EXIF e o começo da
/// imagem. [tag] escolhe onde a data fica: `0x9003` (DateTimeOriginal) no
/// IFD do EXIF, ou `0x0132` (DateTime) direto no IFD0.
Uint8List jpegWithExif(String date, {Endian endian = Endian.little, int tag = 0x9003}) {
  final tiff = BytesBuilder();
  void u16(int v) => tiff.add((ByteData(2)..setUint16(0, v, endian)).buffer.asUint8List());
  void u32(int v) => tiff.add((ByteData(4)..setUint32(0, v, endian)).buffer.asUint8List());

  tiff.add(endian == Endian.little ? [0x49, 0x49] : [0x4D, 0x4D]);
  u16(42);
  u32(8);

  final text = [...date.codeUnits, 0];

  if (tag == 0x0132) {
    // IFD0 com a data dentro dele.
    u16(1);
    u16(0x0132);
    u16(2);
    u32(text.length);
    u32(8 + 2 + 12 + 4);
    u32(0);
  } else {
    // IFD0 apontando para o IFD do EXIF, que tem a data.
    u16(1);
    u16(0x8769);
    u16(4);
    u32(1);
    u32(26);
    u32(0);
    u16(1);
    u16(tag);
    u16(2);
    u32(text.length);
    u32(26 + 2 + 12 + 4);
    u32(0);
  }
  tiff.add(text);

  final payload = [0x45, 0x78, 0x69, 0x66, 0, 0, ...tiff.takeBytes()];
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xFF, 0xD8, //
    0xFF, 0xE1, length >> 8, length & 0xFF, ...payload,
    0xFF, 0xDA, 0, 2,
  ]);
}

void main() {
  group('Data da foto pelo EXIF', () {
    test('lê a DateTimeOriginal como horário local', () {
      expect(exifTakenAt(jpegWithExif('2026:11:14 16:32:05')), DateTime(2026, 11, 14, 16, 32, 5));
    });

    test('entende a ordem de bytes da Motorola', () {
      expect(
        exifTakenAt(jpegWithExif('2025:01:02 08:00:00', endian: Endian.big)),
        DateTime(2025, 1, 2, 8),
      );
    });

    test('sem o IFD do EXIF, usa a data da imagem', () {
      expect(
        exifTakenAt(jpegWithExif('2024:12:31 23:59:59', tag: 0x0132)),
        DateTime(2024, 12, 31, 23, 59, 59),
      );
    });

    test('câmera sem relógio acertado não vira data', () {
      expect(exifTakenAt(jpegWithExif('0000:00:00 00:00:00')), isNull);
    });

    test('JPEG sem EXIF devolve nulo', () {
      expect(exifTakenAt(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDA, 0, 2])), isNull);
    });

    test('outro formato devolve nulo', () {
      expect(exifTakenAt(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])), isNull);
    });

    test('arquivo cortado no meio não lança', () {
      final whole = jpegWithExif('2026:11:14 16:32:05');
      for (var cut = 0; cut < whole.length; cut += 3) {
        expect(() => exifTakenAt(Uint8List.sublistView(whole, 0, cut)), returnsNormally);
      }
    });
  });
}
