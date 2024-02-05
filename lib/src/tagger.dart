import 'package:flutter/material.dart';
import 'package:fluttertagger/src/tagged_text.dart';
import 'package:fluttertagger/src/trie.dart';

typedef UrlListCallback = void Function(List<String>);

// TODO: make tags clearing optional, make url search better (dynamic), add dynamic styling for url
///{@macro builder}
typedef FlutterTaggerWidgetBuilder = Widget Function(
  BuildContext context,
  GlobalKey key,
);

///Formatter for tags in the [TextField] associated
///with [FlutterTagger].
typedef TagTextFormatter = String Function(
  String id,
  String tag,
  String triggerCharacter,
);

///{@macro searchCallback}
typedef FlutterTaggerSearchCallback = void Function(
  String query,
  String triggerCharacter,
);

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
class FlutterTaggers extends StatefulWidget {
  ///Creates an instance of [FlutterTagger]
  const FlutterTaggers({
    Key? key,
    required this.overlay,
    required this.controller,
    required this.onSearch,
    required this.builder,
    this.clearTagsOnInit = false,
    this.padding = EdgeInsets.zero,
    this.triggerCharacterAndStyles = const {},
    this.onFormattedTextChanged,
    this.searchRegex,
    this.triggerCharactersRegex,
    this.tagTextFormatter,
    this.animationController,
    this.onUrlsFound,
    this.urlRegex,
  })  : assert(
          triggerCharacterAndStyles != const {},
          "triggerCharacterAndStyles cannot be empty",
        ),
        super(key: key);

  ///Widget shown in the overlay when search context is active.
  final Widget overlay;

  ///Padding applied to [overlay].
  final EdgeInsetsGeometry padding;


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
  final FlutterTaggerControllers controller;
  // callback to show url that matched urlRegex
  final  UrlListCallback? onUrlsFound;
  // custom url regex
  final RegExp? urlRegex;

  ///Callback to dispatch updated formatted text.
  final void Function(String)? onFormattedTextChanged;

  ///{@template searchCallback}
  ///Called with the search query whenever [FlutterTagger]
  ///enters the search context.
  ////// {@endtemplate}
  final FlutterTaggerSearchCallback onSearch;

  // Keeps the tags inside controller, even after reinicialization of the FlutterTagger
  final bool clearTagsOnInit;

  ///{@template builder}
  ///Widget builder for [FlutterTagger]'s associated TextField.
  /// {@endtemplate}
  ///Returned widget should have a [Container] as parent widget
  ///with the [GlobalKey] as its key,
  ///and the [TextField] as its child.
  final FlutterTaggerWidgetBuilder builder;

  ///{@macro searchRegex}
  final RegExp? searchRegex;

  ///Regex to match allowed trigger characters.
  ///Trigger characters activate the search context.
  ///If null, a Regex pattern is constructed from the
  ///trigger characters in [triggerCharacterAndStyles].
  final RegExp? triggerCharactersRegex;

  ///Controller for the [overlay]'s animation.
  final AnimationController? animationController;

  ///Lookup table of trigger characters and their associated [TextStyle] styles.
  ///These styles are applied to the tags/mentions resulting from their associated
  ///trigger character.
  final Map<String, TextStyle> triggerCharacterAndStyles;

  @override
  State<FlutterTaggers> createState() => _FlutterTaggerState();
}

class _FlutterTaggerState extends State<FlutterTaggers> {
  FlutterTaggerControllers get controller => widget.controller;

  late final _parentContainerKey = GlobalKey(
    debugLabel: "FlutterTagger's child TextField Container key",
  );

  late Offset _offset = Offset.zero;
  late double _width = 0;
  late bool _hideOverlay = true;
  OverlayEntry? _overlayEntry;
  late final OverlayState _overlayState = Overlay.of(context);

  ///Formats tag text to include id
  String _formatTagText(String id, String tag, String triggerCharacter) {
    return widget.tagTextFormatter?.call(id, tag, triggerCharacter) ??
        "@$id#$tag#";
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
      builder: (_) =>   Stack(
        children: [
         GestureDetector(
        onTap: (){_shouldHideOverlay(true);},
        child:  Container(color: Colors.transparent,),),
          Positioned(
                left: _offset.dx,
                width: _width,
                top: _offset.dy,
                child: widget.overlay,
              ),
        ],
      ),
        
      
    );
  }

  ///Custom trie to hold all tags.
  ///This is quite useful for doing a precise position-based tag search.
  late Trie _tagTrie;

  ///Map of tagged texts and their ids
  late  Map<TaggedText, String> _tags = {};

  Iterable<String> get triggerCharacters =>
      widget.triggerCharacterAndStyles.keys;

  /// Regex to match trigger characters that should activate the search context.
  RegExp get _triggerCharactersPattern {
    if (widget.triggerCharactersRegex != null) {
      return widget.triggerCharactersRegex!;
    }
    String pattern = triggerCharacters.first;
    int count = triggerCharacters.length;

    if (count > 1) {
      for (int i = 1; i < count; i++) {
        pattern += "|${triggerCharacters.elementAt(i)}";
      }
    }

    return RegExp(pattern);
  }

  ///Extracts nested tags (if any) from [text] and formats them.
  String _parseAndFormatNestedTags(String text, int startIndex) {
    if (text.isEmpty) return "";
    List<String> result = [];
    int start = startIndex;

    final nestedWords = text.splitWithDelim(_triggerCharactersPattern);
    bool startsWithTrigger =
        triggerCharacters.contains(text[0]) && nestedWords.first.isNotEmpty;

    String triggerChar = "";
    int triggerCharIndex = 0;

    for (int i = 0; i < nestedWords.length; i++) {
      final nestedWord = nestedWords[i];

      if (nestedWord.contains(_triggerCharactersPattern)) {
        if (triggerChar.isNotEmpty && triggerCharIndex == i - 2) {
          result.add(triggerChar);
          start += triggerChar.length;
          triggerChar = "";
          triggerCharIndex = i;
          continue;
        }
        triggerChar = nestedWord;
        triggerCharIndex = i;
        continue;
      }

      String word;
      if (i == 0) {
        word = startsWithTrigger ? "$triggerChar$nestedWord" : nestedWord;
      } else {
        word = "$triggerChar$nestedWord";
      }

      TaggedText? taggedText;

      if (word.isNotEmpty) {
        taggedText = _tagTrie.search(word, start);
      }

      if (taggedText == null) {
        result.add(word);
      } else if (taggedText.startIndex == start) {
        String suffix = word.substring(taggedText.text.length);
        String formattedTagText = taggedText.text.replaceAll(triggerChar, "");
        formattedTagText = _formatTagText(
          _tags[taggedText]!,
          formattedTagText,
          triggerChar,
        );

        result.add(formattedTagText);
        if (suffix.isNotEmpty) result.add(suffix);
      } else {
        result.add(word);
      }

      start += word.length;
      triggerChar = "";
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

      if (text.contains(_triggerCharactersPattern)) {
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

  ///Adds [tag] and [id] to [_tags] and
  ///updates TextField value with [tag].
  void _addTag(String id, String tag) {
    _shouldSearch = false;
    _shouldHideOverlay(true);

    tag = "$_currentTriggerChar${tag.trim()}";
    id = id.trim();

    final text = controller.text;
    late final position = controller.selection.base.offset - 1;
    int index = 0;
    int selectionOffset = 0;

    if (position != text.length - 1) {
      index = text.substring(0, position).lastIndexOf(_currentTriggerChar);
    } else {
      index = text.lastIndexOf(_currentTriggerChar);
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
      _tags[taggedText] = id;
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

  ///Selects a tag from [_tags] when keyboard action attempts to remove it
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
        _tags.clear();
        _tagTrie.clear();
        _lastCachedText = text;
        return false;
      }
      final position = controller.selection.base.offset - 1;
      if (position >= 0 && triggerCharacters.contains(text[position])) {
        _shouldSearch = true;
        return false;
      }

      for (var tag in _tags.keys) {
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
    if (!text.contains(_triggerCharactersPattern)) return false;

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
      if (i == length && triggerCharacters.contains(text[i])) return false;

      temp = text[i] + temp;
      if (triggerCharacters.contains(text[i]) &&
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
    _tags.remove(_selectedTag);
    _tagTrie.clear();
    _tagTrie.insertAll(_tags.keys);
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
  late final _searchRegexPattern =
      widget.searchRegex ?? RegExp(r'^[a-zA-Z-]*$');

   late final _urlRegexPattern =
      widget.urlRegex ?? RegExp(
  r'(((((http:\/\/)?www\.)|((https:\/\/)?www\.)|(http:\/\/)|(https:\/\/))?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,63}(\/[-a-zA-Z0-9()@:%_\+,.~#?\-$&\/=]*)?)|(youtu.be\/[-a-zA-Z0-9()@:%_\+,.~#?\-$&\/=]*))',
);

  int _lastCursorPosition = 0;
  bool _isBacktrackingToSearch = false;

  ///Last trigger character which activated the search context.
  String _currentTriggerChar = "";

  ///This is triggered when deleting text from TextField that isn't
  ///a tag. Useful for continuing search without having to
  ///type a trigger character first.
  ///
  ///E.g, assuming trigger character is '@', if you typed
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
  ///trigger character is sent as the search query.
  ///
  ///Returns `true` if a search query is found from back tracking.
  ///Otherwise, returns `false`.
  bool _backtrackAndSearch() {
    String text = controller.text;
    if (!text.contains(_triggerCharactersPattern)) return false;

    _lastCachedText = text;
    final length = controller.selection.base.offset - 1;

    for (int i = length; i >= 0; i--) {
      if ((i == length && triggerCharacters.contains(text[i])) ||
          !triggerCharacters.contains(text[i]) &&
              !_searchRegexPattern.hasMatch(text[i])) {
        return false;
      }

      if (triggerCharacters.contains(text[i])) {
 // let the search appear only ift here is trigger char, but no tag
     final doesTagEncloseRange = !_tags.keys.any(
        (tag)  => tag.startIndex <= i && tag.endIndex > length
      );
        if (!doesTagEncloseRange) return false;

        _currentTriggerChar = text[i];
        _shouldSearch = true;
        _isTagSelected = false;
        _isBacktrackingToSearch = true;
        if (text.isNotEmpty) {
          _extractAndSearch(text, length);
        }

        return true;
      }
    }

    _isBacktrackingToSearch = false;
    return false;
  }

  ///Listener attached to [controller] to listen for change in
  ///search context and tag selection.
  ///
  ///Triggers search:
  ///Activates the search context when last entered character is a trigger character.
  ///
  ///Ends Search:
  ///Exits search context and hides overlay when a terminating character
  ///not matched by [_searchRegexPattern] is entered.
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
      if (!_searchRegexPattern.hasMatch(text[position])) {
        _shouldSearch = false;
        _shouldHideOverlay(true);
      } else {
        _extractAndSearch(text, position);
        _recomputeTags(oldCachedText, text, position);
        _lastCachedText = text;
        return;
      }
    }

    if (_lastCachedText == text) {
      _recomputeTags(oldCachedText, text, position);
      _onFormattedTextChanged();
      return;
    }

    if (_lastCachedText.length > text.length ||
        currentCursorPosition < text.length) {
      if (_removeEditedTags()) {
        _shouldHideOverlay(true);
        _onFormattedTextChanged();
        return;
      }

      final hideOverlay = !_backtrackAndSearch();
      if (hideOverlay) _shouldHideOverlay(true);

      if (position < 0 || !triggerCharacters.contains(text[position])) {
        _recomputeTags(oldCachedText, text, position);
        _onFormattedTextChanged();
        return;
      }
    }

    _lastCachedText = text;

    if (position >= 0 && triggerCharacters.contains(text[position])) {
      _shouldSearch = true;
      _currentTriggerChar = text[position];
      _recomputeTags(oldCachedText, text, position);
      _onFormattedTextChanged();
      return;
    }

    if (position >= 0 && !_searchRegexPattern.hasMatch(text[position])) {
      _shouldSearch = false;
    }

    if (_shouldSearch && text.isNotEmpty) {
      _extractAndSearch(text, position);
    } else {
      _shouldHideOverlay(true);
    }

    _recomputeTags(oldCachedText, text, position);
    _onFormattedTextChanged();
  }

  ///Recomputes affected tag positions when text value is modified.
  void _recomputeTags(String oldCachedText, String currentText, int position) {
    final currentCursorPosition = controller.selection.baseOffset;
    if (currentCursorPosition != currentText.length) {
      Map<TaggedText, String> newTable = {};
      _tagTrie.clear();

      for (var tag in _tags.keys) {
        if (tag.startIndex >= position) {
          final newTag = TaggedText(
            startIndex:
                tag.startIndex + currentText.length - oldCachedText.length,
            endIndex: tag.endIndex + currentText.length - oldCachedText.length,
            text: tag.text,
          );

          _tagTrie.insert(newTag);
          newTable[newTag] = _tags[tag]!;
        } else {
          _tagTrie.insert(tag);
          newTable[tag] = _tags[tag]!;
        }
      }

      _tags.clear();
      _tags.addAll(newTable);
    }
  }

  ///Extracts text appended to the last [_currentTriggerChar] symbol
  ///found in the substring of [text] up until [endOffset]
  ///and executes [FlutterTagger.onSearch].
  void _extractAndSearch(String text, int endOffset) {
    try {
      int index = text.substring(0, endOffset).lastIndexOf(_currentTriggerChar);

      if (index < 0) return;

      final query = text.substring(
        index + 1,
        endOffset + 1,
      );

      _shouldHideOverlay(false);
      widget.onSearch(query, _currentTriggerChar);
    } catch (_, trace) {
      debugPrint(trace.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _tagTrie = controller._trie;
    controller._setDeferCallback(() => _defer = true);
    if(!widget.clearTagsOnInit){
    _tags = controller._tags;
    }else{
      controller._setTags(_tags);
    }
    
    controller._setTriggerCharactersRegExpPattern(_triggerCharactersPattern);
    controller._setTagStyles(widget.triggerCharacterAndStyles);
    controller._onUrlsFound = widget.onUrlsFound;
    controller._urlSearchRegex = _urlRegexPattern;
    controller.addListener(_tagListener);
    controller._onClear(clearCallback);
    controller._onDismissOverlay(() {
      _shouldHideOverlay(true);
    });
    controller._registerAddTagCallback(_addTag);
    widget.animationController?.addListener(_animationControllerListener);
  }

  void clearCallback(){
      _tags.clear();
      _tagTrie.clear();
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
class FlutterTaggerControllers extends TextEditingController {
  FlutterTaggerControllers({String? text}) : super(text: text);

  late final Trie _trie = Trie();
   Map<TaggedText, String> _tags = {};
  Map<TaggedText, String> get tags => _tags;
  late Map<String, TextStyle> _tagStyles;

  void _setTagStyles(Map<String, TextStyle> tagStyles) {
    _tagStyles = tagStyles;
  }
  // TODO: make more reusable
  UrlListCallback? _onUrlsFound;
  RegExp? _urlSearchRegex;
  RegExp? _triggerCharsPattern;

  RegExp get _triggerCharactersPattern => _triggerCharsPattern!;

  void _setTriggerCharactersRegExpPattern(RegExp pattern) {
    _triggerCharsPattern = pattern;
    _formatTagsCallback ??= () => _formatTags(null, null);
    _formatTagsCallback?.call();
  }

  void _setTags(Map<TaggedText, String> tags) {
    _tags = tags;
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
    if (_triggerCharsPattern == null) {
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
    _text = text;
    String newText = text;

    pattern ??= RegExp(r'([@#]\w+\#.+?\#)');
    parser ??= (value) {
      final split = value.split("#");
      if (split.length == 4) {
        //default hashtag group match (tag and id)
        return [split[1].trim(), split[2].trim()];
      }
      //default user mention group match (name and id)
      final id = split.first.trim().replaceFirst("@", "");
      return [id, split[split.length - 2].trim()];
    };

    final matches = pattern.allMatches(text);

    int diff = 0;

    for (var match in matches) {
      try {
        final matchValue = match.group(1)!;

        final idAndTag = parser(matchValue);
        final triggerChar = text.substring(match.start, match.start + 1);

        final tag = "$triggerChar${idAndTag.last.trim()}";
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
        _tags[taggedText] = idAndTag.first;
        _trie.insert(taggedText);

        diff += matchValue.length - tag.length;
      } catch (e) {
        debugPrint(e.toString());
      }
    }

    if (newText.isNotEmpty) {
      _runDeferedAction(() => text = newText);
      _runDeferedAction(
        () => selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        ),
      );
    }
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

  ///Parses [text] and styles nested tagged texts using style from [_tagStyles].
  List<TextSpan> _getNestedSpans(String text, int startIndex) {
    if (text.isEmpty) return [];

    List<TextSpan> spans = [];
    int start = startIndex;

    final nestedWords = text.splitWithDelim(_triggerCharactersPattern);
    bool startsWithTrigger = text[0].contains(_triggerCharactersPattern) &&
        nestedWords.first.isNotEmpty;

    String triggerChar = "";
    int triggerCharIndex = 0;

    for (int i = 0; i < nestedWords.length; i++) {
      final nestedWord = nestedWords[i];
// TODO: make own style for url
       if (_urlSearchRegex!.hasMatch(nestedWord) ) {
      // If the text is a URL, apply underline style
        spans.add(TextSpan(
          text: nestedWord,
          style: _tagStyles['@'],
        ),);
        continue;
      }
    else

      if (nestedWord.contains(_triggerCharactersPattern)) {
        if (triggerChar.isNotEmpty && triggerCharIndex == i - 2) {
          spans.add(TextSpan(text: triggerChar));
          start += triggerChar.length;
          triggerChar = "";
          triggerCharIndex = i;
          continue;
        }
        triggerChar = nestedWord;
        triggerCharIndex = i;
        continue;
      }

      String word;
      if (i == 0) {
        word = startsWithTrigger ? "$triggerChar$nestedWord" : nestedWord;
      } else {
        word = "$triggerChar$nestedWord";
      }

      TaggedText? taggedText;

      if (word.isNotEmpty) {
        taggedText = _trie.search(word, start);
      }

      if (taggedText == null) {
        spans.add(TextSpan(text: word));
      } else if (taggedText.startIndex == start) {
        String suffix = word.substring(taggedText.text.length);

        spans.add(
          TextSpan(
            text: taggedText.text,
            style: _tagStyles[triggerChar],
          ),
        );
        if (suffix.isNotEmpty) spans.add(TextSpan(text: suffix));
      } else {
        spans.add(TextSpan(text: word));
      }

      start += word.length;
      triggerChar = "";
    }

    return spans;
  }

  ///Builds text value with tagged texts styled using styles from [_tagStyles].
  TextSpan _buildTextSpan(TextStyle? style) {
    if (text.isEmpty) return const TextSpan();

    final splitText = text.split(" ");

    List<TextSpan> spans = [];
    int start = 0;
    int end = splitText.first.length;
  List<String> foundUrls = [];
    for (int i = 0; i < splitText.length; i++) {
      final currentText = splitText[i];
    
  if (currentText.contains(_triggerCharactersPattern) || _urlSearchRegex!.hasMatch(currentText)) {
    if(!foundUrls.contains(currentText) &&  _urlSearchRegex!.hasMatch(currentText)){
  
       foundUrls.add(currentText);    
     
       }
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

   
      _onUrlsFound?.call(foundUrls);
  
      
    return TextSpan(children: spans, style: style);
  }
}

extension _RegExpExtension on RegExp {
  List<String> allMatchesWithSep(String input, [int start = 0]) {
    var result = <String>[];
    for (var match in allMatches(input, start)) {
      result.add(input.substring(start, match.start));
      result.add(match[0]!);
      start = match.end;
    }
    result.add(input.substring(start));
    return result;
  }
}

extension _StringExtension on String {
  List<String> splitWithDelim(RegExp pattern) =>
      pattern.allMatchesWithSep(this);
}