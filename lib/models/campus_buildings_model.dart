import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class Building {
  final String id;
  final String name;
  final List<LatLng> polygon;
  final LatLng center;
  final int floors;
  final Color color;
  final String type;

  Building({
    required this.id,
    required this.name,
    required this.polygon,
    required this.center,
    required this.floors,
    this.color = Colors.blue,
    this.type = 'academic',
  });

  // Create a polygon object for the map
  Polygon toMapPolygon() {
    return Polygon(
      points: polygon,
      color: color.withOpacity(0.3),
      borderColor: color.withOpacity(0.8),
      borderStrokeWidth: 2.0,
      isDotted: false,
    );
  }
  
  // Create a marker for building label (to be displayed at the center)
  Marker toLabelMarker() {
    return Marker(
      width: 140,
      height: 40,
      point: center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: [
                Shadow(
                  offset: const Offset(1.0, 1.0),
                  blurRadius: 3.0,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            'Floors: $floors',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  offset: const Offset(1.0, 1.0),
                  blurRadius: 3.0,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Create a marker for a floor indicator
  Marker toFloorMarker(String floorName) {
    return Marker(
      width: 120,
      height: 40,
      point: center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          floorName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  
  // Factory to create from JSON data
  factory Building.fromJson(Map<String, dynamic> json) {
    // Parse polygon points
    final List<LatLng> polygonPoints = (json['polygon'] as List)
        .map((point) => LatLng(point['lat'], point['lng']))
        .toList();
        
    // Parse center
    final centerPos = json['position'];
    final LatLng center = LatLng(centerPos['lat'], centerPos['lng']);
    
    // Parse color or use default
    final String? colorHex = json['color'];
    Color color = Colors.blue;
    
    if (colorHex != null) {
      color = Color(int.parse(colorHex, radix: 16) + 0xFF000000);
    }
    
    return Building(
      id: json['id'],
      name: json['name'],
      polygon: polygonPoints,
      center: center,
      floors: json['floors'] ?? 1,
      color: color,
      type: json['type'] ?? 'academic',
    );
  }
}

class CampusPath {
  final String id;
  final List<LatLng> points;
  final Color color;
  final double width;
  
  CampusPath({
    required this.id,
    required this.points,
    this.color = Colors.amber,
    this.width = 3.0,
  });
  
  factory CampusPath.fromJson(Map<String, dynamic> json) {
    final List<LatLng> pathPoints = (json['points'] as List)
        .map((point) => LatLng(point['lat'], point['lng']))
        .toList();
        
    return CampusPath(
      id: json['id'],
      points: pathPoints,
      color: json['color'] != null 
          ? Color(int.parse(json['color'], radix: 16) + 0xFF000000)
          : Colors.amber,
      width: json['width']?.toDouble() ?? 3.0,
    );
  }
}

class CampusBuildings {
  final List<Building> buildings;
  final List<CampusPath> paths;
  
  CampusBuildings({
    required this.buildings,
    this.paths = const [],
  });
  
  // Get all building polygons
  List<Polygon> getAllBuildingPolygons() {
    return buildings.map((building) => building.toMapPolygon()).toList();
  }
  
  // Get all building label markers
  List<Marker> getAllBuildingLabels() {
    return buildings.map((building) => building.toLabelMarker()).toList();
  }
  
  // Get all path points for drawing
  List<List<LatLng>> getAllPaths() {
    return paths.map((path) => path.points).toList();
  }
  
  // Get building by ID
  Building? getBuildingById(String id) {
    try {
      return buildings.firstWhere((building) => building.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // Load from asset JSON file
  static Future<CampusBuildings> loadFromAsset() async {
    try {
      final String jsonData = await rootBundle.loadString('assets/data/campus_map.json');
      final Map<String, dynamic> mapData = json.decode(jsonData);
      return CampusBuildings.fromJson(mapData);
    } catch (e) {
      debugPrint('Error loading building data: $e, using default buildings');
      return CampusBuildings.createDefault();
    }
  }
  
  // Factory to create from JSON data
  factory CampusBuildings.fromJson(Map<String, dynamic> json) {
    // Parse buildings
    final List<dynamic> buildingsJson = json['buildings'];
    final List<Building> buildingsList = buildingsJson
        .map((buildingJson) => Building.fromJson(buildingJson))
        .toList();
    
    // Parse paths if available
    List<CampusPath> pathsList = [];
    if (json.containsKey('paths')) {
      final List<dynamic> pathsJson = json['paths'];
      pathsList = pathsJson
          .map((pathJson) => CampusPath.fromJson(pathJson))
          .toList();
    }
    
    return CampusBuildings(
      buildings: buildingsList,
      paths: pathsList,
    );
  }
  
  // Create a hardcoded set of campus buildings
  factory CampusBuildings.createDefault() {
    // Main Building
    final mainBuilding = Building(
      id: "main_building",
      name: "Main Building",
      floors: 4,
      center: LatLng(30.099535, 31.248591),
      polygon: [
        LatLng(30.099320, 31.248287),
        LatLng(30.099320, 31.248887),
        LatLng(30.099750, 31.248887),
        LatLng(30.099750, 31.248287),
        LatLng(30.099320, 31.248287),
      ],
      color: Colors.blue,
    );
    
    // Credit Building
    final creditBuilding = Building(
      id: "credit_building",
      name: "Credit Building",
      floors: 3,
      center: LatLng(30.099800, 31.247820),
      polygon: [
        LatLng(30.099950, 31.247680),
        LatLng(30.099950, 31.247950),
        LatLng(30.099650, 31.247950),
        LatLng(30.099650, 31.247680),
        LatLng(30.099950, 31.247680),
      ],
      color: Colors.red,
    );
    
    return CampusBuildings(
      buildings: [mainBuilding, creditBuilding],
    );
  }
} 