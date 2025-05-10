import 'package:flutter/foundation.dart';

/// Firebase configuration settings for different environments
class FirebaseConfig {
  /// Web client ID from Firebase console
  /// Used for Google Sign-In
  static const String webClientId = '317531017867-cl0aa2u3rp13tuoedj043avc8l7pjc9i.apps.googleusercontent.com';
  
  /// Android client ID from Firebase console
  static const String androidClientId = '317531017867-337tkivqnuu6u716esqh6h7dc3tfcjbl.apps.googleusercontent.com';
  
  /// Server client ID from Firebase console
  static const String serverClientId = '317531017867-cl0aa2u3rp13tuoedj043avc8l7pjc9i.apps.googleusercontent.com';
  
  /// Returns the appropriate client ID for the current platform
  static String get clientId {
    if (kIsWeb) {
      return webClientId;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return androidClientId;
    } else {
      return webClientId; // Fallback for other platforms
    }
  }
  
  /// Debug mode for additional logging
  static bool debugMode = true;
} 