import 'dart:convert';

import 'package:http/http.dart' as http;

class JsonResponseInfo {
  const JsonResponseInfo({
    required this.url,
    required this.statusCode,
    required this.contentType,
    required this.contentLengthHeader,
    required this.bytesLength,
    required this.stringLength,
    required this.responseSnippetStart,
    required this.responseSnippetEnd,
  });

  final String url;
  final int statusCode;
  final String? contentType;
  final String? contentLengthHeader;
  final int bytesLength;
  final int stringLength;
  final String responseSnippetStart;
  final String responseSnippetEnd;
}

class JsonFetchResult {
  const JsonFetchResult({
    required this.raw,
    required this.decoded,
    required this.response,
  });

  final String raw;
  final Object decoded;
  final JsonResponseInfo response;
}

class JsonParseResult {
  const JsonParseResult({required this.raw, required this.decoded});

  final String raw;
  final Object decoded;
}

class JsonFetchException implements Exception {
  JsonFetchException(
    this.message, {
    this.response,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final JsonResponseInfo? response;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

Future<JsonFetchResult> fetchJson({
  required http.Client client,
  required Uri uri,
}) async {
  final response = await client.get(
    uri,
    headers: const {
      'Accept': 'application/json',
    },
  );
  final parsed = decodeJsonResponse(response: response, uri: uri);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw JsonFetchException(
      'HTTP ${response.statusCode}',
      response: parsed.response,
    );
  }
  return parsed;
}

JsonParseResult parseJsonString(String raw) {
  final cleaned = cleanJsonString(raw);
  final decoded = jsonDecode(cleaned);
  return JsonParseResult(raw: cleaned, decoded: decoded);
}

JsonFetchResult decodeJsonResponse({
  required http.Response response,
  required Uri uri,
}) {
  final bytes = response.bodyBytes;
  final decodedString = utf8.decode(bytes, allowMalformed: true);
  final cleaned = cleanJsonString(decodedString);
  final responseInfo = JsonResponseInfo(
    url: uri.toString(),
    statusCode: response.statusCode,
    contentType: response.headers['content-type'],
    contentLengthHeader: response.headers['content-length'],
    bytesLength: bytes.length,
    stringLength: cleaned.length,
    responseSnippetStart: _responseSnippetStart(cleaned),
    responseSnippetEnd: _responseSnippetEnd(cleaned),
  );
  try {
    final decoded = jsonDecode(cleaned);
    return JsonFetchResult(
      raw: cleaned,
      decoded: decoded,
      response: responseInfo,
    );
  } on FormatException catch (error, stackTrace) {
    throw JsonFetchException(
      'Invalid JSON payload: ${error.message}',
      response: responseInfo,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

String cleanJsonString(String input) {
  var cleaned = input;
  cleaned = _stripLeadingBom(cleaned);
  cleaned = _stripLeadingControlChars(cleaned);
  cleaned = cleaned.replaceFirst(RegExp(r'^[\s]+'), '');
  return cleaned;
}

String jsonRootType(Object? value) {
  if (value is Map) {
    return 'Map';
  }
  if (value is List) {
    return 'List';
  }
  if (value == null) {
    return 'null';
  }
  return value.runtimeType.toString();
}

String _stripLeadingBom(String value) {
  var cleaned = value;
  while (cleaned.startsWith('\uFEFF')) {
    cleaned = cleaned.substring(1);
  }
  while (cleaned.startsWith('ï»¿')) {
    cleaned = cleaned.substring(3);
  }
  return cleaned;
}

String _stripLeadingControlChars(String value) {
  var cleaned = value;
  while (cleaned.isNotEmpty) {
    final codeUnit = cleaned.codeUnitAt(0);
    if (codeUnit == 0xFEFF) {
      cleaned = cleaned.substring(1);
      continue;
    }
    if (codeUnit <= 0x1F &&
        codeUnit != 0x09 &&
        codeUnit != 0x0A &&
        codeUnit != 0x0D) {
      cleaned = cleaned.substring(1);
      continue;
    }
    break;
  }
  return cleaned;
}

String _responseSnippetStart(String body) {
  if (body.isEmpty) {
    return '';
  }
  return body.length <= 200 ? body : body.substring(0, 200);
}

String _responseSnippetEnd(String body) {
  if (body.isEmpty) {
    return '';
  }
  if (body.length <= 200) {
    return body;
  }
  return body.substring(body.length - 200);
}
