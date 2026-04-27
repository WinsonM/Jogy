import 'package:jogy_app/core/constants/api_constants.dart';

class UserModel {
  final String id;
  final String username;
  final String avatarUrl;
  final String bio;
  final String gender;
  final DateTime? birthday;
  final int followers;
  final int following;

  const UserModel({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.bio,
    this.gender = '保密',
    this.birthday,
    this.followers = 0,
    this.following = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      username: json['username'] as String? ?? '',
      avatarUrl: _resolveAvatar(
        (json['avatarUrl'] as String?) ?? (json['avatar_url'] as String?) ?? '',
      ),
      bio: json['bio'] as String? ?? '',
      gender: json['gender'] as String? ?? '保密',
      birthday: _parseBirthday(json['birthday'] ?? json['birthdate']),
      followers: json['followers'] as int? ?? 0,
      following: json['following'] as int? ?? 0,
    );
  }

  /// Resolve avatar URL: backend returns "/uploads/..." relative path,
  /// mock data uses full "https://..." URLs — handle both.
  static String _resolveAvatar(String url) {
    if (url.isEmpty) return url;
    return ApiConstants.resolveUrl(url);
  }

  static DateTime? _parseBirthday(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'gender': gender,
      'birthday': birthday?.toIso8601String(),
      'followers': followers,
      'following': following,
    };
  }
}
