import 'package:flutter/material.dart';
import 'package:example/views/view_models/search_view_model.dart';
import 'package:example/views/widgets/loading_indicator.dart';
import 'package:fluttertagger/fluttertagger.dart';

class HashtagListView extends StatelessWidget {
  const HashtagListView({
    Key? key,
    required this.tagController,
    required this.animation,
  }) : super(key: key);

  final FlutterTaggerController tagController;
  final Animation<Offset> animation;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: animation,
      child: Container(
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
              return ValueListenableBuilder<List<String>>(
                valueListenable: searchViewModel.hashtags,
                builder: (_, hashtags, __) {
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          const Spacer(),
                          Text(
                            "Hashtags",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: tagController.dismissOverlay,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      if (loading && hashtags.isEmpty) ...{
                        const Center(
                          heightFactor: 16,
                          child: LoadingWidget(),
                        )
                      },
                      if (!loading && hashtags.isEmpty)
                        const Center(
                          heightFactor: 16,
                          child: Text("Didn't find anything!"),
                        ),
                      if (hashtags.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: hashtags.length,
                            itemBuilder: (_, index) {
                              final hashtag = hashtags[index];
                              return ListTile(
                                leading: Container(
                                  height: 40,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.lightBlueAccent),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    "#",
                                    style: TextStyle(color: Colors.blueAccent),
                                  ),
                                ),
                                title: Text(hashtag),
                                onTap: () {
                                  tagController.addTag(
                                    id: hashtag,
                                    name: hashtag,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
