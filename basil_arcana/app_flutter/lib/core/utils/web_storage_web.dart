import 'dart:html' as html;

String? readWebStorage(String key) => html.window.localStorage[key];

void writeWebStorage(String key, String value) {
  html.window.localStorage[key] = value;
}

void removeWebStorage(String key) {
  html.window.localStorage.remove(key);
}

void clearWebStorageWithPrefixes(List<String> prefixes) {
  final storage = html.window.localStorage;
  final keysToRemove = <String>[];
  for (var i = 0; i < storage.length; i++) {
    final key = storage.keys.elementAt(i);
    if (prefixes.any((prefix) => key.startsWith(prefix))) {
      keysToRemove.add(key);
    }
  }
  for (final key in keysToRemove) {
    storage.remove(key);
  }
}
