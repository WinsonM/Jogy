import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import 'pages/myprofile_page.dart';
import 'pages/profile_page.dart';

/// 根据目标 [userId] 判断"是不是当前登录用户"，是则跳 [MyProfilePage]，
/// 否则跳 [ProfilePage]。所有"查看某用户资料"的入口都应走这个 helper，
/// 避免在 5 处重复 `currentUser.id == userId` 的判断导致漂移。
///
/// - [userId] 是权威判断依据；为 null 时无法判断 self，直接回退到 [ProfilePage]。
/// - 其他字段（[userName] / [avatarUrl] / [bio] / [gender] / [isFollowing]）
///   只用于 [ProfilePage] 加载阶段的 placeholder；[MyProfilePage] 自行从
///   [AuthService] 和 API 取数据，不需要透传。
/// - [replace] = true 时用 `pushReplacement`（扫码页场景）。
Future<void> openUserProfile(
  BuildContext context, {
  String? userId,
  String? userName,
  String? avatarUrl,
  String? bio,
  String? gender,
  bool? isFollowing,
  bool replace = false,
}) {
  final currentUserId = context.read<AuthService>().currentUser?.id;
  final isMe = userId != null && userId == currentUserId;

  final route = MaterialPageRoute<void>(
    builder: (_) => isMe
        ? const MyProfilePage()
        : ProfilePage(
            userId: userId,
            userName: userName,
            avatarUrl: avatarUrl,
            bio: bio,
            gender: gender,
            isFollowing: isFollowing,
          ),
  );

  return replace
      ? Navigator.pushReplacement(context, route)
      : Navigator.push(context, route);
}
