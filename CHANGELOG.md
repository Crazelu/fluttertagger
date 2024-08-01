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