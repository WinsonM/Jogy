import 'package:flutter/material.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  int _selectedTabIndex = 0; // 0: 帖子, 1: 喜欢, 2: 收藏

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 模拟当前用户数据
  final String _userName = '我的用户名';
  final String _avatarUrl = 'https://i.pravatar.cc/300?img=5';
  final String _bio = '这是我的个人简介 ✨';
  final int _postsCount = 42;
  final int _followersCount = 1234;
  final int _followingCount = 567;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openSettings() {
    // TODO: 导航到设置页面
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('设置功能即将推出')));
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: Stack(
        children: [
          // 可滚动内容
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // 顶部留白
                SizedBox(height: topPadding + 20),
                // 头像
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
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
                // 统计数据
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem('$_postsCount', '帖子'),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    _buildStatItem('$_followersCount', '粉丝'),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    _buildStatItem('$_followingCount', '关注'),
                  ],
                ),
                const SizedBox(height: 24),
                // Tab栏
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Stack(
                    children: [
                      // 选中指示器
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        left:
                            _selectedTabIndex *
                            (MediaQuery.of(context).size.width - 40 - 8) /
                            3,
                        top: 0,
                        bottom: 0,
                        width: (MediaQuery.of(context).size.width - 40 - 8) / 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(21),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Tab 项
                      Row(
                        children: [
                          _buildTabItem('足迹', 0),
                          _buildTabItem('喜欢', 1),
                          _buildTabItem('收藏', 2),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 内容网格
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
                  itemCount: 15,
                  itemBuilder: (context, index) {
                    return Container(
                      color: Colors.grey[200],
                      child: Image.network(
                        'https://picsum.photos/200/200?random=${index + 100}',
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          // 固定的设置按钮 - 右上角
          Positioned(
            top: topPadding + 12,
            right: 16,
            child: GestureDetector(
              onTap: _openSettings,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Colors.black,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
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
