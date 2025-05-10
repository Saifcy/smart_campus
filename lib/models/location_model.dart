import 'package:latlong2/latlong.dart';

class LocationModel {
  final String id;
  final String name;
  final String type; // "room", "building", "poi"
  final String? building;
  final int? floor;
  final LatLng coordinates;
  final String description;
  final int? capacity;
  final int? floors; // For buildings only

  LocationModel({
    required this.id,
    required this.name,
    required this.type,
    this.building,
    this.floor,
    required this.coordinates,
    required this.description,
    this.capacity,
    this.floors,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    // Handle different coordinate formats
    LatLng coords;
    
    if (json['coordinates'] is Map) {
      // Handle nested structure: {"latitude": x, "longitude": y}
      final coordsMap = json['coordinates'] as Map<String, dynamic>;
      coords = LatLng(
        coordsMap['latitude'] as double,
        coordsMap['longitude'] as double,
      );
    } else if (json['coordinates'] is List) {
      // Handle array structure: [lat, lng]
      final coordinatesList = json['coordinates'] as List<dynamic>;
      coords = LatLng(
        coordinatesList[0] as double,
        coordinatesList[1] as double,
      );
    } else {
      // Default to campus center if coordinates are invalid
      coords = LatLng(30.099635151230682, 31.248591011030316);
    }
    
    return LocationModel(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      building: json['building'],
      floor: json['floor'],
      coordinates: coords,
      description: json['description'] ?? '',
      capacity: json['capacity'],
      floors: json['floors'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'building': building,
      'floor': floor,
      'coordinates': {
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude
      },
      'description': description,
      'capacity': capacity,
      'floors': floors,
    };
  }
} 