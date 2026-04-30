import 'dart:math' as math;

import '../../../core/map/map_types.dart';
import '../../../data/models/post_model.dart';

const double closePostGroupMinZoom = 17.5;
const double closePostGroupRadiusMeters = 30.0;
const int closePostGroupPreviewLimit = 20;

bool shouldUseClosePostGrouping(double zoom) => zoom >= closePostGroupMinZoom;

class MultiPostGroup {
  final String id;
  final MapLatLng center;
  final List<PostModel> posts;
  final int totalCount;

  const MultiPostGroup({
    required this.id,
    required this.center,
    required this.posts,
    required this.totalCount,
  });
}

List<MultiPostGroup> buildClosePostGroups(
  Iterable<PostModel> posts, {
  double radiusMeters = closePostGroupRadiusMeters,
  int previewLimit = closePostGroupPreviewLimit,
}) {
  final unique = <String, PostModel>{};
  for (final post in posts) {
    unique[post.id] = post;
  }

  final sortedPosts = unique.values.toList()
    ..sort(comparePostsByMapRecommendation);
  final workingGroups = <_WorkingPostGroup>[];

  for (final post in sortedPosts) {
    final point = MapLatLng(post.location.latitude, post.location.longitude);
    _WorkingPostGroup? bestGroup;
    var bestDistance = double.infinity;

    for (final group in workingGroups) {
      final distance = distanceMeters(point, group.center);
      if (distance <= radiusMeters && distance < bestDistance) {
        bestDistance = distance;
        bestGroup = group;
      }
    }

    if (bestGroup == null) {
      workingGroups.add(_WorkingPostGroup([post]));
    } else {
      bestGroup.add(post);
    }
  }

  return [
    for (final group in workingGroups)
      MultiPostGroup(
        id: 'g_${group.posts.map((post) => post.id).join('_')}',
        center: group.center,
        posts: group.previewPosts(previewLimit),
        totalCount: group.posts.length,
      ),
  ];
}

int comparePostsByMapRecommendation(PostModel a, PostModel b) {
  final scoreCompare = mapRecommendationScore(
    b,
  ).compareTo(mapRecommendationScore(a));
  if (scoreCompare != 0) return scoreCompare;
  return b.createdAt.compareTo(a.createdAt);
}

double mapRecommendationScore(PostModel post) {
  return post.likes * 3.0 +
      post.favorites * 2.0 +
      (post.isPhotoBubble ? 0.4 : 0.0);
}

double distanceMeters(MapLatLng a, MapLatLng b) {
  const earthRadiusMeters = 6371000.0;
  final lat1 = a.latitude * 0.017453292519943295;
  final lat2 = b.latitude * 0.017453292519943295;
  final deltaLat = (b.latitude - a.latitude) * 0.017453292519943295;
  final deltaLng = (b.longitude - a.longitude) * 0.017453292519943295;
  final sinLat = math.sin(deltaLat / 2);
  final sinLng = math.sin(deltaLng / 2);
  final h = sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLng * sinLng;
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

class _WorkingPostGroup {
  final List<PostModel> posts;
  late MapLatLng center;

  _WorkingPostGroup(this.posts) {
    center = _averageCenter(posts);
  }

  void add(PostModel post) {
    posts.add(post);
    center = _averageCenter(posts);
  }

  List<PostModel> previewPosts(int limit) {
    final sorted = posts.toList()..sort(comparePostsByMapRecommendation);
    return sorted.take(limit).toList(growable: false);
  }
}

MapLatLng _averageCenter(List<PostModel> posts) {
  var lat = 0.0;
  var lng = 0.0;
  for (final post in posts) {
    lat += post.location.latitude;
    lng += post.location.longitude;
  }
  return MapLatLng(lat / posts.length, lng / posts.length);
}
