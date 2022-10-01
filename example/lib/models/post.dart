import 'package:example/models/user.dart';

class Post {
  final String caption;
  final User poster;
  final String time;

  Post({
    required this.caption,
    required this.poster,
    required this.time,
  });

  static List<Post> posts = [
    Post(
      caption: "Hi @63a27531b866ce0016f9e582#crazelu#. Please call me",
      poster: User.billy(),
      time: "2 days ago",
    ),
    Post(
      caption:
          "@69a12531b866ce0016f9h082#sharky#,@69a48531n066ce0016f9h082#billy# you're gonna want to visit me now",
      poster: User.lucky(),
      time: "2 days ago",
    ),
    Post(
      caption: "Hey guys. I'm new here",
      poster: User.brad(),
      time: "2 days ago",
    ),
    Post(
      caption:
          "Y'all should check my twitter https://twitter.com/ebere_lucky. S/O to @08a98331b866ce0017k9h082#aurora# and @11a27531b866ce0016f9e582#brad#. Real OGs",
      poster: User.lucky(),
      time: "2 days ago",
    ),
    Post(
      caption:
          "Why should I visit you 😏 @63a27531b866ce0016f9e582#crazelu# SMH",
      poster: User.sharky(),
      time: "1 day ago",
    ),
  ];
}
