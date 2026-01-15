class LocationModel {
  final double latitude;
  final double longitude;
  final String? placeName;
  final String? address;

  const LocationModel({
    required this.latitude,
    required this.longitude,
    this.placeName,
    this.address,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      placeName: json['placeName'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'address': address,
    };
  }
}
