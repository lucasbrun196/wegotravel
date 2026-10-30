import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:we_go_travel/data/models/trip.dart';
import 'package:we_go_travel/data/models/weather.dart';
import 'package:we_go_travel/data/services/weather_service.dart';

Trip viagem({DateTime? inicio, DateTime? fim}) => Trip(
      id: 'viagem',
      name: 'Floripa',
      adminId: 'lucas',
      startDate: inicio,
      endDate: fim,
    );

/// Resposta da Open-Meteo no formato real: o bloco `daily` vem em listas
/// paralelas, uma posição por dia.
String respostaDaily() => jsonEncode({
      'latitude': -27.6,
      'longitude': -48.44,
      'timezone': 'America/Sao_Paulo',
      'daily': {
        'time': ['2026-01-10', '2026-01-11', '2026-01-12'],
        'weather_code': [0, 61, 95],
        'temperature_2m_max': [29.4, 24.1, 26.0],
        'temperature_2m_min': [21.2, 19.8, 20.4],
        'precipitation_probability_max': [3, 80, 65],
        'apparent_temperature_max': [31.0, 25.5, 27.7],
        'apparent_temperature_min': [20.0, 19.0, 20.0],
        'precipitation_sum': [0.0, 12.4, 6.1],
        'wind_speed_10m_max': [18.5, 32.2, 25.0],
        'uv_index_max': [9.4, 4.2, 6.8],
        'sunrise': ['2026-01-10T05:32', '2026-01-11T05:33', '2026-01-12T05:34'],
        'sunset': ['2026-01-10T20:01', '2026-01-11T20:01', '2026-01-12T20:00'],
      },
      'hourly': {
        'time': [
          '2026-01-10T12:00',
          '2026-01-10T13:00',
          '2026-01-10T14:00',
          '2026-01-11T12:00',
        ],
        'temperature_2m': [27.0, 28.5, 29.4, 22.0],
        'precipitation_probability': [0, 2, 3, 75],
        'weather_code': [0, 0, 1, 61],
      },
    });

void main() {
  group('Código WMO vira condição', () {
    test('os grupos que mudam a mala', () {
      expect(WeatherCondition.fromWmoCode(0), WeatherCondition.clear);
      expect(WeatherCondition.fromWmoCode(2), WeatherCondition.partlyCloudy);
      expect(WeatherCondition.fromWmoCode(3), WeatherCondition.cloudy);
      expect(WeatherCondition.fromWmoCode(45), WeatherCondition.fog);
      expect(WeatherCondition.fromWmoCode(53), WeatherCondition.drizzle);
      expect(WeatherCondition.fromWmoCode(61), WeatherCondition.rain);
      expect(WeatherCondition.fromWmoCode(82), WeatherCondition.heavyRain);
      expect(WeatherCondition.fromWmoCode(75), WeatherCondition.snow);
      expect(WeatherCondition.fromWmoCode(95), WeatherCondition.storm);
    });

    test('código desconhecido não quebra a tela', () {
      expect(WeatherCondition.fromWmoCode(999), WeatherCondition.cloudy);
    });
  });

  group('Janela de uma semana antes da viagem', () {
    final inicio = DateTime(2026, 1, 10);
    final fim = DateTime(2026, 1, 20);
    final trip = viagem(inicio: inicio, fim: fim);

    test('faltando 8 dias, ainda não', () {
      expect(Weather.isWindowOpen(trip, DateTime(2026, 1, 2)), isFalse);
    });

    test('faltando exatamente 7 dias, abre', () {
      expect(Weather.isWindowOpen(trip, DateTime(2026, 1, 3)), isTrue);
    });

    test('na véspera e durante a viagem, aberta', () {
      expect(Weather.isWindowOpen(trip, DateTime(2026, 1, 9)), isTrue);
      expect(Weather.isWindowOpen(trip, DateTime(2026, 1, 15)), isTrue);
    });

    test('o último dia da viagem ainda conta', () {
      expect(Weather.isWindowOpen(trip, DateTime(2026, 1, 20, 23)), isTrue);
    });

    test('depois que a viagem acaba, fecha', () {
      expect(Weather.isWindowOpen(trip, DateTime(2026, 1, 21)), isFalse);
    });

    test('viagem sem datas nunca abre', () {
      expect(Weather.isWindowOpen(viagem(), DateTime(2026, 1, 15)), isFalse);
      expect(Weather.isWindowOpen(null, DateTime(2026, 1, 15)), isFalse);
    });
  });

  group('Leitura da resposta da Open-Meteo', () {
    test('cada dia vira uma previsão, na chave que a API mandou', () {
      final byDay = Weather.parse(jsonDecode(respostaDaily()));

      expect(byDay.keys, ['2026-01-10', '2026-01-11', '2026-01-12']);

      final dia1 = byDay['2026-01-10']!;
      expect(dia1.condition, WeatherCondition.clear);
      expect(dia1.tempLabel, '29°/21°');
      expect(dia1.precipProbability, 3);

      expect(byDay['2026-01-11']!.condition, WeatherCondition.rain);
      expect(byDay['2026-01-11']!.detail, 'Chuva · 80% de chuva');
    });

    test('dia sem medição é pulado em vez de virar 0°', () {
      final byDay = Weather.parse({
        'daily': {
          'time': ['2026-01-10', '2026-01-11'],
          'weather_code': [0, 3],
          'temperature_2m_max': [29.4, null],
          'temperature_2m_min': [21.2, 18.0],
        },
      });

      expect(byDay.keys, ['2026-01-10']);
      expect(byDay['2026-01-10']!.precipProbability, isNull);
    });

    test('o detalhe do dia vem junto, para o painel', () {
      final dia1 = Weather.parse(jsonDecode(respostaDaily()))['2026-01-10']!;

      expect(dia1.apparentLabel, '31°/20°');
      expect(dia1.precipitationMm, 0.0);
      expect(dia1.windMaxKmh, 18.5);
      expect(dia1.uvIndexMax, 9.4);
      expect(dia1.uvLabel, 'muito alto');
      expect(dia1.sunrise, DateTime(2026, 1, 10, 5, 32));
      expect(dia1.sunset, DateTime(2026, 1, 10, 20, 1));
    });

    test('as horas são separadas por dia pelo carimbo da própria API', () {
      final byDay = Weather.parse(jsonDecode(respostaDaily()));

      expect(byDay['2026-01-10']!.hours.length, 3);
      expect(byDay['2026-01-11']!.hours.length, 1);
      expect(byDay['2026-01-10']!.hours.first.time, DateTime(2026, 1, 10, 12));
      expect(byDay['2026-01-11']!.hours.single.condition, WeatherCondition.rain);
    });

    test('sem bloco horário, o dia continua válido — só não tem curva', () {
      final byDay = Weather.parse({
        'daily': {
          'time': ['2026-01-10'],
          'weather_code': [0],
          'temperature_2m_max': [29.4],
          'temperature_2m_min': [21.2],
        },
      });

      expect(byDay['2026-01-10']!.hours, isEmpty);
      expect(byDay['2026-01-10']!.hourNear(DateTime(2026, 1, 10, 14)), isNull);
      expect(byDay['2026-01-10']!.apparentLabel, isNull);
    });

    test('resposta estranha vira mapa vazio', () {
      expect(Weather.parse(null), isEmpty);
      expect(Weather.parse({'error': true}), isEmpty);
      expect(Weather.parse({'daily': {}}), isEmpty);
    });
  });

  group('Vai chover?', () {
    DailyWeather dia({int? chance, double? mm, int code = 3}) => DailyWeather(
          dayKey: '2026-01-10',
          code: code,
          tempMaxC: 25,
          tempMinC: 18,
          precipProbability: chance,
          precipitationMm: mm,
        );

    test('a resposta sai da chance, não do código da condição', () {
      // Código 61 é "chuva", mas com 10% de chance ninguém muda o
      // programa do dia por causa disso.
      expect(dia(chance: 10, code: 61).rainVerdict, 'Não deve chover');
      expect(dia(chance: 10, code: 61).willRain, isFalse);
    });

    test('as faixas', () {
      expect(dia(chance: 35).rainVerdict, 'Chuva pouco provável');
      expect(dia(chance: 60).rainVerdict, 'Pode chover, leve guarda-chuva');
      expect(dia(chance: 90).rainVerdict, 'Deve chover');
      expect(dia(chance: 60).willRain, isTrue);
    });

    test('volume alto conta como chuva mesmo com chance baixa', () {
      expect(dia(chance: 30, mm: 8.0).willRain, isTrue);
    });

    test('sem dado, não inventa', () {
      expect(dia().rainVerdict, 'Sem dado de chuva para este dia');
      expect(dia(code: 0).rainVerdict, 'Sem previsão de chuva');
      expect(dia().willRain, isFalse);
    });
  });

  group('A hora da atividade', () {
    test('pega a hora cheia mais próxima do horário marcado', () {
      final dia = Weather.parse(jsonDecode(respostaDaily()))['2026-01-10']!;

      expect(dia.hourNear(DateTime(2026, 1, 10, 13, 40))!.tempLabel, '29°');
      expect(dia.hourNear(DateTime(2026, 1, 10, 12, 10))!.tempLabel, '27°');
    });

    test('horário fora da faixa cai na ponta mais próxima', () {
      final dia = Weather.parse(jsonDecode(respostaDaily()))['2026-01-10']!;

      expect(dia.hourNear(DateTime(2026, 1, 10, 6))!.time.hour, 12);
      expect(dia.hourNear(DateTime(2026, 1, 10, 23))!.time.hour, 14);
    });
  });

  group('Consulta por coordenada', () {
    test('arredonda para duas casas, e duas atividades vizinhas se juntam', () {
      expect(WeatherQuery(-27.5969, -48.4444).lat, -27.6);
      expect(WeatherQuery(-27.5969, -48.4444), WeatherQuery(-27.6012, -48.4438));
      expect(
        WeatherQuery(-27.5969, -48.4444).hashCode,
        WeatherQuery(-27.6012, -48.4438).hashCode,
      );
    });

    test('lugares de verdade diferentes continuam diferentes', () {
      expect(WeatherQuery(-27.6, -48.44) == WeatherQuery(-23.55, -46.63), isFalse);
    });
  });

  group('Serviço', () {
    test('busca a previsão e guarda: o mesmo ponto não pede duas vezes', () async {
      var pedidos = 0;
      final service = WeatherService(
        client: MockClient((req) async {
          pedidos++;
          expect(req.url.host, 'api.open-meteo.com');
          expect(req.url.queryParameters['timezone'], 'auto');
          return http.Response(respostaDaily(), 200,
              headers: {'content-type': 'application/json'});
        }),
      );

      final primeira = await service.dailyForecast(WeatherQuery(-27.5969, -48.4444));
      final segunda = await service.dailyForecast(WeatherQuery(-27.6012, -48.4438));

      expect(primeira['2026-01-10']!.tempLabel, '29°/21°');
      expect(segunda, same(primeira));
      expect(pedidos, 1);
    });

    test('erro da API não estoura: devolve mapa vazio', () async {
      final service = WeatherService(
        client: MockClient((_) async => http.Response('rate limited', 429)),
      );

      expect(await service.dailyForecast(WeatherQuery(-27.6, -48.44)), isEmpty);
    });

    test('rede caída também degrada em silêncio', () async {
      final service = WeatherService(
        client: MockClient((_) async => throw const _SemRede()),
      );

      expect(await service.dailyForecast(WeatherQuery(-27.6, -48.44)), isEmpty);
    });
  });
}

class _SemRede implements Exception {
  const _SemRede();
}
