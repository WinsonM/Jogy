import 'package:flutter/material.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '消息',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        centerTitle: false,
        actions: [
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: const Color(0xFF4C4C4C),
                textStyle: const TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Icon(Icons.add, color: Colors.black, size: 20),
              ),
              offset: const Offset(0, 50),
              itemBuilder: (context) => [
                _buildPopupItem(Icons.chat_bubble_outline, '发起群聊'),
                _buildPopupItem(Icons.person_add_alt, '添加朋友'),
                _buildPopupItem(Icons.qr_code_scanner, '扫一扫'),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(
          top: 10,
          bottom: 100,
          left: 16,
          right: 16,
        ),
        itemCount: 10,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.black12, width: 0.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(
                        'https://i.pravatar.cc/150?img=$index',
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
                            border: Border.all(color: Colors.white, width: 2),
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
                        'User Name $index',
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Text(
                    '12:00',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(IconData icon, String text) {
    return PopupMenuItem(
      value: text,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
