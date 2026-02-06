import 'package:flutter/material.dart';
import '../../../../data/models/location_model.dart';

class LocationPickerPage extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const LocationPickerPage({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  // 模拟的附近地点列表
  late List<LocationModel> _nearbyPlaces;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaces();
  }

  Future<void> _loadNearbyPlaces() async {
    // 模拟网络请求延迟
    await Future.delayed(const Duration(milliseconds: 800));

    // 基于当前位置生成一些模拟 POI
    final lat = widget.initialLat;
    final lng = widget.initialLng;

    setState(() {
      _nearbyPlaces = [
        LocationModel(
          latitude: lat,
          longitude: lng,
          placeName: '当前位置',
          address: '精确位置',
        ),
        LocationModel(
          latitude: lat + 0.001,
          longitude: lng + 0.001,
          placeName: '半岛咖啡 (Peninsula Coffee)',
          address: '文化创意园 B栋 101',
        ),
        LocationModel(
          latitude: lat - 0.001,
          longitude: lng + 0.002,
          placeName: '市民中心公园',
          address: '中央大道 88 号',
        ),
        LocationModel(
          latitude: lat + 0.002,
          longitude: lng - 0.001,
          placeName: '万达广场 (Wanda Plaza)',
          address: '商业街 66 号',
        ),
        LocationModel(
          latitude: lat - 0.002,
          longitude: lng - 0.002,
          placeName: '蓝色港湾书店',
          address: '海滨路 12 号',
        ),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择位置', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _nearbyPlaces.length,
              itemBuilder: (context, index) {
                final place = _nearbyPlaces[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(place.placeName ?? '未知地点'),
                  subtitle: Text(place.address ?? '未知地址'),
                  onTap: () {
                    Navigator.pop(context, place);
                  },
                );
              },
            ),
    );
  }
}
