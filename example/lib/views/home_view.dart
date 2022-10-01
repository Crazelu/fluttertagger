import 'package:flutter/material.dart';
import 'package:example/models/post.dart';
import 'package:example/views/view_models/home_view_model.dart';
import 'package:example/views/view_models/search_view_model.dart';
import 'package:example/views/widgets/comment_text_field.dart';
import 'package:example/views/widgets/post_widget.dart';
import 'package:example/views/widgets/user_list_view.dart';
import 'package:usertagger/usertagger.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final homeViewModel = HomeViewModel();
  late final _controller = UserTaggerController();
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
  }

  @override
  void dispose() {
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
        bottomNavigationBar: UserTagger(
          tagStyle: const TextStyle(color: Colors.pink),
          controller: _controller,
          onSearch: (query) {
            searchViewModel.search(query);
          },
          overlay: UserListView(tagController: _controller),
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
            }),
      ),
    );
  }
}
