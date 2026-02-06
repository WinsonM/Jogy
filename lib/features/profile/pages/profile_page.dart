import 'dart:ui';
import 'package:flutter/material.dart';
import '../../message/pages/chat_page.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/location_model.dart';
import '../widgets/posts_timeline.dart';
import '../widgets/user_list_page.dart';
import '../widgets/posts_map_view.dart';
import '../widgets/posts_grid_view.dart';
import '../../detail/pages/detail_page.dart';

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
  bool _isMapView = false; // Toggle between timeline and map view

  // 滚动控制器和状态
  final ScrollController _scrollController = ScrollController();
  bool _showBackButtonBg = false;
  bool _isCollapsed = false; // 头部是否折叠
  final GlobalKey _scrollTabKey = GlobalKey();
  final GlobalKey _pinnedTabKey = GlobalKey();
  double _pinnedTabY = 0.0;

  // 模拟统计数据
  final int _postsCount = 42;
  final int _followersCount = 1234;
  final int _followingCount = 567;

  // Mock followers list
  final List<UserModel> _mockFollowers = const [
    UserModel(
      id: 'follower_1',
      username: '小明',
      avatarUrl: 'https://i.pravatar.cc/150?img=1',
      bio: '热爱生活的旅行者 🌍',
    ),
    UserModel(
      id: 'follower_2',
      username: '小红',
      avatarUrl: 'https://i.pravatar.cc/150?img=2',
      bio: '美食博主 | 摄影爱好者',
    ),
    UserModel(
      id: 'follower_3',
      username: '张三',
      avatarUrl: 'https://i.pravatar.cc/150?img=3',
      bio: '程序员 | 咖啡控 ☕',
    ),
  ];

  // Mock following list
  final List<UserModel> _mockFollowing = const [
    UserModel(
      id: 'following_1',
      username: '李四',
      avatarUrl: 'https://i.pravatar.cc/150?img=4',
      bio: '设计师 | 艺术爱好者',
    ),
    UserModel(
      id: 'following_2',
      username: '王五',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
      bio: '健身达人 💪',
    ),
  ];

  // 模拟帖子数据
  late List<PostModel> _mockPosts;
  late List<PostModel> _likedPosts;
  late List<PostModel> _favoritedPosts;

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
    _likedPosts = _generateLikedPosts();
    _favoritedPosts = _generateFavoritedPosts();

    // 首帧后获取固定 Tab 的目标位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePinnedTabY();
    });
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
    // 当滚动 Tab 到达固定位置后折叠
    final shouldCollapse = _shouldPinTabBar();

    if (shouldShowBg != _showBackButtonBg || shouldCollapse != _isCollapsed) {
      setState(() {
        _showBackButtonBg = shouldShowBg;
        _isCollapsed = shouldCollapse;
      });
    }
  }

  void _updatePinnedTabY() {
    final box = _pinnedTabKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final y = box.localToGlobal(Offset.zero).dy;
    if (y != _pinnedTabY) {
      _pinnedTabY = y;
      if (mounted) {
        _onScroll();
      }
    }
  }

  bool _shouldPinTabBar() {
    final scrollBox =
        _scrollTabKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollBox == null || _pinnedTabY == 0.0) {
      // 回退到旧阈值，避免首帧抖动
      return _scrollController.offset > _expandedHeaderHeight - 100;
    }
    final scrollTabY = scrollBox.localToGlobal(Offset.zero).dy;
    return scrollTabY <= _pinnedTabY;
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

  Widget _buildStatItem(String count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final canPop = Navigator.canPop(context);
    if (_pinnedTabY == 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updatePinnedTabY();
      });
    }

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
                    _buildStatItem(
                      '$_followersCount',
                      '粉丝',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserListPage(
                              listType: UserListType.followers,
                              users: _mockFollowers,
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    _buildStatItem(
                      '$_followingCount',
                      '关注',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserListPage(
                              listType: UserListType.following,
                              users: _mockFollowing,
                            ),
                          ),
                        );
                      },
                    ),
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
                IgnorePointer(
                  ignoring: _isCollapsed,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _isCollapsed ? 0.0 : 1.0,
                    child: Container(
                      key: _scrollTabKey,
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
                                ((MediaQuery.of(context).size.width - 40 - 8) /
                                    3),
                            top: 0,
                            bottom: 0,
                            width:
                                (MediaQuery.of(context).size.width - 40 - 8) /
                                3,
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
          // 固定的折叠头部（跟随滚动状态淡入淡出）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_isCollapsed,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isCollapsed ? 1.0 : 0.0,
                child: _buildCollapsedHeader(topPadding, canPop),
              ),
            ),
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
            key: _pinnedTabKey,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // View toggle button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isMapView = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: !_isMapView ? Colors.black : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_list,
                            size: 16,
                            color: !_isMapView
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '时间',
                            style: TextStyle(
                              fontSize: 12,
                              color: !_isMapView
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _isMapView = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isMapView ? Colors.black : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.map,
                            size: 16,
                            color: _isMapView ? Colors.white : Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '地图',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isMapView
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content based on view mode
            if (_isMapView)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PostsMapView(
                  posts: _mockPosts,
                  onPostTap: (post) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailPage(postId: post.id),
                      ),
                    );
                  },
                ),
              )
            else
              PostsTimeline(
                posts: _mockPosts,
                onPostTap: (post) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailPage(postId: post.id),
                    ),
                  );
                },
              ),
            if (_isMapView) const SizedBox(height: 0), // 调整这里的高度值
          ],
        );
      case 1: // 喜欢
        return _buildPostsWithToggle(_likedPosts);
      case 2: // 收藏
        return _buildPostsWithToggle(_favoritedPosts);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 生成喜欢的帖子
  List<PostModel> _generateLikedPosts() {
    final now = DateTime.now();
    return [
      PostModel(
        id: 'liked_post_1',
        user: const UserModel(
          id: 'user_a',
          username: '摄影师小王',
          avatarUrl: 'https://i.pravatar.cc/150?img=10',
          bio: '摄影爱好者',
        ),
        location: const LocationModel(latitude: 31.24, longitude: 121.48),
        content: '城市夜景 🌃',
        imageUrls: const ['https://picsum.photos/200/200?random=201'],
        createdAt: now.subtract(const Duration(hours: 5)),
        isLiked: true,
      ),
      PostModel(
        id: 'liked_post_2',
        user: const UserModel(
          id: 'user_b',
          username: '美食家小李',
          avatarUrl: 'https://i.pravatar.cc/150?img=11',
          bio: '美食博主',
        ),
        location: const LocationModel(latitude: 31.22, longitude: 121.46),
        content: '今天的下午茶 ☕🍰',
        imageUrls: const ['https://picsum.photos/200/200?random=202'],
        createdAt: now.subtract(const Duration(days: 1)),
        isLiked: true,
      ),
    ];
  }

  /// 生成收藏的帖子
  List<PostModel> _generateFavoritedPosts() {
    final now = DateTime.now();
    return [
      PostModel(
        id: 'fav_post_1',
        user: const UserModel(
          id: 'user_d',
          username: '健身教练小张',
          avatarUrl: 'https://i.pravatar.cc/150?img=20',
          bio: '健身达人',
        ),
        location: const LocationModel(latitude: 31.21, longitude: 121.44),
        content: '今日训练打卡 💪',
        imageUrls: const ['https://picsum.photos/200/200?random=301'],
        createdAt: now.subtract(const Duration(hours: 8)),
        isFavorited: true,
      ),
      PostModel(
        id: 'fav_post_2',
        user: const UserModel(
          id: 'user_e',
          username: '程序员老陈',
          avatarUrl: 'https://i.pravatar.cc/150?img=21',
          bio: '代码人生',
        ),
        location: const LocationModel(latitude: 31.26, longitude: 121.52),
        content: '深夜码代码的日常 💻',
        imageUrls: const ['https://picsum.photos/200/200?random=302'],
        createdAt: now.subtract(const Duration(days: 3)),
        isFavorited: true,
      ),
    ];
  }

  /// 构建带有列表/地图切换的帖子视图
  Widget _buildPostsWithToggle(List<PostModel> posts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isMapView = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: !_isMapView ? Colors.black : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.view_list,
                        size: 16,
                        color: !_isMapView ? Colors.white : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '列表',
                        style: TextStyle(
                          fontSize: 12,
                          color: !_isMapView ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _isMapView = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _isMapView ? Colors.black : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map,
                        size: 16,
                        color: _isMapView ? Colors.white : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '地图',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isMapView ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isMapView)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PostsMapView(
              posts: posts,
              onPostTap: (post) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailPage(postId: post.id),
                  ),
                );
              },
            ),
          )
        else
          PostsGridView(
            posts: posts,
            onPostTap: (post) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailPage(postId: post.id)),
              );
            },
          ),
        if (_isMapView) const SizedBox(height: 25),
      ],
    );
  }
}
