import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'trip.dart';

/// Como o tempo vai estar, no vocabulário da tela.
///
/// A Open-Meteo devolve o código WMO, que tem dezenas de variações
/// ("chuvisco leve", "chuvisco moderado", "chuvisco congelante"). Para um
/// chip de dois centímetros isso não serve: agrupamos no que muda a mala
/// que a pessoa faz.
enum WeatherCondition {
  clear(label: 'Céu limpo', icon: Icons.wb_sunny_rounded, color: AppColors.sunset),
  partlyCloudy(label: 'Parcialmente nublado', icon: Icons.wb_cloudy_rounded, color: AppColors.sky),
  cloudy(label: 'Nublado', icon: Icons.cloud_rounded, color: AppColors.inkMuted),
  fog(label: 'Névoa', icon: Icons.foggy, color: AppColors.inkFaint),
  drizzle(label: 'Garoa', icon: Icons.grain_rounded, color: AppColors.sky),
  rain(label: 'Chuva', icon: Icons.umbrella_rounded, color: AppColors.sky),
  heavyRain(label: 'Chuva forte', icon: Icons.water_drop_rounded, color: AppColors.deepSea),
  snow(label: 'Neve', icon: Icons.ac_unit_rounded, color: AppColors.turquoise),
  storm(label: 'Tempestade', icon: Icons.thunderstorm_rounded, color: AppColors.plum);

  const WeatherCondition({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  /// Tabela de códigos WMO da Open-Meteo, agrupada.
  ///
  /// Código desconhecido cai em [cloudy]: é o palpite mais inofensivo.
  static WeatherCondition fromWmoCode(int code) => switch (code) {
        0 => clear,
        1 || 2 => partlyCloudy,
        3 => cloudy,
        45 || 48 => fog,
        51 || 53 || 55 || 56 || 57 => drizzle,
        61 || 63 || 66 || 80 || 81 => rain,
        65 || 67 || 82 => heavyRain,
        71 || 73 || 75 || 77 || 85 || 86 => snow,
        95 || 96 || 99 => storm,
        _ => cloudy,
      };
}

/// A previsão de uma hora do dia — a linha do tempo do painel.
@immutable
class HourlyWeather {
  const HourlyWeather({
    required this.time,
    required this.tempC,
    required this.code,
    this.precipProbability,
  });

  /// Hora local do lugar, como a API mandou.
  final DateTime time;

  final double tempC;
  final int code;
  final int? precipProbability;

  WeatherCondition get condition => WeatherCondition.fromWmoCode(code);

  String get tempLabel => '${tempC.round()}°';
}

/// A previsão de um dia em um ponto do mapa.
@immutable
class DailyWeather {
  const DailyWeather({
    required this.dayKey,
    required this.code,
    required this.tempMaxC,
    required this.tempMinC,
    this.apparentMaxC,
    this.apparentMinC,
    this.precipProbability,
    this.precipitationMm,
    this.windMaxKmh,
    this.uvIndexMax,
    this.sunrise,
    this.sunset,
    this.hours = const [],
  });

  /// `yyyy-MM-dd`, do jeito que a API devolveu — ver [Weather.parse].
  final String dayKey;

  final int code;
  final double tempMaxC;
  final double tempMinC;

  /// Sensação térmica: o que o corpo sente, contando vento e umidade.
  final double? apparentMaxC;
  final double? apparentMinC;

  /// Chance de chuva do dia, em porcentagem. A API nem sempre manda.
  final int? precipProbability;

  /// Quanto deve cair, em milímetros.
  final double? precipitationMm;

  final double? windMaxKmh;
  final double? uvIndexMax;
  final DateTime? sunrise;
  final DateTime? sunset;

  /// As 24 horas do dia, quando vieram na resposta.
  final List<HourlyWeather> hours;

  WeatherCondition get condition => WeatherCondition.fromWmoCode(code);

  /// O que cabe no chip: "28°/19°".
  String get tempLabel => '${tempMaxC.round()}°/${tempMinC.round()}°';

  /// A linha do tooltip, com a chance de chuva quando existe.
  String get detail => precipProbability == null
      ? condition.label
      : '${condition.label} · $precipProbability% de chuva';

  String? get apparentLabel => apparentMaxC == null || apparentMinC == null
      ? null
      : '${apparentMaxC!.round()}°/${apparentMinC!.round()}°';

  /// A pergunta que a pessoa realmente faz ao abrir o painel.
  ///
  /// A resposta sai da probabilidade, não do código da condição: um
  /// código de "chuva" com 15% de chance não deve mandar ninguém mudar o
  /// programa do dia.
  String get rainVerdict {
    final p = precipProbability;
    if (p == null) {
      return condition == WeatherCondition.clear
          ? 'Sem previsão de chuva'
          : 'Sem dado de chuva para este dia';
    }
    if (p < 20) return 'Não deve chover';
    if (p < 50) return 'Chuva pouco provável';
    if (p < 80) return 'Pode chover, leve guarda-chuva';
    return 'Deve chover';
  }

  bool get willRain => (precipProbability ?? 0) >= 50 || (precipitationMm ?? 0) >= 1;

  /// Faixa do índice UV, na escala da OMS.
  String? get uvLabel {
    final uv = uvIndexMax;
    if (uv == null) return null;
    if (uv < 3) return 'baixo';
    if (uv < 6) return 'moderado';
    if (uv < 8) return 'alto';
    if (uv < 11) return 'muito alto';
    return 'extremo';
  }

  /// A hora cheia mais próxima de [when] — o horário da atividade.
  ///
  /// Devolve `null` quando o dia não veio com detalhamento por hora.
  HourlyWeather? hourNear(DateTime when) {
    if (hours.isEmpty) return null;
    return hours.reduce((a, b) {
      final da = (a.time.difference(when)).abs();
      final db = (b.time.difference(when)).abs();
      return db < da ? b : a;
    });
  }
}

/// Coordenada de consulta, arredondada.
///
/// Duas atividades na mesma cidade não precisam de duas previsões: a
/// terceira casa decimal já é meio quarteirão. Arredondar para duas casas
/// (~1 km) faz o `==` desta classe transformar o roteiro inteiro de um
/// destino em um pedido só — é a igualdade daqui que dedupa a
/// `FutureProvider.family`.
@immutable
class WeatherQuery {
  const WeatherQuery._(this.lat, this.lng);

  factory WeatherQuery(double lat, double lng) =>
      WeatherQuery._(_round(lat), _round(lng));

  final double lat;
  final double lng;

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  @override
  bool operator ==(Object other) =>
      other is WeatherQuery && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => '$lat,$lng';
}

abstract final class Weather {
  /// Por quantos dias antes do início da viagem a previsão já vale.
  static const daysBefore = 7;

  /// Só faz sentido mostrar previsão a partir de uma semana antes da
  /// viagem, e enquanto ela não acabou.
  ///
  /// Mais cedo que isso a previsão é chute — e um chute com número na
  /// tela vira promessa. Depois do fim, não há o que prever.
  ///
  /// O [now] entra por parâmetro para o teste não depender do relógio.
  static bool isWindowOpen(Trip? trip, DateTime now) {
    if (trip == null || !trip.hasDates) return false;

    final today = DateTime(now.year, now.month, now.day);
    final opensAt = DateTime(
      trip.startDate!.year,
      trip.startDate!.month,
      trip.startDate!.day,
    ).subtract(const Duration(days: daysBefore));
    final end = DateTime(trip.endDate!.year, trip.endDate!.month, trip.endDate!.day);

    return !today.isBefore(opensAt) && !today.isAfter(end);
  }

  /// Lê a resposta da Open-Meteo, que vem em listas paralelas.
  ///
  /// A chave do mapa é a string de data que a **própria API** mandou: com
  /// `timezone=auto` ela já está no fuso do lugar, e reconstruir a data
  /// aqui só abriria espaço para o dia escorregar. Pelo mesmo motivo, a
  /// hora do bloco `hourly` é atribuída ao dia pelos dez primeiros
  /// caracteres do carimbo (`2026-01-10T15:00` → `2026-01-10`).
  ///
  /// Resposta estranha vira mapa vazio — o chip some, e ninguém vê erro.
  static Map<String, DailyWeather> parse(Object? json) {
    if (json is! Map) return const {};
    final daily = json['daily'];
    if (daily is! Map) return const {};

    final times = daily['time'];
    final codes = daily['weather_code'];
    final maxs = daily['temperature_2m_max'];
    final mins = daily['temperature_2m_min'];

    if (times is! List || codes is! List || maxs is! List || mins is! List) {
      return const {};
    }

    final hoursByDay = _parseHourly(json['hourly']);

    final out = <String, DailyWeather>{};
    for (var i = 0; i < times.length; i++) {
      if (i >= codes.length || i >= maxs.length || i >= mins.length) break;

      final day = times[i];
      final code = (codes[i] as num?)?.toInt();
      final max = (maxs[i] as num?)?.toDouble();
      final min = (mins[i] as num?)?.toDouble();
      // Dia sem medição chega com null nas listas; pular é melhor que
      // mostrar 0°.
      if (day is! String || code == null || max == null || min == null) continue;

      out[day] = DailyWeather(
        dayKey: day,
        code: code,
        tempMaxC: max,
        tempMinC: min,
        apparentMaxC: _numAt(daily['apparent_temperature_max'], i)?.toDouble(),
        apparentMinC: _numAt(daily['apparent_temperature_min'], i)?.toDouble(),
        precipProbability: _numAt(daily['precipitation_probability_max'], i)?.toInt(),
        precipitationMm: _numAt(daily['precipitation_sum'], i)?.toDouble(),
        windMaxKmh: _numAt(daily['wind_speed_10m_max'], i)?.toDouble(),
        uvIndexMax: _numAt(daily['uv_index_max'], i)?.toDouble(),
        sunrise: _timeAt(daily['sunrise'], i),
        sunset: _timeAt(daily['sunset'], i),
        hours: hoursByDay[day] ?? const [],
      );
    }
    return out;
  }

  /// Bloco `hourly` agrupado por dia. Vazio quando não foi pedido.
  static Map<String, List<HourlyWeather>> _parseHourly(Object? hourly) {
    if (hourly is! Map) return const {};

    final times = hourly['time'];
    final temps = hourly['temperature_2m'];
    if (times is! List || temps is! List) return const {};

    final out = <String, List<HourlyWeather>>{};
    for (var i = 0; i < times.length; i++) {
      final stamp = times[i];
      final temp = _numAt(temps, i)?.toDouble();
      if (stamp is! String || stamp.length < 10 || temp == null) continue;

      final time = DateTime.tryParse(stamp);
      if (time == null) continue;

      out.putIfAbsent(stamp.substring(0, 10), () => []).add(
            HourlyWeather(
              time: time,
              tempC: temp,
              code: _numAt(hourly['weather_code'], i)?.toInt() ?? 0,
              precipProbability:
                  _numAt(hourly['precipitation_probability'], i)?.toInt(),
            ),
          );
    }
    return out;
  }

  static num? _numAt(Object? list, int i) =>
      list is List && i < list.length ? list[i] as num? : null;

  static DateTime? _timeAt(Object? list, int i) {
    final value = list is List && i < list.length ? list[i] : null;
    return value is String ? DateTime.tryParse(value) : null;
  }
}
