class UserModel {
  final String id;
  final String username;
  final String avatarUrl;
  final String bio;
  final int followers;
  final int following;

  const UserModel({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.bio,
    this.followers = 0,
    this.following = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String,
      bio: json['bio'] as String,
      followers: json['followers'] as int? ?? 0,
      following: json['following'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'followers': followers,
      'following': following,
    };
  }
}
