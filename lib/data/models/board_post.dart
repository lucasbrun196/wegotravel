import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/painting.dart' show Color;

import '../../core/utils/formatters.dart';

enum MediaKind {
  photo,
  video;

  static MediaKind of(String? name) => name == 'video' ? video : photo;
}

/// Uma foto ou um vídeo do mural.
///
/// O documento guarda só os **caminhos** no Storage, nunca o link de
/// download. O link carrega um token que abre o arquivo para quem o tiver,
/// sem passar por regra nenhuma; pedido na hora (`mediaUrlProvider`), ele
/// só sai para quem o Storage reconhece como participante da viagem.
///
/// Cada post tem até três arquivos: o original, que é o que se exporta, e
/// duas versões em JPEG geradas no aparelho de quem postou — a miniatura
/// da grade ([thumbPath]) e a de tela cheia ([displayPath]). No vídeo, as
/// duas são o quadro de capa.
class BoardPost {
  const BoardPost({
    required this.id,
    required this.authorId,
    required this.kind,
    required this.storagePath,
    required this.contentType,
    required this.takenAt,
    this.authorName = '',
    this.thumbPath,
    this.displayPath,
    this.fileName = '',
    this.sizeBytes = 0,
    this.width,
    this.height,
    this.durationMs,
    this.colorValue,
    this.caption,
    this.createdAt,
  });

  final String id;
  final String authorId;

  /// O nome de quem postou, copiado na hora do post: a pessoa pode sair da
  /// viagem, e a foto continua dizendo de quem é.
  final String authorName;
  final MediaKind kind;

  final String storagePath;
  final String? thumbPath;
  final String? displayPath;

  final String contentType;

  /// O nome do arquivo no aparelho de quem postou. Vira o nome do arquivo
  /// exportado.
  final String fileName;
  final int sizeBytes;

  /// Dimensões do original, já na orientação em que a foto é vista.
  final int? width;
  final int? height;
  final int? durationMs;

  /// A cor média da imagem: o que o quadro mostra enquanto a foto carrega.
  final int? colorValue;
  final String? caption;

  /// Quando a foto foi tirada (EXIF) ou, sem isso, quando o arquivo foi
  /// criado. É o que decide o dia em que ela aparece.
  final DateTime takenAt;

  /// Nulo enquanto o servidor não confirma a gravação.
  final DateTime? createdAt;

  bool get isVideo => kind == MediaKind.video;
  bool get isPhoto => kind == MediaKind.photo;

  Color? get color => colorValue == null ? null : Color(colorValue!);
  Duration? get duration => durationMs == null ? null : Duration(milliseconds: durationMs!);
  String get dayKey => Fmt.dayKey(takenAt);

  bool get hasCaption => caption != null && caption!.trim().isNotEmpty;

  /// A proporção do quadro na grade. Panorama e print de tela comprido
  /// viram faixas finas demais, então a grade corta nos limites; o
  /// visualizador mostra a imagem inteira.
  double get tileAspectRatio => aspectRatio.clamp(0.56, 1.9);

  double get aspectRatio {
    final w = width, h = height;
    if (w != null && h != null && w > 0 && h > 0) return w / h;
    return isVideo ? 16 / 9 : 4 / 5;
  }

  /// O que a tela cheia carrega: a versão reduzida e, sem ela, o original.
  String get viewPath => displayPath ?? thumbPath ?? storagePath;

  /// O quadro da grade. Vídeo sem capa não tem o que mostrar.
  String? get gridPath => thumbPath ?? displayPath ?? (isPhoto ? storagePath : null);

  /// Todos os arquivos do post, para apagar junto com ele.
  List<String> get storagePaths => [storagePath, ?thumbPath, ?displayPath];

  /// Quem postou exclui; o admin também, para limpar o mural.
  bool canDelete(String? uid, {required bool isAdmin}) =>
      uid != null && (uid == authorId || isAdmin);

  /// A legenda é de quem postou.
  bool canEdit(String? uid) => uid != null && uid == authorId;

  /// Mais recente primeiro; empate (rajada de fotos no mesmo segundo) pela
  /// ordem de envio.
  static int newestFirst(BoardPost a, BoardPost b) {
    final byTaken = b.takenAt.compareTo(a.takenAt);
    if (byTaken != 0) return byTaken;
    final byCreated = (b.createdAt ?? DateTime(9999)).compareTo(a.createdAt ?? DateTime(9999));
    if (byCreated != 0) return byCreated;
    return b.id.compareTo(a.id);
  }

  factory BoardPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BoardPost(
      id: doc.id,
      authorId: d['authorId'] as String? ?? '',
      authorName: d['authorName'] as String? ?? '',
      kind: MediaKind.of(d['kind'] as String?),
      storagePath: d['storagePath'] as String? ?? '',
      thumbPath: d['thumbPath'] as String?,
      displayPath: d['displayPath'] as String?,
      contentType: d['contentType'] as String? ?? 'application/octet-stream',
      fileName: d['fileName'] as String? ?? '',
      sizeBytes: (d['sizeBytes'] as num?)?.toInt() ?? 0,
      width: (d['width'] as num?)?.toInt(),
      height: (d['height'] as num?)?.toInt(),
      durationMs: (d['durationMs'] as num?)?.toInt(),
      colorValue: (d['colorValue'] as num?)?.toInt(),
      caption: d['caption'] as String?,
      takenAt: (d['takenAt'] as Timestamp?)?.toDate() ??
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// O documento novo. As regras do Firestore conferem os caminhos e a
  /// autoria, então isto só é gravado uma vez, na criação.
  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        'kind': kind.name,
        'storagePath': storagePath,
        'thumbPath': thumbPath,
        'displayPath': displayPath,
        'contentType': contentType,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'width': width,
        'height': height,
        'durationMs': durationMs,
        'colorValue': colorValue,
        'caption': caption,
        'takenAt': Timestamp.fromDate(takenAt),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
