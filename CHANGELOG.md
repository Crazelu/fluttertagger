## 1.0.0

* Initial release.
## 1.0.0+1

* Fixes SDK version constraints

## 1.0.0+2

* Updates demo
## 1.0.0+3

* Updates repo banner
## 1.0.0+4

* README update

## 1.0.0+5

* Updates documentation and README example
## 1.0.0+6

* Adds support for formatting tags in FlutterTaggerController's text value set directly using the `text` setter. 
* Exposes a `formatTags` method for this purpose.

## 2.0.0

* Adds support for multiple kinds of tags associated with any single FlutterTaggerController.
* Adds improvement to logic which re-activates the search context from backtracking.
* Updates documentation and example project.

## 2.1.0

* Introduces `OverlayPosition` to indicate where the overlay should be positioned relative to the `TextField`.
* Clears FlutterTaggerController's `formattedText` when `clear` is called.
* Fixes issue with re-activating the search context with a trigger character immediately after adding a tag.
* Removes the need for TextFields returned from FlutterTagger's builder to be wrapped with a Container to which the key from the closure must be passed. The key can now be passed directly to the TextField.

## 2.1.1

* Fixes issue with activating search context after updating controller's text directly.

## 2.2.0

* Fixes issue with text selection throwing range error for "Select All" option or by manually selecting all characters in the text field.
* Adds `cursorPosition` to `FlutterTaggerController` which reports the position of the cursor in the formatted text.

## 2.2.1

* Documentation update.

## 2.3.0

* Updates overlay implementation to use `OverlayPortal` which brings in the fix that lets the overlay reposition itself when the keyboard is dismissed.

* Introduces `TriggerStrategy` to indicate how immediate the search callback should be invoked when a search trigger character is detected.

## 2.3.1

* Adds `tags` getter to `FlutterTaggerController` which returns the currently applied tags.