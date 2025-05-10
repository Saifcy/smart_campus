import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/campus_map_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/floor_selector.dart';
import '../../models/location_model.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _startSearchController = TextEditingController();
  final TextEditingController _destinationSearchController =
      TextEditingController();
  final _flutterMapController = MapController();
  late TabController _searchTabController;
  Timer? _debounceTimer;

  // Default zoom level
  double _currentZoom = 18.2;
  bool _isSearchExpanded = false;
  bool _isStartSearching = false;
  bool _isDestinationSearching = false;
  List<dynamic> _searchResults = [];
  String? _selectedStartId;

  // Cache navigation route to ensure it persists during zoom
  List<LatLng> _cachedNavigationRoute = [];
  bool _navigationActive = false;
  bool _showNavigationRoute = false;
  bool _useSimpleRoute = true;
  Timer? _routeRefreshTimer;
  int _routeRefreshCount = 0;
  bool _isRefreshingRoute = false; // Track when a refresh is in progress

  @override
  void initState() {
    super.initState();
    _searchTabController = TabController(length: 2, vsync: this);

    // Set initial zoom level to show vertical orientation
    _currentZoom = 18.2;

    // Initialize map controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<CampusMapController>(
        context,
        listen: false,
      );
      controller.init().then((_) {
        // Once buildings are loaded, set the initial vertical view
        _setInitialVerticalView();
      });

      // Set up map controller listener for route persistence
      _flutterMapController.mapEventStream.listen(_handleMapEvent);

      // Set up periodic route refresh timer with more frequent updates
      _startRouteRefreshTimer();
    });
  }

  @override
  void dispose() {
    _startSearchController.dispose();
    _destinationSearchController.dispose();
    _searchTabController.dispose();
    _debounceTimer?.cancel();
    _routeRefreshTimer?.cancel();
    super.dispose();
  }

  // Set initial vertical view of the map
  void _setInitialVerticalView() {
    final mapController = Provider.of<CampusMapController>(
      context,
      listen: false,
    );

    // Ensure controller is initialized
    if (_flutterMapController == null) {
      // Try again after a short delay if not ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _setInitialVerticalView();
      });
      return;
    }

    // Use specific coordinates to ensure vertical view
    _flutterMapController.move(
      // Use the user-specified coordinates
      LatLng(30.099738548474637, 31.248532736735118),
      18.2, // Specific zoom level for vertical view
    );

    // Set rotation to swap X and Y axes
    _flutterMapController.rotate(90.0);

    setState(() {
      _currentZoom = 18.2;
    });
  }

  // Go to current location
  void _goToMyLocation() async {
    final mapController = Provider.of<CampusMapController>(
      context,
      listen: false,
    );
    await mapController.getCurrentLocation();

    if (mapController.currentLatLng != null) {
      _flutterMapController.move(mapController.currentLatLng!, _currentZoom);

      // Maintain rotation when moving to current location
      _flutterMapController.rotate(90.0);

      // Update start location to current location
      setState(() {
        _selectedStartId = 'current';
        _startSearchController.text = 'My Location';
      });
    } else {
      // Show error - location not available
      _showErrorSnackbar(
        'Could not get current location. ${mapController.error}',
      );
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  // Handle search
  void _handleSearch(String query) {
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();

    // Start a new timer to debounce the search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final mapController = Provider.of<CampusMapController>(
        context,
        listen: false,
      );
      final searchingTab = _searchTabController.index;

      // Ensure query is not empty before searching
      if (query.trim().isEmpty && searchingTab != 0) {
        setState(() {
          _searchResults = [];
          _isStartSearching = false;
          _isDestinationSearching = false;
        });
        return;
      }

      setState(() {
        if (searchingTab == 0) {
          // Start point search
          _isStartSearching = query.isNotEmpty;
          _isDestinationSearching = false;
        } else {
          // Destination search
          _isDestinationSearching = query.isNotEmpty;
          _isStartSearching = false;
        }

        if (_isStartSearching || _isDestinationSearching) {
          // Improved search - ensure valid results are returned
          _searchResults = mapController.searchLocations(query);
        } else {
          _searchResults = [];
        }
      });
    });
  }

  // Select location from search results
  void _selectLocation(String locationId) {
    final mapController = Provider.of<CampusMapController>(
      context,
      listen: false,
    );
    final searchingTab = _searchTabController.index;

    if (searchingTab == 0) {
      // Selecting start location
      _selectStartLocation(locationId);
    } else {
      // Selecting destination
      _selectDestination(locationId);
    }

    // Collapse search
    if (_isSearchExpanded) {
      setState(() {
        _isSearchExpanded = false;
        _isStartSearching = false;
        _isDestinationSearching = false;
        _searchResults = [];
      });
    }
  }

  // Select start location
  void _selectStartLocation(String locationId) {
    final mapController = Provider.of<CampusMapController>(
      context,
      listen: false,
    );

    // Clear any existing navigation when changing start point
    if (_navigationActive) {
      mapController.stopNavigation();
      _cachedNavigationRoute = [];
      _navigationActive = false;
      _showNavigationRoute = false;
    }

    if (locationId == 'current') {
      // Use current location
      setState(() {
        _selectedStartId = 'current';
        _startSearchController.text = 'My Location';
        _isStartSearching = false;
      });

      // Move to current location
      if (mapController.currentLatLng != null) {
        _flutterMapController.move(
          mapController.currentLatLng!,
          18.0, // Zoom in closer
        );
      }
      return;
    }

    final location = mapController.locations.firstWhere(
      (loc) => loc.id == locationId,
      orElse: () => mapController.locations.first,
    );

    // Set as start location
    setState(() {
      _selectedStartId = locationId;
      _startSearchController.text = location.name;
      _isStartSearching = false;
    });

    // Move map to start location
    _flutterMapController.move(
      location.coordinates,
      18.0, // Zoom in closer
    );
  }

  // Select destination and start navigation
  void _selectDestination(String locationId) {
    final mapController = Provider.of<CampusMapController>(
      context,
      listen: false,
    );
    final location = mapController.locations.firstWhere(
      (loc) => loc.id == locationId,
      orElse: () => mapController.locations.first,
    );

    // Set destination and clear search
    setState(() {
      _destinationSearchController.text = location.name;
      _isDestinationSearching = false;
    });

    // Start navigation
    if (_selectedStartId != null) {
      // Clear previous route before starting a new one
      _cachedNavigationRoute = [];
      mapController.stopNavigation();

      // Use fixed point navigation even if start is "current"
      if (_selectedStartId == 'current' &&
          mapController.currentLatLng != null) {
        // Create a fixed starting point based on current location
        final fixedStart = LocationModel(
          id: 'fixed_start',
          name: 'Starting Point',
          type: 'fixed',
          coordinates: mapController.currentLatLng!,
          description: 'Fixed starting point',
        );
        mapController.startNavigationBetweenFixedPoints(fixedStart, location);

        // This is a navigation from current location, so show the route
        setState(() {
          _showNavigationRoute = true;
        });
      } else {
        // Get the actual start location by ID, don't default to current location
        try {
          final startLocation = mapController.locations.firstWhere(
            (loc) => loc.id == _selectedStartId,
          );

          // This is a navigation between fixed points, show the route
          mapController.startNavigationBetweenFixedPoints(
            startLocation,
            location,
          );
          setState(() {
            _showNavigationRoute = true;
          });
        } catch (e) {
          // Start location not found, show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Start location not found: $_selectedStartId'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // No start selected - use map center as fallback, don't use current location
      _cachedNavigationRoute = [];
      mapController.stopNavigation();

      // Create a fixed center point
      final mapCenter = _flutterMapController.center;

      // Use map center as fallback starting point - not user's location
      final fixedStart = LocationModel(
        id: 'fixed_start',
        name: 'Starting Point',
        type: 'fixed',
        coordinates: mapCenter,
        description: 'Fixed starting point from map center',
      );
      mapController.startNavigationBetweenFixedPoints(fixedStart, location);

      // Show the route since we're not connecting to user's location
      setState(() {
        _showNavigationRoute = true;
      });
    }

    // Cache the navigation route for persistence during zoom
    setState(() {
      _cachedNavigationRoute = List<LatLng>.from(mapController.currentRoute);
      _navigationActive = true;

      // Ensure the timer is running
      _startRouteRefreshTimer();
    });

    // Move map to show the route
    if (_selectedStartId == 'current' && mapController.currentLatLng != null) {
      // Center between current location and destination
      final midLat =
          (mapController.currentLatLng!.latitude +
              location.coordinates.latitude) /
          2;
      final midLng =
          (mapController.currentLatLng!.longitude +
              location.coordinates.longitude) /
          2;

      _flutterMapController.move(
        LatLng(midLat, midLng),
        16.0, // Zoom out to see more of the route
      );
    } else if (_selectedStartId != null) {
      // Find the start location
      try {
        final startLocation = mapController.locations.firstWhere(
          (loc) => loc.id == _selectedStartId,
        );

        // Center between start and destination
        final midLat =
            (startLocation.coordinates.latitude +
                location.coordinates.latitude) /
            2;
        final midLng =
            (startLocation.coordinates.longitude +
                location.coordinates.longitude) /
            2;

        _flutterMapController.move(
          LatLng(midLat, midLng),
          16.0, // Zoom out to see more of the route
        );
      } catch (e) {
        // Just move to destination if start not found
        _flutterMapController.move(location.coordinates, 17.0);
      }
    } else {
      _flutterMapController.move(location.coordinates, 17.0);
    }
  }

  // Clear navigation
  void _clearNavigation() {
    final mapController = Provider.of<CampusMapController>(
      context,
      listen: false,
    );
    mapController.stopNavigation();

    setState(() {
      _startSearchController.clear();
      _destinationSearchController.clear();
      _selectedStartId = null;
      _cachedNavigationRoute = [];
      _navigationActive = false;
      _showNavigationRoute = false; // Hide the route when clearing
    });
  }

  // Build the main search bar
  Widget _buildSearchBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mapController = Provider.of<CampusMapController>(context);

    return Card(
      elevation: 8,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      shadowColor: isDarkMode ? Colors.black54 : Colors.black38,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: _isSearchExpanded ? 260 : 60,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient:
              isDarkMode
                  ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blueGrey.shade900,
                      Colors.blueGrey.shade800,
                    ],
                  )
                  : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.grey.shade50],
                  ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search header/bar
            InkWell(
              onTap: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                  if (!_isSearchExpanded) {
                    _isStartSearching = false;
                    _isDestinationSearching = false;
                    _searchResults = [];
                  }
                });
              },
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Theme.of(context).primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _isSearchExpanded
                            ? 'Search Locations'
                            : 'Where do you want to go?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (mapController.isNavigating)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 22,
                          ),
                          onPressed: _clearNavigation,
                          tooltip: 'Cancel Navigation',
                        ),
                      )
                    else
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: AnimatedRotation(
                            turns: _isSearchExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _isSearchExpanded = !_isSearchExpanded;
                              if (!_isSearchExpanded) {
                                _isStartSearching = false;
                                _isDestinationSearching = false;
                                _searchResults = [];
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Expanded search panel
            if (_isSearchExpanded)
              Expanded(
                child: Column(
                  children: [
                    // Divider
                    Container(
                      height: 1,
                      color:
                          isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),

                    // Tab bar for start/destination with improved styling
                    Container(
                      margin: const EdgeInsets.only(top: 6, bottom: 4),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode
                                ? Colors.blueGrey.shade800.withOpacity(0.5)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color:
                              isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: TabBar(
                        controller: _searchTabController,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color:
                              isDarkMode
                                  ? Colors.blueGrey.shade700
                                  : Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.15),
                        ),
                        labelColor:
                            isDarkMode
                                ? Colors.white
                                : Theme.of(context).primaryColor,
                        unselectedLabelColor:
                            isDarkMode ? Colors.white60 : Colors.black45,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 13,
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.my_location, size: 18),
                            text: 'Start Point',
                            height: 46,
                          ),
                          Tab(
                            icon: const Icon(Icons.place, size: 18),
                            text: 'Destination',
                            height: 46,
                          ),
                        ],
                        onTap: (index) {
                          setState(() {
                            // Clear previous search results when switching tabs
                            _searchResults = [];
                            if (index == 0) {
                              _isStartSearching = false;
                            } else {
                              _isDestinationSearching = false;
                            }
                          });
                        },
                      ),
                    ),

                    // Search input and results
                    Expanded(
                      child: TabBarView(
                        controller: _searchTabController,
                        children: [
                          // Start point search
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Start location search field with improved styling
                                TextField(
                                  controller: _startSearchController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter Starting Location...',
                                    hintStyle: TextStyle(
                                      color:
                                          isDarkMode
                                              ? Colors.white60
                                              : Colors.black45,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.my_location,
                                        color: Colors.blue,
                                        size: 18,
                                      ),
                                    ),
                                    suffixIcon:
                                        _startSearchController.text.isNotEmpty
                                            ? IconButton(
                                              icon: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey
                                                      .withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.clear,
                                                  size: 16,
                                                ),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _startSearchController
                                                      .clear();
                                                  _isStartSearching = false;
                                                  _searchResults = [];
                                                });
                                              },
                                            )
                                            : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide(
                                        color:
                                            isDarkMode
                                                ? Colors.white24
                                                : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide(
                                        color:
                                            isDarkMode
                                                ? Colors.white24
                                                : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    filled: true,
                                    fillColor:
                                        isDarkMode
                                            ? Colors.blueGrey.shade900
                                                .withOpacity(0.5)
                                            : Colors.grey.shade50,
                                  ),
                                  onChanged: _handleSearch,
                                  textInputAction: TextInputAction.search,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // My Current Location button for Start Point
                                InkWell(
                                  onTap: _goToMyLocation,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isDarkMode
                                              ? AppTheme.darkNavy
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.my_location,
                                            color:
                                                Theme.of(context).primaryColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Use My Current Location',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Destination search
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Destination search field with improved styling
                                TextField(
                                  controller: _destinationSearchController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter Destination Location...',
                                    hintStyle: TextStyle(
                                      color:
                                          isDarkMode
                                              ? Colors.white60
                                              : Colors.black45,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.search,
                                        color: Colors.orange,
                                        size: 18,
                                      ),
                                    ),
                                    suffixIcon:
                                        _destinationSearchController
                                                .text
                                                .isNotEmpty
                                            ? IconButton(
                                              icon: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey
                                                      .withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.clear,
                                                  size: 16,
                                                ),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _destinationSearchController
                                                      .clear();
                                                  _isDestinationSearching =
                                                      false;
                                                  _searchResults = [];
                                                });
                                              },
                                            )
                                            : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide(
                                        color:
                                            isDarkMode
                                                ? Colors.white24
                                                : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide(
                                        color:
                                            isDarkMode
                                                ? Colors.white24
                                                : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    filled: true,
                                    fillColor:
                                        isDarkMode
                                            ? Colors.blueGrey.shade900
                                                .withOpacity(0.5)
                                            : Colors.grey.shade50,
                                  ),
                                  onChanged: _handleSearch,
                                  textInputAction: TextInputAction.search,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // My Current Location button for Destination
                                InkWell(
                                  onTap: () => _selectDestination('current'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isDarkMode
                                              ? AppTheme.darkNavy
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.my_location,
                                            color:
                                                Theme.of(context).primaryColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Use My Current Location',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build quick access to campus buildings
  Widget _buildBuildingQuickAccess() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mapController = Provider.of<CampusMapController>(context);

    // Campus buildings data
    final buildings = [
      {
        'id': 'main_building',
        'name': 'Main Building',
        'icon': Icons.business,
        'color': Colors.blue,
      },
      {
        'id': 'garden',
        'name': 'Garden',
        'icon': Icons.park,
        'color': Colors.green,
      },
      {
        'id': 't_buildings',
        'name': 'T1 & T2 Buildings',
        'icon': Icons.account_balance,
        'color': Colors.teal,
      },
      {
        'id': 'credit_building',
        'name': 'Credit Building',
        'icon': Icons.account_balance_wallet,
        'color': Colors.orange,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 12, bottom: 8),
          child: Text(
            'Campus Buildings',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: buildings.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final building = buildings[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                shadowColor: (building['color'] as Color).withOpacity(0.2),
                child: InkWell(
                  onTap: () {
                    _selectDestination(building['id'].toString());
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (building['color'] as Color).withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        building['name'].toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (building['color'] as Color).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          building['icon'] as IconData,
                          color: building['color'] as Color,
                          size: 22,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (building['color'] as Color).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: building['color'] as Color,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Build quick search results
  Widget _buildQuickSearchResults() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: isDarkMode ? Colors.white38 : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No locations found',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final location = _searchResults[index];

        // If it's a LocationModel
        if (location is LocationModel) {
          final locationColor = _getColorForLocationType(location.type);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            shadowColor: locationColor.withOpacity(0.3),
            child: InkWell(
              onTap: () => _selectLocation(location.id),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: locationColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                      location.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      _getLocationSubtitle(location),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: locationColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForLocationType(location.type),
                        color: locationColor,
                        size: 22,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: locationColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: locationColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // If it's a Map (for buildings)
        final buildingColor = Colors.blue;
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          shadowColor: buildingColor.withOpacity(0.3),
          child: InkWell(
            onTap: () => _selectLocation(location['id']),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: buildingColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    location['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: buildingColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.business, color: buildingColor, size: 22),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: buildingColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: buildingColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mapController = Provider.of<CampusMapController>(context);

    // Update cached route if needed
    _updateCachedRouteIfNeeded(mapController);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Smart Campus Map',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        backgroundColor: isDarkMode ? AppTheme.darkNavy : Colors.white,
      ),
      backgroundColor: isDarkMode ? AppTheme.darkNavy : Colors.white,
      body: SafeArea(
        child: Container(
          color: isDarkMode ? AppTheme.darkNavy : Colors.white,
          child: Stack(
            children: [
              // Map layer
              FlutterMap(
                mapController: _flutterMapController,
                options: MapOptions(
                  center: LatLng(30.099738548474637, 31.248532736735118),
                  zoom: 18.2,
                  maxZoom: mapController.maxZoom,
                  minZoom: mapController.minZoom,
                  interactiveFlags:
                      InteractiveFlag
                          .all, // Enable all interactions including rotation
                  rotation: 90.0, // Initial rotation
                  onMapEvent:
                      _handleMapEvent, // Track all map events for route preservation
                  bounds: mapController.mapBounds,
                  boundsOptions: const FitBoundsOptions(
                    padding: EdgeInsets.all(20.0),
                  ),
                  backgroundColor:
                      isDarkMode ? AppTheme.darkNavy : Colors.white,
                  onTap: (_, __) {
                    // Collapse search if expanded
                    if (_isSearchExpanded) {
                      setState(() {
                        _isSearchExpanded = false;
                        _isStartSearching = false;
                        _isDestinationSearching = false;
                        _searchResults = [];
                      });
                    }

                    // Clear selected location when tapping on empty map area
                    if (mapController.selectedLocation != null &&
                        !mapController.isNavigating) {
                      mapController.selectLocation(null);
                    }
                  },
                ),
                children: [
                  // Base background - use both ColoredBox and a Container
                  ColoredBox(
                    color: isDarkMode ? AppTheme.darkNavy : Colors.white,
                  ),

                  // Full-sized container with desired background color
                  SizedBox.expand(
                    child: Container(
                      color: isDarkMode ? AppTheme.darkNavy : Colors.white,
                    ),
                  ),

                  // Building polygons - higher priority than boundary
                  PolygonLayer(polygons: mapController.getBuildingPolygons()),

                  // Room polygons - displayed inside building polygons
                  PolygonLayer(polygons: mapController.getRoomPolygons()),

                  // Room labels
                  MarkerLayer(markers: mapController.roomLabelMarkers),

                  // ONLY ONE marker layer for building labels - avoiding duplicates
                  MarkerLayer(markers: mapController.buildingLabelMarkers),

                  // Corridor visualization - show where paths are allowed
                  /* Corridors are now invisible per user request
                  PolylineLayer(
                    polylines: [
                      // Mainstream corridor
                      Polyline(
                        points: [
                          LatLng(30.09948191131994, 31.24841776223262),
                          LatLng(30.09948955365039, 31.24933843095844),
                          LatLng(30.09955959374038, 31.24933697798108),
                          LatLng(30.09955572213666, 31.24841630306396),
                          LatLng(30.09948191131994, 31.24841776223262),
                        ],
                        color: Colors.blue.withOpacity(0.7),
                        strokeWidth: 4.0,
                        isDotted: false,
                      ),
                      // Garden corridor outline
                      Polyline(
                        points: [
                          LatLng(30.09930226736904, 31.24832667250212),
                          LatLng(30.09948145896256, 31.24832734297594),
                          LatLng(30.09948151756573, 31.24841816308296),
                          LatLng(30.09963864637301, 31.24841466385952),
                          LatLng(30.09964066426354, 31.24790574831776),
                          LatLng(30.09960204050938, 31.24790668917171),
                          LatLng(30.09962789088778, 31.24795910677879),
                          LatLng(30.09950836910099, 31.24819503697926),
                          LatLng(30.09950606958643, 31.24826399949136),
                          LatLng(30.09930065827042, 31.24826652759621),
                          LatLng(30.09930226736904, 31.24832667250212),
                        ],
                        color: Colors.green.withOpacity(0.7),
                        strokeWidth: 4.0,
                        isDotted: false,
                      ),
                      // Credit corridor outline
                      Polyline(
                        points: [
                          LatLng(30.09941005770661, 31.24779253328255),
                          LatLng(30.09941012617524, 31.24783684997295),
                          LatLng(30.10008673509677, 31.24784207712772),
                          LatLng(30.10008720356755, 31.24779347850401),
                          LatLng(30.09941005770661, 31.24779253328255),
                        ],
                        color: Colors.orange.withOpacity(0.7),
                        strokeWidth: 4.0,
                        isDotted: false,
                      ),
                    ],
                  ),
                  */

                  // Navigation route polyline
                  if (_showNavigationRoute &&
                      (mapController.isNavigating || _navigationActive) &&
                      (mapController.currentRoute.isNotEmpty ||
                          _cachedNavigationRoute.isNotEmpty))
                    PolylineLayer(
                      polylines: [
                        // Thicker background line for better visibility
                        Polyline(
                          points:
                              mapController.isNavigating &&
                                      mapController.currentRoute.isNotEmpty
                                  ? mapController.currentRoute
                                  : _cachedNavigationRoute,
                          color: Colors.blue.withOpacity(0.3),
                          strokeWidth: 8.0,
                          isDotted: false,
                        ),
                        // Main route line - always solid and bright
                        Polyline(
                          points:
                              mapController.isNavigating &&
                                      mapController.currentRoute.isNotEmpty
                                  ? mapController.currentRoute
                                  : _cachedNavigationRoute,
                          color: Colors.blue,
                          strokeWidth: 5.0,
                          isDotted: false,
                        ),
                      ],
                    ),

                  // User location marker
                  if (mapController.currentLatLng != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: mapController.currentLatLng!,
                          radius: 14,
                          color:
                              mapController.isWithinCampus
                                  ? Colors.blue.withOpacity(0.8)
                                  : Colors.red.withOpacity(0.8),
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.5,
                          useRadiusInMeter: false,
                        ),
                      ],
                    ),

                  // Clickable icon markers (different from text labels)
                  MarkerLayer(
                    markers:
                        mapController.mapMarkers
                            .where(
                              (marker) =>
                                  // Filter out any markers that might cause duplicate labels
                                  marker.width <=
                                  50, // Assume text labels are wider
                            )
                            .toList(),
                  ),
                ],
              ),

              // Main search bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildSearchBar(context),
              ),

              // Search results panel (conditional)
              if (_isSearchExpanded &&
                  (_isStartSearching ||
                      _isDestinationSearching ||
                      _searchResults.isNotEmpty))
                Positioned(
                  top: 216, // Below the expanded search bar
                  left: 0,
                  right: 0,
                  child: _buildSearchResults(),
                ),

              // Map controls - moved to bottom of screen
              Positioned(
                right: 16,
                bottom: 16, // Positioned at the very bottom
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom in button
                    FloatingActionButton.small(
                      onPressed: () {
                        // Only zoom in if we haven't reached max zoom
                        if (_currentZoom < mapController.maxZoom) {
                          _flutterMapController.move(
                            _flutterMapController.center,
                            _currentZoom + 1,
                          );
                          setState(() {
                            _currentZoom += 1;
                          });
                        }
                      },
                      heroTag: "zoomIn",
                      child: const Icon(Icons.add),
                      backgroundColor:
                          isDarkMode ? AppTheme.darkNavy : Colors.white,
                      foregroundColor:
                          isDarkMode ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(height: 8),

                    // Zoom out button
                    FloatingActionButton.small(
                      onPressed: () {
                        // Only zoom out if we haven't reached min zoom
                        if (_currentZoom > mapController.minZoom) {
                          _flutterMapController.move(
                            _flutterMapController.center,
                            _currentZoom - 1,
                          );
                          setState(() {
                            _currentZoom -= 1;
                          });
                        }
                      },
                      heroTag: "zoomOut",
                      child: const Icon(Icons.remove),
                      backgroundColor:
                          isDarkMode ? AppTheme.darkNavy : Colors.white,
                      foregroundColor:
                          isDarkMode ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(height: 8),

                    // Toggle building labels button
                    FloatingActionButton.small(
                      onPressed: () {
                        mapController.toggleBuildingLabels();
                      },
                      heroTag: "toggleLabels",
                      child: Icon(
                        mapController.showBuildingLabels
                            ? Icons.label_off
                            : Icons.label,
                      ),
                      backgroundColor:
                          isDarkMode ? AppTheme.darkNavy : Colors.white,
                      foregroundColor:
                          isDarkMode ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(height: 8),

                    // Toggle room visibility
                    FloatingActionButton.small(
                      onPressed: () {
                        mapController.toggleRoomVisibility();
                      },
                      heroTag: "toggleRooms",
                      child: Icon(
                        mapController.showRooms
                            ? Icons.grid_off
                            : Icons.grid_on,
                      ),
                      backgroundColor:
                          isDarkMode ? AppTheme.darkNavy : Colors.white,
                      foregroundColor:
                          isDarkMode ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(height: 8),

                    // User location button
                    FloatingActionButton.small(
                      onPressed: () {
                        mapController.getCurrentLocation().then((_) {
                          if (mapController.currentLatLng != null) {
                            // Center on user location
                            _flutterMapController.move(
                              mapController.currentLatLng!,
                              _currentZoom,
                            );
                          }
                        });
                      },
                      heroTag: "userLocation",
                      child: const Icon(Icons.my_location),
                      backgroundColor:
                          isDarkMode ? AppTheme.darkNavy : Colors.white,
                      foregroundColor:
                          isDarkMode ? Colors.white : Colors.black87,
                    ),

                    // Floor selector at the bottom
                    const FloorSelector(),
                  ],
                ),
              ),

              // Error message
              if (mapController.error != null)
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        mapController.error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Get subtitle for location
  String _getLocationSubtitle(dynamic location) {
    if (location is LocationModel) {
      if (location.floor != null) {
        return '${location.building ?? ""}, Floor ${location.floor}';
      } else if (location.description.isNotEmpty) {
        return location.description;
      } else if (location.building != null) {
        return location.building!;
      } else {
        return location.type;
      }
    } else if (location is Map) {
      return location['type'] == 'building' ? 'Campus Building' : '';
    }
    return '';
  }

  IconData _getIconForLocationType(String type) {
    switch (type) {
      case 'classroom':
        return Icons.school;
      case 'office':
        return Icons.business;
      case 'lab':
        return Icons.science;
      case 'study':
        return Icons.menu_book;
      case 'facility':
        return Icons.meeting_room;
      case 'restaurant':
        return Icons.restaurant;
      case 'building':
        return Icons.location_city;
      default:
        return Icons.place;
    }
  }

  Color _getColorForLocationType(String type) {
    switch (type) {
      case 'classroom':
        return Colors.purple;
      case 'office':
        return Colors.orange;
      case 'lab':
        return Colors.teal;
      case 'study':
        return Colors.green;
      case 'facility':
        return Colors.blue;
      case 'restaurant':
        return Colors.red;
      case 'building':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  // Build search results panel
  Widget _buildSearchResults() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_searchResults.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkNavy : Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: ListView.separated(
          itemCount: _searchResults.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shrinkWrap: true,
          separatorBuilder:
              (context, index) => Divider(
                height: 1,
                thickness: 1,
                color:
                    isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.withOpacity(0.1),
                indent: 72,
                endIndent: 16,
              ),
          itemBuilder: (context, index) {
            final location = _searchResults[index];

            // Regular location
            final iconColor =
                location is LocationModel
                    ? _getColorForLocationType(location.type)
                    : Colors.blue;
            final locationName =
                location is LocationModel ? location.name : location['name'];
            final locationSubtitle =
                location is LocationModel ? _getLocationSubtitle(location) : '';
            final locationIcon =
                location is LocationModel
                    ? _getIconForLocationType(location.type)
                    : Icons.business;

            return InkWell(
              onTap:
                  () => _selectLocation(
                    location is LocationModel ? location.id : location['id'],
                  ),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: iconColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(locationIcon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (locationSubtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              locationSubtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    isDarkMode
                                        ? Colors.white60
                                        : Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper to center the map on all buildings
  void _centerMapOnBuildings() {
    _setInitialVerticalView(); // Use our new method for consistency
  }

  // Update cached route from controller when needed
  void _updateCachedRouteIfNeeded(CampusMapController mapController) {
    if (!mapController.isNavigating) {
      // If navigation stopped, clear cache
      if (_navigationActive) {
        setState(() {
          _cachedNavigationRoute = [];
          _navigationActive = false;
        });
      }
      return;
    }

    if (mapController.currentRoute.isNotEmpty) {
      // Only update if the route has actually changed
      if (_cachedNavigationRoute.isEmpty ||
          !_areRoutesEqual(
            _cachedNavigationRoute,
            mapController.currentRoute,
          )) {
        setState(() {
          _cachedNavigationRoute = List<LatLng>.from(
            mapController.currentRoute,
          );
          _navigationActive = true;
        });
      }
    }
  }

  // Helper method to compare routes
  bool _areRoutesEqual(List<LatLng> route1, List<LatLng> route2) {
    if (route1.length != route2.length) return false;

    for (int i = 0; i < route1.length; i++) {
      if (route1[i].latitude != route2[i].latitude ||
          route1[i].longitude != route2[i].longitude) {
        return false;
      }
    }

    return true;
  }

  // Handle map events to maintain route
  void _handleMapEvent(MapEvent event) {
    if (!mounted) return;

    final mapController = Provider.of<CampusMapController>(
      context,
      listen: false,
    );

    // Only process events when navigation is active
    if (!mapController.isNavigating) return;

    // For any map event, preserve the route without changing start points
    mapController.refreshNavigationWithFixedPoints();

    setState(() {
      if (mapController.currentRoute.isNotEmpty) {
        _cachedNavigationRoute = List<LatLng>.from(mapController.currentRoute);
      }
      _navigationActive = true;
    });

    // For move, zoom, and rotation events, ensure route persists with multiple refreshes
    if (event is MapEventMoveStart ||
        event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd ||
        event is MapEventRotateStart ||
        event is MapEventRotateEnd) {
      // Create a sequence of delayed refreshes to ensure route visibility
      // during and after the map interaction completes
      const intervals = [100, 250, 500, 750, 1000];

      for (var delay in intervals) {
        Future.delayed(Duration(milliseconds: delay), () {
          if (!mounted || !mapController.isNavigating) return;

          // Use fixed point refresh to avoid changing start points
          mapController.refreshNavigationWithFixedPoints();

          setState(() {
            if (mapController.currentRoute.isNotEmpty) {
              _cachedNavigationRoute = List<LatLng>.from(
                mapController.currentRoute,
              );
            }
            _navigationActive = true;
          });
        });
      }
    }
  }

  // Start a timer to periodically refresh the route
  void _startRouteRefreshTimer() {
    _routeRefreshTimer?.cancel();

    // Use a very frequent refresh interval to ensure route stays visible
    _routeRefreshTimer = Timer.periodic(const Duration(milliseconds: 150), (
      timer,
    ) {
      if (!mounted) return;

      final mapController = Provider.of<CampusMapController>(
        context,
        listen: false,
      );

      if (mapController.isNavigating) {
        _routeRefreshCount++;

        // Prevent multiple refreshes from overlapping
        if (_isRefreshingRoute) return;

        setState(() {
          _isRefreshingRoute = true;

          // Always update the cached route if the controller has a valid route
          if (mapController.currentRoute.isNotEmpty) {
            _cachedNavigationRoute = List<LatLng>.from(
              mapController.currentRoute,
            );
            _navigationActive = true;
          }
          // Keep using cached route if controller's is empty but we have a cache
          else if (_cachedNavigationRoute.isNotEmpty) {
            _navigationActive = true;

            // Force the controller to refresh navigation on interval
            if (_routeRefreshCount % 3 == 0) {
              // Every 450ms
              mapController.refreshNavigationWithFixedPoints();
            }
          }
          // Last resort - force refresh navigation if we have no route data
          else if (mapController.destinationLocation != null) {
            mapController.refreshNavigationWithFixedPoints();
          }

          _isRefreshingRoute = false;
        });

        // Force more complete refreshes periodically - use fixed points version
        if (_routeRefreshCount % 10 == 0) {
          // Every 1.5 seconds
          mapController.refreshNavigationWithFixedPoints();
          if (mounted) {
            setState(() {}); // Force complete UI refresh
          }
        }
      }
    });
  }
}
