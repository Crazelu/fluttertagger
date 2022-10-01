class User {
  final String id;
  final String userName;
  final String fullName;
  final String avatar;

  User({
    required this.id,
    required this.userName,
    required this.fullName,
    required this.avatar,
  });

  factory User.lucky() => User(
        id: "63a27531b866ce0016f9e582",
        fullName: "Lucky Ebere",
        userName: "crazelu",
        avatar:
            "https://github.githubassets.com/images/modules/profile/achievements/quickdraw-default.png",
      );

  factory User.brad() => User(
        id: "11a27531b866ce0016f9e582",
        fullName: "Brad Francis",
        userName: "brad",
        avatar: "https://avatars.githubusercontent.com/u/45284758?v=4",
      );

  factory User.sharky() => User(
        id: "69a12531b866ce0016f9h082",
        fullName: "Tom Hanks",
        userName: "sharky",
        avatar:
            "https://github.githubassets.com/images/modules/profile/achievements/pull-shark-default.png",
      );

  factory User.billy() => User(
        id: "69a48531n066ce0016f9h082",
        fullName: "Vecna Finn",
        userName: "billy",
        avatar:
            "https://github.githubassets.com/images/modules/profile/achievements/yolo-default.png",
      );

  factory User.lyon() => User(
        id: "69a48531n066cekk16f9h082",
        fullName: "Russel Van",
        userName: "lyon",
        avatar: "https://avatars.githubusercontent.com/u/26209401?s=64&v=4",
      );

  factory User.aurora() => User(
        id: "08a98331b866ce0017k9h082",
        fullName: "Aurora Peters",
        userName: "aurora",
        avatar:
            "https://github.githubassets.com/images/modules/profile/achievements/arctic-code-vault-contributor-default.png",
      );

  factory User.anon() => User(
        id: "69a00531b866ce0017k9h082",
        fullName: "Anonymous User",
        userName: "anon",
        avatar:
            "https://github.githubassets.com/images/modules/profile/achievements/pair-extraordinaire-default.png",
      );

  static List<User> allUsers = [
    User.lucky(),
    User.anon(),
    User.billy(),
    User.sharky(),
    User.lyon(),
    User.aurora(),
    User.brad(),
  ];
}
