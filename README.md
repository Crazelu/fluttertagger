## FlutterTagger

<p align="center">
  <img src="https://raw.githubusercontent.com/crazelu/fluttertagger/main/assets/fluttertagger_banner.svg" max-height="100" alt="FlutterTagger" />
</p>

<p align="center">
  <a href="https://pub.dev/packages/fluttertagger/score"><img src="https://img.shields.io/pub/likes/fluttertagger" alt="likes"></a>
  <a href="https://pub.dev/packages/fluttertagger/score"><img src="https://img.shields.io/pub/popularity/fluttertagger" alt="popularity"></a>
  <a href="https://pub.dev/packages/fluttertagger/score"><img src="https://img.shields.io/pub/points/fluttertagger" alt="pub points"></a>
  <a href="https://codecov.io/gh/crazelu/fluttertagger"><img src="https://codecov.io/gh/crazelu/fluttertagger/graph/badge.svg" alt="code coverage"/></a>
</p>


FlutterTagger is a Flutter package that allows for the extension of TextFields to provide tagging capabilities. A typical use case is in social apps where user mentions and hashtags features are desired.

## Install 🚀

In the `pubspec.yaml` of your flutter project, add the following dependency:

```yaml
dependencies:
  fluttertagger: ^2.2.1
```

## Import the package in your project 📥

```dart
import 'package:fluttertagger/fluttertagger.dart';
```

## Usage 🏗️

```dart
FlutterTagger(
          controller: flutterTaggerController,
          onSearch: (query, triggerCharacter) {
              //perform search
          },
          //characters that can trigger a search and the styles
          //to be applied to their tagged results in the TextField
          triggerCharacterAndStyles: const {
            '@': TextStyle(color: Colors.pinkAccent),
            '#': TextStyle(color: Colors.blueAccent),
          },
          overlay: SearchResultView(),
          builder: (context, textFieldKey) {
              //return a TextField and pass it `textFieldKey`
              return TextField(
                    key: textFieldKey,
                    controller: flutterTaggerController,
                    suffix: IconButton(
                      onPressed: () {
                        //get formatted text from controller
                        final text = flutterTaggerController.formattedText;

                        //perform send action...

                        FocusScope.of(context).unfocus();
                        flutterTaggerController.clear();
                      },
                    icon: const Icon(
                      Icons.send,
                      color: Colors.redAccent,
                    ),
                  ),
                );
          },
        )
```

Here's how trigger a search by updating the controller directly instead of typing into a keyboard:

```dart
FlutterTagger(
          controller: flutterTaggerController,
          onSearch: (query, triggerCharacter) {
              //perform search
          },
          //characters that can trigger a search and the styles
          //to be applied to their tagged results in the TextField
          triggerCharacterAndStyles: const {
            '@': TextStyle(color: Colors.pinkAccent),
            '#': TextStyle(color: Colors.blueAccent),
          },
          overlay: SearchResultView(),
          builder: (context, textFieldKey) {
              // return a TextField and pass it `textFieldKey`
              return TextField(
                    key: textFieldKey,
                    controller: flutterTaggerController,
                    suffix: IconButton(
                      onPressed: () {
                        // get formatted text from controller
                        String text = flutterTaggerController.formattedText;

                        // append a trigger character to activate the search context
                        flutterTaggerController.text = text += '#';

                        // update text selection
                        flutterTaggerController.selection = TextSelection.fromPosition(
                          TextPosition(offset: flutterTaggerController.text.length),
                        );

                        // append other characters to trigger search
                        flutterTaggerController.text = text += 'f';

                        // update text selection
                        flutterTaggerController.selection = TextSelection.fromPosition(
                          TextPosition(offset: flutterTaggerController.text.length),
                        );

                        // then call formatTags on the controller to preserve formatting
                        flutterTaggerController.formatTags();
                      },
                    icon: const Icon(
                      Icons.send,
                      color: Colors.redAccent,
                    ),
                  ),
                );
          },
        )
```

Explore detailed example demo [here](https://github.com/Crazelu/fluttertagger/tree/main/example).

## Demo 📷

<img src="https://raw.githubusercontent.com/Crazelu/fluttertagger/main/assets/fluttertagger.gif" width="280" alt="Example demo"> 

## Contributions 🫱🏾‍🫲🏼

Feel free to contribute to this project.

If you find a bug or want a feature, but don't know how to fix/implement it, please fill an [issue](https://github.com/Crazelu/fluttertagger/issues).  
If you fixed a bug or implemented a feature, please send a [pull request](https://github.com/Crazelu/fluttertagger/pulls).
