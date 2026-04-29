import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../../presentation/providers/post_provider.dart';
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
  PostProvider? _postProvider;
  final Set<String> _removedPostIds = <String>{};
  int _lastHandledEngagementVersion = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePinnedTabY();
    });
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final postProvider = context.read<PostProvider>();
    if (_postProvider == postProvider) return;
    _postProvider?.removeListener(_syncPostProviderState);
    _postProvider = postProvider;
    _postProvider!.addListener(_syncPostProviderState);
    _syncPostProviderState();
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

      // 三个 fetch 各自独立。早先用 Future.wait 任何一条挂掉就会让其它两条
      // 的成功结果也被丢弃 → 整页 0 post。改成并行触发 + 各自 catch，
      // 让每条 tab 独立 succeed/fail。失败时打日志（之前是静默的）。
      final myPostsFut = _remote
          .fetchPostsByUser(user.id)
          .then(
            (v) => v,
            onError: (e, st) {
              debugPrint('[MyProfile] fetchPostsByUser FAILED: $e\n$st');
              return <PostModel>[];
            },
          );
      final likedFut = _remote
          .fetchLikedPosts(user.id)
          .then(
            (v) => v,
            onError: (e, st) {
              debugPrint('[MyProfile] fetchLikedPosts FAILED: $e\n$st');
              return <PostModel>[];
            },
          );
      final favoritedFut = _remote
          .fetchFavoritedPosts(user.id)
          .then(
            (v) => v,
            onError: (e, st) {
              debugPrint('[MyProfile] fetchFavoritedPosts FAILED: $e\n$st');
              return <PostModel>[];
            },
          );

      final myPosts = await myPostsFut;
      final liked = await likedFut;
      final favorited = await favoritedFut;

      if (!mounted) return;
      debugPrint(
        '[MyProfile] loaded user=${user.id} '
        'myPosts=${myPosts.length} liked=${liked.length} favorited=${favorited.length}',
      );
      setState(() {
        _myPosts = _filterRemovedPosts(myPosts);
        _likedPosts = _filterRemovedPosts(liked);
        _favoritedPosts = _filterRemovedPosts(favorited);
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('[MyProfile] _loadProfile FAILED: $e\n$st');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyUserData(UserModel user) {
    setState(() {
      _userName = user.username;
      _avatarUrl = user.avatarUrl;
      _localAvatarFile = null;
      _bio = user.bio;
      _gender = user.gender;
      _birthday = user.birthday;
      _followersCount = user.followers;
      _followingCount = user.following;
    });
  }

  @override
  void dispose() {
    _postProvider?.removeListener(_syncPostProviderState);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _syncPostProviderState() {
    final postId = _postProvider?.lastRemovedPostId;
    if (!mounted) return;
    if (postId != null) {
      _removePostFromLocalLists(postId);
    }

    final engagement = _postProvider?.lastEngagementChange;
    if (engagement == null ||
        engagement.version == _lastHandledEngagementVersion) {
      return;
    }
    _lastHandledEngagementVersion = engagement.version;
    _applyEngagementChange(engagement);
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
        SnackBar(
          content: Text('加载失败：${e.toString().replaceFirst("Exception: ", "")}'),
        ),
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

  void _handleTabSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) return;

    final nextIndex = velocity < 0
        ? (_selectedTabIndex < 2 ? _selectedTabIndex + 1 : 2)
        : (_selectedTabIndex > 0 ? _selectedTabIndex - 1 : 0);
    if (nextIndex == _selectedTabIndex) return;
    setState(() => _selectedTabIndex = nextIndex);
  }

  Future<void> _openPostDetail(PostModel post) async {
    final deletedPostId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => DetailPage(postId: post.id)),
    );
    if (!mounted || deletedPostId == null) return;
    _removePostFromLocalLists(deletedPostId);
  }

  void _removePostFromLocalLists(String postId) {
    _removedPostIds.add(postId);
    final hasPost =
        _myPosts.any((post) => post.id == postId) ||
        _likedPosts.any((post) => post.id == postId) ||
        _favoritedPosts.any((post) => post.id == postId);
    if (!hasPost) return;

    setState(() {
      _myPosts.removeWhere((post) => post.id == postId);
      _likedPosts.removeWhere((post) => post.id == postId);
      _favoritedPosts.removeWhere((post) => post.id == postId);
    });
  }

  List<PostModel> _filterRemovedPosts(List<PostModel> posts) {
    if (_removedPostIds.isEmpty) return posts;
    return posts.where((post) => !_removedPostIds.contains(post.id)).toList();
  }

  void _applyEngagementChange(PostEngagementChange change) {
    if (_removedPostIds.contains(change.post.id)) return;

    setState(() {
      _replacePostIfPresent(_myPosts, change.post);
      _replacePostIfPresent(_likedPosts, change.post);
      _replacePostIfPresent(_favoritedPosts, change.post);

      if (change.isLiked != null) {
        if (change.isLiked! && change.post.isPhotoBubble) {
          _upsertPost(_likedPosts, change.post);
        } else {
          _likedPosts.removeWhere((post) => post.id == change.post.id);
        }
      }

      if (change.isFavorited != null) {
        if (change.isFavorited! && change.post.canFavorite) {
          _upsertPost(_favoritedPosts, change.post);
        } else {
          _favoritedPosts.removeWhere((post) => post.id == change.post.id);
        }
      }
    });
  }

  void _replacePostIfPresent(List<PostModel> posts, PostModel updated) {
    final index = posts.indexWhere((post) => post.id == updated.id);
    if (index != -1) {
      posts[index] = updated;
    }
  }

  void _upsertPost(List<PostModel> posts, PostModel updated) {
    posts.removeWhere((post) => post.id == updated.id);
    posts.insert(0, updated);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isPushMode = Navigator.canPop(context);
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
            physics: const AlwaysScrollableScrollPhysics(),
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
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          )
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
                        final updatedUser = await Navigator.push<UserModel>(
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
                        if (!context.mounted || updatedUser == null) return;
                        _applyUserData(updatedUser);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('资料已保存'),
                            duration: Duration(seconds: 2),
                          ),
                        );
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
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: _handleTabSwipe,
                  child: _buildTabContent(),
                ),
                SizedBox(height: isPushMode ? bottomPadding + 16 : 100),
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
          // 固定的返回按钮 - 左上角（仅当通过 Navigator.push 进来时显示；
          // 从 HomeWrapper 的 IndexedStack 渲染时 canPop=false，不出现）
          if (isPushMode)
            Positioned(
              top: topPadding + 12,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.black,
                    size: 20,
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
                  onPostTap: _openPostDetail,
                ),
              )
            else
              PostsTimeline(posts: _myPosts, onPostTap: _openPostDetail),
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
            child: PostsMapView(posts: posts, onPostTap: _openPostDetail),
          )
        else
          PostsGridView(posts: posts, onPostTap: _openPostDetail),
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
