import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../../models/location_model.dart';

// Define Node class outside of the method
class _PathNode {
  final LatLng point;
  final double gScore; // Cost from start to current
  final double fScore; // Total estimated cost (g + h)
  final _PathNode? parent;

  _PathNode(this.point, this.gScore, this.fScore, this.parent);
}

class NavigationService {
  // Define the single corridor from user specifications
  final List<LatLng> _corridor = [
    LatLng(30.09955559628265, 31.24841696636461),
    LatLng(30.09963893303386, 31.24841364006907),
    LatLng(30.09964251715623, 31.24783876591777),
    LatLng(30.10008672389663, 31.24784206495544),
    LatLng(30.10008603980757, 31.24779410604725),
    LatLng(30.09940987064243, 31.24779314213979),
    LatLng(30.09940904362808, 31.24783626942594),
    LatLng(30.09960193324671, 31.24783828126703),
    LatLng(30.0996018197922, 31.2479065211119),
    LatLng(30.09962777725931, 31.24795956847894),
    LatLng(30.09950836314191, 31.24819483384765),
    LatLng(30.09949578204415, 31.24819619929479),
    LatLng(30.09949638629645, 31.24823505639434),
    LatLng(30.09949633335508, 31.24826280208287),
    LatLng(30.09929993274825, 31.2482599197748),
    LatLng(30.09930344804032, 31.24834428572862),
    LatLng(30.09948036879596, 31.24834243240053),
    LatLng(30.0994815324349, 31.24841847610736),
    LatLng(30.09948937879046, 31.2493382505917),
    LatLng(30.0995597759862, 31.24933736661073),
    LatLng(30.09955559628265, 31.24841696636461), // Close the polygon
  ];

  NavigationService();

  // Simple function to find path between two points
  List<LatLng> findPath(
    LatLng start,
    LatLng end,
    List<List<LatLng>> obstacles,
  ) {
    // Create a new empty path
    List<LatLng> path = [];

    // Always add start point
    path.add(start);

    // Check if start or end is inside corridor
    bool startInCorridor = _isPointInCorridor(start);
    bool endInCorridor = _isPointInCorridor(end);

    // If start is outside corridor, get closest entry point
    if (!startInCorridor) {
      LatLng entry = _findClosestPointOnCorridor(start);
      path.add(entry);
    }

    // Now add corridor waypoints to ensure the path follows the corridor
    if (startInCorridor || endInCorridor) {
      // Find the closest points on corridor to start and end
      LatLng startRef = startInCorridor ? start : path.last;
      LatLng endRef = endInCorridor ? end : _findClosestPointOnCorridor(end);

      // Add corridor waypoints between these points
      List<LatLng> corridorPath = _getPathAlongCorridor(startRef, endRef);
      path.addAll(corridorPath);
    }

    // If end is outside corridor, add exit point
    if (!endInCorridor && !path.contains(_findClosestPointOnCorridor(end))) {
      path.add(_findClosestPointOnCorridor(end));
    }

    // Always add end point
    if (path.last != end) {
      path.add(end);
    }

    return path;
  }

  // Find the closest point on corridor to given point
  LatLng _findClosestPointOnCorridor(LatLng point) {
    LatLng closest = _corridor[0];
    double minDistance = _calculateDistance(point, closest);

    // Check each corridor point
    for (int i = 1; i < _corridor.length; i++) {
      double distance = _calculateDistance(point, _corridor[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closest = _corridor[i];
      }
    }

    // Also check for closest point on each corridor segment
    for (int i = 0; i < _corridor.length - 1; i++) {
      LatLng segmentPoint = _findClosestPointOnSegment(
        point,
        _corridor[i],
        _corridor[i + 1],
      );

      double distance = _calculateDistance(point, segmentPoint);
      if (distance < minDistance) {
        minDistance = distance;
        closest = segmentPoint;
      }
    }

    return closest;
  }

  // Find if a point is inside corridor polygon
  bool _isPointInCorridor(LatLng point) {
    if (_corridor.length < 3) return false;

    bool inside = false;
    int j = _corridor.length - 1;

    for (int i = 0; i < _corridor.length; i++) {
      // Ray casting algorithm to determine if point is in polygon
      if ((_corridor[i].latitude > point.latitude) !=
              (_corridor[j].latitude > point.latitude) &&
          (point.longitude <
              (_corridor[j].longitude - _corridor[i].longitude) *
                      (point.latitude - _corridor[i].latitude) /
                      (_corridor[j].latitude - _corridor[i].latitude) +
                  _corridor[i].longitude)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  // Get path along corridor from one point to another
  List<LatLng> _getPathAlongCorridor(LatLng start, LatLng end) {
    // First find closest corridor points
    LatLng startClosest = _findClosestCorridorVertex(start);
    LatLng endClosest = _findClosestCorridorVertex(end);

    // If they're the same point, no corridor path needed
    if (startClosest == endClosest) {
      return [];
    }

    // Find indices of these points in corridor
    int startIndex = _corridor.indexOf(startClosest);
    int endIndex = _corridor.indexOf(endClosest);

    // If either point isn't exactly a corridor vertex, use approximations
    if (startIndex == -1) {
      // Find the segment it's on and use the closest vertex
      int segmentIndex = _findClosestSegmentIndex(start);
      startIndex = segmentIndex;
    }

    if (endIndex == -1) {
      // Find the segment it's on and use the closest vertex
      int segmentIndex = _findClosestSegmentIndex(end);
      endIndex = segmentIndex;
    }

    // Now generate path along corridor
    List<LatLng> path = [];

    // Determine if clockwise or counterclockwise path is shorter
    int clockwiseSteps =
        (endIndex >= startIndex)
            ? endIndex - startIndex
            : _corridor.length - startIndex + endIndex - 1;

    int counterClockwiseSteps =
        (startIndex >= endIndex)
            ? startIndex - endIndex
            : _corridor.length - endIndex + startIndex - 1;

    if (clockwiseSteps <= counterClockwiseSteps) {
      // Go clockwise
      int i = startIndex;
      while (i != endIndex) {
        i =
            (i + 1) %
            (_corridor.length - 1); // Skip last point (duplicate of first)
        path.add(_corridor[i]);
      }
    } else {
      // Go counterclockwise
      int i = startIndex;
      while (i != endIndex) {
        i = (i - 1 + (_corridor.length - 1)) % (_corridor.length - 1);
        path.add(_corridor[i]);
      }
    }

    return path;
  }

  // Find closest corridor vertex to a point
  LatLng _findClosestCorridorVertex(LatLng point) {
    LatLng closest = _corridor[0];
    double minDistance = _calculateDistance(point, closest);

    for (int i = 1; i < _corridor.length; i++) {
      double distance = _calculateDistance(point, _corridor[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closest = _corridor[i];
      }
    }

    return closest;
  }

  // Find index of closest corridor segment to a point
  int _findClosestSegmentIndex(LatLng point) {
    double minDistance = double.infinity;
    int closestSegment = 0;

    for (int i = 0; i < _corridor.length - 1; i++) {
      LatLng segmentPoint = _findClosestPointOnSegment(
        point,
        _corridor[i],
        _corridor[i + 1],
      );

      double distance = _calculateDistance(point, segmentPoint);
      if (distance < minDistance) {
        minDistance = distance;
        closestSegment = i;
      }
    }

    return closestSegment;
  }

  // Find closest point on a line segment
  LatLng _findClosestPointOnSegment(LatLng p, LatLng start, LatLng end) {
    double dx = end.longitude - start.longitude;
    double dy = end.latitude - start.latitude;

    if (dx == 0 && dy == 0) {
      return start; // Segment is a point
    }

    // Calculate projection of point onto line
    double t =
        ((p.longitude - start.longitude) * dx +
            (p.latitude - start.latitude) * dy) /
        (dx * dx + dy * dy);

    // Constrain to segment
    t = max(0, min(1, t));

    // Calculate the closest point on segment
    return LatLng(start.latitude + t * dy, start.longitude + t * dx);
  }

  // Calculate Haversine distance between two points in meters
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // in meters
    double lat1 = start.latitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double dLat = (end.latitude - start.latitude) * pi / 180;
    double dLon = (end.longitude - start.longitude) * pi / 180;

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Get the corridor definition for visualization
  List<LatLng> getCorridor() {
    return _corridor;
  }

  // Calculate total distance along a path
  double calculatePathLength(List<LatLng> path) {
    double length = 0;
    for (int i = 0; i < path.length - 1; i++) {
      length += _calculateDistance(path[i], path[i + 1]);
    }
    return length;
  }

  // Calculate estimated time to reach destination (in minutes)
  double calculateEta(List<LatLng> path, {double walkingSpeed = 1.4}) {
    // Average walking speed is about 1.4 m/s
    double totalDistance = calculatePathLength(path);
    return totalDistance / (walkingSpeed * 60); // Convert to minutes
  }

  // Calculate distance between two locations
  double calculateDistanceBetween(LocationModel start, LocationModel end) {
    return _calculateDistance(start.coordinates, end.coordinates);
  }

  // Find a path that strictly follows corridors with A* algorithm
  List<LatLng> findCorridorPath(LatLng start, LatLng end) {
    // Create a new empty path
    List<LatLng> path = [];

    // Always add start point
    path.add(start);

    // Check if start or end is inside corridor
    bool startInCorridor = _isPointInCorridor(start);
    bool endInCorridor = _isPointInCorridor(end);

    // Find closest corridor points for both start and end
    LatLng startCorridorPoint = _findClosestPointOnCorridor(start);
    LatLng endCorridorPoint = _findClosestPointOnCorridor(end);

    // For start: if it's not in corridor, add path to closest corridor point
    if (!startInCorridor) {
      path.add(startCorridorPoint);
    }

    // Use A* to find the optimal path through the corridor
    List<LatLng> corridorPath = _findPathWithAStar(
      startCorridorPoint,
      endCorridorPoint,
    );
    path.addAll(corridorPath);

    // For end: if it's not in corridor, add path from corridor to end
    if (!endInCorridor && !path.contains(endCorridorPoint)) {
      path.add(endCorridorPoint);
    }

    // Always add end point
    if (path.last != end) {
      path.add(end);
    }

    // Remove any duplicate points that might be very close to each other
    return _optimizePath(path);
  }

  // Find shortest path using A* algorithm
  List<LatLng> _findPathWithAStar(LatLng start, LatLng end) {
    // Helper to reconstruct path from node chain
    List<LatLng> _reconstructPath(_PathNode currentNode) {
      List<LatLng> pathPoints = [currentNode.point];
      _PathNode? parent = currentNode.parent;

      while (parent != null) {
        pathPoints.insert(0, parent.point);
        parent = parent.parent;
      }

      return pathPoints;
    }

    // Heuristic function (Haversine distance)
    double _heuristic(LatLng a, LatLng b) {
      return _calculateDistance(a, b);
    }

    // Use corridor vertices as navigation nodes
    List<LatLng> nodes = List.from(_corridor);

    // Make sure start and end are in nodes
    if (!nodes.contains(start)) {
      nodes.add(start);
    }
    if (!nodes.contains(end)) {
      nodes.add(end);
    }

    // Open and closed sets
    List<_PathNode> openSet = [];
    Set<LatLng> closedSet = {};

    // Start with the start node
    openSet.add(_PathNode(start, 0, _heuristic(start, end), null));

    while (openSet.isNotEmpty) {
      // Find node with lowest fScore
      openSet.sort((a, b) => a.fScore.compareTo(b.fScore));
      _PathNode current = openSet.removeAt(0);

      // Reached the goal
      if (current.point.latitude == end.latitude &&
          current.point.longitude == end.longitude) {
        return _reconstructPath(current);
      }

      closedSet.add(current.point);

      // Check all possible connections
      for (LatLng neighbor in nodes) {
        // Skip if already processed or same as current
        if (closedSet.contains(neighbor) || neighbor == current.point) {
          continue;
        }

        // Only consider neighbors that are visible (direct line of sight) through corridor
        if (!_hasLineOfSight(current.point, neighbor)) {
          continue;
        }

        // Calculate new g score
        double newGScore =
            current.gScore + _calculateDistance(current.point, neighbor);

        // Check if node is in open set
        _PathNode? existingNode;
        for (var node in openSet) {
          if (node.point == neighbor) {
            existingNode = node;
            break;
          }
        }

        if (existingNode == null) {
          // New node, add to open set
          openSet.add(
            _PathNode(
              neighbor,
              newGScore,
              newGScore + _heuristic(neighbor, end),
              current,
            ),
          );
        } else if (newGScore < existingNode.gScore) {
          // Found a better path, update node
          openSet.remove(existingNode);
          openSet.add(
            _PathNode(
              neighbor,
              newGScore,
              newGScore + _heuristic(neighbor, end),
              current,
            ),
          );
        }
      }
    }

    // No path found, fall back to direct path
    return [start, end];
  }

  // Check if two points have line of sight through corridor
  bool _hasLineOfSight(LatLng a, LatLng b) {
    // Points are visible if they're both on corridor and line between them
    // doesn't exit the corridor

    // Simple first check: are both points in/on corridor?
    if (!_isPointInCorridor(a) && !_isOnCorridorBoundary(a)) return false;
    if (!_isPointInCorridor(b) && !_isOnCorridorBoundary(b)) return false;

    // Check multiple points along the line to ensure it stays in corridor
    const int steps = 10;
    for (int i = 1; i < steps; i++) {
      double t = i / steps;
      LatLng point = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

      if (!_isPointInCorridor(point)) {
        return false;
      }
    }

    return true;
  }

  // Check if point is on corridor boundary
  bool _isOnCorridorBoundary(LatLng point) {
    const double tolerance =
        0.00001; // Small tolerance for floating point comparison

    // Check if point is very close to any corridor segment
    for (int i = 0; i < _corridor.length - 1; i++) {
      LatLng segmentPoint = _findClosestPointOnSegment(
        point,
        _corridor[i],
        _corridor[i + 1],
      );

      double distance = _calculateDistance(point, segmentPoint);
      if (distance < tolerance) {
        return true;
      }
    }

    return false;
  }

  // Optimize path by removing unnecessary points
  List<LatLng> _optimizePath(List<LatLng> path) {
    if (path.length <= 2) return path;

    List<LatLng> optimized = [path.first];
    const double minDistance = 0.5; // Minimum distance in meters to keep points

    for (int i = 1; i < path.length - 1; i++) {
      // Calculate distance from previous point
      double distance = _calculateDistance(optimized.last, path[i]);

      // Only add point if it's far enough from the previous one
      if (distance > minDistance) {
        optimized.add(path[i]);
      }
    }

    // Always add last point
    if (path.last != optimized.last) {
      optimized.add(path.last);
    }

    return optimized;
  }
}
