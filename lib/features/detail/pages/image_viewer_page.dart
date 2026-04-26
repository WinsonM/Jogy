import 'package:flutter/material.dart';

/// 全屏多图查看器：水平 PageView 切图 + InteractiveViewer 双指缩放/拖动。
///
/// 视觉模仿 iOS Photos / 微信朋友圈：黑底、半透明顶栏、计数指示。
///
/// 交互：
/// - 单击图片或左上角 X：返回
/// - 横滑：切换到上/下一张
/// - 双指捏合：缩放（1×–4×）；缩放后单指拖动平移
/// - 缩放期间，PageView 横滑被 [InteractiveViewer] 接管 → 只有 reset 到 1×
///   后才能继续切换图片（标准做法，与 Photos 一致）
class ImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imageUrls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: '关闭',
        ),
        title: total > 1
            ? Text(
                '${_currentIndex + 1} / $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              )
            : null,
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: total,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          // 每页一个独立 InteractiveViewer，避免缩放状态在切图后残留。
          return GestureDetector(
            // 单击退出：放在 InteractiveViewer 之外；缩放手势在内层先消化，
            // 单点不会被吞，仍能正常 onTap。
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  widget.imageUrls[i],
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
