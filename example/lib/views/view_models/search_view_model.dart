import 'package:flutter/material.dart';
import 'package:example/models/user.dart';

///Search view model
final searchViewModel = SearchViewModel();

enum SearchResultView { users, hashtag, none }

class SearchViewModel {
  late final ValueNotifier<List<User>> _users = ValueNotifier([]);
  ValueNotifier<List<User>> get users => _users;

  late final ValueNotifier<List<String>> _hashtags = ValueNotifier([]);
  ValueNotifier<List<String>> get hashtags => _hashtags;

  late final ValueNotifier<bool> _loading = ValueNotifier(false);
  ValueNotifier<bool> get loading => _loading;

  late final ValueNotifier<SearchResultView> _activeView =
      ValueNotifier(SearchResultView.none);
  ValueNotifier<SearchResultView> get activeView => _activeView;

  void _setLoading(bool val) {
    if (val != _loading.value) {
      _loading.value = val;
    }
  }

  Future<void> searchUser(String query) async {
    _activeView.value = SearchResultView.users;
    if (query.isEmpty) return;

    query = query.toLowerCase().trim();

    _users.value = [];

    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 250));

    final result = User.allUsers
        .where(
          (user) =>
              user.userName.toLowerCase().contains(query) ||
              user.fullName.toLowerCase().contains(query),
        )
        .toList();

    _users.value = [...result];
    _setLoading(false);
  }

  Future<void> searchHashtag(String query) async {
    _activeView.value = SearchResultView.hashtag;
    if (query.isEmpty) return;

    query = query.toLowerCase().trim();

    _hashtags.value = [];

    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 250));

    final result = _dummyHashtags
        .where((tag) => tag.toLowerCase().contains(query))
        .toList();

    _hashtags.value = [...result];
    _setLoading(false);
  }
}

const _dummyHashtags = <String>[
  "Flutter",
  "FlutterDev",
  "Dash",
  "MobileDev",
  "Dart",
];
