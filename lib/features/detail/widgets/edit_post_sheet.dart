import 'package:flutter/material.dart';

import '../../../data/datasources/remote_data_source.dart';
import '../../../data/models/post_model.dart';

/// 编辑 post 内容的底部弹层。
///
/// 当前只支持改 `content_text`（最常见场景：发完发现错别字想改一下）。
/// 标题 / 留存时长 / 坐标 / 图片 后续按需扩展；坐标和图片改变更接近"重新
/// 发布"语义，建议另开通道。
///
/// 用法：
/// ```dart
/// final updated = await showEditPostSheet(context, post: post);
/// if (updated != null) postProvider.updatePost(updated);
/// ```
/// 返回 null = 用户取消，否则返回服务端最新的 PostModel。
Future<PostModel?> showEditPostSheet(
  BuildContext context, {
  required PostModel post,
}) {
  return showModalBottomSheet<PostModel>(
    context: context,
    isScrollControlled: true, // 让 sheet 跟键盘一起上推
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _EditPostSheet(post: post),
    ),
  );
}

class _EditPostSheet extends StatefulWidget {
  final PostModel post;
  const _EditPostSheet({required this.post});

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.post.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasChanges => _controller.text.trim() != widget.post.content;

  Future<void> _save() async {
    final newContent = _controller.text.trim();
    if (newContent.isEmpty) {
      setState(() => _error = '内容不能为空');
      return;
    }
    if (newContent == widget.post.content) {
      Navigator.pop(context); // 没改动，直接关
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await RemoteDataSource()
          .updatePost(widget.post.id, contentText: newContent);
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const Spacer(),
                const Text(
                  '编辑',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: (_saving || !_hasChanges) ? null : _save,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF3FAAF0),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '保存',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Content textarea
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 5,
              maxLines: 12,
              maxLength: 5000,
              decoration: const InputDecoration(
                hintText: '说点什么…',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
