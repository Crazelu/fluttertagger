import 'package:flutter/material.dart';
import 'package:example/models/post.dart';
import 'package:example/models/user.dart';

class HomeViewModel {
  final ValueNotifier<List<Post>> _posts = ValueNotifier(Post.posts);
  ValueNotifier<List<Post>> get posts => _posts;

  void addPost(String caption) {
    if (caption.isEmpty) return;

    final post = Post(
      caption: caption,
      poster: User.anon(),
      time: "now",
    );
    final postsCopy = _posts.value;
    postsCopy.add(post);
    _posts.value = [...postsCopy];
  }
}
