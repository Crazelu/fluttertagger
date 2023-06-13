## FlutterTagger

FlutterTagger is a Flutter package that allows for the extension of TextFields to provide tagging capabilities. A typical use case is in social apps where tagging users or hashtags is required.

## Install 🚀

In the `pubspec.yaml` of your flutter project, add the following dependency:

```yaml
dependencies:
  fluttertagger: ^1.0.0
```

## Import the package in your project 📥

```dart
import 'package:fluttertagger/fluttertagger.dart';
```

## Usage 🏗️

```dart
FlutterTagger(
          tagController: _tagController,
          textEditingController: _controller,
          onSearch: (query) {
              //perform search
          },
          overlay: UserListView(tagController: _tagController),
          builder: (context, containerKey) {
              //return child TextField wrapped with a Container
              //and pass it `containerKey`
            return CommentTextField(
              focusNode: _focusNode,
              containerKey: containerKey,
              controller: _controller,
              onSend: () {
                //perform send action
                FocusScope.of(context).unfocus();
                _tagController.clear();
              },
            );
          },
        )
```


Explore detailed example demo [here](https://github.com/Crazelu/fluttertagger/tree/main/example).

## Screenshots 📷

<img src="https://raw.githubusercontent.com/Crazelu/fluttertagger/main/screenshots/screenshot1.png" width="280" height="600"> <img src="https://raw.githubusercontent.com/Crazelu/fluttertagger/main/screenshots/screenshot2.png" width="280" height="600">

## Contributions 🫱🏾‍🫲🏼

Feel free to contribute to this project.

If you find a bug or want a feature, but don't know how to fix/implement it, please fill an [issue](https://github.com/Crazelu/usertagger/issues).  
If you fixed a bug or implemented a feature, please send a [pull request](https://github.com/Crazelu/fluttertagger/pulls).
