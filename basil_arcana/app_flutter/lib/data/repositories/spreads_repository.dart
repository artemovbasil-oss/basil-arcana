import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/diagnostics.dart';
import '../../core/network/json_loader.dart';
import '../models/spread_model.dart';

class SpreadsRepository {
  SpreadsRepository();

  static const int _cacheVersion = 1;
  static const String _spreadsPrefix = 'local_spreads_';
  final Map<String, DateTime> _lastFetchTimes = {};
  final Map<String, DateTime> _lastCacheTimes = {};
  final Map<String, String> _lastAttemptedUrls = {};
  final Map<String, int> _lastStatusCodes = {};
  final Map<String, String> _lastResponseSnippetsStart = {};
  final Map<String, String> _lastResponseSnippetsEnd = {};
  final Map<String, String?> _lastContentTypes = {};
  final Map<String, String?> _lastContentLengths = {};
  final Map<String, int> _lastResponseStringLengths = {};
  final Map<String, int> _lastResponseByteLengths = {};
  final Map<String, String> _lastResponseRootTypes = {};
  String? _lastError;

  UnmodifiableMapView<String, DateTime> get lastFetchTimes =>
      UnmodifiableMapView(_lastFetchTimes);
  UnmodifiableMapView<String, DateTime> get lastCacheTimes =>
      UnmodifiableMapView(_lastCacheTimes);
  UnmodifiableMapView<String, String> get lastAttemptedUrls =>
      UnmodifiableMapView(_lastAttemptedUrls);
  UnmodifiableMapView<String, int> get lastStatusCodes =>
      UnmodifiableMapView(_lastStatusCodes);
  UnmodifiableMapView<String, String> get lastResponseSnippetsStart =>
      UnmodifiableMapView(_lastResponseSnippetsStart);
  UnmodifiableMapView<String, String> get lastResponseSnippetsEnd =>
      UnmodifiableMapView(_lastResponseSnippetsEnd);
  UnmodifiableMapView<String, String?> get lastContentTypes =>
      UnmodifiableMapView(_lastContentTypes);
  UnmodifiableMapView<String, String?> get lastContentLengths =>
      UnmodifiableMapView(_lastContentLengths);
  UnmodifiableMapView<String, int> get lastResponseStringLengths =>
      UnmodifiableMapView(_lastResponseStringLengths);
  UnmodifiableMapView<String, int> get lastResponseByteLengths =>
      UnmodifiableMapView(_lastResponseByteLengths);
  UnmodifiableMapView<String, String> get lastResponseRootTypes =>
      UnmodifiableMapView(_lastResponseRootTypes);
  String? get lastError => _lastError;

  String spreadsCacheKey(Locale locale) =>
      '${_spreadsPrefix}v${_cacheVersion}_${locale.languageCode}';

  String spreadsFileNameForLocale(Locale locale) {
    return switch (locale.languageCode) {
      'ru' => 'spreads_ru.json',
      'kk' => 'spreads_kz.json',
      _ => 'spreads_en.json',
    };
  }

  Future<List<SpreadModel>> fetchSpreads({required Locale locale}) async {
    final cacheKey = spreadsCacheKey(locale);
    final raw = await _loadLocalSpreads(cacheKey: cacheKey, locale: locale);
    return _parseSpreads(raw: raw);
  }

  Future<String> _loadLocalSpreads({
    required String cacheKey,
    required Locale locale,
  }) async {
    final assetPath = 'assets/data/${spreadsFileNameForLocale(locale)}';
    _lastAttemptedUrls[cacheKey] = assetPath;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final parsed = parseJsonString(raw);
      final rootType = jsonRootType(parsed.decoded);
      _lastResponseRootTypes[cacheKey] = rootType;
      if (rootType != 'List' || !_isValidSpreadsJson(parsed.decoded)) {
        if (kEnableRuntimeLogs) {
          debugPrint(
            '[SpreadsRepository] local schemaMismatch cacheKey=$cacheKey rootType=$rootType',
          );
        }
        _lastError = 'Spreads data failed schema validation';
        throw SpreadsLoadException(_lastError!, cacheKey: cacheKey);
      }
      _recordLocalResponseInfo(cacheKey, raw);
      _lastCacheTimes[cacheKey] = DateTime.now();
      _lastError = null;
      return parsed.raw;
    } catch (error, stackTrace) {
      _lastError = '${error.toString()}\n$stackTrace';
      if (kEnableRuntimeLogs) {
        debugPrint('[SpreadsRepository] local load failed: $error');
      }
      throw SpreadsLoadException(
        'Failed to load spreads',
        cacheKey: cacheKey,
      );
    }
  }

  void _recordLocalResponseInfo(String cacheKey, String raw) {
    _lastStatusCodes[cacheKey] = 200;
    _lastContentTypes[cacheKey] = 'application/json';
    _lastContentLengths[cacheKey] = raw.length.toString();
    _lastResponseSnippetsStart[cacheKey] = _snippetStart(raw);
    _lastResponseSnippetsEnd[cacheKey] = _snippetEnd(raw);
    _lastResponseStringLengths[cacheKey] = raw.length;
    _lastResponseByteLengths[cacheKey] = raw.length;
  }
}

class SpreadsLoadException implements Exception {
  SpreadsLoadException(this.message, {this.cacheKey});

  final String message;
  final String? cacheKey;

  @override
  String toString() => message;
}

bool _isValidSpreadsJson(Object? payload) {
  if (payload is! List<dynamic> || payload.isEmpty) {
    return false;
  }
  final sample = payload.first;
  if (sample is! Map<String, dynamic>) {
    return false;
  }
  return sample.containsKey('id') &&
      sample.containsKey('name') &&
      sample.containsKey('positions');
}

String _snippetStart(String body) {
  if (body.isEmpty) {
    return '';
  }
  return body.length <= 200 ? body : body.substring(0, 200);
}

String _snippetEnd(String body) {
  if (body.isEmpty) {
    return '';
  }
  if (body.length <= 200) {
    return body;
  }
  return body.substring(body.length - 200);
}

List<SpreadModel> _parseSpreads({required String raw}) {
  final data = jsonDecode(raw) as List<dynamic>;
  return data.map((item) => SpreadModel.fromJson(item)).toList();
}
