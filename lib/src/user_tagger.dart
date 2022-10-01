import 'package:flutter/material.dart';
import 'package:usertagger/src/tagged_text.dart';
import 'package:usertagger/src/trie.dart';

//TODO: When text is edited, check for TaggedTexts that have their
//TODO: positions made invalid and modify
//TODO: (+1 if text is added, -1 if text is removed)
//TODO: Update _taggedUsers map, clear Trie and reinsert

//TODO: Add overlay animation
typedef UserTaggerWidgetBuilder = Widget Function(
  BuildContext context,
  GlobalKey key,
);
typedef TagTextFormatter = String Function(String id, String name);

class UserTagger extends StatefulWidget {
  const UserTagger({
    Key? key,
    required this.overlay,
    required this.tagController,
    required this.onSearch,
    required this.builder,
    this.padding = EdgeInsets.zero,
    this.overlayHeight = 380,
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

  /// {@macro usertagger}
  final UserTaggerController tagController;

  ///Callback to dispatch updated formatted text.
  final void Function(String)? onFormattedTextChanged;

  ///Triggered with the search query whenever [UserTagger]
  ///enters the search context.
  final void Function(String) onSearch;

  ///Parent wrapper widget builder.
  ///Returned widget should have a Container as parent widget
  ///with the [GlobalKey] as its key.
  final UserTaggerWidgetBuilder builder;

  ///{@macro searchRegex}
  final RegExp? searchRegex;

  ///TextStyle for tags.
  final TextStyle? tagStyle;

  @override
  State<UserTagger> createState() => _UserTaggerState();
}

class _UserTaggerState extends State<UserTagger> {
  UserTaggerController get controller => widget.tagController;
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
          Overlay.of(context)!.insert(_overlayEntry!);
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

  ///Custom trie to hold all tagged usernames.
  ///This is quite useful for doing a precise position-based tag search.
  late final Trie _tagTrie = Trie();

  ///Table of tagged user names and their ids
  late final Map<TaggedText, String> _taggedUsers = {};

  ///Formatted text where tagged user names are replaced with
  ///the result of calling [TagTextFormatter] if it's not null.
  ///Otherwise, tagged user names are replaced in this format:
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
        String formattedTagText = taggedText.text.replaceAll("@", "");
        formattedTagText =
            _formatTagText(_taggedUsers[taggedText]!, formattedTagText);

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

  ///Current tagged user selected in TextField
  TaggedText? _selectedTag;

  ///Adds [name] and [id] to [_taggedUsers] and
  ///updates content of TextField with [name]
  void _tagUser(String id, String name) {
    _shouldSearch = false;
    _shouldHideOverlay(true);

    name = "@${name.trim()}";
    id = id.trim();

    final text = controller.text;
    late final position = controller.selection.base.offset - 1;
    int index = 0;
    if (position != text.length - 1) {
      index = text.substring(0, position).lastIndexOf("@");
    } else {
      index = text.lastIndexOf("@");
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

      _lastCachedText = newText;
      controller.text = newText;
      _defer = true;

      int offset = index + name.length;

      final taggedText = TaggedText(
        startIndex: offset - name.length,
        endIndex: offset,
        text: name,
      );
      _taggedUsers[taggedText] = id;
      _tagTrie.insert(taggedText);

      controller.selection = TextSelection.fromPosition(
        TextPosition(
          offset: offset + 1,
        ),
      );

      _onFormattedTextChanged();
    }
  }

  ///Highlights a tagged user from [_taggedUsers] when keyboard action attempts to remove them
  ///to prompt the user.
  ///
  ///Highlighted user when [_removeEditedTags] is triggered is removed from
  ///the TextField.
  ///
  ///Does nothing when there is no tagged user or when there's no attempt
  ///to remove a tagged user from the TextField.
  ///
  ///Returns `true` if a tagged user is either selected or removed
  ///(if they were previously selected).
  ///Otherwise, returns `false`.
  bool _removeEditedTags() {
    try {
      final text = controller.text;
      if (_isTagSelected) {
        _removeSelection();
        return true;
      }
      if (text.isEmpty) {
        _taggedUsers.clear();
        _tagTrie.clear();
        _lastCachedText = text;
        return false;
      }
      final position = controller.selection.base.offset - 1;
      if (text[position] == "@") {
        _shouldSearch = true;
        return false;
      }

      for (var tag in _taggedUsers.keys) {
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
  ///a tagged user, if any.
  ///
  ///Returns `true` if a tagged user is found and selected.
  ///Otherwise, returns `false`.
  bool _backtrackAndSelect(TaggedText tag) {
    String text = controller.text;
    if (!text.contains("@")) return false;

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
      if (i == length && text[i] == "@") return false;

      temp = text[i] + temp;
      if (text[i] == "@" &&
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
    _taggedUsers.remove(_selectedTag);
    _tagTrie.clear();
    _tagTrie.insertAll(_taggedUsers.keys);
    _selectedTag = null;
    _lastCachedText = controller.text;
    _startOffset = null;
    _endOffset = null;
    _isTagSelected = false;
    _onFormattedTextChanged();
  }

  ///Whether a tagged user is selected in the TextField
  bool _isTagSelected = false;

  ///Start offset for selection in the TextField
  int? _startOffset;

  ///End offset for selection in the TextField
  int? _endOffset;

  ///Text from the TextField in it's previous state before a new update
  ///(new text input from keyboard or deletion).
  ///
  ///This is necessary to compare and see if changes have occured and to restore
  ///the text field content when user attempts to remove a tagged user
  ///so the tagged user can be selected and with further action, be removed.
  String _lastCachedText = "";

  ///Whether to initiate a user search
  bool _shouldSearch = false;

  ///{@template searchRegex}
  ///Regex to match allowed search characters.
  ///Non-conforming characters terminate the search context.
  /// {@endtemplate}
  late final _regExp = widget.searchRegex ?? RegExp(r'^[a-zA-Z-]*$');

  int _lastCursorPosition = 0;
  bool _isBacktrackingToSearch = false;

  ///This is triggered when deleting text from TextField that isn't
  ///a tagged user. Useful for continuing search without having to
  ///type `@` first.
  ///
  ///E.g, if you typed
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
  ///the search context is entered again and the text after the `@` is
  ///sent as the search query.
  ///
  ///Returns `false` when a search query is found from back tracking.
  ///Otherwise, returns `true`.
  bool _backtrackAndSearch() {
    String text = controller.text;
    if (!text.contains("@")) return true;

    final length = controller.selection.base.offset - 1;

    late String temp = "";

    for (int i = length; i >= 0; i--) {
      if (i == length && text[i] == "@") return true;

      if (!_regExp.hasMatch(text[i]) && text[i] != "@") return true;

      temp = text[i] + temp;
      if (text[i] == "@" && temp.length > 1) {
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

  ///Shifts cursor to end of tagged user name
  ///when an attempt to edit one is made.
  ///
  ///This shift of the cursor allows the next backbutton press from the
  ///same position to trigger the selection (and removal on next press)
  ///of the tagged user.
  void _shiftCursorForTaggedUser() {
    String text = controller.text;
    if (!text.contains("@")) return;
    final length = controller.selection.base.offset - 1;

    late String temp = "";

    for (int i = length; i >= 0; i--) {
      if (i == length && text[i] == "@") {
        temp = "@";
        break;
      }

      temp = text[i] + temp;
      if (text[i] == "@" && temp.length > 1) break;
    }

    if (temp.isEmpty || !temp.contains("@")) return;
    for (var tag in _taggedUsers.keys) {
      if (length + 1 > tag.startIndex &&
          tag.startIndex <= length + 1 &&
          length + 1 < tag.endIndex) {
        _defer = true;
        print("YEET");
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: tag.endIndex),
        );
        return;
      }
    }
  }

  ///Listener attached to [controller] to listen for change in
  ///search context and tagged user selection.
  ///
  ///Triggers search:
  ///Starts the search context when last entered character is `@`.
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

    if (_shouldSearch && position != text.length - 1 && text.contains("@")) {
      _extractAndSearch(text, position);
      return;
    }

    if (_lastCachedText == text) {
      _shiftCursorForTaggedUser();
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
      _onFormattedTextChanged();
      return;
    }
    _lastCachedText = text;

    if (text[position] == "@") {
      _shouldSearch = true;
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
    _onFormattedTextChanged();
  }

  ///Extract text appended to the last `@` symbol found
  ///in the substring of [text] up until [endOffset]
  ///and performs a user search.
  void _extractAndSearch(String text, int endOffset) {
    try {
      int index = text.substring(0, endOffset).lastIndexOf("@");

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
      _taggedUsers.clear();
      _tagTrie.clear();
    });
    controller._onDismissOverlay(() {
      _shouldHideOverlay(true);
    });
    controller._registerTagUserCallback(_tagUser);
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

/// {@template usertagger}
///Controller for [UserTagger].
///This object exposes callback registration bindings to enable clearing
///[UserTagger]'s tags, dismissing overlay and retrieving formatted text.
/// {@endtemplate}
class UserTaggerController extends TextEditingController {
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
  Function(String id, String name)? _tagUserCallback;

  late String _text = "";

  ///Formatted text from [UserTagger]
  String get formattedText => _text;

  ///Clears [UserTagger] internal tagged users state
  @override
  void clear() {
    _clearCallback?.call();
    super.clear();
  }

  ///Dismisses user list overlay
  void dismissOverlay() {
    _dismissOverlayCallback?.call();
  }

  ///Tags a user
  void tagUser({required String id, required String name}) {
    _tagUserCallback?.call(id, name);
  }

  ///Registers callback for clearing [UserTagger]'s
  ///internal tagged users state.
  void _onClear(Function callback) {
    _clearCallback = callback;
  }

  ///Registers callback for dismissing [UserTagger]'s
  ///user list overlay.
  void _onDismissOverlay(Function callback) {
    _dismissOverlayCallback = callback;
  }

  ///Registers callback for retrieving updated
  ///formatted text from [UserTagger].
  void _onTextChanged(String newText) {
    _text = newText;
  }

  ///Registers callback for tagging a user
  void _registerTagUserCallback(Function(String id, String name) callback) {
    _tagUserCallback = callback;
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

  ///
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
