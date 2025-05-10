import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class RoomModel {
  final String id;
  final String name;
  final String buildingId;
  final int floor;
  final List<LatLng> polygon;
  final Color color;

  RoomModel({
    required this.id,
    required this.name,
    required this.buildingId,
    required this.floor,
    required this.polygon,
    this.color = Colors.blue,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    // Parse polygon points
    final List<LatLng> polygonPoints = [];
    if (json['polygon'] != null) {
      for (var point in json['polygon']) {
        polygonPoints.add(LatLng(
          point['lat'],
          point['lng'],
        ));
      }
    }

    return RoomModel(
      id: json['id'],
      name: json['name'],
      buildingId: json['building_id'],
      floor: json['floor'],
      polygon: polygonPoints,
      // Use a default color or parse from JSON if provided
      color: json['color'] != null
          ? Color(int.parse(json['color'], radix: 16) | 0xFF000000)
          : Colors.blue.withOpacity(0.5),
    );
  }

  // Calculate the room's center for displaying labels
  LatLng get center {
    double latSum = 0;
    double lngSum = 0;
    
    for (var point in polygon) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    
    return LatLng(
      latSum / polygon.length,
      lngSum / polygon.length,
    );
  }
} 