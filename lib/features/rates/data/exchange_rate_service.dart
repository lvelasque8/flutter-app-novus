import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/database/app_database.dart';

class ExchangeRateResult {
  const ExchangeRateResult({
    required this.rateBs,
    required this.date,
    required this.source,
  });

  final double rateBs;
  final DateTime date;

  /// `bcv` o `api`.
  final String source;

  String get sourceLabel => source == 'bcv' ? 'BCV' : 'API';
}

class ExchangeRateService {
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Tablet) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/json,*/*',
  };

  Future<ExchangeRateResult> fetch() async {
    try {
      return await _fetchBcv();
    } catch (_) {
      // Continúa con las fuentes alternativas.
    }

    try {
      return await _fetchApi();
    } catch (_) {
      // Continúa con la última fuente.
    }

    try {
      return await _fetchOpenErApi();
    } catch (_) {
      // Ninguna fuente respondió.
    }

    throw Exception(
      'No se pudo obtener la tasa. Revisa la conexión e inténtalo de nuevo.',
    );
  }

  Future<ExchangeRateResult> updateRate() async {
    final result = await fetch();
    await AppDatabase.instance.setSettings({
      'rate_bs': result.rateBs.toString(),
      'rate_updated_at': DateTime.now().toIso8601String(),
      'rate_source': result.source,
    });
    return result;
  }

  Future<ExchangeRateResult> _fetchBcv() async {
    final response = await http
        .get(Uri.parse('https://www.bcv.org.ve/'), headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final block = RegExp(
      r'id="dolar"[\s\S]{0,2500}?<strong[^>]*>([\d.,]+)</strong>',
    ).firstMatch(html);

    if (block == null) {
      throw Exception('No se encontró el valor del dólar');
    }

    final rate = _parseVenezuelanNumber(block.group(1)!);
    if (rate <= 0) {
      throw Exception('Valor inválido');
    }

    final dateMatch = RegExp(
      r'content="(\d{4}-\d{2}-\d{2})T',
    ).firstMatch(html);

    final date = dateMatch == null
        ? DateTime.now()
        : DateTime.tryParse(dateMatch.group(1)!) ?? DateTime.now();

    return ExchangeRateResult(rateBs: rate, date: date, source: 'bcv');
  }

  Future<ExchangeRateResult> _fetchApi() async {
    final response = await http
        .get(
          Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final rate = (json['rates']?['VES'] as num?)?.toDouble() ?? 0;
    if (rate <= 0) {
      throw Exception('La API no devolvió VES');
    }

    final date = DateTime.tryParse((json['date'] as String?) ?? '') ??
        DateTime.now();

    return ExchangeRateResult(rateBs: rate, date: date, source: 'api');
  }

  Future<ExchangeRateResult> _fetchOpenErApi() async {
    final response = await http
        .get(
          Uri.parse('https://open.er-api.com/v6/latest/USD'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final rate = (json['rates']?['VES'] as num?)?.toDouble() ?? 0;
    if (rate <= 0) {
      throw Exception('La API no devolvió VES');
    }

    final date = DateTime.tryParse(
          (json['time_last_update_utc'] as String?) ?? '',
        ) ??
        DateTime.now();

    return ExchangeRateResult(rateBs: rate, date: date, source: 'api');
  }

  double _parseVenezuelanNumber(String value) {
    final cleaned = value.trim().replaceAll(' ', '');
    if (cleaned.contains(',') && cleaned.contains('.')) {
      return double.tryParse(
            cleaned.replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          0;
    }
    if (cleaned.contains(',')) {
      return double.tryParse(cleaned.replaceAll(',', '.')) ?? 0;
    }
    return double.tryParse(cleaned) ?? 0;
  }
}
