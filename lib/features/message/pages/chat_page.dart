import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../profile/pages/profile_page.dart';

class ChatPage extends StatefulWidget {
  final String userName;
  final String avatarUrl;
  final int unreadCount; // 未读消息数，从数据库获取

  const ChatPage({
    super.key,
    required this.userName,
    required this.avatarUrl,
    this.unreadCount = 0, // 默认为 0
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Mock messages
  final List<Map<String, dynamic>> _messages = [
    {'isMe': true, 'type': 'text', 'content': 'iknow'},
    {'isMe': true, 'type': 'text', 'content': 'but 好听'},
    {'isMe': false, 'type': 'text', 'content': '确实好听'},
    {'isMe': false, 'type': 'text', 'content': '我舍友曼城球迷 天天放'},
    {'isMe': true, 'type': 'text', 'content': '那他真的'},
    {'isMe': true, 'type': 'text', 'content': '可以突了'},
    {'isMe': true, 'type': 'text', 'content': '我就自己听'},
    {
      'isMe': true,
      'type': 'image_link',
      'content':
          'https://i.scdn.co/image/ab67616d0000b273b640e6c66601463ec162232f', // Example placeholder
      'title': '牡丹江',
      'subtitle': 'open.spotify.com',
    },
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  // Selected files/images for preview (optional, for future use)
  List<File> _selectedImages = [];
  List<File> _selectedFiles = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe Left (Drag Right-to-Left) to view profile
          // standard "Push" navigation gesture
          if (details.primaryVelocity! < -1000) {
            _navigateToProfile();
          }
        },
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                itemCount: _messages.length + 1, // +1 for timestamp
                itemBuilder: (context, index) {
                  if (index == 4) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          '11月10日 周一 下午7:16',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }
                  // Adjust index because of inserted timestamp
                  final msgIndex = index > 4 ? index - 1 : index;
                  final msg = _messages[msgIndex];

                  return _buildMessageBubble(msg);
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(
        0xFFF9F9F9,
      ), // Light greyish background like iOS
      elevation: 0,
      toolbarHeight: 60,
      leadingWidth: 80,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black, // 与 profile_page 保持一致
                size: 20,
              ),
              const SizedBox(width: 4),
              // 未读消息数角标 - 只在有未读消息时显示
              if (widget.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      centerTitle: true,
      title: GestureDetector(
        onTap: _navigateToProfile,
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF9FA6C5),
              backgroundImage: NetworkImage(widget.avatarUrl),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
      actions: const [
        // No video button as requested
        SizedBox(width: 16),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: Colors.grey.withOpacity(0.2), height: 0.5),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isMe = msg['isMe'];
    String type = msg['type'];

    if (type == 'image_link') {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 240,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF380808), // Dark reddish brown from image
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                // Placeholder image
                child: Image.network(
                  'https://upload.wikimedia.org/wikipedia/en/3/3b/Dark_Side_of_the_Moon.png',
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) =>
                      Container(height: 240, color: Colors.grey),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      msg['subtitle'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Local image message
    if (type == 'image') {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          width: 200,
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(msg['content']),
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 48),
              ),
            ),
          ),
        ),
      );
    }

    // File message
    if (type == 'file') {
      final fileName = msg['fileName'] as String? ?? 'Unknown';
      final fileSize = msg['fileSize'] as int? ?? 0;
      final fileSizeStr = fileSize > 1024 * 1024
          ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
          : '${(fileSize / 1024).toStringAsFixed(1)} KB';

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF3FAAF0) : const Color(0xFFE9E9EB),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white24 : Colors.grey[400],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insert_drive_file,
                  color: isMe ? Colors.white : Colors.black54,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      fileSizeStr,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF3FAAF0) : const Color(0xFFE9E9EB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          msg['content'],
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  /// Helper to scroll to bottom of message list
  void _scrollToBottom({bool jump = false}) {
    // Use double post-frame callback to ensure layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final target = _scrollController.position.maxScrollExtent;
        if (jump) {
          _scrollController.jumpTo(target);
        } else {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'isMe': true, 'type': 'text', 'content': text.trim()});
      _controller.clear();
    });

    _scrollToBottom();
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(
          userName: widget.userName,
          avatarUrl: widget.avatarUrl,
          isFollowing: false, // TODO: 从数据库获取关注状态
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Show attachment options popup
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Photo album option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.blue),
                ),
                title: const Text('相册'),
                subtitle: const Text('最多选择9张照片'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImages();
                },
              ),
              const Divider(height: 1),
              // File folder option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder, color: Colors.orange),
                ),
                title: const Text('文件夹'),
                subtitle: const Text('单个文件不超过100MB'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles();
                },
              ),
              const SizedBox(height: 10),
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '取消',
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick images from gallery (max 9)
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        limit: 9,
        imageQuality: 85,
      );

      if (images.isNotEmpty && mounted) {
        setState(() {
          // Add each image as a message
          for (final image in images) {
            _messages.add({
              'isMe': true,
              'type': 'image',
              'content': image.path,
            });
          }
        });

        // Auto scroll to bottom
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择照片失败: $e')));
      }
    }
  }

  /// Pick files from file system (max 100MB each)
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        // Filter files larger than 100MB
        const maxSize = 100 * 1024 * 1024; // 100MB in bytes
        final validFiles = <PlatformFile>[];
        final oversizedFiles = <String>[];

        for (final file in result.files) {
          if (file.size > maxSize) {
            oversizedFiles.add(file.name);
          } else if (file.path != null) {
            validFiles.add(file);
          }
        }

        // Show warning for oversized files
        if (oversizedFiles.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('以下文件超过100MB限制: ${oversizedFiles.join(", ")}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Add valid files as messages
        if (validFiles.isNotEmpty) {
          setState(() {
            for (final file in validFiles) {
              _messages.add({
                'isMe': true,
                'type': 'file',
                'content': file.path,
                'fileName': file.name,
                'fileSize': file.size,
              });
            }
          });

          // Auto scroll to bottom
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
      }
    }
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
        ),
        child: Row(
          children: [
            // Plus button with attachment options
            GestureDetector(
              onTap: _showAttachmentOptions,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.grey, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            // Text input field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(bottom: 10),
                  ),
                ),
              ),
            ),
            // Voice button removed as requested
          ],
        ),
      ),
    );
  }
}
