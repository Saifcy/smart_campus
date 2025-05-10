import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../profile/profile_edit_screen.dart';
import '../../core/services/notification_service.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authController = Provider.of<AuthController>(context);
    final settingsController = Provider.of<SettingsController>(context);
    final user = authController.user;

    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr),
        elevation: 0,
        centerTitle: true,
        backgroundColor: isDarkMode ? AppTheme.darkNavy : Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDarkMode
                    ? [AppTheme.darkNavy, const Color(0xFF1A2B45)]
                    : [Colors.white, Colors.grey[100]!],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // User profile section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: isDarkMode ? const Color(0xFF1F2E45) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Profile picture with material design elevation
                    Material(
                      elevation: 4,
                      shape: const CircleBorder(),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.electricBlue.withOpacity(0.2),
                        backgroundImage:
                            user?.profilePhotoUrl != null
                                ? NetworkImage(user!.profilePhotoUrl!)
                                : null,
                        child:
                            user?.profilePhotoUrl == null
                                ? const Icon(
                                  Icons.person_rounded,
                                  size: 40,
                                  color: AppTheme.electricBlue,
                                )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Username
                    Text(
                      user?.username ?? 'User',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Email
                    Text(
                      user?.email ?? 'Email',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Edit profile button
                    OutlinedButton.icon(
                      onPressed: () {
                        // Navigate to edit profile screen
                        Get.to(() => const ProfileEditScreen());
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(
                        'Edit Profile',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.electricBlue,
                        side: const BorderSide(color: AppTheme.electricBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Theme settings with Google Maps style
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: isDarkMode ? const Color(0xFF1F2E45) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 22,
                          color: AppTheme.electricBlue,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Appearance',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Dark mode switch
                  SwitchListTile(
                    value: settingsController.darkMode,
                    onChanged: (value) {
                      settingsController.setDarkMode(value);
                    },
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (settingsController.darkMode
                                ? Colors.indigo
                                : Colors.amber)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        settingsController.darkMode
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color:
                            settingsController.darkMode
                                ? Colors.indigo
                                : Colors.amber,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      'dark_mode'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Switch between light and dark theme',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    activeColor: AppTheme.electricBlue,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Language settings with Google Maps style
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: isDarkMode ? const Color(0xFF1F2E45) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.translate_rounded,
                          size: 22,
                          color: AppTheme.electricBlue,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'language'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Language selector
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.language_rounded,
                              color: Colors.blue,
                              size: 22,
                            ),
                          ),
                          title: const Text(
                            'App Language',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            settingsController.language == 'en'
                                ? 'English'
                                : 'Arabic',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildLanguageOption(
                                title: 'English',
                                flag: '🇺🇸',
                                isSelected: settingsController.language == 'en',
                                onTap: () {
                                  settingsController.setLanguage('en');
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildLanguageOption(
                                title: 'العربية',
                                flag: '🇪🇬',
                                isSelected: settingsController.language == 'ar',
                                onTap: () {
                                  settingsController.setLanguage('ar');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notifications settings
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: isDarkMode ? const Color(0xFF1F2E45) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 22,
                          color: AppTheme.electricBlue,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'notifications'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Notifications switch
                  SwitchListTile(
                    value: settingsController.notificationsEnabled,
                    onChanged: (value) async {
                      // Update the controller setting first
                      settingsController.setNotifications(value);

                      // Get access to notification service
                      final notificationService =
                          Provider.of<NotificationService>(
                            context,
                            listen: false,
                          );

                      try {
                        // Toggle notification service state
                        if (value) {
                          // Enable notifications
                          await notificationService.enableNotifications();

                          // Try to subscribe to topics for FCM
                          final firebaseService = Provider.of<FirebaseService>(
                            context,
                            listen: false,
                          );
                          await firebaseService.subscribeToTopic('events');
                          await firebaseService.subscribeToTopic(
                            'campus_events',
                          );

                          // Show success message
                          Get.snackbar(
                            'Notifications Enabled',
                            'You will now receive campus updates',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            margin: const EdgeInsets.all(10),
                            borderRadius: 10,
                            duration: const Duration(seconds: 2),
                          );

                          // For testing, send a test notification
                          await notificationService.showLocalNotification(
                            id: Random().nextInt(1000000),
                            title: 'Notifications Enabled',
                            body:
                                'You will now receive updates about campus events.',
                            payload: 'notification_test',
                          );
                        } else {
                          // Disable notifications
                          await notificationService.disableNotifications();

                          // Try to unsubscribe from topics
                          final firebaseService = Provider.of<FirebaseService>(
                            context,
                            listen: false,
                          );
                          await firebaseService.unsubscribeFromTopic('events');
                          await firebaseService.unsubscribeFromTopic(
                            'campus_events',
                          );

                          // Show confirmation
                          Get.snackbar(
                            'Notifications Disabled',
                            'Notifications turned off',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.grey,
                            colorText: Colors.white,
                            margin: const EdgeInsets.all(10),
                            borderRadius: 10,
                            duration: const Duration(seconds: 2),
                          );
                        }

                        // Force refresh UI
                        setState(() {});
                      } catch (e) {

                        // Show error message
                        Get.snackbar(
                          'Notification Error',
                          'Could not change notification settings',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          margin: const EdgeInsets.all(10),
                          borderRadius: 10,
                          duration: const Duration(seconds: 2),
                        );
                      }
                    },
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (settingsController.notificationsEnabled
                                ? Colors.green
                                : Colors.grey)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        settingsController.notificationsEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        color:
                            settingsController.notificationsEnabled
                                ? Colors.green
                                : Colors.grey,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      'notifications'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Receive push notifications for events and updates',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    activeColor: AppTheme.electricBlue,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Security settings with Google Maps style
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: isDarkMode ? const Color(0xFF1F2E45) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 22,
                          color: AppTheme.electricBlue,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Security',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Change Password option
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.blue,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      'Change Password',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Update your account password',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to forgot password screen
                      Get.toNamed(AppConstants.forgotPasswordRoute);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Admin section
            if (user?.email == 'demo@example.com' ||
                user?.email?.endsWith('@admin.com') == true)
              const SizedBox.shrink(),

            // Logout button
            ElevatedButton.icon(
              onPressed: () async {
                await authController.signOut();
                Get.offAllNamed(AppConstants.loginRoute);
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                'logout'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.electricBlue.withOpacity(isDarkMode ? 0.2 : 0.1)
                  : isDarkMode
                  ? Colors.transparent
                  : Colors.grey[100],
          border: Border.all(
            color: isSelected ? AppTheme.electricBlue : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.electricBlue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
