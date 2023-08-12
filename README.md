## FlutterTagger

<p align="center">
  <img src="https://raw.githubusercontent.com/crazelu/fluttertagger/main/assets/fluttertagger_banner.svg" max-height="100" alt="FlutterTagger" />
</p>

<p align="center">
  <a href="https://pub.dev/packages/fluttertagger/score"><img src="https://img.shields.io/pub/likes/fluttertagger" alt="likes"></a>
  <a href="https://pub.dev/packages/fluttertagger/score"><img src="https://img.shields.io/pub/popularity/fluttertagger" alt="popularity"></a>
  <a href="https://pub.dev/packages/fluttertagger/score"><img src="https://img.shields.io/pub/points/fluttertagger" alt="pub points"></a>
</p>

FlutterTagger is a Flutter package that allows for the extension of TextFields to provide tagging capabilities. A typical use case is in social apps where user mentions and hashtags features are desired.

## Install 🚀

In the `pubspec.yaml` of your flutter project, add the following dependency:

```yaml
dependencies:
  fluttertagger: ^1.0.0+6
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
          overlay: SearchResultView(),
          builder: (context, containerKey) {
              //return child TextField wrapped with a Container
              //and pass it `containerKey`
              return Container(
                key: containerKey,
                child: TextField(
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
