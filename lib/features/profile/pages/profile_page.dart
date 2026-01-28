import 'package:flutter/material.dart';
import '../../message/pages/chat_page.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  final String? userName;
  final String? avatarUrl;
  final String? bio;
  final bool? isFollowing;

  const ProfilePage({
    super.key,
    this.userId,
    this.userName,
    this.avatarUrl,
    this.bio,
    this.isFollowing,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late bool _isFollowing;
  late String _userName;
  late String _avatarUrl;
  late String _bio;
  int _selectedTabIndex = 0; // 0: 喜欢, 1: 收藏

  @override
  void initState() {
    super.initState();
    // 使用传入的参数或默认值
    _isFollowing = widget.isFollowing ?? false;
    _userName = widget.userName ?? 'Alice Chen';
    _avatarUrl = widget.avatarUrl ?? 'https://i.pravatar.cc/300';
    _bio = widget.bio ?? 'Digital nomad & coffee enthusiast ☕️';
  }

  void _toggleFollow() {
    setState(() {
      _isFollowing = !_isFollowing;
    });
    // TODO: 更新数据库中的关注状态
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatPage(userName: _userName, avatarUrl: _avatarUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false, // 禁用底部安全区域，让内容延伸到屏幕底部
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 返回按钮（如果是从其他页面导航过来的）
              if (Navigator.canPop(context))
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
              else
                const SizedBox(height: 20),
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey,
                backgroundImage: NetworkImage(_avatarUrl),
              ),
              const SizedBox(height: 16),
              Text(
                _userName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(_bio, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 关注/已关注 按钮
                  GestureDetector(
                    onTap: _toggleFollow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isFollowing ? Colors.grey[300] : Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isFollowing ? '已关注' : '关注',
                        style: TextStyle(
                          color: _isFollowing ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 私信按钮
                  GestureDetector(
                    onTap: _openChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '私信',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    // 选中指示器背景
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: _selectedTabIndex == 0 ? 0 : null,
                      right: _selectedTabIndex == 1 ? 0 : null,
                      top: 0,
                      bottom: 0,
                      width: (MediaQuery.of(context).size.width - 40 - 8) / 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(21),
                        ),
                      ),
                    ),
                    // Tab 按钮
                    Row(
                      children: [
                        _buildTabItem('喜欢', 0),
                        _buildTabItem('收藏', 1),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                padding: const EdgeInsets.all(2),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  return Container(
                    color: Colors.grey[200],
                    child: Image.network(
                      'https://picsum.photos/200/200?random=$index',
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String text, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
