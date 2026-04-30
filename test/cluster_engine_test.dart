import 'package:flutter_test/flutter_test.dart';
import 'package:jogy_app/data/models/location_model.dart';
import 'package:jogy_app/data/models/post_model.dart';
import 'package:jogy_app/data/models/user_model.dart';
import 'package:jogy_app/features/map/clustering/cluster_engine.dart';
import 'package:jogy_app/features/map/clustering/close_post_grouping.dart';
import 'package:jogy_app/features/map/clustering/cluster_models.dart';
import 'package:jogy_app/core/map/map_types.dart';

void main() {
  group('SuperclusterEngine', () {
    test('clusters high-density posts at homepage zoom', () {
      final posts = List.generate(
        10,
        (i) => _post(
          'p$i',
          latitude: 37.7749 + i * 0.00001,
          longitude: -122.4194 + i * 0.00001,
        ),
      );
      final engine = SuperclusterEngine()..load(posts);

      final results = engine.getClusters(
        bounds: _boundsAround(37.7749, -122.4194),
        zoom: 17,
      );

      final clusters = results.whereType<ClusterNode>().toList();
      expect(clusters, isNotEmpty);
      expect(clusters.first.count, 10);
    });

    test('sorts cluster leaves by recommendation then createdAt', () {
      final base = DateTime.utc(2026, 4, 30, 10);
      final posts = [
        _post(
          'latest',
          latitude: 37.7749,
          longitude: -122.4194,
          createdAt: base.add(const Duration(minutes: 5)),
        ),
        _post(
          'liked',
          latitude: 37.77491,
          longitude: -122.41939,
          likes: 3,
          createdAt: base,
        ),
        _post(
          'favorited',
          latitude: 37.77492,
          longitude: -122.41938,
          favorites: 4,
          createdAt: base.add(const Duration(minutes: 1)),
        ),
        _post(
          'same_score_newer',
          latitude: 37.77493,
          longitude: -122.41937,
          likes: 1,
          createdAt: base.add(const Duration(minutes: 4)),
        ),
        _post(
          'same_score_older',
          latitude: 37.77494,
          longitude: -122.41936,
          likes: 1,
          createdAt: base.add(const Duration(minutes: 2)),
        ),
      ];
      final engine = SuperclusterEngine()..load(posts);
      final cluster = engine
          .getClusters(bounds: _boundsAround(37.7749, -122.4194), zoom: 17)
          .whereType<ClusterNode>()
          .first;

      final leaves = engine.getClusterLeaves(cluster);

      expect(leaves.map((p) => p.id), [
        'liked',
        'favorited',
        'same_score_newer',
        'same_score_older',
        'latest',
      ]);
    });

    test('splits dense posts after cluster max zoom', () {
      final posts = List.generate(
        5,
        (i) => _post(
          'p$i',
          latitude: 37.7749 + i * 0.00001,
          longitude: -122.4194 + i * 0.00001,
        ),
      );
      final engine = SuperclusterEngine()..load(posts);

      final results = engine.getClusters(
        bounds: _boundsAround(37.7749, -122.4194),
        zoom: 19,
      );

      expect(results.whereType<ClusterNode>(), isEmpty);
      expect(results.whereType<SinglePoint>(), hasLength(5));
    });
  });

  group('close post grouping', () {
    test('is disabled before near-street zoom', () {
      expect(shouldUseClosePostGrouping(17.49), isFalse);
      expect(shouldUseClosePostGrouping(17.5), isTrue);
    });

    test('groups posts within 30 meters', () {
      final posts = [
        _post('p1', latitude: 37.7749, longitude: -122.4194),
        _post('p2', latitude: 37.7750, longitude: -122.4194),
        _post('p3', latitude: 37.77508, longitude: -122.4194),
      ];

      final groups = buildClosePostGroups(posts);

      expect(groups, hasLength(1));
      expect(groups.first.totalCount, 3);
      expect(
        groups.first.posts.map((p) => p.id),
        containsAll(['p1', 'p2', 'p3']),
      );
    });

    test('keeps posts farther than 30 meters separate', () {
      final posts = [
        _post('p1', latitude: 37.7749, longitude: -122.4194),
        _post('p2', latitude: 37.7754, longitude: -122.4194),
        _post('p3', latitude: 37.7759, longitude: -122.4194),
      ];

      final groups = buildClosePostGroups(posts);

      expect(groups, hasLength(3));
      expect(groups.every((group) => group.totalCount == 1), isTrue);
    });

    test('sorts grouped posts by recommendation then createdAt', () {
      final base = DateTime.utc(2026, 4, 30, 10);
      final posts = [
        _post(
          'latest',
          latitude: 37.7749,
          longitude: -122.4194,
          createdAt: base.add(const Duration(minutes: 5)),
        ),
        _post(
          'liked',
          latitude: 37.77491,
          longitude: -122.4194,
          likes: 3,
          createdAt: base,
        ),
        _post(
          'favorited',
          latitude: 37.77492,
          longitude: -122.4194,
          favorites: 4,
          createdAt: base.add(const Duration(minutes: 1)),
        ),
        _post(
          'same_score_newer',
          latitude: 37.77493,
          longitude: -122.4194,
          likes: 1,
          createdAt: base.add(const Duration(minutes: 4)),
        ),
        _post(
          'same_score_older',
          latitude: 37.77494,
          longitude: -122.4194,
          likes: 1,
          createdAt: base.add(const Duration(minutes: 2)),
        ),
      ];

      final group = buildClosePostGroups(posts).single;

      expect(group.posts.map((p) => p.id), [
        'liked',
        'favorited',
        'same_score_newer',
        'same_score_older',
        'latest',
      ]);
    });
  });
}

PostModel _post(
  String id, {
  required double latitude,
  required double longitude,
  DateTime? createdAt,
  int likes = 0,
  int favorites = 0,
}) {
  return PostModel(
    id: id,
    user: const UserModel(id: 'u1', username: 'tester', avatarUrl: '', bio: ''),
    location: LocationModel(latitude: latitude, longitude: longitude),
    content: 'post $id',
    imageUrls: const ['https://example.com/image.jpg'],
    likes: likes,
    favorites: favorites,
    createdAt: createdAt ?? DateTime.utc(2026, 4, 30),
  );
}

MapBounds _boundsAround(double latitude, double longitude) {
  return MapBounds(
    southwest: MapLatLng(latitude - 0.01, longitude - 0.01),
    northeast: MapLatLng(latitude + 0.01, longitude + 0.01),
  );
}
