import 'package:flutter/material.dart';
import 'package:example/models/user.dart';
import 'package:example/views/view_models/search_view_model.dart';
import 'package:example/views/widgets/loading_indicator.dart';
import 'package:fluttertagger/fluttertagger.dart';

class UserListView extends StatelessWidget {
  final FlutterTaggerController tagController;
  const UserListView({
    Key? key,
    required this.tagController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.2),
            offset: const Offset(0, -20),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ValueListenableBuilder<bool>(
            valueListenable: searchViewModel.loading,
            builder: (_, loading, __) {
              return ValueListenableBuilder<List<User>>(
                  valueListenable: searchViewModel.users,
                  builder: (_, users, __) {
                    if (loading && users.isEmpty) {
                      return const Center(
                        child: LoadingWidget(),
                      );
                    }
                    return Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: tagController.dismissOverlay,
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        if (users.isEmpty)
                          const Center(child: Text("No user found"))
                        else
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: users.length,
                              itemBuilder: (_, index) {
                                final user = users[index];
                                return ListTile(
                                  leading: Container(
                                    height: 50,
                                    width: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image: NetworkImage(user.avatar),
                                      ),
                                    ),
                                  ),
                                  title: Text(user.fullName),
                                  subtitle: Text("@${user.userName}"),
                                  onTap: () {
                                    tagController.addTag(
                                      id: user.id,
                                      name: user.userName,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  });
            }),
      ),
    );
  }
}
