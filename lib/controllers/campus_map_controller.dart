import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:xml/xml.dart';
import '../models/location_model.dart';
import '../models/campus_buildings_model.dart';
import '../models/room_model.dart';
import '../core/services/navigation_service.dart';

class CampusMapController extends ChangeNotifier {
  // Services
  final NavigationService _navigationService = NavigationService();

  // Data
  List<LocationModel> _locations = [];
  List<List<LatLng>> _obstacles = [];

  // JSON data
  Map<String, dynamic>? _mapData;

  // Building data
  CampusBuildings? _campusBuildings;
  bool _showBuildingLabels = true;

  // Room data
  List<RoomModel> _rooms = [];
  bool _showRooms = true;
  List<Marker> _roomLabelMarkers = [];

  // Map settings
  LatLng _campusCenter = LatLng(
    30.099738548474637,
    31.248532736735118,
  ); // User-specified coordinates
  List<LatLng> _campusBoundary = [];
  double _zoomLevel = 18.2; // Specific zoom for vertical view
  double _minZoom = 17.5; // Adjusted minimum zoom
  double _maxZoom = 21.0; // Maximum zoom

  // Bounds for restricting map view
  LatLngBounds? _mapBounds;

  // User location
  Position? _currentPosition;
  LatLng? _currentLatLng;
  bool _isWithinCampus = false;
  Timer? _locationUpdateTimer;
  bool _isLocationEnabled = false;

  // Navigation state
  LocationModel? _selectedLocation;
  LocationModel? _destinationLocation;
  List<LatLng> _currentRoute = [];
  double _estimatedTimeMinutes = 0;
  double _distanceToDestination = 0;
  bool _isNavigating = false;

  // UI state
  int _selectedFloor = 0;
  final List<int> _availableFloors = [0, 1, 2, 3, 4, 5, 6, 7, 8];
  bool _isSearching = false;
  bool _isLoading = false;
  String? _error;

  // Markers
  List<Marker> _mapMarkers = [];
  List<Marker> _buildingLabelMarkers = [];

  // Offline map data
  bool _isDownloadingMapTiles = false;
  double _downloadProgress = 0;
  bool _offlineModeAvailable = false;

  // Cached navigation data
  LatLng? _cachedStartCoordinates;
  LatLng? _cachedDestinationCoordinates;

  // Getters
  List<LocationModel> get locations => _locations;
  LocationModel? get selectedLocation => _selectedLocation;
  LocationModel? get destinationLocation => _destinationLocation;
  LatLng get campusCenter => _campusCenter;
  List<LatLng> get campusBoundary => _campusBoundary;
  LatLngBounds? get mapBounds => _mapBounds;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  List<Marker> get mapMarkers => _mapMarkers;
  List<Marker> get buildingLabelMarkers => _buildingLabelMarkers;
  List<Marker> get roomLabelMarkers => _roomLabelMarkers;
  List<LatLng> get currentRoute => _currentRoute;
  double get estimatedTimeMinutes => _estimatedTimeMinutes;
  double get distanceToDestination => _distanceToDestination;
  bool get isNavigating => _isNavigating;
  bool get isWithinCampus => _isWithinCampus;
  bool get isLoading => _isLoading;
  String? get error => _error;
  LatLng? get currentLatLng => _currentLatLng;
  int get selectedFloor => _selectedFloor;
  List<int> get availableFloors => _availableFloors;
  bool get isLocationEnabled => _isLocationEnabled;
  bool get isDownloadingMapTiles => _isDownloadingMapTiles;
  double get downloadProgress => _downloadProgress;
  bool get offlineModeAvailable => _offlineModeAvailable;
  bool get showBuildingLabels => _showBuildingLabels;
  bool get showRooms => _showRooms;
  List<RoomModel> get rooms => _rooms;

  // Initialize controller
  Future<void> init() async {
    _setLoading(true);

    try {
      // Load locations from JSON
      await _loadLocations();

      // Initialize campus buildings
      await _initializeCampusBuildings();

      // Load map data
      await _loadMapData();

      // Load room data
      await _loadRoomData();

      // Set up location tracking
      await _initLocationService();

      // Create markers
      _updateMarkers();

      _setLoading(false);
    } catch (e) {
      _setError('Failed to initialize map: ${e.toString()}');
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    super.dispose();
  }

  // Initialize campus buildings
  Future<void> _initializeCampusBuildings() async {
    try {
      // Load hardcoded building data instead of KML
      _loadHardcodedBuildingData();

      // Extract building polygons as obstacles for navigation
      if (_campusBuildings != null) {
        for (final building in _campusBuildings!.buildings) {
          _obstacles.add(building.polygon);
        }

        // Update building label markers
        _updateBuildingLabels();
      }

      debugPrint(
        'Initialized ${_campusBuildings?.buildings.length} campus buildings',
      );
    } catch (e) {
      debugPrint('Error initializing campus buildings: ${e.toString()}');
      _setError('Failed to initialize buildings: ${e.toString()}');
    }
  }

  // Load hardcoded building data
  void _loadHardcodedBuildingData() {
    try {
      final buildings = <Building>[];

      // Define building colors
      final List<Color> buildingColors = [
        Colors.blue.shade700,
        Colors.red.shade700,
        Colors.green.shade700,
        Colors.orange.shade700,
      ];

      // Credit Building
      final creditBuildingCoords = [
        [31.24774033538091, 30.09929247427096],
        [31.24790647221498, 30.09929438969887],
        [31.24790540993349, 30.10024432077717],
        [31.24773855923246, 30.10024599412244],
        [31.24774033538091, 30.09929247427096],
      ];

      final creditBuildingPolygon =
          creditBuildingCoords.map((coord) {
            return LatLng(
              coord[1],
              coord[0],
            ); // Convert [lon, lat] to LatLng(lat, lon)
          }).toList();

      // T1 and T2 Building
      final tBuildingsCoords = [
        [31.24790587874221, 30.09932904470624],
        [31.24796868776697, 30.09930381883619],
        [31.24811917027011, 30.0993875940742],
        [31.24811755293528, 30.09934040841679],
        [31.24816921875271, 30.09931368514714],
        [31.24819949247691, 30.09932426044625],
        [31.24819705151111, 30.09937961104083],
        [31.24818606350784, 30.09938556047014],
        [31.24818479428829, 30.09941606736973],
        [31.24823645049782, 30.09941626855818],
        [31.24823522502405, 30.09949614255066],
        [31.24819591673757, 30.09949573781973],
        [31.24819503102756, 30.09950818569319],
        [31.24795916137032, 30.09962773317696],
        [31.24790721540059, 30.09960188487001],
        [31.24790587874221, 30.09932904470624],
      ];

      final tBuildingsPolygon =
          tBuildingsCoords.map((coord) {
            return LatLng(
              coord[1],
              coord[0],
            ); // Convert [lon, lat] to LatLng(lat, lon)
          }).toList();

      // Garden
      final gardenCoords = [
        [31.24795909556174, 30.09962789251497],
        [31.24819482373288, 30.09950846330934],
        [31.24819612969019, 30.09949574514183],
        [31.24823526494474, 30.09949631731007],
        [31.24823614043003, 30.0994162627675],
        [31.24818471123856, 30.09941655197731],
        [31.24818618300137, 30.09938543283051],
        [31.24819722623384, 30.09938006289291],
        [31.24820005027214, 30.09929855190834],
        [31.24842220000424, 30.09930541307574],
        [31.24841497685999, 30.09963880759176],
        [31.24790645527499, 30.09964064051146],
        [31.24790701008225, 30.09960237712718],
        [31.24795909556174, 30.09962789251497],
      ];

      final gardenPolygon =
          gardenCoords.map((coord) {
            return LatLng(
              coord[1],
              coord[0],
            ); // Convert [lon, lat] to LatLng(lat, lon)
          }).toList();

      // Mainstream Building
      final mainBuildingCoords = [
        [31.24842225746107, 30.09930533414632],
        [31.24934208807413, 30.09931318699747],
        [31.2493332637019, 30.09974532467731],
        [31.24841256438667, 30.09972988367897],
        [31.24842225746107, 30.09930533414632],
      ];

      final mainBuildingPolygon =
          mainBuildingCoords.map((coord) {
            return LatLng(
              coord[1],
              coord[0],
            ); // Convert [lon, lat] to LatLng(lat, lon)
          }).toList();

      // Create Building objects with calculated centers
      buildings.add(
        Building(
          id: "credit_building",
          name: "Credit Building",
          polygon: creditBuildingPolygon,
          center: _calculatePolygonCenter(creditBuildingPolygon),
          floors: 5, // Updated to 0-4 (5 floors total)
          type: 'academic',
          color: buildingColors[0],
        ),
      );

      buildings.add(
        Building(
          id: "t_buildings",
          name: "T1 and T2",
          polygon: tBuildingsPolygon,
          center: _calculatePolygonCenter(tBuildingsPolygon),
          floors: 2,
          type: 'academic',
          color: buildingColors[1],
        ),
      );

      buildings.add(
        Building(
          id: "garden",
          name: "Garden",
          polygon: gardenPolygon,
          center: _calculatePolygonCenter(gardenPolygon),
          floors: 1,
          type: 'outdoor',
          color: buildingColors[2],
        ),
      );

      buildings.add(
        Building(
          id: "main_building",
          name: "Mainstream Building",
          polygon: mainBuildingPolygon,
          center: _calculatePolygonCenter(mainBuildingPolygon),
          floors: 9, // Updated to 0-8 (9 floors total)
          type: 'academic',
          color: buildingColors[3],
        ),
      );

      _campusBuildings = CampusBuildings(buildings: buildings);

      // Set college center based on all buildings
      if (buildings.isNotEmpty) {
        _setCampusCenter();
      }

      debugPrint('Loaded ${buildings.length} buildings from hardcoded data');
    } catch (e) {
      debugPrint(
        'Error loading buildings from hardcoded data: ${e.toString()}',
      );
      rethrow;
    }
  }

  // Helper to get element value
  String? _getElementValue(XmlElement element, String name) {
    final elements = element.findElements(name);
    if (elements.isNotEmpty) {
      return elements.first.text;
    }
    return null;
  }

  // Helper to get polygon coordinates
  List<List<double>> _getPolygonCoordinates(XmlElement polygonElement) {
    try {
      final outerBoundaryIs =
          polygonElement.findElements('outerBoundaryIs').first;
      final linearRing = outerBoundaryIs.findElements('LinearRing').first;
      final coordinatesElement = linearRing.findElements('coordinates').first;
      final coordinatesText = coordinatesElement.text.trim();

      // Parse coordinates
      final List<List<double>> coordinates = [];
      final coords = coordinatesText.split(' ');

      for (var coord in coords) {
        final parts = coord.trim().split(',');
        if (parts.length >= 2) {
          try {
            final lon = double.parse(parts[0]);
            final lat = double.parse(parts[1]);
            coordinates.add([lon, lat]);
          } catch (e) {
            debugPrint('Error parsing coordinate: $coord');
          }
        }
      }

      return coordinates;
    } catch (e) {
      debugPrint('Error getting polygon coordinates: $e');
      return [];
    }
  }

  // Calculate polygon center
  LatLng _calculatePolygonCenter(List<LatLng> points) {
    double latitude = 0;
    double longitude = 0;

    for (var point in points) {
      latitude += point.latitude;
      longitude += point.longitude;
    }

    return LatLng(latitude / points.length, longitude / points.length);
  }

  // Set campus center based on buildings
  void _setCampusCenter() {
    if (_campusBuildings == null || _campusBuildings!.buildings.isEmpty) {
      return;
    }

    // Calculate center from all building polygons
    List<LatLng> allPoints = [];
    for (var building in _campusBuildings!.buildings) {
      allPoints.addAll(building.polygon);
    }

    if (allPoints.isEmpty) return;

    // Use a fixed vertical-oriented center instead of calculating
    _campusCenter = LatLng(30.09970, 31.24820);

    // Calculate bounds
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (var point in allPoints) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    // Set boundary using calculated bounds
    _campusBoundary = [
      LatLng(minLat, minLng),
      LatLng(minLat, maxLng),
      LatLng(maxLat, maxLng),
      LatLng(maxLat, minLng),
      LatLng(minLat, minLng),
    ];

    // Set map bounds with padding to maintain vertical orientation
    // Increased padding values to allow more movement
    _mapBounds = LatLngBounds(
      LatLng(minLat - 0.0015, minLng - 0.0010),
      LatLng(maxLat + 0.0015, maxLng + 0.0010),
    );

    debugPrint('Set college center at: $campusCenter with defined boundary');
  }

  // Update building labels based on current settings
  void _updateBuildingLabels() {
    _buildingLabelMarkers = [];

    if (_campusBuildings == null || !_showBuildingLabels) {
      return;
    }

    // Create a single label per building - no duplicates
    Map<String, Marker> buildingMarkers = {};

    // Use optimized positions for clarity
    Map<String, LatLng> adjustedPositions = {
      "main_building": LatLng(30.09947, 31.24890),
      "garden": LatLng(30.09946, 31.24835),
      "t_buildings": LatLng(30.09947, 31.24805),
      "credit_building": LatLng(30.09975, 31.24782),
    };

    for (var building in _campusBuildings!.buildings) {
      // Custom floor visibility logic for specific buildings
      bool buildingHasThisFloor = false;

      if (building.id == "garden") {
        // Garden is only visible on floor 0
        buildingHasThisFloor = _selectedFloor == 0;
      } else if (building.id == "credit_building") {
        // Credit Building is visible on floors 0-4 (not 5)
        buildingHasThisFloor = _selectedFloor <= 4;
      } else if (building.id == "t_buildings") {
        // T Building is visible on floors 0-2
        buildingHasThisFloor = _selectedFloor <= 2;
      } else {
        // Default logic for other buildings
        buildingHasThisFloor = building.floors >= _selectedFloor;
      }

      if (buildingHasThisFloor) {
        // Use adjusted position if available
        final position = adjustedPositions[building.id] ?? building.center;

        // Create a marker with simple text label (no container)
        buildingMarkers[building.id] = Marker(
          width: 120, // Width for text
          height:
              building.id == "main_building"
                  ? 40
                  : 25, // More height for two-line text
          point: position,
          child:
              building.id == "main_building"
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Mainstream",
                        style: TextStyle(
                          color: building.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "Building",
                        style: TextStyle(
                          color: building.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                  : Text(
                    building.name,
                    style: TextStyle(
                      color: building.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
        );
      }
    }

    // Add all building markers to the list
    _buildingLabelMarkers = buildingMarkers.values.toList();
  }

  // Helper to get floor data
  Map<String, dynamic>? _getFloorData(int floorLevel) {
    try {
      if (_mapData != null && _mapData!.containsKey('floors')) {
        final floorsData = _mapData!['floors'] as List;
        for (var floor in floorsData) {
          if (floor['level'] == floorLevel) {
            return floor;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting floor data: $e');
    }
    return null;
  }

  // Helper to get floor labels
  List<Map<String, dynamic>> _getFloorLabels() {
    List<Map<String, dynamic>> floorLabels = [];

    try {
      if (_mapData != null && _mapData!.containsKey('pois')) {
        final poisData = _mapData!['pois'] as List;
        for (var poi in poisData) {
          if (poi['type'] == 'label') {
            floorLabels.add(poi);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting floor labels: $e');
    }

    return floorLabels;
  }

  // Toggle building labels
  void toggleBuildingLabels() {
    _showBuildingLabels = !_showBuildingLabels;
    _updateBuildingLabels();
    notifyListeners();
  }

  // Load locations from JSON file
  Future<void> _loadLocations() async {
    try {
      final String jsonData = await rootBundle.loadString(
        'assets/data/locations.json',
      );
      final List<dynamic> jsonList = json.decode(jsonData);

      _locations =
          jsonList.map((json) => LocationModel.fromJson(json)).toList();

      debugPrint('Loaded ${_locations.length} locations');
    } catch (e) {
      debugPrint('Error loading locations: ${e.toString()}');
      _setError('Failed to load locations: ${e.toString()}');
      rethrow;
    }
  }

  // Load map data
  Future<void> _loadMapData() async {
    try {
      // Load the JSON data
      final String jsonString = await rootBundle.loadString(
        'assets/data/campus_map.json',
      );
      _mapData = json.decode(jsonString);

      // Set specific coordinates for the college - adjusted for vertical view
      _campusCenter = LatLng(30.09970, 31.24820);

      // Define campus boundary - adjusted for vertical view
      _campusBoundary = [
        LatLng(30.10020, 31.24760),
        LatLng(30.10020, 31.24890),
        LatLng(30.09920, 31.24890),
        LatLng(30.09920, 31.24760),
        LatLng(30.10020, 31.24760),
      ];

      // Calculate min/max for precise bounds
      double minLat = _campusBoundary.map((p) => p.latitude).reduce(min);
      double maxLat = _campusBoundary.map((p) => p.latitude).reduce(max);
      double minLng = _campusBoundary.map((p) => p.longitude).reduce(min);
      double maxLng = _campusBoundary.map((p) => p.longitude).reduce(max);

      // Add buffer to avoid edge issues - increased for more movement
      minLat -= 0.0008;
      maxLat += 0.0008;
      minLng -= 0.0005;
      maxLng += 0.0005;

      // Create LatLngBounds for map restriction
      _mapBounds = LatLngBounds(
        LatLng(minLat, minLng), // Southwest
        LatLng(maxLat, maxLng), // Northeast
      );

      debugPrint('Set college center at: $_campusCenter with defined boundary');

      // Try to load building data from JSON if available
      if (_mapData != null) {
        debugPrint('Loaded building data from JSON');
      }
    } catch (e) {
      debugPrint('Error loading map data: ${e.toString()}');
      _setError('Failed to load map data: ${e.toString()}');
    }
  }

  // Initialize location service
  Future<void> _initLocationService() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setError('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setError('Location permissions are permanently denied');
        return;
      }

      _isLocationEnabled =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      if (_isLocationEnabled) {
        await getCurrentLocation();
        _startLocationUpdates();
      }
    } catch (e) {
      debugPrint('Error initializing location service: ${e.toString()}');
      _setError('Failed to initialize location: ${e.toString()}');
    }
  }

  // Get current location
  Future<void> getCurrentLocation() async {
    if (!_isLocationEnabled) {
      return;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLatLng = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      _checkWithinCampus();
      _updateNavigationIfActive();
      _updateMarkers();

      notifyListeners();
    } catch (e) {
      debugPrint('Error getting location: ${e.toString()}');

      // Try to get last known position as fallback
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          _currentPosition = lastPosition;
          _currentLatLng = LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );

          _checkWithinCampus();
          _updateMarkers();

          notifyListeners();
        }
      } catch (_) {
        // If that also fails, use campus center
        _currentLatLng = _campusCenter;
      }
    }
  }

  // Start periodic location updates
  void _startLocationUpdates() {
    // Cancel any existing timer
    _stopLocationUpdates();

    // Update location every 5 seconds
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => getCurrentLocation(),
    );
  }

  // Stop location updates
  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  // Check if user is within campus boundaries
  void _checkWithinCampus() {
    if (_currentLatLng == null) {
      _isWithinCampus = false;
      return;
    }

    // Make the boundary check more lenient
    // Since we're using exact coordinates from real buildings, we need to add some margin
    _isWithinCampus =
        true; // Default to true to avoid irritating users if they're close to campus

    // Only show the warning if they're very far away from campus center
    double distance = _calculateDistanceInMeters(
      _currentLatLng!.latitude,
      _currentLatLng!.longitude,
      _campusCenter.latitude,
      _campusCenter.longitude,
    );

    // If they're more than 300 meters away from the campus center, show the warning
    _isWithinCampus = distance <= 300;
  }

  // Calculate distance between two coordinates in meters
  double _calculateDistanceInMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const int earthRadius = 6371000; // meters
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Select a floor
  void setSelectedFloor(int floor) {
    if (_availableFloors.contains(floor)) {
      _selectedFloor = floor;
      _updateMarkers();
      notifyListeners();
    }
  }

  // Get rooms on the selected floor
  List<LocationModel> getLocationsByFloor(int floor) {
    return _locations
        .where((loc) => loc.type == 'room' && loc.floor == floor)
        .toList();
  }

  // Select a location
  void selectLocation(String? locationId) {
    if (locationId == null) {
      _selectedLocation = null;
      notifyListeners();
      return;
    }

    final location = _locations.firstWhere(
      (loc) => loc.id == locationId,
      orElse: () => _locations.first,
    );

    _selectedLocation = location;

    // If it's a room, select its floor
    if (location.type == 'room' && location.floor != null) {
      setSelectedFloor(location.floor!);
    }

    _updateMarkers();
    notifyListeners();
  }

  // Search locations based on query
  List<dynamic> searchLocations(String query) {
    if (query.isEmpty) {
      // Return empty result if no query
      return [];
    }

    final List<dynamic> results = [];
    final lowerQuery = query.toLowerCase();

    try {
      // First search for exact buildings by name
      if (_campusBuildings != null) {
        for (final building in _campusBuildings!.buildings) {
          if (building.name.toLowerCase().contains(lowerQuery)) {
            results.add({
              'id': building.id,
              'name': building.name,
              'type': 'building',
              'coordinates': building.center,
            });
          }
        }
      }

      // Then add matching locations
      for (final location in _locations) {
        if (location.name.toLowerCase().contains(lowerQuery) ||
            location.description.toLowerCase().contains(lowerQuery) ||
            (location.building?.toLowerCase().contains(lowerQuery) ?? false)) {
          results.add(location);
        }
      }
    } catch (e) {
      debugPrint('Error searching locations: $e');
    }

    // Limit results to avoid overwhelming the UI
    return results.length > 10 ? results.sublist(0, 10) : results;
  }

  // Start navigation to a location
  void startNavigation(String destinationId) {
    // Find the destination location
    final destination = _locations.firstWhere(
      (loc) => loc.id == destinationId,
      orElse: () => _locations.first,
    );

    _destinationLocation = destination;

    // If current location is not available, can't navigate
    if (_currentLatLng == null) {
      _setError('Cannot navigate: Your location is unknown');
      return;
    }

    // Calculate route using A* algorithm
    _currentRoute = _navigationService.findPath(
      _currentLatLng!,
      destination.coordinates,
      _obstacles,
    );

    // Cache the calculated route to prevent recalculation during zoom
    _cachedDestinationCoordinates = destination.coordinates;
    _cachedStartCoordinates = _currentLatLng!;

    // Calculate statistics
    _distanceToDestination = _navigationService.calculateDistanceBetween(
      LocationModel(
        id: 'current',
        name: 'Current Location',
        type: 'current',
        coordinates: _currentLatLng!,
        description: 'Your current location',
      ),
      destination,
    );

    _estimatedTimeMinutes = _navigationService.calculateEta(_currentRoute);

    _isNavigating = true;
    _updateMarkers();
    notifyListeners();
  }

  // Start navigation between two locations
  void startNavigationBetween(String startId, String destinationId) {
    // If startId is "current", use current location
    if (startId == 'current') {
      startNavigation(destinationId);
      return;
    }

    // Find both locations
    final start = _locations.firstWhere(
      (loc) => loc.id == startId,
      orElse: () => _locations.first,
    );

    final destination = _locations.firstWhere(
      (loc) => loc.id == destinationId,
      orElse: () => _locations.first,
    );

    _destinationLocation = destination;

    // Calculate route using A* algorithm
    _currentRoute = _navigationService.findPath(
      start.coordinates,
      destination.coordinates,
      _obstacles,
    );

    // Cache the calculated route to prevent recalculation during zoom
    _cachedStartCoordinates = start.coordinates;
    _cachedDestinationCoordinates = destination.coordinates;

    // Calculate statistics
    _distanceToDestination = _navigationService.calculateDistanceBetween(
      start,
      destination,
    );

    _estimatedTimeMinutes = _navigationService.calculateEta(_currentRoute);

    _isNavigating = true;
    _updateMarkers();
    notifyListeners();
  }

  // Stop navigation
  void stopNavigation() {
    _isNavigating = false;
    _destinationLocation = null;
    _currentRoute = [];
    _estimatedTimeMinutes = 0;
    _distanceToDestination = 0;
    _cachedStartCoordinates = null;
    _cachedDestinationCoordinates = null;
    _updateMarkers();
    notifyListeners();
  }

  // Refresh navigation route while strictly preserving the fixed start point
  void refreshNavigationWithFixedPoints() {
    if (_isNavigating &&
        _destinationLocation != null &&
        _cachedStartCoordinates != null &&
        _cachedDestinationCoordinates != null) {
      // Always use original cached points, never current location
      final startPoint = _cachedStartCoordinates!;
      final endPoint = _cachedDestinationCoordinates!;

      // Recalculate route using the corridor-based method
      _currentRoute = _navigationService.findCorridorPath(startPoint, endPoint);

      // Calculate statistics
      _distanceToDestination = _navigationService.calculateDistanceBetween(
        LocationModel(
          id: 'fixed_start',
          name: 'Fixed Start',
          type: 'fixed',
          coordinates: startPoint,
          description: 'Fixed starting point',
        ),
        _destinationLocation!,
      );

      _estimatedTimeMinutes = _navigationService.calculateEta(_currentRoute);

      notifyListeners();
    }
  }

  // Update navigation if active
  void _updateNavigationIfActive() {
    if (_isNavigating && _destinationLocation != null) {
      // Only update if using real-time navigation (when cached start is null)
      // Otherwise, use fixed points for consistent routing
      if (_cachedStartCoordinates == null && _currentLatLng != null) {
        // Only perform real-time updates for current location mode
        bool shouldRecalculate = true;

        // Recalculate route only if necessary
        if (shouldRecalculate) {
          _currentRoute = _navigationService.findCorridorPath(
            _currentLatLng!,
            _destinationLocation!.coordinates,
          );

          // Store coordinates
          _cachedStartCoordinates = _currentLatLng;
          _cachedDestinationCoordinates = _destinationLocation!.coordinates;
        }

        // Update stats
        _distanceToDestination = _navigationService.calculateDistanceBetween(
          LocationModel(
            id: 'current',
            name: 'Current Location',
            type: 'current',
            coordinates: _currentLatLng!,
            description: 'Your current location',
          ),
          _destinationLocation!,
        );

        _estimatedTimeMinutes = _navigationService.calculateEta(_currentRoute);

        // Check if arrived (within 10 meters)
        if (_distanceToDestination < 10) {
          _isNavigating = false;
          _setError('You have arrived at ${_destinationLocation!.name}');
          _destinationLocation = null;
          _currentRoute = [];
          _estimatedTimeMinutes = 0;
          _distanceToDestination = 0;
          _cachedStartCoordinates = null;
          _cachedDestinationCoordinates = null;
        }
      } else if (_cachedStartCoordinates != null) {
        // For fixed point navigation, use the dedicated refresh method
        refreshNavigationWithFixedPoints();
      }

      notifyListeners();
    }
  }

  // Update map markers
  void _updateMarkers() {
    _mapMarkers = [];

    // Keep track of buildings we've already created markers for
    final Set<String> processedBuildingIds = {};

    // Add location markers for the current floor
    final locationsOnFloor = getLocationsByFloor(_selectedFloor);

    for (final location in locationsOnFloor) {
      final bool isSelected = _selectedLocation?.id == location.id;
      final bool isDestination = _destinationLocation?.id == location.id;

      // Skip buildings that will have text labels from buildingLabelMarkers
      if (location.type == "building" && _campusBuildings != null) {
        final buildingExists = _campusBuildings!.buildings.any(
          (b) => b.id == location.id,
        );
        if (buildingExists) {
          processedBuildingIds.add(location.id);
          continue; // Skip creating this marker
        }
      }

      // Skip rooms as they'll have their own labels without location icons
      if (location.type == "room") {
        continue; // Skip adding location pins for rooms
      }

      _mapMarkers.add(
        Marker(
          width: isSelected || isDestination ? 40.0 : 30.0,
          height: isSelected || isDestination ? 40.0 : 30.0,
          point: location.coordinates,
          child: GestureDetector(
            onTap: () => selectLocation(location.id),
            child: Icon(
              isDestination ? Icons.location_on : Icons.place,
              color:
                  isDestination
                      ? Colors.red
                      : (isSelected ? Colors.blue : Colors.purple),
              size: isSelected || isDestination ? 40.0 : 30.0,
            ),
          ),
        ),
      );
    }

    // Add building markers if on ground floor
    if (_selectedFloor == 1) {
      final buildings =
          _locations
              .where(
                (loc) =>
                    loc.type == 'building' &&
                    !processedBuildingIds.contains(loc.id),
              )
              .toList();

      for (final building in buildings) {
        final bool isSelected = _selectedLocation?.id == building.id;
        final bool isDestination = _destinationLocation?.id == building.id;

        _mapMarkers.add(
          Marker(
            width: isSelected || isDestination ? 40.0 : 30.0,
            height: isSelected || isDestination ? 40.0 : 30.0,
            point: building.coordinates,
            child: GestureDetector(
              onTap: () => selectLocation(building.id),
              child: Icon(
                isDestination ? Icons.business : Icons.business,
                color:
                    isDestination
                        ? Colors.red
                        : (isSelected ? Colors.blue : Colors.green),
                size: isSelected || isDestination ? 40.0 : 30.0,
              ),
            ),
          ),
        );
      }
    }

    // Add POIs
    final pois =
        _locations
            .where(
              (loc) =>
                  loc.type == 'poi' &&
                  (loc.floor == null || loc.floor == _selectedFloor),
            )
            .toList();

    for (final poi in pois) {
      final bool isSelected = _selectedLocation?.id == poi.id;
      final bool isDestination = _destinationLocation?.id == poi.id;

      _mapMarkers.add(
        Marker(
          width: isSelected || isDestination ? 40.0 : 30.0,
          height: isSelected || isDestination ? 40.0 : 30.0,
          point: poi.coordinates,
          child: GestureDetector(
            onTap: () => selectLocation(poi.id),
            child: Icon(
              isDestination ? Icons.location_on : Icons.star,
              color:
                  isDestination
                      ? Colors.red
                      : (isSelected ? Colors.blue : Colors.amber),
              size: isSelected || isDestination ? 40.0 : 30.0,
            ),
          ),
        ),
      );
    }

    // Add current location marker if available
    if (_currentLatLng != null) {
      _mapMarkers.add(
        Marker(
          width: 30.0,
          height: 30.0,
          point: _currentLatLng!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    }

    // Update building labels
    _updateBuildingLabels();
  }

  // Helper methods for state management
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();

    // Auto-clear error after 5 seconds
    if (error != null) {
      Future.delayed(const Duration(seconds: 5), () {
        _error = null;
        notifyListeners();
      });
    }
  }

  // Get building polygons for the map
  List<Polygon> getBuildingPolygons() {
    List<Polygon> polygons = [];

    if (_campusBuildings != null) {
      // Only show buildings on the current floor
      for (var building in _campusBuildings!.buildings) {
        // Custom floor visibility logic for specific buildings
        bool buildingHasThisFloor = false;

        if (building.id == "garden") {
          // Garden is only visible on floor 0
          buildingHasThisFloor = _selectedFloor == 0;
        } else if (building.id == "credit_building") {
          // Credit Building is visible on floors 0-4 (not 5)
          buildingHasThisFloor = _selectedFloor <= 4;
        } else if (building.id == "t_buildings") {
          // T Building is visible on floors 0-2
          buildingHasThisFloor = _selectedFloor <= 2;
        } else {
          // For other buildings, check floors data
          try {
            if (_mapData != null && _mapData!.containsKey('floors')) {
              final floorData = _getFloorData(_selectedFloor);
              if (floorData != null && floorData['buildings'] != null) {
                buildingHasThisFloor = (floorData['buildings'] as List)
                    .contains(building.id);
              } else {
                // Default logic for buildings without specific floor data
                buildingHasThisFloor = building.floors >= _selectedFloor;
              }
            } else {
              // Fallback - show buildings with at least this many floors
              buildingHasThisFloor = building.floors >= _selectedFloor;
            }
          } catch (e) {
            // Fallback - show all buildings
            buildingHasThisFloor = true;
            debugPrint('Error checking floor data: $e');
          }
        }

        if (buildingHasThisFloor) {
          polygons.add(
            Polygon(
              points: building.polygon,
              color: building.color.withOpacity(0.5),
              borderColor: building.color,
              borderStrokeWidth: 3.0, // Force a thicker border for visibility
              isDotted: false, // Ensure it's not dotted
            ),
          );
        }
      }

      return polygons;
    }

    // Fallback to old method if campus buildings are not initialized
    for (int i = 0; i < _obstacles.length; i++) {
      polygons.add(
        Polygon(
          points: _obstacles[i],
          color: Colors.blueGrey.withOpacity(0.5),
          borderColor: Colors.blueGrey.shade800,
          borderStrokeWidth: 3.0, // Add border here too
          isDotted: false, // Ensure it's not dotted
        ),
      );
    }

    return polygons;
  }

  // Get campus paths for visualization
  List<List<LatLng>> getCampusPaths() {
    // Return empty list to remove all paths (including white lines)
    return [];
  }

  // Download map tiles for offline use
  Future<void> downloadMapTilesForOfflineUse() async {
    if (_isDownloadingMapTiles) {
      return;
    }

    try {
      _isDownloadingMapTiles = true;
      _downloadProgress = 0;
      notifyListeners();

      // Define the area to download (campus boundary with some padding)
      final bounds = _calculateMapBounds(_campusBoundary);
      final southWest = bounds[0];
      final northEast = bounds[1];

      // Zoom levels to download
      const minZoom = 15;
      const maxZoom = 19;

      // Calculate total tiles to download
      int totalTiles = 0;
      for (int z = minZoom; z <= maxZoom; z++) {
        final sw = _latLonToTile(southWest.latitude, southWest.longitude, z);
        final ne = _latLonToTile(northEast.latitude, northEast.longitude, z);

        final xTiles = (ne[0] - sw[0]).abs() + 1;
        final yTiles = (ne[1] - sw[1]).abs() + 1;

        totalTiles += xTiles * yTiles;
      }

      // Simulate downloading tiles
      int downloadedTiles = 0;

      for (int z = minZoom; z <= maxZoom; z++) {
        final sw = _latLonToTile(southWest.latitude, southWest.longitude, z);
        final ne = _latLonToTile(northEast.latitude, northEast.longitude, z);

        final xMin = min(sw[0], ne[0]);
        final xMax = max(sw[0], ne[0]);
        final yMin = min(sw[1], ne[1]);
        final yMax = max(sw[1], ne[1]);

        for (int x = xMin; x <= xMax; x++) {
          for (int y = yMin; y <= yMax; y++) {
            // Simulate downloading a tile
            // In a real app, you'd download the tile from OSM or Google Maps
            await Future.delayed(const Duration(milliseconds: 1));

            // Update progress
            downloadedTiles++;
            _downloadProgress = downloadedTiles / totalTiles;

            // Notify listeners periodically
            if (downloadedTiles % 20 == 0) {
              notifyListeners();
            }
          }
        }
      }

      // Mark offline mode as available
      _offlineModeAvailable = true;
      _downloadProgress = 1.0;
      _setError('Map data downloaded for offline use');
    } catch (e) {
      _setError('Failed to download map data: ${e.toString()}');
    } finally {
      _isDownloadingMapTiles = false;
      notifyListeners();
    }
  }

  // Helper to calculate the bounding box of a list of coordinates
  List<LatLng> _calculateMapBounds(List<LatLng> points) {
    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;

    for (var point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    // Add padding (0.001 degree is roughly 100 meters) - increased for more movement
    minLat -= 0.003;
    maxLat += 0.003;
    minLng -= 0.003;
    maxLng += 0.003;

    return [
      LatLng(minLat, minLng), // Southwest
      LatLng(maxLat, maxLng), // Northeast
    ];
  }

  // Convert latitude, longitude to tile coordinates
  List<int> _latLonToTile(double lat, double lon, int zoom) {
    final x = ((lon + 180) / 360 * pow(2, zoom)).floor();
    final y =
        ((1 - log(tan(lat * pi / 180) + 1 / cos(lat * pi / 180)) / pi) /
                2 *
                pow(2, zoom))
            .floor();
    return [x, y];
  }

  // Helper to check if a point is inside the campus boundaries
  bool isPointInCampusBounds(LatLng point) {
    if (_mapBounds == null) return false;

    // Check if the point is within the bounds
    return point.latitude >= _mapBounds!.south &&
        point.latitude <= _mapBounds!.north &&
        point.longitude >= _mapBounds!.west &&
        point.longitude <= _mapBounds!.east;
  }

  // Set the current floor
  void setFloor(int floor) {
    if (floor != _selectedFloor && _availableFloors.contains(floor)) {
      _selectedFloor = floor;
      // Update markers and building labels for the new floor
      _updateMarkers();
      _updateBuildingLabels();
      _updateRoomLabels();
      notifyListeners();
    }
  }

  // Create polygon layers for buildings
  List<PolygonLayer> _createBuildingLayers() {
    if (_campusBuildings == null) {
      return [];
    }

    // Group buildings by floor for better layering
    final floorMap = <int, List<Building>>{};

    for (var building in _campusBuildings!.buildings) {
      for (var floor = 0; floor <= building.floors; floor++) {
        if (!floorMap.containsKey(floor)) {
          floorMap[floor] = [];
        }
        floorMap[floor]!.add(building);
      }
    }

    // Create a polygon layer for the current floor only
    if (floorMap.containsKey(_selectedFloor)) {
      final polygons =
          floorMap[_selectedFloor]!
              .map(
                (building) => Polygon(
                  points: building.polygon,
                  color: building.color.withOpacity(0.5),
                  borderColor: building.color,
                  borderStrokeWidth: 2.0,
                  isDotted: false,
                ),
              )
              .toList();

      if (polygons.isNotEmpty) {
        return [PolygonLayer(polygons: polygons)];
      }
    }

    return [];
  }

  // Create building polygons for overlay
  List<Polygon> _createBuildingPolygons() {
    if (_campusBuildings == null) {
      return [];
    }

    // Only show buildings for the selected floor
    List<Polygon> polygons = [];

    for (var building in _campusBuildings!.buildings) {
      // Custom floor visibility logic for specific buildings
      bool buildingHasThisFloor = false;

      if (building.id == "garden") {
        // Garden is only visible on floor 0
        buildingHasThisFloor = _selectedFloor == 0;
      } else if (building.id == "credit_building") {
        // Credit Building is visible on floors 0-4 (not 5)
        buildingHasThisFloor = _selectedFloor <= 4;
      } else if (building.id == "t_buildings") {
        // T Building is visible on floors 0-2
        buildingHasThisFloor = _selectedFloor <= 2;
      } else {
        // Default logic for other buildings
        buildingHasThisFloor = building.floors >= _selectedFloor;
      }

      if (buildingHasThisFloor) {
        polygons.add(
          Polygon(
            points: building.polygon,
            color: building.color.withOpacity(0.5),
            borderColor: building.color,
            borderStrokeWidth: 2.0,
            isDotted: false, // Ensure it's not dotted
          ),
        );
      }
    }
    return polygons;
  }

  // Load buildings from KML file - REPLACED BY HARDCODED IMPLEMENTATION
  Future<void> _loadBuildingsFromKML() async {
    try {
      // This method is now replaced by _loadHardcodedBuildingData
      debugPrint('KML loading method is now replaced by hardcoded data');
      _loadHardcodedBuildingData();
    } catch (e) {
      debugPrint('Error in legacy KML loading method: ${e.toString()}');
      rethrow;
    }
  }

  // Load room data from JSON file
  Future<void> _loadRoomData() async {
    try {
      final String jsonData = await rootBundle.loadString(
        'assets/data/rooms.json',
      );
      final Map<String, dynamic> data = json.decode(jsonData);

      // Parse rooms
      _rooms =
          (data['rooms'] as List)
              .map((roomJson) => RoomModel.fromJson(roomJson))
              .toList();

      debugPrint('Loaded ${_rooms.length} rooms');

      // Update room markers
      _updateRoomLabels();
    } catch (e) {
      debugPrint('Error loading room data: ${e.toString()}');
      _setError('Failed to load room data: ${e.toString()}');
    }
  }

  // Update room labels based on current floor
  void _updateRoomLabels() {
    _roomLabelMarkers = [];

    if (!_showRooms) {
      return;
    }

    // Filter rooms for the current floor
    final roomsOnCurrentFloor =
        _rooms.where((room) => room.floor == _selectedFloor).toList();

    // Debug print to check for Room 100
    for (var room in roomsOnCurrentFloor) {
      if (room.id == "room_100") {
        debugPrint(
          'Room 100 found on floor: ${room.floor} in building: ${room.buildingId}',
        );
      }
    }

    // Create markers for each room on the current floor
    for (var room in roomsOnCurrentFloor) {
      // Check if room belongs to mainstream or credit building
      final buildingId = room.buildingId;

      // Skip rooms not in the main buildings we're focusing on
      if (buildingId != 'main_building' &&
          buildingId != 'credit_building' &&
          buildingId != 't_buildings') {
        continue;
      }

      // Create a marker at the center of the room - WITHOUT location icons
      _roomLabelMarkers.add(
        Marker(
          width: 70,
          height: 30,
          point: room.center,
          child: GestureDetector(
            onTap: () {
              debugPrint('Room selected: ${room.name}');
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.purple.shade300),
              ),
              child: Text(
                room.name,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    notifyListeners();
  }

  // Toggle room visibility
  void toggleRoomVisibility() {
    _showRooms = !_showRooms;
    _updateRoomLabels();
    notifyListeners();
  }

  // Get room polygons for the current floor
  List<Polygon> getRoomPolygons() {
    List<Polygon> polygons = [];

    if (!_showRooms) {
      return polygons;
    }

    // Filter rooms for the current floor
    final roomsOnCurrentFloor =
        _rooms.where((room) => room.floor == _selectedFloor).toList();

    // Create polygons for each room
    for (var room in roomsOnCurrentFloor) {
      // Set different colors for different buildings
      Color roomColor;
      double borderWidth = 1.0;

      if (room.buildingId == 'main_building') {
        roomColor = Colors.blue.withOpacity(0.3);
      } else if (room.buildingId == 'credit_building') {
        roomColor = Colors.orange.withOpacity(0.3);
      } else if (room.buildingId == 't_buildings') {
        roomColor = Colors.red.withOpacity(0.3);
        borderWidth = 0.0; // Remove border for T buildings
      } else {
        roomColor = Colors.grey.withOpacity(0.3);
      }

      polygons.add(
        Polygon(
          points: room.polygon,
          color: roomColor,
          borderColor: roomColor.withOpacity(0.7),
          borderStrokeWidth: borderWidth,
          isDotted: false,
        ),
      );
    }

    return polygons;
  }

  // Start navigation between two fixed points without using real-time location
  void startNavigationBetweenFixedPoints(
    dynamic startId,
    dynamic destinationId,
  ) {
    LocationModel? startLocation;
    LocationModel? destinationLocation;

    // Resolve start location
    if (startId is String) {
      // Find by ID
      try {
        startLocation = _locations.firstWhere((loc) => loc.id == startId);
      } catch (e) {
        _setError('Start location not found');
        return;
      }
    } else if (startId is LocationModel) {
      // Direct location model
      startLocation = startId;
    }

    // Resolve destination location
    if (destinationId is String) {
      // Find by ID
      try {
        destinationLocation = _locations.firstWhere(
          (loc) => loc.id == destinationId,
        );
      } catch (e) {
        _setError('Destination location not found');
        return;
      }
    } else if (destinationId is LocationModel) {
      // Direct location model
      destinationLocation = destinationId;
    }

    // Ensure both locations are valid
    if (startLocation == null || destinationLocation == null) {
      _setError('Cannot navigate: Invalid start or destination');
      return;
    }

    _destinationLocation = destinationLocation;

    // Calculate route using corridor-based path finding - never use current location
    _currentRoute = _navigationService.findCorridorPath(
      startLocation.coordinates,
      destinationLocation.coordinates,
    );

    // Cache the calculated route to prevent recalculation during zoom
    // Store the exact start coordinates to prevent defaulting to user's location
    _cachedStartCoordinates = startLocation.coordinates;
    _cachedDestinationCoordinates = destinationLocation.coordinates;

    // Calculate statistics
    _distanceToDestination = _navigationService.calculateDistanceBetween(
      startLocation,
      destinationLocation,
    );

    _estimatedTimeMinutes = _navigationService.calculateEta(_currentRoute);

    _isNavigating = true;
    _updateMarkers();
    notifyListeners();
  }

  // Regular refresh method for backward compatibility - now uses the fixed point version
  void refreshNavigation() {
    // Call the fixed points version to ensure consistency
    refreshNavigationWithFixedPoints();
  }
}
