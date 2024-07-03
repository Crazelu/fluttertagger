import 'package:flutter/material.dart';
import 'package:example/models/user.dart';
import 'package:example/views/widgets/custom_text_field.dart';

class CommentTextField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> emojis;
  final VoidCallback onSend;
  final EdgeInsets insets;
  final FocusNode? focusNode;

  ///Key passed down from FlutterTagger
  final Key? containerKey;

  const CommentTextField({
    Key? key,
    required this.controller,
    required this.onSend,
    required this.insets,
    this.emojis = const [
      '😍',
      '😜',
      '👍',
      '🤞',
      '🙌',
      '😉',
      '🙏',
    ],
    this.focusNode,
    this.containerKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      key: containerKey,
      constraints: BoxConstraints(
        maxHeight: insets == EdgeInsets.zero ? 158 : 158 + insets.bottom,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 20,
        horizontal: 10,
      ),
      color: Colors.white,
      child: Column(
        mainAxisAlignment: insets == EdgeInsets.zero
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var emoji in emojis)
                    EmojiIcon(
                      fontSize: 24,
                      emoji: emoji,
                      onTap: (emoji) {
                        controller.text += emoji;
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
                        );
                      },
                    )
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: NetworkImage(User.anon().avatar),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: width * .82,
                child: CustomTextField(
                  focusNode: focusNode,
                  controller: controller,
                  hint: "Type something fun...",
                  suffix: IconButton(
                    onPressed: onSend,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class EmojiIcon extends StatelessWidget {
  final String emoji;
  final Function(String) onTap;
  final double fontSize;

  const EmojiIcon({
    Key? key,
    required this.emoji,
    required this.onTap,
    this.fontSize = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(emoji),
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: fontSize,
        ),
      ),
    );
  }
}
