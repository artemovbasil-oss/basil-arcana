import 'package:flutter/foundation.dart';

class RuntimeErrorEntry {
  const RuntimeErrorEntry({
    required this.timestamp,
    required this.source,
    required this.message,
    required this.stackTrace,
  });

  final DateTime timestamp;
  final String source;
  final String message;
  final String stackTrace;
}

class RuntimeErrorBuffer {
  RuntimeErrorBuffer._();

  static final RuntimeErrorBuffer instance = RuntimeErrorBuffer._();

  static const int _maxEntries = 20;
  final ValueNotifier<List<RuntimeErrorEntry>> _entries =
      ValueNotifier<List<RuntimeErrorEntry>>(<RuntimeErrorEntry>[]);

  ValueListenable<List<RuntimeErrorEntry>> get listenable => _entries;

  void add({
    required String source,
    required Object error,
    StackTrace? stackTrace,
  }) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return;
    }
    final next = List<RuntimeErrorEntry>.from(_entries.value);
    next.insert(
      0,
      RuntimeErrorEntry(
        timestamp: DateTime.now(),
        source: source,
        message: message,
        stackTrace: (stackTrace ?? StackTrace.current).toString(),
      ),
    );
    if (next.length > _maxEntries) {
      next.removeRange(_maxEntries, next.length);
    }
    _entries.value = next;
  }
}
