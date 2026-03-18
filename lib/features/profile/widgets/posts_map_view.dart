import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/post_model.dart';
import '../../map/widgets/zoom_arc_control.dart';
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
  late MapController _mapController;
  PostModel? _selectedPost;
  double _currentZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng _calculateCenter() {
    if (widget.posts.isEmpty) {
      return const LatLng(31.2304, 121.4737); // Default: Shanghai
    }
    double lat = 0, lng = 0;
    for (final post in widget.posts) {
      lat += post.location.latitude;
      lng += post.location.longitude;
    }
    return LatLng(lat / widget.posts.length, lng / widget.posts.length);
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
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _currentZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    setState(() => _currentZoom = position.zoom);
                  }
                },
                onTap: (_, __) {
                  setState(() => _selectedPost = null);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.tileUrl,
                  userAgentPackageName: 'com.jogy.app',
                ),
                MarkerLayer(
                  markers: widget.posts.map((post) {
                    final isSelected = _selectedPost?.id == post.id;
                    return Marker(
                      point: LatLng(
                        post.location.latitude,
                        post.location.longitude,
                      ),
                      width: isSelected ? 60 : 50,
                      height: isSelected ? 60 : 50,
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
                  }).toList(),
                ),
              ],
            ),
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
            // Zoom Arc Control - bottom right, smaller size
            Positioned(
              right: 8,
              bottom: 8,
              child: Transform.scale(
                scale: 0.7,
                alignment: Alignment.bottomRight,
                child: ZoomArcControl(
                  currentZoom: _currentZoom,
                  onZoomChanged: (zoom) {
                    setState(() => _currentZoom = zoom);
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                  onLocationTap: () {
                    // Center on posts
                    _mapController.move(_calculateCenter(), _currentZoom);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
