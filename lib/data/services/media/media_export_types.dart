/// Um arquivo do mural a caminho de fora do app.
class ExportFile {
  const ExportFile({required this.url, required this.fileName, required this.mimeType});

  /// Link de download recém-pedido ao Storage.
  final String url;
  final String fileName;
  final String mimeType;

  bool get isVideo => mimeType.startsWith('video/');
}

enum ShareOutcome {
  shared,

  /// A pessoa fechou a folha de compartilhar sem escolher nada.
  cancelled,

  /// O navegador só abre o compartilhamento logo depois de um toque. Baixar
  /// os arquivos demorou, o toque "venceu", e é preciso pedir outro.
  needsTap,
}
