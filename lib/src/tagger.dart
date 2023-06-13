import 'package:flutter/material.dart';
import 'package:fluttertagger/src/tagged_text.dart';
import 'package:fluttertagger/src/trie.dart';

//TODO: Add overlay animation
typedef FlutterTaggerWidgetBuilder = Widget Function(
  BuildContext context,
  GlobalKey key,
);
typedef TagTextFormatter = String Function(String id, String name);

class FlutterTagger extends StatefulWidget {
  const FlutterTagger({
    Key? key,
    required this.overlay,
    required this.controller,
    required this.onSearch,
    required this.builder,
    this.padding = EdgeInsets.zero,
    this.overlayHeight = 380,
    this.triggerCharacter = "@",
    this.onFormattedTextChanged,
    this.searchRegex,
    this.tagTextFormatter,
    this.tagStyle,
  }) : super(key: key);

  ///Widget shown in an overlay when search context is entered.
  final Widget overlay;

  ///Padding applied to [overlay].
  final EdgeInsetsGeometry padding;

  ///[overlay]'s height.
  final double overlayHeight;

  ///Formats and replaces tagged user names.
  ///By default, tagged user names are replaced in this format:
  ///```dart
  ///"@Lucky Ebere"
  ///```
  ///becomes
  ///
  ///```dart
  ///"@6zo22531b866ce0016f9e5tt#Lucky Ebere#"
  ///```
  ///assuming that `Lucky Ebere`'s id is `6zo22531b866ce0016f9e5tt`.
  ///
  ///Specify this parameter to use a different format.
  final TagTextFormatter? tagTextFormatter;

  /// {@macro flutterTaggerController}
  final FlutterTaggerController controller;

  ///Callback to dispatch updated formatted text.
  final void Function(String)? onFormattedTextChanged;

  ///Triggered with the search query whenever [UserTagger]
  ///enters the search context.
  final void Function(String) onSearch;

  ///Parent wrapper widget builder.
  ///Returned widget should have a Container as parent widget
  ///with the [GlobalKey] as its key.
  final FlutterTaggerWidgetBuilder builder;

  ///{@macro searchRegex}
  final RegExp? searchRegex;

  ///TextStyle for tags.
  final TextStyle? tagStyle;

  ///Character that initiates the search context.
  ///E.g, "@" to search for users or "#" for hashtags.
  final String triggerCharacter;

  @override
  State<FlutterTagger> createState() => _FlutterTaggerState();
}

class _FlutterTaggerState extends State<FlutterTagger> {
  FlutterTaggerController get controller => widget.controller;
  late final _parentContainerKey = GlobalKey(
    debugLabel: "TextField Container Key",
  );

  late Offset _offset = Offset.zero;
  late double _width = 0;
  late bool _hideOverlay = true;
  OverlayEntry? _overlayEntry;

  ///Formats tag text to include id
  String _formatTagText(String id, String name) {
    return widget.tagTextFormatter?.call(id, name) ?? "@$id#$name#";
  }

  ///Updates formatted text
  void _onFormattedTextChanged() {
    controller._onTextChanged(_formattedText);
    widget.onFormattedTextChanged?.call(_formattedText);
  }

  ///Retrieves rendering information necessary to determine where
  ///the overlay is positioned on the screen.
  void _computeSize() {
    try {
      final renderBox =
          _parentContainerKey.currentContext!.findRenderObject() as RenderBox;
      _width = renderBox.size.width;
      _offset = renderBox.localToGlobal(Offset.zero);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  ///Hides overlay if [val] is true.
  ///Otherwise, this computes size, creates and inserts and OverlayEntry.
  void _shouldHideOverlay(bool val) {
    try {
      if (_hideOverlay == val) return;
      setState(() {
        _hideOverlay = val;
        if (_hideOverlay) {
          _overlayEntry?.remove();
          _overlayEntry = null;
        } else {
          _computeSize();
          _overlayEntry = _createOverlay();
          Overlay.of(context).insert(_overlayEntry!);
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  ///Creates an overlay to show search result
  OverlayEntry _createOverlay() {
    return OverlayEntry(
      builder: (_) => Positioned(
        left: _offset.dx,
        width: _width,
        height: widget.overlayHeight,
        top: _offset.dy - (widget.overlayHeight + widget.padding.vertical),
        child: widget.overlay,
      ),
    );
  }

  ///Custom trie to hold all tags.
  ///This is quite useful for doing a precise position-based tag search.
  late final Trie _tagTrie = Trie();

  ///Table of tagged texts and their ids
  late final Map<TaggedText, String> _tagTable = {};

  String get triggerCharacter => widget.triggerCharacter;

  ///Formatted text where tags are replaced with
  ///the result of calling [TagTextFormatter] if it's not null.
  ///Otherwise, tags are replaced in this format:
  ///```dart
  ///"@Lucky Ebere"
  ///```
  ///becomes
  ///
  ///```dart
  ///"@6zo22531b866ce0016f9e5tt#Lucky Ebere#"
  ///```
  ///assuming that `Lucky Ebere`'s id is `6zo22531b866ce0016f9e5tt`
  String get _formattedText {
    String controllerText = controller.text;

    if (controllerText.isEmpty) return "";

    final splitText = controllerText.split(" ");

    List<String> result = [];
    int start = 0;
    int end = splitText.first.length;

    for (int i = 0; i < splitText.length; i++) {
      final text = splitText[i];
      final taggedText = _tagTrie.search(text, start);

      if (taggedText == null) {
        start = end + 1;
        if (i + 1 < splitText.length) {
          end = start + splitText[i + 1].length;
        }
        result.add(text);
        continue;
      }

      if (taggedText.startIndex == start) {
        String suffix = text.substring(taggedText.text.length);
        String formattedTagText =
            taggedText.text.replaceAll(triggerCharacter, "");
        formattedTagText =
            _formatTagText(_tagTable[taggedText]!, formattedTagText);

        start = end + 1;
        if (i + 1 < splitText.length) {
          end = start + splitText[i + 1].length;
        }
        result.add(formattedTagText + suffix);
      } else {
        start = end + 1;
        if (i + 1 < splitText.length) {
          end = start + splitText[i + 1].length;
        }
        result.add(text);
      }
    }

    final resultString = result.join(" ");

    return resultString;
  }

  ///Whether to not execute the [_tagListener] logic
  bool _defer = false;

  ///Current tag selected in TextField
  TaggedText? _selectedTag;

  ///Adds [name] and [id] to [_tagTable] and
  ///updates content of TextField with [name]
  void _addTag(String id, String name) {
    _shouldSearch = false;
    _shouldHideOverlay(true);

    name = "$triggerCharacter${name.trim()}";
    id = id.trim();

    final text = controller.text;
    late final position = controller.selection.base.offset - 1;
    int index = 0;
    if (position != text.length - 1) {
      index = text.substring(0, position).lastIndexOf(triggerCharacter);
    } else {
      index = text.lastIndexOf(triggerCharacter);
    }
    if (index >= 0) {
      _defer = true;

      String newText;

      if (index - 1 > 0 && text[index - 1] != " ") {
        newText = text.replaceRange(index, position + 1, " $name ");
        index++;
      } else {
        newText = text.replaceRange(index, position + 1, "$name ");
      }
      final oldCachedText = _lastCachedText;
      _lastCachedText = newText;
      controller.text = newText;
      _defer = true;

      int offset = index + name.length;

      final taggedText = TaggedText(
        startIndex: offset - name.length,
        endIndex: offset,
        text: name,
      );
      _tagTable[taggedText] = id;
      _tagTrie.insert(taggedText);

      controller.selection = TextSelection.fromPosition(
        TextPosition(
          offset: offset + 1,
        ),
      );

      _recomputeTags(
        oldCachedText,
        newText,
        taggedText.startIndex + 1,
      );

      _onFormattedTextChanged();
    }
  }

  ///Selects a tag from [_tagTable] when keyboard action attempts to remove it
  ///so as to prompt the user.
  ///
  ///The selected tag is removed from the TextField
  ///when [_removeEditedTags] is triggered.
  ///
  ///Does nothing when there is no tag or when there's no attempt
  ///to remove a tag from the TextField.
  ///
  ///Returns `true` if a tag is either selected or removed
  ///(if it was previously selected).
  ///Otherwise, returns `false`.
  bool _removeEditedTags() {
    try {
      final text = controller.text;
      if (_isTagSelected) {
        _removeSelection();
        return true;
      }
      if (text.isEmpty) {
        _tagTable.clear();
        _tagTrie.clear();
        _lastCachedText = text;
        return false;
      }
      final position = controller.selection.base.offset - 1;
      if (text[position] == triggerCharacter) {
        _shouldSearch = true;
        return false;
      }

      for (var tag in _tagTable.keys) {
        if (tag.endIndex - 1 == position + 1) {
          if (!_isTagSelected) {
            if (_backtrackAndSelect(tag)) return true;
          }
        }
      }
    } catch (_, trace) {
      debugPrint(trace.toString());
    }
    _lastCachedText = controller.text;
    _defer = false;
    return false;
  }

  ///Back tracks from current cursor position to find and select
  ///a tag, if any.
  ///
  ///Returns `true` if a tag is found and selected.
  ///Otherwise, returns `false`.
  bool _backtrackAndSelect(TaggedText tag) {
    String text = controller.text;
    if (!text.contains(triggerCharacter)) return false;

    final length = controller.selection.base.offset;

    if (tag.startIndex > length || tag.endIndex - 1 > length) {
      return false;
    }
    _defer = true;
    controller.text = _lastCachedText;
    text = _lastCachedText;
    _defer = true;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: length),
    );

    late String temp = "";

    for (int i = length; i >= 0; i--) {
      if (i == length && text[i] == triggerCharacter) return false;

      temp = text[i] + temp;
      if (text[i] == triggerCharacter &&
          temp.length > 1 &&
          temp == tag.text &&
          i == tag.startIndex) {
        _selectedTag = TaggedText(
          startIndex: i,
          endIndex: length + 1,
          text: tag.text,
        );
        _isTagSelected = true;
        _startOffset = i;
        _endOffset = length + 1;
        _defer = true;
        controller.selection = TextSelection(
          baseOffset: _startOffset!,
          extentOffset: _endOffset!,
        );
        return true;
      }
    }

    return false;
  }

  ///Updates offsets after [_selectedTag] set in [_backtrackAndSelect]
  ///has been removed.
  void _removeSelection() {
    _tagTable.remove(_selectedTag);
    _tagTrie.clear();
    _tagTrie.insertAll(_tagTable.keys);
    _selectedTag = null;
    final oldCachedText = _lastCachedText;
    _lastCachedText = controller.text;

    final pos = _startOffset!;
    _startOffset = null;
    _endOffset = null;
    _isTagSelected = false;

    _recomputeTags(oldCachedText, _lastCachedText, pos);
    _onFormattedTextChanged();
  }

  ///Whether a tag is selected in the TextField.
  bool _isTagSelected = false;

  ///Start offset for selection in the TextField.
  int? _startOffset;

  ///End offset for selection in the TextField.
  int? _endOffset;

  ///Text from the TextField in it's previous state before a new update
  ///(new text input from keyboard or deletion).
  ///
  ///This is necessary to compare and see if changes have occured and to restore
  ///the text field content when user attempts to remove a tag
  ///so that the tag can be selected and with further action, be removed.
  String _lastCachedText = "";

  ///Whether the search context is active.
  bool _shouldSearch = false;

  ///{@template searchRegex}
  ///Regex to match allowed search characters.
  ///Non-conforming characters terminate the search context.
  /// {@endtemplate}
  late final _regExp = widget.searchRegex ?? RegExp(r'^[a-zA-Z-]*$');

  int _lastCursorPosition = 0;
  bool _isBacktrackingToSearch = false;

  ///This is triggered when deleting text from TextField that isn't
  ///a tag. Useful for continuing search without having to
  ///type [triggerCharacter] first.
  ///
  ///E.g, assuming [triggerCharacter] is '@', if you typed
  ///```dart
  ///@lucky|
  ///```
  ///the search context is activated and `lucky` is sent as the search query.
  ///
  ///But if you continue with a terminating character like so:
  ///```dart
  ///@lucky |
  ///```
  ///the search context is exited and the overlay is dismissed.
  ///
  ///However, if the text is edited to bring the cursor back to
  ///
  ///```dart
  ///@luck|
  ///```
  ///the search context is entered again and the text after the
  ///[triggerCharacter] is sent as the search query.
  ///
  ///Returns `false` when a search query is found from back tracking.
  ///Otherwise, returns `true`.
  bool _backtrackAndSearch() {
    String text = controller.text;
    if (!text.contains(triggerCharacter)) return true;

    final length = controller.selection.base.offset - 1;

    late String temp = "";

    for (int i = length; i >= 0; i--) {
      if (i == length && text[i] == triggerCharacter) return true;

      if (!_regExp.hasMatch(text[i]) && text[i] != triggerCharacter) {
        return true;
      }

      temp = text[i] + temp;
      if (text[i] == triggerCharacter && temp.length > 1) {
        _shouldSearch = true;
        _isTagSelected = false;
        _isBacktrackingToSearch = true;
        _extractAndSearch(controller.text, length);
        return false;
      }
    }

    _lastCachedText = controller.text;
    _isBacktrackingToSearch = false;
    return true;
  }

  ///Shifts cursor to end of a tag
  ///when an attempt to edit it is made.
  ///
  ///This shift of the cursor allows the next backbutton press from the
  ///same position to trigger the selection (and removal on next press)
  ///of the tag.
  void _shiftCursorForTaggedUser() {
    String text = controller.text;
    if (!text.contains(triggerCharacter)) return;
    final length = controller.selection.base.offset - 1;

    late String temp = "";

    for (int i = length; i >= 0; i--) {
      if (i == length && text[i] == triggerCharacter) {
        temp = triggerCharacter;
        break;
      }

      temp = text[i] + temp;
      if (text[i] == triggerCharacter && temp.length > 1) break;
    }

    if (temp.isEmpty || !temp.contains(triggerCharacter)) return;
    for (var tag in _tagTable.keys) {
      if (length + 1 > tag.startIndex &&
          tag.startIndex <= length + 1 &&
          length + 1 < tag.endIndex) {
        _defer = true;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: tag.endIndex),
        );
        return;
      }
    }
  }

  ///Listener attached to [controller] to listen for change in
  ///search context and tag selection.
  ///
  ///Triggers search:
  ///Starts the search context when last entered character is [triggerCharacter].
  ///
  ///Ends Search:
  ///Exits search context and hides overlay when a terminating character
  ///not matched by [_regExp] is entered.
  void _tagListener() {
    final currentCursorPosition = controller.selection.base.offset;
    final text = controller.text;

    if (_shouldSearch &&
        _isBacktrackingToSearch &&
        ((text.trim().length < _lastCachedText.trim().length &&
                _lastCursorPosition - 1 != currentCursorPosition) ||
            _lastCursorPosition + 1 != currentCursorPosition)) {
      _shouldSearch = false;
      _isBacktrackingToSearch = false;
      _shouldHideOverlay(true);
    }

    if (currentCursorPosition < text.length - 1 &&
        _tagTable.keys.any((e) => e.startIndex == currentCursorPosition - 1)) {
      String char;
      try {
        char = text.substring(_lastCursorPosition, currentCursorPosition);
      } catch (e) {
        return;
      }

      if (char.trim().isNotEmpty) {
        final newText = text.replaceRange(
            _lastCursorPosition, currentCursorPosition, "$char ");
        _defer = true;
        final oldCachedText = _lastCachedText;

        final pos = _lastCursorPosition;

        _lastCachedText = newText;
        controller.text = newText;

        controller.selection = TextSelection.fromPosition(
          TextPosition(
            offset: currentCursorPosition,
          ),
        );
        _recomputeTags(oldCachedText, newText, pos);
        _lastCursorPosition = currentCursorPosition;

        return;
      }
    }

    _lastCursorPosition = currentCursorPosition;

    if (_defer) {
      _defer = false;
      return;
    }

    if (text.isEmpty && _selectedTag != null) {
      _removeSelection();
    }

    //When a previously selected tag is unselected without removing
    //reset tag selection values
    if (_startOffset != null &&
        controller.selection.base.offset != _startOffset) {
      _selectedTag = null;
      _startOffset = null;
      _endOffset = null;
      _isTagSelected = false;
    }

    late final position = controller.selection.base.offset - 1;
    final oldCachedText = _lastCachedText;

    if (_shouldSearch &&
        position != text.length - 1 &&
        text.contains(triggerCharacter)) {
      _extractAndSearch(text, position);
      _recomputeTags(oldCachedText, text, currentCursorPosition - 1);
      _lastCachedText = text;
      return;
    }

    if (_lastCachedText == text) {
      _shiftCursorForTaggedUser();
      _recomputeTags(oldCachedText, text, currentCursorPosition - 1);
      _onFormattedTextChanged();
      return;
    }

    if (_lastCachedText.trim().length > text.trim().length) {
      if (_removeEditedTags()) {
        _shouldHideOverlay(true);
        _onFormattedTextChanged();
        return;
      }
      _shiftCursorForTaggedUser();

      final hideOverlay = _backtrackAndSearch();
      if (hideOverlay) _shouldHideOverlay(true);
      _recomputeTags(oldCachedText, text, currentCursorPosition - 1);
      _onFormattedTextChanged();
      return;
    }

    _lastCachedText = text;

    if (text[position] == triggerCharacter) {
      _shouldSearch = true;
      _recomputeTags(oldCachedText, text, currentCursorPosition - 1);
      _onFormattedTextChanged();
      return;
    }

    if (!_regExp.hasMatch(text[position])) {
      _shouldSearch = false;
    }

    if (_shouldSearch) {
      _extractAndSearch(text, position);
    } else {
      _shouldHideOverlay(true);
    }

    _recomputeTags(oldCachedText, text, currentCursorPosition - 1);

    _onFormattedTextChanged();
  }

  void _recomputeTags(String oldCachedText, String currentText, int position) {
    final currentCursorPosition = controller.selection.base.offset;
    if (currentCursorPosition != currentText.length) {
      Map<TaggedText, String> newTable = {};
      _tagTrie.clear();

      for (var tag in _tagTable.keys) {
        if (tag.startIndex >= position) {
          final newTag = TaggedText(
            startIndex:
                tag.startIndex + currentText.length - oldCachedText.length,
            endIndex: tag.endIndex + currentText.length - oldCachedText.length,
            text: tag.text,
          );

          _tagTrie.insert(newTag);
          newTable[newTag] = _tagTable[tag]!;
        } else {
          _tagTrie.insert(tag);
          newTable[tag] = _tagTable[tag]!;
        }
      }

      _tagTable.clear();
      _tagTable.addAll(newTable);
    }
  }

  ///Extracts text appended to the last [triggerCharacter] symbol found
  ///in the substring of [text] up until [endOffset]
  ///and performs a user search.
  void _extractAndSearch(String text, int endOffset) {
    try {
      int index = text.substring(0, endOffset).lastIndexOf(triggerCharacter);

      if (index < 0) return;

      final userName = text.substring(
        index + 1,
        endOffset + 1,
      );
      if (userName.isNotEmpty) {
        _shouldHideOverlay(false);
        widget.onSearch(userName);
      }
    } catch (_, trace) {
      debugPrint(trace.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    controller._setTrie(_tagTrie);
    controller._setTagStyle(widget.tagStyle);
    controller.addListener(_tagListener);
    controller._onClear(() {
      _tagTable.clear();
      _tagTrie.clear();
    });
    controller._onDismissOverlay(() {
      _shouldHideOverlay(true);
    });
    controller._registerAddTagCallback(_addTag);
  }

  @override
  void dispose() {
    controller.removeListener(_tagListener);
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _parentContainerKey);
  }
}

/// {@template flutterTaggerController}
///Controller for [FlutterTagger].
///This object exposes callback registration bindings to enable clearing
///[FlutterTagger]'s tags, dismissing overlay and retrieving formatted text.
/// {@endtemplate}
class FlutterTaggerController extends TextEditingController {
  late Trie _trie = Trie();

  void _setTrie(Trie trie) {
    _trie = trie;
  }

  TextStyle? _tagStyle;

  void _setTagStyle(TextStyle? style) {
    _tagStyle = style;
  }

  Function? _clearCallback;
  Function? _dismissOverlayCallback;
  Function(String id, String name)? _addTagCallback;

  late String _text = "";

  ///Formatted text from [FlutterTagger]
  String get formattedText => _text;

  ///Clears [FlutterTagger] internal tagged users state
  @override
  void clear() {
    _clearCallback?.call();
    super.clear();
  }

  ///Dismisses user list overlay
  void dismissOverlay() {
    _dismissOverlayCallback?.call();
  }

  ///Adds a tag
  void addTag({required String id, required String name}) {
    _addTagCallback?.call(id, name);
  }

  ///Registers callback for clearing [FlutterTagger]'s
  ///internal tags state.
  void _onClear(Function callback) {
    _clearCallback = callback;
  }

  ///Registers callback for dismissing [FlutterTagger]'s
  ///user list overlay.
  void _onDismissOverlay(Function callback) {
    _dismissOverlayCallback = callback;
  }

  ///Registers callback for retrieving updated
  ///formatted text from [FlutterTagger].
  void _onTextChanged(String newText) {
    _text = newText;
  }

  ///Registers callback for adding tags
  void _registerAddTagCallback(Function(String id, String name) callback) {
    _addTagCallback = callback;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    assert(!value.composing.isValid ||
        !withComposing ||
        value.isComposingRangeValid);

    return _buildTextSpan(style);
  }

  ///Builds text value with tags styled according to [_tagStyle].
  TextSpan _buildTextSpan(TextStyle? style) {
    if (text.isEmpty) return const TextSpan();

    final splitText = text.split(" ");

    List<TextSpan> spans = [];
    int start = 0;
    int end = splitText.first.length;

    for (int i = 0; i < splitText.length; i++) {
      final currentText = splitText[i];
      final taggedText = _trie.search(currentText, start);

      if (taggedText == null) {
        start = end + 1;
        if (i + 1 < splitText.length) {
          end = start + splitText[i + 1].length;
        }
        spans.add(TextSpan(text: "$currentText ", style: style));
        continue;
      }

      if (taggedText.startIndex == start) {
        String suffix = currentText.substring(taggedText.text.length);
        start = end + 1;
        if (i + 1 < splitText.length) {
          end = start + splitText[i + 1].length;
        }
        spans.add(TextSpan(text: taggedText.text, style: _tagStyle));
        spans.add(TextSpan(text: "$suffix "));
      } else {
        start = end + 1;
        if (i + 1 < splitText.length) {
          end = start + splitText[i + 1].length;
        }
        spans.add(TextSpan(text: "$currentText "));
      }
    }
    return TextSpan(children: spans, style: style);
  }
}
