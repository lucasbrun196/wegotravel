import 'package:intl/intl.dart';

/// Formatação centralizada em pt-BR. Se um dia houver outra moeda,
/// muda-se apenas aqui.
abstract final class Fmt {
  static final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 2);
  static final _currencyCompact = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 1);
  static final _number = NumberFormat.decimalPattern('pt_BR');

  static String money(num value) => _currency.format(value);
  static String moneyCompact(num value) => value.abs() >= 10000 ? _currencyCompact.format(value) : money(value);
  static String number(num value) => _number.format(value);
  static String percent(double fraction) => '${(fraction * 100).clamp(0, 999).toStringAsFixed(0)}%';

  static String date(DateTime d) => DateFormat("d 'de' MMMM", 'pt_BR').format(d);
  static String dateShort(DateTime d) => DateFormat('dd/MM', 'pt_BR').format(d);
  static String dateFull(DateTime d) => DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d);
  static String dateWithYear(DateTime d) => DateFormat("d 'de' MMM 'de' y", 'pt_BR').format(d);
  static String dateShortWithYear(DateTime d) => DateFormat('dd/MM/y', 'pt_BR').format(d);
  static String monthYear(DateTime d) => DateFormat("MMMM 'de' y", 'pt_BR').format(d);

  /// Período de datas, com as duas pontas no mesmo formato.
  ///
  /// O ano aparece nos dois lados de propósito: viagem de fim de ano
  /// atravessa o réveillon, e "27/12 — 03/01" esconde justamente isso.
  static String dateRange(DateTime start, DateTime end) =>
      '${dateShortWithYear(start)} – ${dateShortWithYear(end)}';

  /// "27 dez"; com o ano quando não é o corrente: "3 jan 2027".
  static String dayMonth(DateTime d) {
    final base = DateFormat('d MMM', 'pt_BR').format(d).replaceAll('.', '');
    return d.year == DateTime.now().year ? base : '$base ${d.year}';
  }
  static String weekday(DateTime d) => DateFormat('EEEE', 'pt_BR').format(d);
  static String weekdayShort(DateTime d) => DateFormat('E', 'pt_BR').format(d).replaceAll('.', '');
  static String monthShort(DateTime d) => DateFormat('MMM', 'pt_BR').format(d).replaceAll('.', '');
  static String time(DateTime d) => DateFormat('HH:mm', 'pt_BR').format(d);
  static String dateTime(DateTime d) => '${dateShort(d)} · ${time(d)}';

  /// Chave estável de agrupamento por dia, imune a fuso horário.
  static String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String duration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  /// "há 2 horas", "ontem", "há 3 dias"
  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';
    return dateShort(d);
  }
}

extension DateOnlyX on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
  bool isSameDay(DateTime other) => year == other.year && month == other.month && day == other.day;
  bool get isToday => isSameDay(DateTime.now());
}
