import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/event_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/notification_service.dart';
import '../../models/event_model.dart';
import '../map/map_screen.dart';
import '../events/events_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription<EventModel>? _notificationSubscription;
  late final NotificationService _notificationService;
  
  final List<Widget> _screens = [
    const MapScreen(),
    const EventsScreen(),
    const SettingsScreen(),
  ];
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    
    // Check authentication
    _checkAuthentication();
    
    // Listen for new notifications
    _subscribeToNotifications();
    
    // Initialize the event controller to start background checks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eventController = Provider.of<EventController>(context, listen: false);
      eventController.init();
    });
  }
  
  void _subscribeToNotifications() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }
  
  void _showNotification(EventModel event) {
    // Only show if mounted and context is available
    if (!mounted) {
      return;
    }    
    // Show a non-intrusive snackbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New ${event.type}: ${event.title} at ${event.location}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: event.type == 'lecture' 
                ? Colors.deepPurple.shade700 
                : Colors.blue.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to the events screen
                setState(() {
                  _selectedIndex = 1; // Index of EventsScreen
                });
              },
            ),
          ),
        );
        debugPrint('✅ In-app notification displayed for: ${event.title}');
      } catch (e) {
        debugPrint('❌ Error showing notification: $e');
      }
    });
  }
  
  void _checkAuthentication() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController = Provider.of<AuthController>(context, listen: false);
      if (!authController.isAuthenticated) {
        // If not authenticated, redirect to login
        Get.offAllNamed('/login');
      }
    });
  }
  
  @override
  void dispose() {
    // Cancel notification subscription when the widget is disposed
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: isDarkMode
              ? const Color(0xFF1A2B45)
              : Colors.white,
          selectedItemColor: AppTheme.electricBlue,
          unselectedItemColor: isDarkMode ? Colors.grey[500] : Colors.grey[700],
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.map_outlined),
              activeIcon: const Icon(Icons.map),
              label: 'map'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_today_outlined),
              activeIcon: const Icon(Icons.calendar_today),
              label: 'calendar'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: 'settings'.tr,
            ),
          ],
        ),
      ),
    );
  }
} 