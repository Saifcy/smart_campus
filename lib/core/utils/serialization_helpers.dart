import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility functions for serializing Firestore data types
class SerializationHelpers {
  /// Recursively convert Firestore data types to JSON-serializable types
  /// Handles Timestamp, Map, and List types
  static dynamic serializeFirestoreData(dynamic data) {
    if (data is Timestamp) {
      return data.toDate().toIso8601String();
    } else if (data is Map) {
      return Map.fromEntries(data.entries.map(
        (entry) => MapEntry(entry.key, serializeFirestoreData(entry.value))
      ));
    } else if (data is List) {
      return data.map((item) => serializeFirestoreData(item)).toList();
    } else {
      return data;
    }
  }
  
  /// Convert an ISO8601 string to DateTime
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
} 