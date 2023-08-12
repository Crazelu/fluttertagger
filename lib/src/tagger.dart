import 'package:flutter/material.dart';
import 'package:fluttertagger/src/tagged_text.dart';
import 'package:fluttertagger/src/trie.dart';

///{@macro builder}
typedef FlutterTaggerWidgetBuilder = Widget Function(
  BuildContext context,
  GlobalKey key,
);

///Formatter for tags in the [TextField] associated
///with [FlutterTagger].
typedef TagTextFormatter = String Function(String id, String tag);

///Provides tagging capabilities (e.g user mentions and adding hashtags)
///to a [TextField] returned from [builder].
///
///Listens to [controller] and activates search context when [triggerCharacter]
///is detected; sending subsequent text as search query using [onSearch].
///
///Search results should be shown in [overlay] which is
///animated if [animationController] is provided.
///
///[FlutterTagger] maintains tag positions during text editing and allows
///for formatting of the tags in [TextField]'s text value with [tagTextFormatter].
///
///Tags in the [TextField] are styled with [tagStyle].
class FlutterTagger extends StatefulWidget {
  ///Creates an instance of [FlutterTagger]
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
    this.animationController,
  }) : super(key: key);

  ///Widget shown in the overlay when search context is active.
  final Widget overlay;

  ///Padding applied to [overlay].
  final EdgeInsetsGeometry padding;

  ///[overlay]'s height.
  final double overlayHeight;

  ///Formats and replaces tags for raw text retrieval.
  ///By default, tags are replaced in this format:
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

  ///Triggered with the search query whenever [FlutterTagger]
  ///enters the search context.
  final void Function(String) onSearch;

  ///{@template builder}
  ///Widget builder for [FlutterTagger]'s associated TextField.
  /// {@endtemplate}
  ///Returned widget should have a [Container] as parent widget
  ///with the [GlobalKey] as its key,
  ///and the [TextField] as its child.
  final FlutterTaggerWidgetBuilder builder;

  ///{@macro searchRegex}
  final RegExp? searchRegex;

  ///TextStyle for tags.
  final TextStyle? tagStyle;

  ///Character that initiates the search context.
  ///E.g, "@" to mention users or "#" for hashtags.
  final String triggerCharacter;

  ///Controller for the [overlay]'s animation.
  final AnimationController? animationController;

  @override
  State<FlutterTagger> createState() => _FlutterTaggerState();
}

class _FlutterTaggerState extends State<FlutterTagger> {
  FlutterTaggerController get controller => widget.controller;

  late final _parentContainerKey = GlobalKey(
    debugLabel: "FlutterTagger's child TextField Container key",
  );

  late Offset _offset = Offset.zero;
  late double _width = 0;
  late bool _hideOverlay = true;
  OverlayEntry? _overlayEntry;
  late final OverlayState _overlayState = Overlay.of(context);

  ///Formats tag text to include id
  String _formatTagText(String id, String tag) {
    return widget.tagTextFormatter?.call(id, tag) ?? "@$id#$tag#";
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
          widget.animationController?.reverse();
          if (widget.animationController == null) {
            _overlayEntry?.remove();
            _overlayEntry = null;
          }
        } else {
          _overlayEntry?.remove();

          _computeSize();
          _overlayEntry = _createOverlay();
          _overlayState.insert(_overlayEntry!);

          widget.animationController?.forward();
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _animationControllerListener() {
    if (widget.animationController?.status == AnimationStatus.dismissed &&
        _overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    _overlayState.setState(() {});
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
  late Trie _tagTrie;

  ///Table of tagged texts and their ids
  late final Map<TaggedText, String> _tagTable = {};

  String get triggerCharacter => widget.triggerCharacter;

  ///Extracts nested tags (if any) from [text] and formats them.
  String _parseAndFormatNestedTags(String text, int startIndex) {
    List<String> result = [];
    int start = startIndex;

    final nestedWords = text.split(triggerCharacter);
    bool startsWithTrigger =
        text[0] == triggerCharacter && nestedWords.first.isNotEmpty;

    for (int i = 0; i < nestedWords.length; i++) {
      final nestedWord = nestedWords[i];
      String word;
      if (i == 0) {
        word = startsWithTrigger ? "$triggerCharacter$nestedWord" : nestedWord;
      } else {
        word = "$triggerCharacter$nestedWord";
      }

      TaggedText? taggedText;

      if (word.isNotEmpty) {
        taggedText = _tagTrie.search(word, start);
      }

      if (taggedText == null) {
        result.add(word);
      } else if (taggedText.startIndex == start) {
        String suffix = word.substring(taggedText.text.length);
        String formattedTagText =
            taggedText.text.replaceAll(triggerCharacter, "");
        formattedTagText =
            _formatTagText(_tagTable[taggedText]!, formattedTagText);

        result.add(formattedTagText);
        if (suffix.isNotEmpty) result.add(suffix);
      } else {
        result.add(word);
      }

      start += word.length;
    }

    return result.join("");
  }

  ///Formatted text where tags are replaced with the result
  ///of calling [FlutterTagger.tagTextFormatter] if it's not null.
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
    int length = splitText.length;

    for (int i = 0; i < length; i++) {
      final text = splitText[i];

      if (text.contains(triggerCharacter)) {
        final parsedText = _parseAndFormatNestedTags(text, start);
        result.add(parsedText);
      } else {
        result.add(text);
      }

      start = end + 1;
      if (i + 1 < length) {
        end = start + splitText[i + 1].length;
      }
    }

    final resultString = result.join(" ");

    return resultString;
  }

  ///Whether to not execute the [_tagListener] logic.
  bool _defer = false;

  ///Current tag selected in TextField.
  TaggedText? _selectedTag;

  ///Adds [tag] and [id] to [_tagTable] and
  ///updates TextField value with [tag].
  void _addTag(String id, String tag) {
    _shouldSearch = false;
    _shouldHideOverlay(true);

    tag = "$triggerCharacter${tag.trim()}";
    id = id.trim();

    final text = controller.text;
    late final position = controller.selection.base.offset - 1;
    int index = 0;
    int selectionOffset = 0;

    if (position != text.length - 1) {
      index = text.substring(0, position).lastIndexOf(triggerCharacter);
    } else {
      index = text.lastIndexOf(triggerCharacter);
    }
    if (index >= 0) {
      _defer = true;

      String newText;

      if (index - 1 > 0 && text[index - 1] != " ") {
        newText = text.replaceRange(index, position + 1, " $tag");
        index++;
      } else {
        newText = text.replaceRange(index, position + 1, tag);
      }

      if (text.length - 1 == position) {
        newText += " ";
        selectionOffset++;
      }

      final oldCachedText = _lastCachedText;
      _lastCachedText = newText;
      controller.text = newText;
      _defer = true;

      int offset = index + tag.length;

      final taggedText = TaggedText(
        startIndex: offset - tag.length,
        endIndex: offset,
        text: tag,
      );
      _tagTable[taggedText] = id;
      _tagTrie.insert(taggedText);

      controller.selection = TextSelection.fromPosition(
        TextPosition(
          offset: offset + selectionOffset,
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
      if (position >= 0 && text[position] == triggerCharacter) {
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
  ///Returns `true` if a search query is found from back tracking.
  ///Otherwise, returns `false`.
  bool _backtrackAndSearch() {
    String text = controller.text;
    if (!text.contains(triggerCharacter)) return false;

    final length = controller.selection.base.offset - 1;

    late String temp = "";

    for (int i = length; i >= 0; i--) {
      if ((i == length && text[i] == triggerCharacter) ||
          text[i] != triggerCharacter && !_regExp.hasMatch(text[i])) {
        return false;
      }

      temp = text[i] + temp;
      if (text[i] == triggerCharacter) {
        final doesTagExistInRange = _tagTable.keys.any(
          (tag) => tag.startIndex == i && tag.endIndex == length + 1,
        );

        if (doesTagExistInRange) return false;

        _shouldSearch = true;
        _isTagSelected = false;
        _isBacktrackingToSearch = true;
        if (text.isNotEmpty) {
          _extractAndSearch(text, length);
        }

        return true;
      }
    }

    _lastCachedText = text;
    _isBacktrackingToSearch = false;
    return false;
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
    final currentCursorPosition = controller.selection.baseOffset;
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

    if (_defer) {
      _defer = false;
      return;
    }

    _lastCursorPosition = currentCursorPosition;

    if (text.isEmpty && _selectedTag != null) {
      _removeSelection();
    }

    //When a previously selected tag is unselected without removing,
    //reset tag selection state variables.
    if (_startOffset != null && currentCursorPosition != _startOffset) {
      _selectedTag = null;
      _startOffset = null;
      _endOffset = null;
      _isTagSelected = false;
    }

    final position = currentCursorPosition - 1;
    final oldCachedText = _lastCachedText;

    if (_shouldSearch && position >= 0) {
      if (!_regExp.hasMatch(text[position])) {
        _shouldSearch = false;
        _shouldHideOverlay(true);
      } else {
        _extractAndSearch(text, position);
        _recomputeTags(oldCachedText, text, currentCursorPosition - 1);
        _lastCachedText = text;
        return;
      }
    }

    if (_lastCachedText == text) {
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

      final hideOverlay = !_backtrackAndSearch();
      if (hideOverlay) _shouldHideOverlay(true);
      _recomputeTags(oldCachedText, text, currentCursorPosition - 1);
      _onFormattedTextChanged();
      return;
    }

    _lastCachedText = text;

    if (position >= 0 && text[position] == triggerCharacter) {
      _shouldSearch = true;
      _recomputeTags(oldCachedText, text, currentCursorPosition - 1);
      _onFormattedTextChanged();
      return;
    }

    if (position >= 0 && !_regExp.hasMatch(text[position])) {
      _shouldSearch = false;
    }

    if (_shouldSearch && text.isNotEmpty) {
      _extractAndSearch(text, position);
    } else {
      _shouldHideOverlay(true);
    }

    _recomputeTags(oldCachedText, text, currentCursorPosition - 1);

    _onFormattedTextChanged();
  }

  ///Recomputes affected tag positions when text value is modified.
  void _recomputeTags(String oldCachedText, String currentText, int position) {
    final currentCursorPosition = controller.selection.baseOffset;
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

  ///Extracts text appended to the last [triggerCharacter] symbol
  ///found in the substring of [text] up until [endOffset]
  ///and executes [FlutterTagger.onSearch].
  void _extractAndSearch(String text, int endOffset) {
    try {
      int index = text.substring(0, endOffset).lastIndexOf(triggerCharacter);

      if (index < 0) return;

      final query = text.substring(
        index + 1,
        endOffset + 1,
      );

      _shouldHideOverlay(false);
      widget.onSearch(query);
    } catch (_, trace) {
      debugPrint(trace.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _tagTrie = controller._trie;
    controller._setDeferCallback(() => _defer = true);
    controller._setTagTable(_tagTable);
    controller._setTriggerCharacter(triggerCharacter);
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
    widget.animationController?.addListener(_animationControllerListener);
  }

  @override
  void dispose() {
    controller.removeListener(_tagListener);
    _overlayEntry?.remove();
    widget.animationController?.removeListener(_animationControllerListener);
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
  FlutterTaggerController({String? text}) : super(text: text);

  late final Trie _trie = Trie();
  late Map<TaggedText, String> _tagTable;

  TextStyle? _tagStyle;

  void _setTagStyle(TextStyle? style) {
    _tagStyle = style;
  }

  String? _triggerChar;

  String get _triggerCharacter => _triggerChar!;

  void _setTriggerCharacter(String char) {
    _triggerChar = char;
    _formatTagsCallback ??= () => _formatTags(null, null);
    _formatTagsCallback?.call();
  }

  void _setTagTable(Map<TaggedText, String> table) {
    _tagTable = table;
  }

  void _setDeferCallback(Function callback) {
    _deferCallback = callback;
  }

  Function? _deferCallback;
  Function? _clearCallback;
  Function? _dismissOverlayCallback;
  Function(String id, String name)? _addTagCallback;

  late String _text = "";

  ///Formatted text from [FlutterTagger]
  String get formattedText => _text;

  Function? _formatTagsCallback;

  /// {@template formatTags}
  ///Extracts tags from [FlutterTaggerController]'s [text] and formats the textfield to display them as tags.
  ///This should be called after [FlutterTaggerController] is constructed with a non-null
  ///text value that contain unformatted tags.
  ///
  ///[pattern] -> Pattern to match tags.
  ///Specify this if you supply your own [FlutterTagger.tagTextFormatter].
  ///
  ///[parser] -> Parser to extract id and tag name for regex matches.
  ///Returned list should have this structure: `[id, tagName]`.
  ///{@endtemplate}
  void formatTags({
    RegExp? pattern,
    List<String> Function(String)? parser,
  }) {
    if (_triggerChar == null) {
      _formatTagsCallback = () => _formatTags(pattern, parser);
    } else {
      _formatTagsCallback?.call();
    }
  }

  ///{@macro formatTags}
  void _formatTags([
    RegExp? pattern,
    List<String> Function(String)? parser,
  ]) {
    _clearCallback?.call();
    _text = text;
    String newText = text;

    pattern ??= RegExp(r'(\@.+?\#.+?\#)');
    parser ??= (value) {
      final split = value.split("#");
      return [split.first.substring(1).trim(), split[1].trim()];
    };

    final matches = pattern.allMatches(text);

    int diff = 0;

    for (var match in matches) {
      try {
        final matchValue = match.group(1)!;

        final idAndTag = parser(matchValue);
        final tag = "$_triggerCharacter${idAndTag.last.trim()}";
        final startIndex = match.start;
        final endIndex = startIndex + tag.length;

        newText = newText.replaceRange(
          startIndex - diff,
          startIndex + matchValue.length - diff,
          tag,
        );

        final taggedText = TaggedText(
          startIndex: startIndex - diff,
          endIndex: endIndex - diff,
          text: tag,
        );
        _tagTable[taggedText] = idAndTag.first;
        _trie.insert(taggedText);

        diff += matchValue.length - tag.length;
      } catch (e) {
        debugPrint(e.toString());
      }
    }

    _runDeferedAction(() => text = newText);
    _runDeferedAction(
      () => selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      ),
    );
  }

  ///Defers [FlutterTagger]'s listener attached to this controller.
  void _runDeferedAction(Function action) {
    _deferCallback?.call();
    action.call();
  }

  ///Clears [FlutterTagger] internal tag state.
  @override
  void clear() {
    _clearCallback?.call();
    super.clear();
  }

  ///Dismisses overlay.
  void dismissOverlay() {
    _dismissOverlayCallback?.call();
  }

  ///Adds a tag.
  void addTag({required String id, required String name}) {
    _addTagCallback?.call(id, name);
  }

  ///Registers callback for clearing [FlutterTagger]'s
  ///internal tags state.
  void _onClear(Function callback) {
    _clearCallback = callback;
  }

  ///Registers callback for dismissing [FlutterTagger]'s overlay.
  void _onDismissOverlay(Function callback) {
    _dismissOverlayCallback = callback;
  }

  ///Registers callback for retrieving updated.
  ///formatted text from [FlutterTagger].
  void _onTextChanged(String newText) {
    _text = newText;
  }

  ///Registers callback for adding tags.
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

  ///Parses [text] and styles nested tagged texts using [_tagStyle].
  List<TextSpan> _getNestedSpans(String text, int startIndex) {
    List<TextSpan> spans = [];
    int start = startIndex;

    final nestedWords = text.split(_triggerCharacter);
    bool startsWithTrigger =
        text[0] == _triggerCharacter && nestedWords.first.isNotEmpty;

    for (int i = 0; i < nestedWords.length; i++) {
      final nestedWord = nestedWords[i];
      String word;
      if (i == 0) {
        word = startsWithTrigger ? "$_triggerCharacter$nestedWord" : nestedWord;
      } else {
        word = "$_triggerCharacter$nestedWord";
      }

      TaggedText? taggedText;

      if (word.isNotEmpty) {
        taggedText = _trie.search(word, start);
      }

      if (taggedText == null) {
        spans.add(TextSpan(text: word));
      } else if (taggedText.startIndex == start) {
        String suffix = word.substring(taggedText.text.length);

        spans.add(TextSpan(text: taggedText.text, style: _tagStyle));
        if (suffix.isNotEmpty) spans.add(TextSpan(text: suffix));
      } else {
        spans.add(TextSpan(text: word));
      }

      start += word.length;
    }

    return spans;
  }

  ///Builds text value with tagged texts styled using [_tagStyle].
  TextSpan _buildTextSpan(TextStyle? style) {
    if (text.isEmpty) return const TextSpan();

    final splitText = text.split(" ");

    List<TextSpan> spans = [];
    int start = 0;
    int end = splitText.first.length;

    for (int i = 0; i < splitText.length; i++) {
      final currentText = splitText[i];

      if (currentText.contains(_triggerCharacter)) {
        final nestedSpans = _getNestedSpans(currentText, start);
        spans.addAll(nestedSpans);
        spans.add(const TextSpan(text: " "));

        start = end + 1;
        if (i + 1 < splitText.length) {
          end = start + splitText[i + 1].length;
        }
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
