import 'package:flutter/material.dart';
import '../../../core/map/map_types.dart';
import '../../../core/map/map_controller.dart';
import '../../../core/map/map_widget_builder.dart';
import '../../../core/map/mapbox/mapbox_map_widget_builder.dart';
import '../../../data/models/post_model.dart';
import '../../map/widgets/zoom_arc_control.dart' show LocationButton;
import '../../../config/map_config.dart';

/// A map view that displays posts as markers on a map
class PostsMapView extends StatefulWidget {
  final List<PostModel> posts;
  final void Function(PostModel post)? onPostTap;

  const PostsMapView({super.key, required this.posts, this.onPostTap});

  @override
  State<PostsMapView> createState() => _PostsMapViewState();
}

class _PostsMapViewState extends State<PostsMapView> {
  JogyMapController? _jogyMapController;
  PostModel? _selectedPost;
  double _currentZoom = 13.0;
  bool _isViewportReady = false;

  @override
  void dispose() {
    _jogyMapController?.dispose();
    super.dispose();
  }

  MapLatLng _calculateCenter() {
    if (widget.posts.isEmpty) {
      return const MapLatLng(31.2304, 121.4737); // Default: Shanghai
    }
    double lat = 0, lng = 0;
    for (final post in widget.posts) {
      lat += post.location.latitude;
      lng += post.location.longitude;
    }
    return MapLatLng(lat / widget.posts.length, lng / widget.posts.length);
  }

  void _onCameraMove(MapCameraEvent event) {
    if (!_isViewportReady &&
        event.camera.viewportSize.x > 0 &&
        event.camera.viewportSize.y > 0) {
      setState(() => _isViewportReady = true);
    }

    if (event.source == MapMoveSource.gesture && _currentZoom != event.camera.zoom) {
      setState(() => _currentZoom = event.camera.zoom);
    }
  }

  // 构建单个帖子标记覆盖层
  Widget _buildPostMarkerOverlay(PostModel post) {
    if (_jogyMapController == null) return const SizedBox.shrink();

    final screenPoint = _jogyMapController!.latLngToScreenPoint(
      MapLatLng(post.location.latitude, post.location.longitude),
    );
    if (screenPoint == null) return const SizedBox.shrink();

    final isSelected = _selectedPost?.id == post.id;
    final markerSize = isSelected ? 60.0 : 50.0;

    return Positioned(
      left: screenPoint.x - markerSize / 2,
      top: screenPoint.y - markerSize / 2,
      width: markerSize,
      height: markerSize,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPost = post);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.white,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: post.imageUrls.isNotEmpty
                ? Image.network(
                    post.imageUrls.first,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 24),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _calculateCenter();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 400,
        child: Stack(
          children: [
            // 基础地图 Widget
            MapboxMapWidgetBuilder(
              styleUri: MapConfig.mapboxStyleUri,
            ).build(JogyMapOptions(
              initialCenter: center,
              initialZoom: _currentZoom,
              initialPitch: 0,
              rotationEnabled: false,
              onMapCreated: (controller) {
                setState(() {
                  _jogyMapController = controller;
                  _isViewportReady =
                      controller.cameraState.viewportSize.x > 0 &&
                      controller.cameraState.viewportSize.y > 0;
                });
              },
              onCameraMove: _onCameraMove,
              onTap: (_) {
                setState(() => _selectedPost = null);
              },
            )),
            // 帖子标记覆盖层
            if (_jogyMapController != null && _isViewportReady)
              ...widget.posts
                  .map((post) => _buildPostMarkerOverlay(post)),
            // Selected post preview card
            if (_selectedPost != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: GestureDetector(
                  onTap: () {
                    if (widget.onPostTap != null && _selectedPost != null) {
                      widget.onPostTap!(_selectedPost!);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _selectedPost!.imageUrls.isNotEmpty
                              ? Image.network(
                                  _selectedPost!.imageUrls.first,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedPost!.content,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _selectedPost!.location.placeName ??
                                          _selectedPost!.location.address ??
                                          '未知位置',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            // 定位按钮
            Positioned(
              right: 12,
              bottom: 12,
              child: LocationButton(
                onTap: () {
                  _jogyMapController?.moveTo(
                    _calculateCenter(),
                    zoom: _currentZoom,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
