String sanitizeOracleText(String input) {
  var text = input;
  text = text.replaceAll('```', '');
  text = text.replaceAll(RegExp(r'\*\*'), '');
  text = text.replaceAll(RegExp(r'__'), '');
  text = text.replaceAll(RegExp(r'##+'), '');

  final lines = text.split('\n');
  final cleaned = <String>[];
  for (var line in lines) {
    if (RegExp(r'\[?\s*Left:.*\]\s*\[?\s*Center:.*\]\s*\[?\s*Right:.*\]')
        .hasMatch(line)) {
      continue;
    }
    if (RegExp(r'^\s*\[?[^\]]+\]?\s*$').hasMatch(line) &&
        line.contains('Left:') == false &&
        line.contains('Center:') == false &&
        line.contains('Right:') == false) {
      continue;
    }
    line = line.replaceAll('[', '');
    line = line.replaceAll(']', '');
    line = line.replaceAll('(', '');
    line = line.replaceAll(')', '');
    line = line.replaceAll(RegExp(r'^\s*([-*•–—]+|\d+\.)\s+'), '');
    line = line.trim();
    if (line.isEmpty) {
      cleaned.add('');
      continue;
    }
    line = line.replaceAll(RegExp(r'\s+'), ' ');
    cleaned.add(line);
  }

  final buffer = <String>[];
  var previousBlank = false;
  for (final line in cleaned) {
    final isBlank = line.trim().isEmpty;
    if (isBlank) {
      if (!previousBlank) {
        buffer.add('');
      }
    } else {
      buffer.add(line);
    }
    previousBlank = isBlank;
  }
  return buffer.join('\n').trim();
}
