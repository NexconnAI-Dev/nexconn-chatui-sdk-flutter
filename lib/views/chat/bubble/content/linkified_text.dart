part of '../message_bubble.dart';

class _LinkifiedText extends StatefulWidget {
  static final RegExp _urlPattern = RegExp(
    r'((?:https?:\/\/|www\.)[^\s<]+)',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(
    r'(?<!\d)(?:\+?\d[\d\s-]{5,}\d)(?!\d)',
  );

  final String text;
  final TextStyle style;
  final TextStyle linkStyle;
  final ValueChanged<Uri> onLinkTap;
  final ValueChanged<String> onPhoneTap;

  const _LinkifiedText({
    required this.text,
    required this.style,
    required this.linkStyle,
    required this.onLinkTap,
    required this.onPhoneTap,
  });

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  List<InlineSpan>? _spans;

  @override
  void didUpdateWidget(covariant _LinkifiedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.linkStyle != widget.linkStyle) {
      _disposeRecognizers();
      _spans = null;
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = <_TextActionMatch>[
      ..._LinkifiedText._urlPattern
          .allMatches(widget.text)
          .map((match) => _TextActionMatch.uri(match)),
      ..._LinkifiedText._phonePattern
          .allMatches(widget.text)
          .map((match) => _TextActionMatch.phone(match)),
    ]..sort((a, b) => a.start.compareTo(b.start));
    if (matches.isEmpty) {
      return Text(widget.text, style: widget.style);
    }
    return Text.rich(
      TextSpan(style: widget.style, children: _spans ??= _buildSpans(matches)),
      semanticsLabel: widget.text,
    );
  }

  List<InlineSpan> _buildSpans(List<_TextActionMatch> matches) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) {
        continue;
      }
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final raw = widget.text.substring(match.start, match.end);
      if (match.type == _TextActionMatchType.phone) {
        final phone = raw.replaceAll(RegExp(r'[\s-]'), '');
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onPhoneTap(phone);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(text: raw, style: widget.linkStyle, recognizer: recognizer),
        );
      } else {
        final linkText = _trimTrailingPunctuation(raw);
        final trailing = raw.substring(linkText.length);
        final normalized = _normalizeUrl(linkText);
        final uri = Uri.tryParse(normalized);
        if (uri == null || !uri.hasScheme) {
          spans.add(TextSpan(text: raw));
        } else {
          final recognizer = TapGestureRecognizer()
            ..onTap = () => widget.onLinkTap(uri);
          _recognizers.add(recognizer);
          spans.add(
            TextSpan(
              text: linkText,
              style: widget.linkStyle,
              recognizer: recognizer,
            ),
          );
          if (trailing.isNotEmpty) {
            spans.add(TextSpan(text: trailing));
          }
        }
      }
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return spans;
  }

  String _trimTrailingPunctuation(String raw) {
    return raw.replaceFirst(RegExp(r'[\]\)}>.,;:!?，。！？；：]+$'), '');
  }

  String _normalizeUrl(String raw) {
    if (raw.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return raw;
    }
    return 'https://$raw';
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}

enum _TextActionMatchType { uri, phone }

class _TextActionMatch {
  final RegExpMatch match;
  final _TextActionMatchType type;

  const _TextActionMatch.uri(this.match) : type = _TextActionMatchType.uri;

  const _TextActionMatch.phone(this.match) : type = _TextActionMatchType.phone;

  int get start => match.start;
  int get end => match.end;
}
