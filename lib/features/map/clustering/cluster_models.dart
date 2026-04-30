import '../../../core/map/map_types.dart';
import '../../../data/models/post_model.dart';

/// 聚合配置（参考 Mapbox `clusterRadius`/`clusterMaxZoom` 默认行为）
///
/// 所有参数都是地图库无关的——不含 mapbox / amap 概念。
class ClusterConfig {
  /// 聚合像素半径：屏幕距离 < 此值的点合并为一个 cluster
  ///
  /// Jogy 未展开气泡 `collapsedSize=60px`。默认半径略大于气泡本体，
  /// 近距离下主要聚合同楼/视觉上明显重叠的内容，避免街区级点位被过早吞掉。
  final double clusterRadiusPx;

  /// 缩放阈值：zoom > 此值不再聚合，全部显示为单点
  ///
  /// Jogy 默认 zoom 17，仍需要对热点区域聚合，直到用户明确点开。
  final int clusterMaxZoom;

  /// 形成 cluster 所需最少点数。Mapbox 默认 2。
  final int clusterMinPoints;

  const ClusterConfig({
    this.clusterRadiusPx = 72,
    this.clusterMaxZoom = 18,
    this.clusterMinPoints = 2,
  });
}

/// 聚合查询结果中的一个元素——要么是单个点，要么是一个聚合节点
sealed class ClusterOrPoint {
  /// 中心点地理坐标
  MapLatLng get center;

  /// 稳定的字符串 id，用于在渲染层缓存屏幕坐标等
  String get id;
}

/// 单点：未被聚合的 post
class SinglePoint extends ClusterOrPoint {
  final PostModel post;

  SinglePoint(this.post);

  @override
  MapLatLng get center =>
      MapLatLng(post.location.latitude, post.location.longitude);

  @override
  String get id => 'p_${post.id}';
}

/// 聚合节点：多个 post 合并后的圆圈
class ClusterNode extends ClusterOrPoint {
  /// supercluster 返回的 cluster id，用于 `getClusterExpansionZoom` 回查
  final int clusterId;

  /// 聚合中心（加权平均位置）
  final MapLatLng _center;

  /// 聚合内 post 数量
  final int count;

  ClusterNode({
    required this.clusterId,
    required MapLatLng center,
    required this.count,
  }) : _center = center;

  @override
  MapLatLng get center => _center;

  @override
  String get id => 'c_$clusterId';
}
