import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../../presentation/providers/notification_provider.dart';
import 'chat_page.dart';
import 'notifications_page.dart';

// Message Model
class MessageItem {
  final int id;
  final String userName;
  final String avatarUrl;
  int unreadCount;
  bool isPinned;

  MessageItem({
    required this.id,
    required this.userName,
    required this.avatarUrl,
    this.unreadCount = 0,
    this.isPinned = false,
  });
}

class MessagePage extends StatefulWidget {
  final ValueChanged<int>? onUnreadCountChanged;

  const MessagePage({super.key, this.onUnreadCountChanged});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage>
    with TickerProviderStateMixin {
  late List<MessageItem> _messages;
  final Map<int, SlidableController> _controllersById = {};
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  double _savedScrollOffset = 0.0;

  List<MessageItem> get _filteredMessages {
    if (_searchQuery.isEmpty) return _messages;
    final query = _searchQuery.toLowerCase();
    return _messages
        .where((m) => m.userName.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    // TODO: 从 API 加载消息列表
    _messages = [];
    _reportUnreadCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().refreshUnreadCount();
    });
  }

  void _reportUnreadCount() {
    final total = _messages.fold<int>(0, (sum, m) => sum + m.unreadCount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onUnreadCountChanged?.call(total);
    });
  }

  @override
  void dispose() {
    for (var controller in _controllersById.values) {
      controller.dispose();
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _togglePin(MessageItem item) {
    setState(() {
      item.isPinned = !item.isPinned;
      // Sort: Pinned items first, then by ID (original order)
      _messages.sort((a, b) {
        if (a.isPinned == b.isPinned) {
          return a.id.compareTo(b.id);
        }
        return b.isPinned ? 1 : -1;
      });
    });
  }

  void _deleteMessage(MessageItem item) {
    final index = _messages.indexWhere((m) => m.id == item.id);
    if (index == -1) return;
    setState(() {
      _messages.removeAt(index);
      // Remove controller corresponding to deleted item
      final controller = _controllersById.remove(item.id);
      controller?.dispose();
    });
    _reportUnreadCount();
  }

  // Handle tap on background or other items
  // Returns true if an action pane was closed, false otherwise
  bool _closeOpenSlidables() {
    bool closed = false;
    for (var controller in _controllersById.values) {
      // Check if pane is open (ActionPaneType.end in our case)
      if (controller.actionPaneType.value != ActionPaneType.none) {
        controller.close();
        closed = true;
      }
    }
    return closed;
  }

  SlidableController _controllerFor(MessageItem item) {
    return _controllersById.putIfAbsent(
      item.id,
      () => SlidableController(this),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
    if (!mounted) return;
    unawaited(context.read<NotificationProvider>().refreshUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final notificationUnread = context
        .watch<NotificationProvider>()
        .unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: GestureDetector(
        onTap: () {
          // Close any open swipe actions when tapping background
          _closeOpenSlidables();
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Full screen message list with gradient mask
            if (_filteredMessages.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无消息',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  ],
                ),
              )
            else
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, (topPadding + 70) / bounds.height, 0.85, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: topPadding + 80,
                    bottom: 120,
                    left: 16,
                    right: 16,
                  ),
                  itemCount: _filteredMessages.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _filteredMessages[index];

                    return Slidable(
                      key: ValueKey(item.id),
                      controller: _controllerFor(item),
                      // Disable automatic closing group tag to handle manually
                      groupTag: 'message_list',
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.35,
                        children: [
                          // Pin Button
                          CustomSlidableAction(
                            onPressed: (context) {
                              _togglePin(item);
                            },
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildGlassIcon(Icons.push_pin, Colors.grey),
                          ),
                          // Delete Button
                          CustomSlidableAction(
                            onPressed: (context) {
                              _deleteMessage(item);
                            },
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildGlassIcon(Icons.delete, Colors.red),
                          ),
                        ],
                      ),
                      child: Builder(
                        builder: (context) {
                          return GestureDetector(
                            onTap: () {
                              // If any slide is open, close it and DO NOT navigate
                              if (_closeOpenSlidables()) {
                                return;
                              }

                              // 清零该聊天的未读数
                              setState(() {
                                item.unreadCount = 0;
                              });
                              _reportUnreadCount();

                              // 传入清零后的全局未读总数
                              final totalUnread = _messages.fold<int>(
                                0,
                                (sum, m) => sum + m.unreadCount,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    userName: item.userName,
                                    avatarUrl: item.avatarUrl,
                                    unreadCount: totalUnread,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                // Grey background for pinned items
                                color: item.isPinned
                                    ? Colors.grey[200]
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: Colors.black12,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 10),
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundImage: NetworkImage(
                                          item.avatarUrl,
                                        ),
                                      ),
                                      if (index < 3)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.userName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'This is a preview message content...',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 20),
                                    child: Text(
                                      '12:00',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            // Fixed Title Button / Search Box
            Positioned(
              top: topPadding + 12,
              left: 16,
              right: 16,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  AnimatedOpacity(
                    opacity: _isSearching ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_isSearching,
                      child: _buildSearchField(),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _isSearching ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: _isSearching,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildTitleButton(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: topPadding + 12,
              right: 16,
              child: AnimatedOpacity(
                opacity: _isSearching ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: _isSearching,
                  child: _buildNotificationButton(notificationUnread),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassIcon(IconData icon, Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(50), width: 1),
      ),
      child: Center(
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.transparent,
              child: Icon(icon, color: color, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton(int unreadCount) {
    return GestureDetector(
      onTap: _openNotifications,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(153),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none,
                  color: Colors.black87,
                  size: 24,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
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

  Widget _buildTitleButton() {
    return GestureDetector(
      onTap: () {
        _savedScrollOffset = _scrollController.offset;
        setState(() => _isSearching = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _searchFocusNode.requestFocus();
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(153),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '消息',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.search, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  decoration: const InputDecoration(
                    hintText: '搜索聊天',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _isSearching = false;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    FocusManager.instance.primaryFocus?.unfocus();
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_savedScrollOffset);
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
