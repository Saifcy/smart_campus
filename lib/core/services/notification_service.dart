import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/event_model.dart';

/// A simple service to handle push notifications, focused on reliable delivery
class NotificationService {
  // FCM Server key for sending direct API requests - KEEP PRIVATE
  // This is a general key format, replace with your actual key from Firebase Console
  static const String _fcmServerKey =
      'AAAA0PEu-nA:APA91bEiPL9VXV8weXfx2qh4-x7Xfz6PLp_1uOV3fALfXDR8QCawu25YMeDmJ3QgbG7p4A7-k8tUFu40Abn_NJSsL2XDCVeJdVEvLmfIRfq1iPMnG1v8Kk4Z93vhLZGrXFU2qU_5z3kE';

  // Channel configuration for Android notifications
  static const String _channelId = 'campus_events_channel';
  static const String _channelName = 'Campus Events';
  static const String _channelDescription =
      'Notifications for campus events and announcements';

  // FCM API URL
  static const String _fcmApiUrl = 'https://fcm.googleapis.com/fcm/send';

  // Storage key for device token
  static const String _tokenStorageKey = 'fcm_device_token';

  // Flag to track initialization
  static bool _initialized = false;

  // Singleton pattern
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  // Flutter Local Notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Secure storage for tokens
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Track if notifications are enabled
  bool _notificationsEnabled = true;

  // Private constructor
  NotificationService._();

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      // Check if notifications are enabled in settings
      final storedPreference = await _secureStorage.read(
        key: 'notifications_enabled',
      );
      _notificationsEnabled =
          storedPreference != 'false'; // Default to true if not set

      // 1. Configure local notifications
      await _setupLocalNotifications();

      // 2. Request permissions
      if (_notificationsEnabled) {
        await _requestPermissions();
      }

      // 3. Set up Firebase Messaging handlers
      _setupFirebaseMessaging();

      // 4. Get and save the FCM token
      await _saveFCMToken();

      // 5. Subscribe to backup topics (just in case)
      if (_notificationsEnabled) {
        await _subscribeToTopics();
      }

      // 6. Check if we have any pending notification data
      await _checkPendingNotifications();

      _initialized = true;
    } catch (e) {
      // Still mark as initialized to prevent repeated failures
      _initialized = true;
    }
  }

  /// Re-initialize the service if needed (can be called multiple times safely)
  Future<void> reinitialize() async {
    _initialized = false;
    await initialize();
  }

  /// Set up the local notifications plugin
  Future<void> _setupLocalNotifications() async {
    try {
      // Android settings with proper notification icon
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('ic_notification');

      // iOS settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // Initialize with platform-specific settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the plugin with tap handling
      final bool? initialized = await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // This could be used to navigate to a specific screen
        },
      );

      if (initialized != null && initialized) {
      } else {}

      // Create high importance notification channel for Android
      if (Platform.isAndroid) {
        try {
          final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
              _localNotifications
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >();

          if (androidPlugin != null) {
            await androidPlugin.createNotificationChannel(
              const AndroidNotificationChannel(
                _channelId,
                _channelName,
                description: _channelDescription,
                importance: Importance.max,
                enableVibration: true,
                playSound: true,
                enableLights: true,
              ),
            );
          } else {}
        } catch (e) {}
      }
    } catch (e) {}
  }

  /// Request necessary notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Check for Android platform
      if (Platform.isAndroid) {
        // For newer Android versions, post notifications permission is requested
        // through the system dialog when showing notifications on Android 13+
        // Note: We can't directly request POST_NOTIFICATIONS permission through the plugin
        // in some versions of the plugin
      }

      // For iOS, request notification permissions from Firebase Messaging
      if (Platform.isIOS) {
        try {
          final NotificationSettings settings = await FirebaseMessaging.instance
              .requestPermission(
                alert: true,
                badge: true,
                sound: true,
                provisional: false,
                criticalAlert: true,
                carPlay: true,
                announcement: true,
              );

          // Log the status
        } catch (e) {}
      }

      // For all platforms, set foreground notification options
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true, // Show notification when app is in foreground
            badge: true, // Update app badge count
            sound: true, // Play sound
          );
    } catch (e) {}
  }

  /// Set up Firebase Messaging handlers
  void _setupFirebaseMessaging() {
    // 1. When app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // 2. When app is opened from a notification (was in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {});

    // 3. Check if app was launched from a notification
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {}
    });
  }

  /// Get and save the FCM token
  Future<void> _saveFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveTokenToStorage(token);

        // Listen for token refreshes
        FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
          _saveTokenToStorage(token);

          // Re-subscribe to topics with new token (just to be safe)
          _subscribeToTopics();
        });
      } else {}
    } catch (e) {}
  }

  /// Save the FCM token to secure storage
  Future<void> _saveTokenToStorage(String token) async {
    try {
      // Save to secure storage
      await _secureStorage.write(key: _tokenStorageKey, value: token);

      // Verify token was properly saved (for debugging)
      final savedToken = await _secureStorage.read(key: _tokenStorageKey);
      if (savedToken == token) {
      } else {}
    } catch (e) {}
  }

  /// Get the saved FCM token
  Future<String?> getSavedToken() async {
    try {
      return await _secureStorage.read(key: _tokenStorageKey);
    } catch (e) {
      return null;
    }
  }

  /// Subscribe to FCM topics as a backup delivery mechanism
  Future<void> _subscribeToTopics() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('events');
      await FirebaseMessaging.instance.subscribeToTopic('campus_events');
    } catch (e) {}
  }

  /// Handle incoming foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      final notification = message.notification;

      if (notification != null) {
        _showLocalNotification(
          title: notification.title ?? 'New Notification',
          body: notification.body ?? '',
          payload: json.encode(message.data),
        );
      }
    } catch (e) {}
  }

  /// Send an event notification to all devices
  Future<bool> sendEventNotification(EventModel event) async {
    try {
      bool remoteSuccess = false;
      bool localShown = false;

      // 1. Try sending via FCM topics first
      final topicSuccess = await _sendToTopic(event);
      if (topicSuccess) {
        remoteSuccess = true;
      } else {}

      // 2. Only try direct token delivery if topic delivery failed
      if (!remoteSuccess) {
        final tokenSuccess = await _sendToThisDevice(event);
        if (tokenSuccess) {
          remoteSuccess = true;
        } else {}
      }

      // 3. Only show a local notification if both remote methods failed
      if (!remoteSuccess && !localShown) {
        try {
          await _showLocalNotification(
            title: 'New ${_capitalize(event.type)}: ${event.title}',
            body:
                '${_truncate(event.description, 100)}\nLocation: ${event.location}',
            payload: event.id,
          );
          localShown = true;
        } catch (e) {}
      }

      if (remoteSuccess) {
        return true;
      } else if (localShown) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Send notification using FCM topics
  Future<bool> _sendToTopic(EventModel event) async {
    try {
      // Determine which topic to send to
      final topic = event.type == 'lecture' ? 'lectures' : 'events';

      // Create notification payload - OPTIMIZED FOR BACKGROUND DELIVERY
      final Map<String, dynamic> payload = {
        'to': '/topics/$topic',
        'priority': 'high',
        'content_available': true,

        // Notification part (needed for iOS foreground/background and Android foreground)
        'notification': {
          'title': 'New ${_capitalize(event.type)}: ${event.title}',
          'body':
              '${_truncate(event.description, 100)}\nLocation: ${event.location}',
          'sound': 'default',
          'badge': 1,
          'icon': 'ic_notification',
          'android_channel_id': _channelId,
          'tag': event.id, // Prevents duplicates with same ID
        },

        // Data part (essential for background processing)
        'data': {
          'id': event.id,
          'title': event.title,
          'description': event.description,
          'location': event.location,
          'date': event.date.toIso8601String(),
          'time': event.time,
          'type': event.type,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'priority': 'high',
          'channel_id': _channelId,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },

        // Android specific
        'android': {
          'priority': 'high',
          'ttl': '86400s', // 24 hours
          'notification': {
            'channel_id': _channelId,
            'priority': 'max',
            'icon': 'ic_notification',
            'color': '#4990E2',
            'tag': event.id, // Prevents duplicates with same ID
          },
        },
      };

      // Send the FCM request
      try {
        final response = await http.post(
          Uri.parse(_fcmApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=$_fcmServerKey',
          },
          body: json.encode(payload),
        );

        // Log response
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          final success = responseData['success'] ?? 0;
          return success > 0;
        } else {
          return false;
        }
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Send notification directly to this device
  Future<bool> _sendToThisDevice(EventModel event) async {
    try {
      // Get device token
      final token = await getSavedToken();
      if (token == null || token.isEmpty) {
        return false;
      }

      // Create direct notification payload - OPTIMIZED FOR BACKGROUND DELIVERY
      final Map<String, dynamic> payload = {
        'to': token,
        'priority': 'high',
        'content_available': true,

        // Notification part (needed for iOS foreground/background and Android foreground)
        'notification': {
          'title': 'New ${_capitalize(event.type)}: ${event.title}',
          'body':
              '${_truncate(event.description, 100)}\nLocation: ${event.location}',
          'sound': 'default',
          'badge': 1,
          'icon': 'ic_notification',
          'android_channel_id': _channelId,
          'tag': event.id, // Prevents duplicates with same ID
        },

        // Data part (essential for background processing)
        'data': {
          'id': event.id,
          'title': event.title,
          'description': event.description,
          'location': event.location,
          'date': event.date.toIso8601String(),
          'time': event.time,
          'type': event.type,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'priority': 'high',
          'channel_id': _channelId,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },

        // Android specific
        'android': {
          'priority': 'high',
          'ttl': '86400s', // 24 hours
          'notification': {
            'channel_id': _channelId,
            'priority': 'max',
            'icon': 'ic_notification',
            'color': '#4990E2',
            'tag': event.id, // Prevents duplicates with same ID
          },
        },
      };

      // Send the FCM request
      try {
        final response = await http.post(
          Uri.parse(_fcmApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=$_fcmServerKey',
          },
          body: json.encode(payload),
        );

        // Log response
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          final success = responseData['success'] ?? 0;
          return success > 0;
        } else {
          return false;
        }
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Show a local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // Generate a notification ID that's guaranteed to be within 32-bit int range
      // Use the last 6 digits of the timestamp to create a small, unique ID
      final int notificationId =
          (DateTime.now().millisecondsSinceEpoch % 1000000).toInt();

      await _localNotifications.show(
        notificationId,
        title,
        body,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            color: Color(0xFF4990E2),
            fullScreenIntent: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {}
  }

  /// Capitalize the first letter of a string
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Truncate a string to a maximum length
  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Check if the app was opened by a notification
  Future<void> _checkPendingNotifications() async {
    try {
      final launchData = await _secureStorage.read(
        key: 'app_launched_by_notification',
      );
      if (launchData != null) {
        // Clear the data to prevent re-processing
        await _secureStorage.delete(key: 'app_launched_by_notification');

        // Process if needed
        // This would be where you'd handle navigation or other app state changes
      }
    } catch (e) {}
  }

  // Enable notifications
  Future<void> enableNotifications() async {
    try {
      // Save the preference
      await _secureStorage.write(key: 'notifications_enabled', value: 'true');

      // Request permissions if needed
      await _requestPermissions();

      // Subscribe to topics
      await FirebaseMessaging.instance.subscribeToTopic('events');
      await FirebaseMessaging.instance.subscribeToTopic('campus_events');

      // For Android, ensure notification channel is created
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
            _localNotifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();

        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.max,
              enableVibration: true,
              playSound: true,
              enableLights: true,
            ),
          );
        }
      }

      _notificationsEnabled = true;
    } catch (e) {
      rethrow;
    }
  }

  // Disable notifications
  Future<void> disableNotifications() async {
    try {
      // Save the preference
      await _secureStorage.write(key: 'notifications_enabled', value: 'false');

      // Unsubscribe from topics
      await FirebaseMessaging.instance.unsubscribeFromTopic('events');
      await FirebaseMessaging.instance.unsubscribeFromTopic('campus_events');

      _notificationsEnabled = false;
    } catch (e) {
      rethrow;
    }
  }

  // Check if notifications are enabled
  bool get notificationsEnabled => _notificationsEnabled;

  // Show a local notification
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // Skip if notifications are disabled
      if (!_notificationsEnabled) {
        return;
      }

      // Android-specific notification details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            icon: 'ic_notification',
          );

      // iOS-specific notification details
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Platform-specific notification details
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show the notification
      await _localNotifications.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {}
  }
}

/// Helper function for min calculation
int min(int a, int b) => a < b ? a : b;

// Helper extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Helper function to format date
String formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}
