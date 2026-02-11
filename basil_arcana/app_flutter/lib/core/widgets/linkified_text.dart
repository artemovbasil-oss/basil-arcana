import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkifiedText extends StatelessWidget {
  const LinkifiedText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+|t\.me\/[^\s]+)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final effectiveLinkStyle = linkStyle ??
        defaultStyle?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        );

    final matches = _urlRegex.allMatches(text).toList(growable: false);
    if (matches.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in matches) {
      if (match.start > index) {
        spans.add(
          TextSpan(
            text: text.substring(index, match.start),
            style: defaultStyle,
          ),
        );
      }
      final raw = text.substring(match.start, match.end);
      final normalized = raw.startsWith('http') ? raw : 'https://$raw';
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () async {
              final uri = Uri.tryParse(normalized);
              if (uri == null) {
                return;
              }
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Text(
              raw,
              style: effectiveLinkStyle,
            ),
          ),
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(index),
          style: defaultStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: defaultStyle,
        children: spans,
      ),
    );
  }
}
