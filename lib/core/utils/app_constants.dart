class AppConstants {
  // App Information
  static const String appName = "Smart Campus";
  static const String appVersion = "1.0.0";
  
  // Routes
  static const String splashRoute = "/splash";
  static const String loginRoute = "/login";
  static const String registerRoute = "/register";
  static const String forgotPasswordRoute = "/forgot-password";
  static const String emailVerificationRoute = "/email-verification";
  static const String mfaVerificationRoute = "/mfa-verification";
  static const String homeRoute = "/home";
  static const String mapRoute = "/map";
  static const String eventsRoute = "/events";
  static const String settingsRoute = "/settings";
  static const String classroomFinderRoute = "/classroom-finder";
  static const String addEventRoute = "/add-event";
  static const String adminEventsRoute = "/admin/events";
  static const String secondStepVerificationRoute = '/second-step-verification';
  static const String profileRoute = '/profile';
  static const String eventDetailsRoute = '/event-details';
  
  // Animation Durations
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  // Firebase Collections
  static const String usersCollection = "users";
  static const String eventsCollection = "events";
  static const String classroomsCollection = "classrooms";
  
  // Storage References
  static const String profilePhotosStorage = "profile_photos";
  static const String eventImagesStorage = "event_images";
  
  // Default Values
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  
  // Error Messages
  static const String networkErrorMessage = "Please check your internet connection";
  static const String unknownErrorMessage = "An unknown error occurred";
  static const String authErrorMessage = "Authentication failed";
} 