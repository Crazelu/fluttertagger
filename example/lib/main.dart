import 'package:flutter/material.dart';
import 'package:example/models/post.dart';
import 'package:example/views/view_models/home_view_model.dart';
import 'package:example/views/view_models/search_view_model.dart';
import 'package:example/views/widgets/comment_text_field.dart';
import 'package:example/views/widgets/post_widget.dart';
import 'package:example/views/widgets/user_list_view.dart';
import 'package:fluttertagger/fluttertagger.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlutterTagger Demo',
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

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _animation;

  double overlayHeight = 380;

  late final homeViewModel = HomeViewModel();
  late final _controller = FlutterTaggerController(
    //Initial text value with tag is formatted internally
    //after FlutterTaggerControlleris constructed.
    //After this controller is constructed, if you
    //wish to update its text value with raw tag string,
    //call (_controller.formatTags) after that.
    text: "Hey @11a27531b866ce0016f9e582#brad#",
  );
  late final _focusNode = FocusNode();

  void _focusListener() {
    if (!_focusNode.hasFocus) {
      _controller.dismissOverlay();
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusListener);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _animation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.removeListener(_focusListener);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var insets = MediaQuery.of(context).viewInsets;
    return GestureDetector(
      onTap: () {
        _controller.dismissOverlay();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.redAccent,
          title: const Text("The Squad"),
        ),
        bottomNavigationBar: FlutterTagger(
          overlayHeight: overlayHeight,
          animationController: _animationController,
          tagStyle: const TextStyle(color: Colors.pink),
          controller: _controller,
          onSearch: (query) {
            searchViewModel.search(query);
          },
          overlay: UserListView(
            animation: _animation,
            tagController: _controller,
          ),
          builder: (context, containerKey) {
            return CommentTextField(
              focusNode: _focusNode,
              containerKey: containerKey,
              insets: insets,
              controller: _controller,
              onSend: () {
                FocusScope.of(context).unfocus();
                homeViewModel.addPost(_controller.formattedText);
                _controller.clear();
              },
            );
          },
        ),
        body: ValueListenableBuilder<List<Post>>(
          valueListenable: homeViewModel.posts,
          builder: (_, posts, __) {
            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (_, index) {
                return PostWidget(post: posts[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
