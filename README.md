## FlutterTagger

FlutterTagger is a Flutter library that allows for the extension of TextFields to provide tagging capabilities. A typical use case is in social apps where tagging users or hashtags is required.

## Install 🚀

In the `pubspec.yaml` of your flutter project, add the following dependency:

```yaml
dependencies:
  fluttertagger:
    git:
      url: git@github.com:Crazelu/fluttertagger.git
```

## Import the package in your project 📥

```dart
import 'package:fluttertagger/fluttertagger.dart';
```

## Usage 🏗️

```dart
FlutterTagger(
          controller: flutterTaggerController,
          onSearch: (query) {
              //perform search
          },
          //
          overlay: SearchResultView(),
          builder: (context, containerKey) {
              //return child TextField wrapped with a Container
              //and pass it `containerKey`
            return CommentTextField(
              focusNode: _focusNode,
              containerKey: containerKey,
              controller: flutterTaggerController,
              onSend: () {
                //perform send action
                FocusScope.of(context).unfocus();
                flutterTaggerController.clear();
              },
            );
          },
        )
```


Explore detailed example demo [here](https://github.com/Crazelu/fluttertagger/tree/main/example).

## Demo 📷

<img src="https://raw.githubusercontent.com/Crazelu/fluttertagger/main/assets/demo.gif" width="400" height="800"> 

## Contributions 🫱🏾‍🫲🏼

Feel free to contribute to this project.

If you find a bug or want a feature, but don't know how to fix/implement it, please fill an [issue](https://github.com/Crazelu/fluttertagger/issues).  
If you fixed a bug or implemented a feature, please send a [pull request](https://github.com/Crazelu/fluttertagger/pulls).
