import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:linkify/linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final Color? textColor;
  final int maxTextLength;
  final VoidCallback? onSuffixPressed;
  final bool showAllText;
  final String suffix;
  final String? parentText;
  final TextStyle? parentTextStyle;
  final VoidCallback? onParentPressed;
  final Function(String)? onUserTagPressed;

  CustomText({
    Key? key,
    required this.text,
    this.maxTextLength = 300,
    this.showAllText = false,
    this.suffix = "Show more",
    this.fontSize,
    this.onSuffixPressed,
    this.parentText,
    this.parentTextStyle,
    this.textColor,
    this.onParentPressed,
    this.onUserTagPressed,
  })  : _suffix = "...$suffix",
        _text = text.trim(),
        _fontSize = fontSize ?? 14,
        super(key: key);

  final double _fontSize;

  final String _text;

  final String _suffix;

  late final List<TextSpan> _spans = [];

  int _length = 0;

  TextSpan _copyWith(TextSpan span, {String? text}) {
    return TextSpan(
      style: span.style,
      recognizer: span.recognizer,
      children: span.children,
      text: text ?? span.text,
    );
  }

  int get _maxTextLength {
    if (showAllText) return _text.length;
    return maxTextLength;
  }

  void _addText(TextSpan span) {
    if (_length >= _maxTextLength) {
      if (_spans.isNotEmpty && _spans.last.text == _suffix) {
        return;
      }

      if (span.text!.length > _maxTextLength) {
        _spans.add(
          _copyWith(
            span,
            text: text.substring(0, _maxTextLength),
          ),
        );
      } else {
        _spans.add(span);
      }

      if (_length > maxTextLength) {
        _spans.add(
          TextSpan(
            text: _suffix,
            style: const TextStyle(color: Colors.pink),
            recognizer: TapGestureRecognizer()..onTap = onSuffixPressed,
          ),
        );
      }

      return;
    }

    _spans.add(span);
  }

  bool _isEmail(String? email) {
    if (email != null) {
      String source =
          r"[a-zA-Z0-9\+\.\_\%\-\+]{1,256}\\@[a-zA-Z0-9][a-zA-Z0-9\\-]{0,64}(\\.[a-zA-Z0-9][a-zA-Z0-9\\-]{0,25})+";
      return RegExp(source).hasMatch(email);
    }
    return false;
  }

  TextSpan get _parsedTextSpan {
    final elements = linkify(
      _text,
      options: const LinkifyOptions(
        removeWww: true,
        looseUrl: true,
      ),
      linkifiers: [
        const UrlLinkifier(),
        CustomUserTagLinkifier(),
        HashtagLinkifier(),
      ],
    );

    for (var element in elements) {
      _length += element.text.length;
      if (element is UrlElement) {
        _addText(
          TextSpan(
            text: element.text,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: _fontSize,
              color: Colors.pinkAccent,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final isEmail = _isEmail(element.text);

                if (isEmail) {
                  await launchUrl(Uri.parse("mailto:${element.text}"));
                } else {
                  await launchUrl(Uri.parse(element.url));
                }
              },
          ),
        );
      } else if (element is CustomUserTagElement) {
        _addText(
          TextSpan(
            text: element.name,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: _fontSize,
              color: Colors.pinkAccent,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                onUserTagPressed?.call(element.userId);
              },
          ),
        );
      } else if (element is HashtagElement) {
        _addText(
          TextSpan(
            text: element.title,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: _fontSize,
              color: Colors.blueAccent,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                onUserTagPressed?.call(element.title);
              },
          ),
        );
      } else {
        _addText(
          TextSpan(
            text: element.text,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: _fontSize,
              color: textColor ?? Colors.black.withOpacity(.8),
            ),
          ),
        );
      }
    }

    if (showAllText &&
        _length > maxTextLength &&
        _spans.isNotEmpty &&
        _spans.last.text != _suffix) {
      _spans.add(
        TextSpan(
          text: _suffix,
          style: const TextStyle(color: Colors.pink),
          recognizer: TapGestureRecognizer()..onTap = onSuffixPressed,
        ),
      );
    }
    return TextSpan(children: _spans);
  }

  @override
  Widget build(BuildContext context) {
    TextSpan child = _parsedTextSpan;

    if (parentText != null) {
      child = TextSpan(
        text: parentText,
        style: parentTextStyle,
        children: [child],
        recognizer: TapGestureRecognizer()..onTap = onParentPressed,
      );
    }
    return RichText(
      text: child,
    );
  }
}

class CustomUserTagLinkifier extends Linkifier {
  ///This matches any string in this format
  ///"@{userId}#{userName}#"
  final _userTagRegex = RegExp(r'^(.*?)(\@\w+\#..+?\#)');
  @override
  List<LinkifyElement> parse(
    List<LinkifyElement> elements,
    LinkifyOptions options,
  ) {
    final list = <LinkifyElement>[];

    for (var element in elements) {
      if (element is TextElement) {
        final match = _userTagRegex.firstMatch(element.text);

        if (match == null) {
          list.add(element);
        } else {
          final text = element.text.replaceFirst(match.group(0)!, '');

          if (match.group(1)?.isNotEmpty == true) {
            list.add(TextElement(match.group(1)!));
          }

          if (match.group(2)?.isNotEmpty == true) {
            final blob = match.group(2)!.split("#");
            list.add(
              CustomUserTagElement(
                userId: blob.first.replaceAll(
                  "@",
                  "",
                ),
                name: "@${blob[1]}",
              ),
            );
          }

          if (text.isNotEmpty) {
            list.addAll(parse([TextElement(text)], options));
          }
        }
      } else {
        list.add(element);
      }
    }

    return list;
  }
}

class CustomUserTagElement extends LinkableElement {
  final String userId;
  final String name;
  CustomUserTagElement({required this.userId, required this.name})
      : super(userId, name);

  @override
  String toString() {
    return "CustomUserTagElement(userId: '$userId', name: $name)";
  }

  @override
  bool operator ==(other) => equals(other);

  @override
  int get hashCode => Object.hashAll([userId, name]);

  @override
  bool equals(other) =>
      other is CustomUserTagElement &&
      super.equals(other) &&
      other.userId == userId &&
      other.name == name;
}

class HashtagLinkifier extends Linkifier {
  ///This matches any string in this format
  ///"#{id}#{hashtagTitle}#"
  final _userTagRegex = RegExp(r'^(.*?)(\#\w+\#..+?\#)');
  @override
  List<LinkifyElement> parse(
    List<LinkifyElement> elements,
    LinkifyOptions options,
  ) {
    final list = <LinkifyElement>[];

    for (var element in elements) {
      if (element is TextElement) {
        final match = _userTagRegex.firstMatch(element.text);

        if (match == null) {
          list.add(element);
        } else {
          final text = element.text.replaceFirst(match.group(0)!, '');

          if (match.group(1)?.isNotEmpty == true) {
            list.add(TextElement(match.group(1)!));
          }

          if (match.group(2)?.isNotEmpty == true) {
            final blob = match.group(2)!.split("#");
            list.add(
              HashtagElement(
                title: "#${blob[blob.length - 2]}",
              ),
            );
          }

          if (text.isNotEmpty) {
            list.addAll(parse([TextElement(text)], options));
          }
        }
      } else {
        list.add(element);
      }
    }

    return list;
  }
}

class HashtagElement extends LinkableElement {
  final String title;
  HashtagElement({required this.title}) : super(title, title);

  @override
  String toString() {
    return "HashtagElement(title: '$title')";
  }

  @override
  bool operator ==(other) => equals(other);

  @override
  int get hashCode => Object.hashAll([title]);

  @override
  bool equals(other) =>
      other is HashtagElement && super.equals(other) && other.title == title;
}
