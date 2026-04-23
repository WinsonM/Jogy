import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../auth/pages/login_page.dart';
import '../widgets/posts_timeline.dart';
import 'edit_profile_page.dart';
import 'browsing_history_page.dart';
import '../widgets/user_list_page.dart';
import '../../detail/pages/detail_page.dart';
import '../widgets/posts_map_view.dart';
import '../widgets/posts_grid_view.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final RemoteDataSource _remote = RemoteDataSource();

  int _selectedTabIndex = 0; // 0: 帖子, 1: 喜欢, 2: 收藏
  bool _isMapView = false;

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();
  bool _isTabPinned = false;
  final GlobalKey _scrollTabKey = GlobalKey();
  final GlobalKey _pinnedTabKey = GlobalKey();
  double _pinnedTabY = 0.0;

  // User data — loaded from API
  String _userName = '';
  String _avatarUrl = '';
  File? _localAvatarFile;
  String _bio = '';
  String _gender = '保密';
  DateTime? _birthday;
  int _followersCount = 0;
  int _followingCount = 0;

  // Posts — loaded from API
  List<PostModel> _myPosts = [];
  List<PostModel> _likedPosts = [];
  List<PostModel> _favoritedPosts = [];

  bool _isLoading = true;
  String? _userId; // current user id for follow list queries

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePinnedTabY();
    });
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Sync auth token to our local RemoteDataSource instance
    final auth = context.read<AuthService>();
    if (auth.currentUser != null) {
      _applyUserData(auth.currentUser!);
    }

    try {
      final user = await _remote.getCurrentUser();
      if (!mounted) return;
      _applyUserData(user);
      _userId = user.id;

      // Load posts in parallel
      final results = await Future.wait([
        _remote.fetchPostsByUser(user.id),
        _remote.fetchLikedPosts(user.id),
        _remote.fetchFavoritedPosts(user.id),
      ]);

      if (!mounted) return;
      setState(() {
        _myPosts = results[0];
        _likedPosts = results[1];
        _favoritedPosts = results[2];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyUserData(UserModel user) {
    setState(() {
      _userName = user.username;
      _avatarUrl = user.avatarUrl;
      _bio = user.bio;
      _gender = user.gender;
      _followersCount = user.followers;
      _followingCount = user.following;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldPin = _shouldPinTabBar();
    if (shouldPin != _isTabPinned) {
      setState(() {
        _isTabPinned = shouldPin;
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
      return false;
    }
    final scrollTabY = scrollBox.localToGlobal(Offset.zero).dy;
    return scrollTabY <= _pinnedTabY;
  }

  /// Open followers or following list fetched from API
  void _openFollowList(UserListType listType) async {
    if (_userId == null) return;
    try {
      final data = listType == UserListType.followers
          ? await _remote.fetchFollowers(_userId!)
          : await _remote.fetchFollowing(_userId!);
      final users = (data['users'] as List)
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserListPage(listType: listType, users: users),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败：${e.toString().replaceFirst("Exception: ", "")}')),
      );
    }
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
    if (_pinnedTabY == 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updatePinnedTabY();
      });
    }

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
                if (_isLoading)
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _localAvatarFile != null
                        ? FileImage(_localAvatarFile!) as ImageProvider
                        : (_avatarUrl.isNotEmpty
                            ? NetworkImage(_avatarUrl)
                            : null),
                    child: _avatarUrl.isEmpty && _localAvatarFile == null
                        ? const Icon(Icons.person, size: 40, color: Colors.white)
                        : null,
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
                            await Navigator.push<Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfilePage(
                                  userName: _userName,
                                  avatarUrl: _avatarUrl,
                                  bio: _bio,
                                  gender: _gender,
                                  birthday: _birthday,
                                ),
                              ),
                            );
                        // 更新用户资料
                        if (result != null && mounted) {
                          setState(() {
                            _userName =
                                result['userName'] as String? ?? _userName;
                            _avatarUrl =
                                result['avatarUrl'] as String? ?? _avatarUrl;
                            final localPath =
                                result['localAvatarPath'] as String?;
                            if (localPath != null) {
                              _localAvatarFile = File(localPath);
                            }
                            _bio = result['bio'] as String? ?? _bio;
                            _gender = result['gender'] as String? ?? _gender;
                            _birthday =
                                result['birthday'] as DateTime? ?? _birthday;
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
                    _buildStatItem('${_myPosts.length}', '发布'),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    _buildStatItem(
                      '$_followersCount',
                      '粉丝',
                      onTap: () => _openFollowList(UserListType.followers),
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
                      onTap: () => _openFollowList(UserListType.following),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Tab栏
                IgnorePointer(
                  ignoring: _isTabPinned,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _isTabPinned ? 0.0 : 1.0,
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
                                (MediaQuery.of(context).size.width - 40 - 8) /
                                3,
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
          // 固定 Tab 后的顶部蒙版，遮住滚动内容（覆盖设置按钮 + Tab 栏区域）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 120,
            child: IgnorePointer(
              ignoring: !_isTabPinned,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isTabPinned ? 1.0 : 0.0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(color: Colors.white.withAlpha(180)),
                  ),
                ),
              ),
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
          // 固定 Tab 栏（到达顶部后停住）
          Positioned(
            top: topPadding + 64,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_isTabPinned,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isTabPinned ? 1.0 : 0.0,
                child: Container(
                  key: _pinnedTabKey,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Stack(
                    children: [
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
          ),
        ],
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
                  posts: _myPosts,
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
                posts: _myPosts,
                onPostTap: (post) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailPage(postId: post.id),
                    ),
                  );
                },
              ),
            if (_isMapView) const SizedBox(height: 25), // 调整这里的高度值
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

  /// 构建带有列表/地图切换的帖子视图
  Widget _buildPostsWithToggle(List<PostModel> posts) {
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
        // Content based on view mode
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BrowsingHistoryPage(),
                      ),
                    );
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
                        onTap: () async {
                          // Clear tokens and navigate to login
                          await context.read<AuthService>().logout();
                          if (!context.mounted) return;
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
