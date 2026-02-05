import 'package:flutter/material.dart';
import '../../../data/models/user_model.dart';
import '../pages/profile_page.dart';

enum UserListType { followers, following }

class UserListPage extends StatelessWidget {
  final UserListType listType;
  final List<UserModel> users;

  const UserListPage({super.key, required this.listType, required this.users});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final title = listType == UserListType.followers ? '粉丝' : '关注';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 主要内容
          users.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: EdgeInsets.only(top: topPadding + 60, bottom: 100),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _buildUserTile(context, user);
                  },
                ),
          // 顶部导航栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.only(top: topPadding),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$title (${users.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Placeholder for alignment
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, UserModel user) {
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(
              userId: user.id,
              userName: user.username,
              avatarUrl: user.avatarUrl,
              bio: user.bio,
              gender: user.gender,
            ),
          ),
        );
      },
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[300],
        backgroundImage: NetworkImage(user.avatarUrl),
      ),
      title: Text(
        user.username,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        user.bio,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = listType == UserListType.followers ? '暂无粉丝' : '暂无关注';
    final subMessage = listType == UserListType.followers
        ? '快去分享精彩内容吸引粉丝吧'
        : '去发现更多有趣的人吧';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            listType == UserListType.followers
                ? Icons.people_outline
                : Icons.person_add_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
