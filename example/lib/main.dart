import 'package:flutter/material.dart';
import 'package:example/views/home_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Tag Demo',
      theme: ThemeData(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: Colors.redAccent.withOpacity(.3),
        ),
        primarySwatch: Colors.red,
      ),
      home: const HomeView(),
    );
  }
}
