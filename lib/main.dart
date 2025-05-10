import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'controllers/event_controller.dart';
import 'controllers/campus_map_controller.dart';
import 'controllers/settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_constants.dart';
import 'core/utils/app_localization.dart';
import 'core/services/notification_service.dart';
import 'core/services/firebase_service.dart';
import 'views/splash/splash_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/register_screen.dart';
import 'views/auth/forgot_password_screen.dart';
import 'views/home/home_screen.dart';
import 'views/map/map_screen.dart';
import 'views/events/events_screen.dart';
import 'views/settings/settings_screen.dart';
import 'views/admin/admin_events_screen.dart';
import 'views/auth/email_verification_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:math';

/// Initialize Firebase App Check with retry mechanism to handle rate limiting
Future<void> _initializeAppCheckWithRetry({int attempt = 1}) async {
  try {
    // Maximum 5 retry attempts
    if (attempt > 5) {
      print(
        'Unable to initialize Firebase App Check after 5 attempts. Continuing without it.',
      );
      return;
    }

    // Initialize Firebase App Check
    await FirebaseAppCheck.instance.activate(
      // Use debug provider for all environments during testing
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    print('Firebase App Check initialized successfully on attempt $attempt');
  } catch (e) {
    if (e.toString().contains('Too many attempts')) {
      // Calculate backoff delay (exponential backoff with jitter)
      final baseDelay = 1000; // 1 second base
      final maxDelay = 10000; // 10 seconds max
      final exponentialDelay =
          baseDelay * (2 << (attempt - 1)); // 2^attempt seconds
      final jitter = Random().nextInt(500); // Add random jitter (0-500ms)
      final delay = min(exponentialDelay + jitter, maxDelay);

      print('App Check rate limited. Retrying in ${delay / 1000} seconds...');

      // Wait and retry
      await Future.delayed(Duration(milliseconds: delay));
      await _initializeAppCheckWithRetry(attempt: attempt + 1);
    } else {
      // For other errors, log but continue
      print('Error initializing Firebase App Check: $e');
    }
  }
}

/// Background message handler - must be a top-level function (not a class method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Need to initialize Firebase first
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase App Check in background with simpler retry
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } catch (e) {
    // If rate limited, try one more time after a short delay
    if (e.toString().contains('Too many attempts')) {
      try {
        await Future.delayed(Duration(seconds: 2));
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
      } catch (retryError) {
        // Ignore retry error and continue
        print('Background App Check activation retry failed: $retryError');
      }
    } else {
      // Ignore other errors and continue
      print('Background App Check activation failed: $e');
    }
  }

  // Process the notification in background
  try {
    // Initialize FlutterLocalNotificationsPlugin to display notification when app is in background
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Create Android channel for background notifications
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Campus event notifications',
      importance: Importance.max,
    );

    // Create the Android notification channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Show a local notification when in background
    if (message.notification != null) {
      // Extract notification and data
      final notification = message.notification!;
      final android = message.notification?.android;

      // Generate a notification ID that's guaranteed to be within 32-bit int range
      final int notificationId =
          (DateTime.now().millisecondsSinceEpoch % 1000000).toInt();

      // Show the notification
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        notification.title ?? 'New notification',
        notification.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: 'ic_notification',
            priority: Priority.max,
          ),
        ),
        payload: json.encode(message.data),
      );
    }

    // Store the notification data for retrieval when app opens
    if (message.data.isNotEmpty) {
      final storage = FlutterSecureStorage();
      await storage.write(
        key: 'last_notification_data',
        value: json.encode(message.data),
      );
    }
  } catch (e) {
    // Error handling
  }
}

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Initialize Firebase FIRST - with check to prevent duplicate initialization
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize Firebase App Check with retry mechanism
      await _initializeAppCheckWithRetry();
    } catch (e) {
      if (e.toString().contains('core/duplicate-app')) {
        // Firebase app already exists, continue with the flow
      } else {
        // Re-throw if it's a different error
        rethrow;
      }
    }

    // 2. Set background message handler IMMEDIATELY after Firebase initialization
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Request notification permissions immediately (important for iOS)
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

    // 4. Configure how notifications appear when app is in foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true, // Show notification popup
          badge: true, // Update app badge
          sound: true, // Play sound
        );

    // 5. Check for any notification that launched the app
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        // Store this information for use after app is fully initialized
        final FlutterSecureStorage storage = const FlutterSecureStorage();
        storage.write(
          key: 'app_launched_by_notification',
          value: json.encode(message.data),
        );
      }
    });

    // 6. Listen for notifications that open the app from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // You'll handle this in your app's state
    });

    // 7. Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // 8. Check for Remember Me setting
    await checkRememberMeAndSignOut();
  } catch (e) {
    // Error during initialization
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => SettingsController()),
        ChangeNotifierProvider(create: (_) => EventController()),
        ChangeNotifierProvider(create: (_) => CampusMapController()),
        Provider<FirebaseService>(create: (_) => FirebaseService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Check Remember Me setting for auto sign-out
Future<void> checkRememberMeAndSignOut() async {
  try {
    final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
    final rememberMe = await secureStorage.read(key: 'remember_me');

    // If Remember Me is explicitly set to false, clear any tokens
    if (rememberMe == 'false') {
      // Clear any saved user data
      await secureStorage.delete(key: 'user_id');
      await secureStorage.delete(key: 'user_email');
      await secureStorage.delete(key: 'user_data');

      // Force sign out at initialization
      await secureStorage.write(key: 'force_signout', value: 'true');
    }
  } catch (e) {
    // Error checking Remember Me status at startup
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AuthController _authController;
  late final FlutterSecureStorage _secureStorage;
  late final SettingsController _settingsController;
  late final NotificationService _notificationService;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _secureStorage = const FlutterSecureStorage();
    _authController = Provider.of<AuthController>(context, listen: false);
    _settingsController = Provider.of<SettingsController>(
      context,
      listen: false,
    );
    _notificationService = NotificationService();

    // Register app lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Initialize app controllers
    _initializeApp();

    // Set up notification listeners
    _setupNotificationListeners();
  }

  @override
  void dispose() {
    // Remove lifecycle observer when widget is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App lifecycle changed (background/foreground)
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground
      // Re-initialize the notification service if needed
      _notificationService.reinitialize();

      // Check for notifications that might have been missed
      _checkForNotificationData();
    } else if (state == AppLifecycleState.paused) {
      // App went to background
    } else if (state == AppLifecycleState.detached) {
      // App detached from UI (likely being terminated)

      // Ensure token is saved properly before termination
      _ensureTokenSaved();
    }
  }

  /// Set up listeners for notification events
  void _setupNotificationListeners() {
    // Listen for notifications opened when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationNavigation(message.data);
    });
  }

  /// Check for stored notification data
  Future<void> _checkForNotificationData() async {
    try {
      final notificationData = await _secureStorage.read(
        key: 'last_notification_data',
      );
      if (notificationData != null) {
        // Clear the data to prevent re-processing
        await _secureStorage.delete(key: 'last_notification_data');

        // Handle navigation
        _handleNotificationNavigation(json.decode(notificationData));
      }
    } catch (e) {
      // Error checking for notification data
    }
  }

  /// Handle navigation from a notification
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Only handle navigation when the app is fully initialized
    if (!_initialized) {
      return;
    }

    try {
      // Extract relevant information
      final String? type = data['type'];
      final String? id = data['id'];

      if (type == null || id == null) {
        return;
      }

      // Navigate based on notification type
      if (type == 'lecture' || type == 'event') {
        // Navigate to events screen
        Get.toNamed(AppConstants.eventsRoute);
      }
    } catch (e) {
      // Error handling notification navigation
    }
  }

  Future<void> _initializeApp() async {
    // Initialize controllers
    await _settingsController.init();
    await _authController.init();

    setState(() {
      _initialized = true;
    });

    // Check for notification data after initialization
    _checkForNotificationData();
  }

  /// Ensure the FCM token is saved before app termination
  Future<void> _ensureTokenSaved() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _secureStorage.write(key: 'fcm_device_token', value: token);
      }
    } catch (e) {
      // Error saving token before termination
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return Consumer<SettingsController>(
      builder: (context, settingsController, child) {
        // Determine initial route based on authentication status
        final String initialRoute =
            _authController.isAuthenticated
                ? AppConstants.homeRoute
                : AppConstants.loginRoute;

        return GetMaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settingsController.themeMode,
          translations: AppLocalization(),
          locale: Locale(settingsController.language),
          fallbackLocale: LocalizationService.enLocale,
          initialRoute: AppConstants.splashRoute,
          getPages: [
            GetPage(
              name: AppConstants.splashRoute,
              page: () => const SplashScreen(),
            ),
            GetPage(
              name: AppConstants.loginRoute,
              page: () => const LoginScreen(),
            ),
            GetPage(
              name: AppConstants.registerRoute,
              page: () => const RegisterScreen(),
            ),
            GetPage(
              name: AppConstants.forgotPasswordRoute,
              page: () => const ForgotPasswordScreen(),
            ),
            GetPage(
              name: AppConstants.emailVerificationRoute,
              page:
                  () => EmailVerificationScreen(
                    email: Get.arguments?['email'] ?? '',
                  ),
            ),
            GetPage(
              name: AppConstants.homeRoute,
              page: () => const HomeScreen(),
            ),
            GetPage(name: AppConstants.mapRoute, page: () => const MapScreen()),
            GetPage(
              name: AppConstants.eventsRoute,
              page: () => const EventsScreen(),
            ),
            GetPage(
              name: AppConstants.settingsRoute,
              page: () => const SettingsScreen(),
            ),
            GetPage(
              name: AppConstants.adminEventsRoute,
              page: () => const AdminEventsScreen(),
            ),
          ],
        );
      },
    );
  }
}
