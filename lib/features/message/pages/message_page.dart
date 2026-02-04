import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'chat_page.dart';

// Message Model
class MessageItem {
  final int id;
  final String userName;
  final String avatarUrl;
  final int unreadCount;
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
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  late List<MessageItem> _messages;

  @override
  void initState() {
    super.initState();
    // Initialize mock data
    _messages = List.generate(10, (index) {
      return MessageItem(
        id: index,
        userName: 'User Name $index',
        avatarUrl: 'https://i.pravatar.cc/150?img=$index',
        unreadCount: (index * 7 + 3) % 50,
      );
    });
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
    setState(() {
      _messages.remove(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Full screen message list with gradient mask
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
              padding: EdgeInsets.only(
                top: topPadding + 80,
                bottom: 120,
                left: 16,
                right: 16,
              ),
              itemCount: _messages.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _messages[index];

                return Slidable(
                  key: ValueKey(item.id),
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
                          final slidable = Slidable.of(context);
                          if (slidable != null &&
                              slidable.actionPaneType.value !=
                                  ActionPaneType.none) {
                            slidable.close();
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                userName: item.userName,
                                avatarUrl: item.avatarUrl,
                                unreadCount: item.unreadCount,
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
          // Fixed Title Button
          Positioned(
            top: topPadding + 12,
            left: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
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
                  child: const Text(
                    '消息',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
}
