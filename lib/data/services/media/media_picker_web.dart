import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

import 'local_media.dart';

/// Arquivo escolhido no navegador.
///
/// Fica como `File` do próprio navegador até a hora de enviar: o upload
/// sai dele direto (`putBlob`), sem copiar os bytes para o Dart. Num vídeo
/// de 100 MB é a diferença entre enviar e travar a aba.
class WebLocalMedia extends LocalMedia {
  WebLocalMedia(this.file)
      : mimeType = file.type.isNotEmpty ? file.type : mediaTypeFor(file.name);

  final web.File file;

  @override
  final String mimeType;

  @override
  String get name => file.name;

  @override
  int get sizeBytes => file.size;

  @override
  DateTime? get lastModified =>
      file.lastModified > 0 ? DateTime.fromMillisecondsSinceEpoch(file.lastModified) : null;

  String? _objectUrl;

  /// Endereço `blob:` do arquivo, criado na primeira vez que alguém pede.
  String get objectUrl => _objectUrl ??= web.URL.createObjectURL(file);

  @override
  ImageProvider? get preview => isImage ? NetworkImage(objectUrl) : null;

  @override
  Future<Uint8List> readAsBytes() async =>
      (await file.arrayBuffer().toDart).toDart.asUint8List();

  @override
  Future<Uint8List> readHead(int length) async =>
      (await file.slice(0, length).arrayBuffer().toDart).toDart.asUint8List();

  @override
  UploadTask putTo(Reference ref, SettableMetadata metadata) => ref.putBlob(file, metadata);

  @override
  void dispose() {
    final url = _objectUrl;
    if (url != null) web.URL.revokeObjectURL(url);
    _objectUrl = null;
  }
}

/// Fotos e vídeos do aparelho. Com [multiple], dá para marcar vários de
/// uma vez; escolher um só também funciona.
Future<List<LocalMedia>> pickMedia({bool multiple = true}) =>
    _pick(accept: 'image/*,video/*', multiple: multiple);

/// A câmera do próprio sistema, para quando a do app não abre. No celular
/// o atributo `capture` vai direto para a câmera; no computador vira um
/// seletor de arquivos comum.
Future<List<LocalMedia>> captureWithSystemCamera() =>
    _pick(accept: 'image/*', multiple: false, capture: 'environment');

Future<List<LocalMedia>> _pick({
  required String accept,
  required bool multiple,
  String? capture,
}) {
  final done = Completer<List<LocalMedia>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..multiple = multiple;
  input.style.display = 'none';
  if (capture != null) input.capture = capture;

  void finish(List<LocalMedia> files) {
    if (!done.isCompleted) done.complete(files);
    input.remove();
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      finish(filesOf(input.files));
    }.toJS,
  );
  // Sem este evento (navegador antigo) o futuro só não termina — nada
  // fica esperando por ele além de quem abriu o seletor.
  input.addEventListener(
    'cancel',
    (web.Event _) {
      finish(const []);
    }.toJS,
  );

  // O Safari do iPhone só abre o seletor de um campo que está na página.
  web.document.body?.append(input);
  input.click();
  return done.future;
}

/// Converte a `FileList` do navegador.
List<LocalMedia> filesOf(web.FileList? list) => [
      if (list != null)
        for (var i = 0; i < list.length; i++)
          if (list.item(i) case final file?) WebLocalMedia(file),
    ];
