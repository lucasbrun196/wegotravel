/// Configuração do mapa.
///
/// O token do Mapbox entra por `--dart-define`, nunca pelo código:
///
/// ```bash
/// flutter run -d web-server --web-port 5173 --dart-define=MAPBOX_TOKEN=pk.xxx
/// ```
///
/// Sem token o app continua funcionando — o seletor de mapa fica
/// desabilitado e o lugar é digitado à mão, como antes.
abstract final class MapConfig {
  /// Token público do Mapbox (começa com `pk.`). Vazio quando não foi
  /// passado no build.
  static const token = String.fromEnvironment('MAPBOX_TOKEN');

  static bool get isConfigured => token.isNotEmpty;

  /// Estilo do mapa, no formato `usuario/estilo`.
  ///
  /// Para usar um estilo próprio feito no Mapbox Studio, é só trocar esta
  /// constante pelo id de lá (`seu-usuario/clx...`). O resto do app não
  /// muda.
  static const style = 'mapbox/streets-v12';

  /// Tiles raster do estilo, no esquema de 256px.
  ///
  /// Isto é a **Static Tiles API**: o plano gratuito cobre 200 mil
  /// requisições por mês.
  ///
  /// As peças de 512px cobririam a mesma área com um quarto das
  /// requisições, mas não combinam com o `flutter_map`: ele desenha cada
  /// peça no tamanho do seu próprio esquema de 256px, então as de 512
  /// saem com o dobro do tamanho — o mapa fica mais aproximado do que
  /// deveria e as peças pedidas cobrem só um pedaço da caixa, deixando o
  /// resto cinza. Compensar com `zoomOffset: -1` conserta a escala e
  /// quebra as coordenadas: a partir de certo zoom o x/y estoura o limite
  /// do nível pedido e nenhuma peça é buscada. Com 256 em todo lugar,
  /// nada precisa ser compensado.
  ///
  /// O `{r}` vira `@2x` em telas de alta densidade — mesma quantidade de
  /// requisições, o dobro de resolução.
  static String get tileUrl =>
      'https://api.mapbox.com/styles/v1/$style'
      '/tiles/256/{z}/{x}/{y}{r}?access_token=$token';

  /// Identifica o app para o Mapbox e para o Nominatim.
  static const userAgent = 'com.viagem.wegotravel';

  /// Onde o mapa abre quando não há nenhuma pista de lugar: Brasil
  /// inteiro, para a pessoa navegar até onde quiser.
  static const fallbackLat = -14.235;
  static const fallbackLng = -51.925;
  static const fallbackZoom = 3.5;

  /// Zoom de quando já sabemos o ponto exato. Fechado o bastante para
  /// reconhecer a rua, aberto o bastante para saber em que bairro está.
  static const pinZoom = 13.0;
}
