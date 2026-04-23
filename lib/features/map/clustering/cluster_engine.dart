import 'package:supercluster/supercluster.dart';

import '../../../core/map/map_types.dart';
import '../../../data/models/post_model.dart';
import 'cluster_models.dart';

/// 聚合算法接口
///
/// **地图库无关**：此接口与实现均不导入任何 mapbox / amap 包，
/// 切换地图 SDK 时算法层 0 改动。
abstract class ClusterEngine {
  /// 加载点集（一次性 O(n log n) 索引构建）。
  /// 后续调用同一个 engine 的 [getClusters]/[getClusterExpansionZoom] 均基于此索引。
  void load(List<PostModel> posts);

  /// 查询当前视口内的聚合结果（cluster 与单点混合列表）
  ///
  /// [bounds] 当前可视范围
  /// [zoom] 当前 zoom 级别（会被 engine 内部 floor 到整数）
  List<ClusterOrPoint> getClusters({
    required MapBounds bounds,
    required double zoom,
  });

  /// 给定 cluster，返回展开它需要的目标 zoom
  ///
  /// 用于点击 cluster 时的 "smart zoom"：比 `currentZoom + 2` 更精确，
  /// 恰好让此 cluster 在目标 zoom 下分裂成单点或更小的 cluster。
  double getClusterExpansionZoom(ClusterNode cluster);
}

/// 基于 `supercluster` package（Mapbox JS 同源算法的 Dart port）的实现
///
/// - KD-Tree 索引，1000 个点 load < 20ms，search < 1ms
/// - 纯 Dart，无平台依赖
class SuperclusterEngine implements ClusterEngine {
  final ClusterConfig config;

  SuperclusterImmutable<PostModel>? _index;

  SuperclusterEngine({this.config = const ClusterConfig()});

  @override
  void load(List<PostModel> posts) {
    // supercluster 的 radius / extent 关系：
    //   r_pixels = radius * 256 / extent
    // 我们用 extent=512（与 Mapbox JS 默认一致），
    // 要达到 config.clusterRadiusPx 像素半径：radius = clusterRadiusPx * 512 / 256
    final radius = (config.clusterRadiusPx * 2).round();

    _index = SuperclusterImmutable<PostModel>(
      getX: (p) => p.location.longitude,
      getY: (p) => p.location.latitude,
      radius: radius,
      extent: 512,
      // 聚合在 [minZoom, clusterMaxZoom] 范围内生效；
      // zoom > clusterMaxZoom 时 search 返回未聚合的单点（见下 getClusters zoom 分支）
      minZoom: 0,
      maxZoom: config.clusterMaxZoom,
      minPoints: config.clusterMinPoints,
    )..load(posts);
  }

  @override
  List<ClusterOrPoint> getClusters({
    required MapBounds bounds,
    required double zoom,
  }) {
    final index = _index;
    if (index == null) return const [];

    // 超过 clusterMaxZoom 时，直接查最精细层（= maxZoom+1 内部层）
    // supercluster 内部会 clamp 到 maxZoom+1，返回全单点
    final queryZoom = zoom.floor();

    final results = index.search(
      bounds.minLongitude,
      bounds.minLatitude,
      bounds.maxLongitude,
      bounds.maxLatitude,
      queryZoom,
    );

    final out = <ClusterOrPoint>[];
    for (final e in results) {
      if (e is ImmutableLayerCluster<PostModel>) {
        out.add(
          ClusterNode(
            clusterId: e.id,
            center: MapLatLng(e.latitude, e.longitude),
            count: e.childPointCount,
          ),
        );
      } else if (e is ImmutableLayerPoint<PostModel>) {
        out.add(SinglePoint(e.originalPoint));
      }
    }
    return out;
  }

  @override
  double getClusterExpansionZoom(ClusterNode cluster) {
    final index = _index;
    if (index == null) return config.clusterMaxZoom.toDouble() + 1;
    try {
      return index.expansionZoomOf(cluster.clusterId).toDouble();
    } catch (_) {
      // cluster 可能已因 reload 失效，兜底返回 maxZoom+1（保证能完全展开）
      return config.clusterMaxZoom.toDouble() + 1;
    }
  }
}
