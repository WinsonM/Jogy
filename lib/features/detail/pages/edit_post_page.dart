import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/datasources/remote_data_source.dart';
import '../../../data/models/post_model.dart';

/// 编辑 post 的全屏页面：标题 / 内容 / 图片。
///
/// 与之前的 `showEditPostSheet` (bottom sheet) 相比：
/// - 全屏 → 长内容 / 多图编辑空间充裕
/// - 增加图片增删（之前只能改文字）
/// - 顶部 AppBar：左返回（带未保存变更确认）/ 右保存（无变更时 disabled）
///
/// 不可编辑项：location / post_type / expire_at —— 后端 PATCH 也不接受这些字段
/// 的修改语义。需要改这些 = 重新发布。
///
/// 用法：
/// ```dart
/// final updated = await Navigator.push<PostModel>(
///   context,
///   MaterialPageRoute(builder: (_) => EditPostPage(post: post)),
/// );
/// if (updated != null) provider.updatePost(updated);
/// ```
class EditPostPage extends StatefulWidget {
  final PostModel post;
  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  static const _accent = Color(0xFF3FAAF0);
  static const _maxImages = 9;

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  /// 图片混合列表：保留的远端 url + 新加的本地 File。顺序 = 最终 media_urls 顺序。
  late List<_EditImage> _images;

  // 原始快照，用来判断 _hasChanges
  late final String _origTitle;
  late final String _origContent;
  late final List<String> _origImageUrls;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title ?? '');
    _contentController = TextEditingController(text: widget.post.content);
    _images = widget.post.imageUrls
        .map((url) => _EditImage.remote(url))
        .toList();
    _origTitle = widget.post.title ?? '';
    _origContent = widget.post.content;
    _origImageUrls = List<String>.from(widget.post.imageUrls);

    _titleController.addListener(_onAnyChange);
    _contentController.addListener(_onAnyChange);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onAnyChange() {
    // 只为重算 AppBar "保存" 按钮的 enabled 状态触发 rebuild
    if (mounted) setState(() {});
  }

  bool get _hasChanges {
    if (_titleController.text.trim() != _origTitle.trim()) return true;
    if (_contentController.text.trim() != _origContent.trim()) return true;
    if (_images.length != _origImageUrls.length) return true;
    for (var i = 0; i < _images.length; i++) {
      final img = _images[i];
      if (img.isLocal) return true; // 新增本地图必然是改动
      if (img.url != _origImageUrls[i]) return true; // 顺序变了或换了
    }
    return false;
  }

  // ── Image picker ────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      _toast('最多 $_maxImages 张图片');
      return;
    }
    try {
      final picked = await ImagePicker().pickMultiImage(limit: remaining);
      if (picked.isEmpty || !mounted) return;
      setState(() {
        for (final f in picked.take(remaining)) {
          _images.add(_EditImage.local(File(f.path)));
        }
      });
    } catch (e) {
      _toast('选图失败：$e');
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  // ── Save / discard ──────────────────────────────────────────────

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _toast('内容不能为空');
      return;
    }

    setState(() => _saving = true);
    try {
      final remote = RemoteDataSource();

      // 1. 上传所有本地图，按顺序攒成最终 url 列表
      final mediaUrls = <String>[];
      for (final img in _images) {
        if (img.isLocal) {
          final url = await remote.uploadImage(img.localFile!.path);
          mediaUrls.add(url);
        } else {
          mediaUrls.add(img.url!);
        }
      }

      // 2. PATCH —— 后端 media_urls 是全量替换语义
      final updated = await remote.updatePost(
        widget.post.id,
        title: title.isEmpty ? '' : title, // '' 让后端清掉 title
        contentText: content,
        mediaUrls: mediaUrls,
      );

      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('保存失败：${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('退出后未保存的修改将丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canSave = _hasChanges && !_saving;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (!context.mounted || !shouldPop) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              final shouldPop = await _confirmDiscard();
              if (!context.mounted || !shouldPop) return;
              Navigator.pop(context);
            },
          ),
          title: const Text(
            '编辑',
            style: TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextButton(
                onPressed: canSave ? _save : null,
                style: TextButton.styleFrom(
                  foregroundColor: _accent,
                  disabledForegroundColor: Colors.grey[400],
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent,
                        ),
                      )
                    : const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                _SectionLabel('标题'),
                TextField(
                  controller: _titleController,
                  enabled: !_saving,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: '加个标题（可选）',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _accent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 12),

                // 内容
                _SectionLabel('内容'),
                TextField(
                  controller: _contentController,
                  enabled: !_saving,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: 5000,
                  decoration: InputDecoration(
                    hintText: '说点什么…',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _accent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 12),

                // 图片
                _SectionLabel('图片  (${_images.length}/$_maxImages)'),
                _ImageGrid(
                  images: _images,
                  maxImages: _maxImages,
                  enabled: !_saving,
                  onRemove: _removeImage,
                  onAdd: _pickImages,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 图片混合条目：要么是已有的远端 url，要么是新选的本地 File。
class _EditImage {
  final String? url;
  final File? localFile;

  const _EditImage._(this.url, this.localFile);
  factory _EditImage.remote(String url) => _EditImage._(url, null);
  factory _EditImage.local(File f) => _EditImage._(null, f);

  bool get isLocal => localFile != null;
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<_EditImage> images;
  final int maxImages;
  final bool enabled;
  final void Function(int index) onRemove;
  final VoidCallback onAdd;

  const _ImageGrid({
    required this.images,
    required this.maxImages,
    required this.enabled,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = images.length < maxImages;
    final tileCount = images.length + (canAdd ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tileCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        if (i == images.length && canAdd) {
          return _AddTile(enabled: enabled, onTap: onAdd);
        }
        return _ImageTile(
          image: images[i],
          enabled: enabled,
          onRemove: () => onRemove(i),
        );
      },
    );
  }
}

class _ImageTile extends StatelessWidget {
  final _EditImage image;
  final bool enabled;
  final VoidCallback onRemove;

  const _ImageTile({
    required this.image,
    required this.enabled,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.grey[200],
      child: Icon(Icons.broken_image_outlined, color: Colors.grey[400]),
    );
    final imageWidget = image.isLocal
        ? Image.file(image.localFile!, fit: BoxFit.cover)
        : Image.network(
            image.url!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          // 删除按钮（右上角）
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: enabled ? onRemove : null,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _AddTile({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 30,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}
