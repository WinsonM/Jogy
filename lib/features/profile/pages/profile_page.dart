import 'dart:ui';
import 'package:flutter/material.dart';
import '../../message/pages/chat_page.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/location_model.dart';
import '../widgets/posts_timeline.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  final String? userName;
  final String? avatarUrl;
  final String? bio;
  final String? gender;
  final bool? isFollowing;

  const ProfilePage({
    super.key,
    this.userId,
    this.userName,
    this.avatarUrl,
    this.bio,
    this.gender,
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
  late String _gender;
  int _selectedTabIndex = 0; // 0: 发布, 1: 喜欢, 2: 收藏

  // 滚动控制器和状态
  final ScrollController _scrollController = ScrollController();
  bool _showBackButtonBg = false;
  bool _isCollapsed = false; // 头部是否折叠

  // 模拟帖子数据
  late List<PostModel> _mockPosts;

  // 头部展开时的高度（头像 + 名字 + bio + 按钮区域）
  static const double _expandedHeaderHeight = 260.0;

  @override
  void initState() {
    super.initState();
    // 使用传入的参数或默认值
    _isFollowing = widget.isFollowing ?? false;
    _userName = widget.userName ?? 'Alice Chen';
    _avatarUrl = widget.avatarUrl ?? 'https://i.pravatar.cc/300';
    _bio = widget.bio ?? 'Digital nomad & coffee enthusiast ☕️';
    _gender = widget.gender ?? '女'; // Default to female for mock profile

    // 监听滚动
    _scrollController.addListener(_onScroll);

    // 初始化模拟数据
    _mockPosts = _generateMockPosts();
  }

  /// 生成模拟帖子数据
  List<PostModel> _generateMockPosts() {
    final now = DateTime.now();
    final mockUser = UserModel(
      id: 'user_1',
      username: _userName,
      avatarUrl: _avatarUrl,
      bio: _bio,
      gender: _gender,
    );
    const mockLocation = LocationModel(
      latitude: 31.2304,
      longitude: 121.4737,
      address: '上海市',
    );

    return [
      // 刚刚发布的帖子（测试分钟前）
      PostModel(
        id: 'post_1',
        user: mockUser,
        location: mockLocation,
        content: '全网紧急寻亲！21岁扬大女生患白血病急需骨髓移植，裸辞...',
        imageUrls: const ['https://picsum.photos/200/200?random=1'],
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      // 几小时前的帖子
      PostModel(
        id: 'post_2',
        user: mockUser,
        location: mockLocation,
        content: '21岁，她亲手为自己签下病危通知书',
        imageUrls: const ['https://picsum.photos/200/200?random=2'],
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      // 昨天的帖子
      PostModel(
        id: 'post_3',
        user: mockUser,
        location: mockLocation,
        content: '呼。',
        imageUrls: const [
          'https://picsum.photos/200/200?random=3',
          'https://picsum.photos/200/200?random=4',
          'https://picsum.photos/200/200?random=5',
          'https://picsum.photos/200/200?random=6',
          'https://picsum.photos/200/200?random=7',
          'https://picsum.photos/200/200?random=8',
        ],
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      // 2025年的帖子
      PostModel(
        id: 'post_4',
        user: mockUser,
        location: mockLocation,
        content: '出现一下来点存在感叭',
        imageUrls: const [
          'https://picsum.photos/200/200?random=9',
          'https://picsum.photos/200/200?random=10',
          'https://picsum.photos/200/200?random=11',
          'https://picsum.photos/200/200?random=12',
          'https://picsum.photos/200/200?random=13',
          'https://picsum.photos/200/200?random=14',
          'https://picsum.photos/200/200?random=15',
          'https://picsum.photos/200/200?random=16',
          'https://picsum.photos/200/200?random=17',
        ],
        createdAt: DateTime(2025, 11, 30),
      ),
      PostModel(
        id: 'post_5',
        user: mockUser,
        location: mockLocation,
        content: '跨越半个世纪的婚约...听爷爷奶奶们讲相遇相知相爱，"我爱您""相伴永...',
        imageUrls: const [
          'https://picsum.photos/200/200?random=18',
          'https://picsum.photos/200/200?random=19',
          'https://picsum.photos/200/200?random=20',
          'https://picsum.photos/200/200?random=21',
        ],
        createdAt: DateTime(2025, 8, 29),
      ),
    ];
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 滚动超过 20px 时显示玻璃背景
    final shouldShowBg = _scrollController.offset > 20;
    // 滚动超过展开头部高度时折叠
    final shouldCollapse =
        _scrollController.offset > _expandedHeaderHeight - 100;

    if (shouldShowBg != _showBackButtonBg || shouldCollapse != _isCollapsed) {
      setState(() {
        _showBackButtonBg = shouldShowBg;
        _isCollapsed = shouldCollapse;
      });
    }
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
    final topPadding = MediaQuery.of(context).padding.top;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 可滚动内容
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // 顶部留白（给返回按钮留空间）
                SizedBox(height: canPop ? topPadding + 48 : topPadding + 20),
                // 头像
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_gender != '保密') ...[
                      Icon(
                        _gender == '男' ? Icons.male : Icons.female,
                        size: 16,
                        color: _gender == '男' ? Colors.blue : Colors.pink,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(_bio, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
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
                    const SizedBox(width: 12),
                    // 消息按钮
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
                          '消息',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Tab栏 - 匹配导航栏样式
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
                            ((MediaQuery.of(context).size.width - 40 - 8) / 3),
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
          // 固定的返回按钮
          if (canPop)
            Positioned(
              top: topPadding + 8,
              left: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: _showBackButtonBg
                    ? ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(153), // 60% 不透明度
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(20),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 20,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
              ),
            ),
          // 模糊遮罩（折叠时覆盖原始内容）
          if (_isCollapsed)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 200, // 覆盖原头像和按钮区域
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.white.withAlpha(180)),
                ),
              ),
            ),
          // 固定的折叠头部（滚动时显示）
          if (_isCollapsed)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildCollapsedHeader(topPadding, canPop),
            ),
        ],
      ),
    );
  }

  /// 构建折叠后的固定头部
  Widget _buildCollapsedHeader(double topPadding, bool canPop) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：返回按钮 + 头像 + 按钮（带淡入淡出动画）
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isCollapsed ? 1.0 : 0.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // 返回按钮
                  if (canPop)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                  if (canPop) const SizedBox(width: 12),
                  // 小头像
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: NetworkImage(_avatarUrl),
                  ),
                  const Spacer(),
                  // 关注按钮
                  GestureDetector(
                    onTap: _toggleFollow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isFollowing ? Colors.grey[300] : Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _isFollowing ? '已关注' : '关注',
                        style: TextStyle(
                          color: _isFollowing ? Colors.black : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 消息按钮
                  GestureDetector(
                    onTap: _openChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '消息',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 固定的 Tab 栏
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
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
                  left: _selectedTabIndex * ((screenWidth - 40 - 8) / 3),
                  top: 0,
                  bottom: 0,
                  width: (screenWidth - 40 - 8) / 3,
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
        ],
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
