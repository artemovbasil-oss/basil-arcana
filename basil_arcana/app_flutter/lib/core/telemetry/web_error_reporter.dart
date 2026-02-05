import 'package:flutter/foundation.dart';

class WebErrorReporter {
  WebErrorReporter._();

  static final WebErrorReporter instance = WebErrorReporter._();

  final ValueNotifier<String?> _message = ValueNotifier<String?>(null);

  ValueListenable<String?> get listenable => _message;

  void report(String message) {
    if (!kIsWeb) {
      return;
    }
    if (message.trim().isEmpty) {
      return;
    }
    _message.value = message.trim();
  }

  void clear() {
    _message.value = null;
  }
}
