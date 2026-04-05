import 'dart:math' as math;

class MapLatLng {
  final double latitude;
  final double longitude;
  MapLatLng(this.latitude, this.longitude);
}

class MapScreenPoint {
  final double x;
  final double y;
  MapScreenPoint(this.x, this.y);
  @override String toString() => '($x, $y)';
}

class _MercatorPoint {
  final double x;
  final double y;
  _MercatorPoint(this.x, this.y);
}

_MercatorPoint _latLngToMercator(MapLatLng latLng, double scale) {
  final x = (latLng.longitude + 180.0) / 360.0 * scale;
  final latRad = latLng.latitude * math.pi / 180.0;
  final y = (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * scale;
  return _MercatorPoint(x, y);
}

MapScreenPoint latLngToScreenPoint(MapLatLng latLng, MapLatLng center, double zoom, double pitch, double bearing, double vw, double vh) {
  final scale = 512.0 * math.pow(2, zoom);
  final centerPx = _latLngToMercator(center, scale);
  final pointPx = _latLngToMercator(latLng, scale);
  
  var dx = pointPx.x - centerPx.x;
  var dy = pointPx.y - centerPx.y;
  
  if (bearing != 0) {
    final rad = bearing * math.pi / 180;
    final cosR = math.cos(rad);
    final sinR = math.sin(rad);
    final rx = dx * cosR + dy * sinR;
    final ry = -dx * sinR + dy * cosR;
    dx = rx;
    dy = ry;
  }
  
  if (pitch > 0) {
    final pitchRad = pitch * math.pi / 180;
    dy *= math.cos(pitchRad);
  }
  return MapScreenPoint(dx + vw/2, dy + vh/2);
}

void main() {
  final center = MapLatLng(39.9042, 116.4074);
  final point = MapLatLng(39.9142, 116.4174);
  final pt = latLngToScreenPoint(point, center, 12, 0, 0, 800, 600);
  print('Zoom 12 test: $pt');
}
