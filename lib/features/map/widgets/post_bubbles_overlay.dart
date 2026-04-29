import 'package:flutter/material.dart';

import '../../../core/map/map_controller.dart';
import '../../../core/map/map_types.dart';
import '../../../data/models/post_model.dart';
import 'map_broadcast_cloud.dart';
import 'map_bubble.dart';

/// 一层独立、最简的 post 气泡覆盖层。
///
/// 设计目标：从根上绕开 supercluster + `_clusterResults` + `_postScreenPoints`
/// 异步缓存 + `_isViewportReady` 等所有现有渲染机制 —— 它们任意一环出问题都
/// 会让整列 post 在屏幕上消失。这一层的契约非常窄：
///
///   posts × controller × 每帧 sync screen-point → Positioned + MapBubbleWidget
///
/// ## 工作原理
///
/// 1. [cameraTick] 是一个 [Listenable]（一般是 `ValueNotifier<int>`），父级
///    在 `onCameraMove` 里 `tick.value++`，通知 overlay 重建。
/// 2. 每次 build 对 [posts] 顺序遍历，调 [JogyMapController.latLngToScreenPoint]
///    （同步 Mercator + bearing/pitch 近似）拿屏幕坐标。
/// 3. 拿到非空就 [Positioned] 套 [MapBubbleWidget]（视觉与原 `_buildBubbleOverlay`
///    完全一致）；拿不到（如视口尺寸=0、controller 处于初始化中）就 skip 该条，
///    下一个 tick 自动补上 —— 不会让所有 bubble 一起消失。
///
/// ## 已知限制
///
/// - **不做聚合**：每条 post 一个独立 bubble。当前业务量级（用户量级 10²）够用；
///   未来若同一视口经常 >50 条，可在外层包一层 cluster 但保留这一层做渲染。
/// - **同步 Mercator vs 原生 pixelForCoordinate**：在大 pitch 视角下有几像素
///   偏移。如果想更精确可以再叠一层 async 修正（不阻塞首帧显示）。
///
/// ## 调用方契约
///
/// - [expandedIndex]：当前展开的 bubble 在 [posts] 里的下标，对齐原 `_expandedIndex`
///   语义；为空 / 越界都安全（不展开任何）。展开态的 bubble 会被渲染到最上层。
/// - [scaleFactors]：与原 `_scaleFactors` 一致的 index→scale 字典。缺失项默认 1.0。
/// - [onTap]：点击 bubble 时回调，调用方负责展开/导航/移动相机等业务。
class PostBubblesOverlay extends StatefulWidget {
  final JogyMapController controller;
  final Listenable cameraTick;
  final List<PostModel> posts;
  final double mapRotation;
  final int? expandedIndex;
  final Map<int, double> scaleFactors;
  final void Function(PostModel post, int index) onTap;
  final void Function(PostModel post)? onBroadcastLike;
  final void Function(PostModel post)? onBroadcastReply;

  const PostBubblesOverlay({
    super.key,
    required this.controller,
    required this.cameraTick,
    required this.posts,
    required this.mapRotation,
    required this.expandedIndex,
    required this.scaleFactors,
    required this.onTap,
    this.onBroadcastLike,
    this.onBroadcastReply,
  });

  @override
  State<PostBubblesOverlay> createState() => _PostBubblesOverlayState();
}

class _PostBubblesOverlayState extends State<PostBubblesOverlay> {
  String? _lastDebugKey;

  @override
  void initState() {
    super.initState();
    widget.cameraTick.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant PostBubblesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraTick != widget.cameraTick) {
      oldWidget.cameraTick.removeListener(_onTick);
      widget.cameraTick.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.cameraTick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 气泡用 expandedHeight 作为方框边长；广播云朵用独立尺寸，但同样
    // 以底部中心对齐地理坐标。
    const double bubbleBoxSize = MapBubbleWidget.expandedHeight;

    final children = <Widget>[];
    Widget? expandedChild;
    var skipped = 0;
    var onscreen = 0;
    MapScreenPoint? firstPoint;

    for (var i = 0; i < widget.posts.length; i++) {
      final post = widget.posts[i];
      final pt = widget.controller.latLngToScreenPoint(
        MapLatLng(post.location.latitude, post.location.longitude),
      );
      if (pt == null) {
        skipped++;
        continue;
      }
      firstPoint ??= pt;

      final isExpanded = widget.expandedIndex == i && post.isPhotoBubble;
      final scale = widget.scaleFactors[i] ?? 1.0;
      final child = post.isBroadcast
          ? Positioned(
              key: ValueKey('broadcast_${post.id}'),
              left: pt.x - MapBroadcastCloudWidget.width / 2,
              top: pt.y - MapBroadcastCloudWidget.height,
              width: MapBroadcastCloudWidget.width,
              height: MapBroadcastCloudWidget.height,
              child: MapBroadcastCloudWidget(
                post: post,
                onLike: () => widget.onBroadcastLike?.call(post),
                onReply: () => widget.onBroadcastReply?.call(post),
              ),
            )
          : Positioned(
              key: ValueKey('p_${post.id}'),
              left: pt.x - bubbleBoxSize / 2,
              top: pt.y - bubbleBoxSize,
              width: bubbleBoxSize,
              height: bubbleBoxSize,
              child: MapBubbleWidget(
                isExpanded: isExpanded,
                scaleFactor: scale,
                post: post,
                mapRotation: widget.mapRotation,
                onTap: () => widget.onTap(post, i),
              ),
            );

      final viewport = widget.controller.cameraState.viewportSize;
      if (pt.x >= 0 && pt.x <= viewport.x && pt.y >= 0 && pt.y <= viewport.y) {
        onscreen++;
      }

      if (isExpanded) {
        // 缓存到末尾，渲染在最上层（同原 renderItems.sort 行为）
        expandedChild = child;
      } else {
        children.add(child);
      }
    }

    if (expandedChild != null) {
      children.add(expandedChild);
    }

    final viewport = widget.controller.cameraState.viewportSize;
    final debugKey =
        '${widget.posts.length}:${children.length}:$onscreen:$skipped:'
        '${viewport.x.toStringAsFixed(0)}x${viewport.y.toStringAsFixed(0)}';
    if (_lastDebugKey != debugKey) {
      _lastDebugKey = debugKey;
      debugPrint(
        '[PostBubblesOverlay] posts=${widget.posts.length} '
        'projected=${children.length} onscreen=$onscreen skipped=$skipped '
        'viewport=${viewport.x.toStringAsFixed(0)}x'
        '${viewport.y.toStringAsFixed(0)} '
        'firstPt=${firstPoint == null ? "null" : "(${firstPoint.x.toStringAsFixed(1)},${firstPoint.y.toStringAsFixed(1)})"}',
      );
    }

    return SizedBox.expand(
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}
