import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../auth/pages/login_page.dart';
import '../widgets/posts_timeline.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/location_model.dart';
import 'edit_profile_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  int _selectedTabIndex = 0; // 0: 帖子, 1: 喜欢, 2: 收藏

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 模拟当前用户数据（可编辑）
  String _userName = '我的用户名';
  String _avatarUrl = 'https://i.pravatar.cc/300?img=5';
  String _bio = '这是我的个人简介 ✨';
  final int _postsCount = 42;
  final int _followersCount = 1234;
  final int _followingCount = 567;

  // 模拟帖子数据
  late List<PostModel> _mockPosts;

  @override
  void initState() {
    super.initState();
    _mockPosts = _generateMockPosts();
  }

  /// 生成模拟帖子数据
  List<PostModel> _generateMockPosts() {
    final now = DateTime.now();
    final mockUser = UserModel(
      id: 'my_user',
      username: _userName,
      avatarUrl: _avatarUrl,
      bio: _bio,
    );
    const mockLocation = LocationModel(
      latitude: 31.2304,
      longitude: 121.4737,
      address: '上海市',
    );

    return [
      PostModel(
        id: 'my_post_1',
        user: mockUser,
        location: mockLocation,
        content: '今天天气真好，出去走走 🌞',
        imageUrls: const ['https://picsum.photos/200/200?random=101'],
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      PostModel(
        id: 'my_post_2',
        user: mockUser,
        location: mockLocation,
        content: '分享一些最近的摄影作品',
        imageUrls: const [
          'https://picsum.photos/200/200?random=102',
          'https://picsum.photos/200/200?random=103',
          'https://picsum.photos/200/200?random=104',
        ],
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      PostModel(
        id: 'my_post_3',
        user: mockUser,
        location: mockLocation,
        content: '周末的小确幸 ☕',
        imageUrls: const [
          'https://picsum.photos/200/200?random=105',
          'https://picsum.photos/200/200?random=106',
        ],
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      PostModel(
        id: 'my_post_4',
        user: mockUser,
        location: mockLocation,
        content: '记录生活的美好瞬间',
        imageUrls: const [
          'https://picsum.photos/200/200?random=107',
          'https://picsum.photos/200/200?random=108',
          'https://picsum.photos/200/200?random=109',
          'https://picsum.photos/200/200?random=110',
        ],
        createdAt: DateTime(2025, 10, 15),
      ),
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openSettings() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _SettingsDrawer();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation =
            Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: slideAnimation, child: child);
      },
    );
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final result =
                            await Navigator.push<Map<String, String>>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfilePage(
                                  userName: _userName,
                                  avatarUrl: _avatarUrl,
                                  bio: _bio,
                                ),
                              ),
                            );
                        // 更新用户资料
                        if (result != null && mounted) {
                          setState(() {
                            _userName = result['userName'] ?? _userName;
                            _avatarUrl = result['avatarUrl'] ?? _avatarUrl;
                            _bio = result['bio'] ?? _bio;
                          });
                        }
                      },
                      child: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_bio, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                // 统计数据
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem('$_postsCount', '发布'),
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
                          _buildTabItem('发布', 0),
                          _buildTabItem('喜欢', 1),
                          _buildTabItem('收藏', 2),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 根据选中的 tab 显示不同内容
                _buildTabContent(),
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

  /// 根据选中的 tab 构建内容
  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: // 发布
        return PostsTimeline(
          posts: _mockPosts,
          onPostTap: (post) {
            // TODO: 导航到帖子详情页
          },
        );
      case 1: // 喜欢
      case 2: // 收藏
      default:
        // 其他 tab 暂时显示占位 GridView
        return GridView.builder(
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
            final seed = _selectedTabIndex * 100 + index;
            return Container(
              color: Colors.grey[200],
              child: Image.network(
                'https://picsum.photos/200/200?random=$seed',
                fit: BoxFit.cover,
              ),
            );
          },
        );
    }
  }
}

// 设置侧边栏
class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.75,
          height: double.infinity,
          child: SafeArea(
            child: Column(
              children: [
                // 顶部标题
                Padding(
                  padding: EdgeInsets.only(
                    top: topPadding,
                    left: 20,
                    right: 20,
                  ),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // 浏览历史
                _buildMenuItem(
                  icon: Icons.history,
                  title: '浏览历史',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('浏览历史功能即将推出')));
                  },
                ),
                // 联系客服
                _buildMenuItem(
                  icon: Icons.headset_mic_outlined,
                  title: '联系客服',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('联系客服功能即将推出')));
                  },
                ),
                const Spacer(),
                // 退出登录按钮 - 玻璃效果
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: GestureDetector(
                        onTap: () {
                          // 导航到登录页并清除所有历史路由
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(180),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            '退出登录',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.grey[700]),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            Icon(Icons.chevron_right, size: 24, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
