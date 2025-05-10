import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/utils/app_localization.dart';

class SettingsController extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _darkMode = true; // Default to dark mode (Neo Campus theme)
  String _language = 'en'; // Default language
  bool _notificationsEnabled = true; // Default notifications setting

  bool get darkMode => _darkMode;
  String get language => _language;
  bool get notificationsEnabled => _notificationsEnabled;

  // Storage keys
  static const String _darkModeKey = 'dark_mode';
  static const String _languageKey = 'language';
  static const String _notificationsKey = 'notifications_enabled';

  // Initialize controller with stored settings
  Future<void> init() async {
    await _loadSettings();
  }

  // Load saved settings from secure storage
  Future<void> _loadSettings() async {
    try {
      // Load theme mode
      final storedDarkMode = await _secureStorage.read(key: _darkModeKey);
      if (storedDarkMode != null) {
        _darkMode = storedDarkMode == 'true';
      }

      // Load language
      final storedLanguage = await _secureStorage.read(key: _languageKey);
      if (storedLanguage != null) {
        _language = storedLanguage;
        LocalizationService.changeLocale(_language);
      }

      // Load notifications setting
      final storedNotifications = await _secureStorage.read(
        key: _notificationsKey,
      );
      if (storedNotifications != null) {
        _notificationsEnabled = storedNotifications == 'true';
      }

      notifyListeners();
    } catch (e) {
      // If there's an error, use defaults
    }
  }

  // Toggle dark mode
  Future<void> toggleDarkMode() async {
    _darkMode = !_darkMode;
    await _secureStorage.write(key: _darkModeKey, value: _darkMode.toString());
    notifyListeners();
  }

  // Set dark mode
  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _secureStorage.write(key: _darkModeKey, value: _darkMode.toString());
    notifyListeners();
  }

  // Set language
  Future<void> setLanguage(String languageCode) async {
    _language = languageCode;
    await _secureStorage.write(key: _languageKey, value: _language);
    LocalizationService.changeLocale(_language);
    notifyListeners();
  }

  // Toggle notifications
  Future<void> toggleNotifications() async {
    _notificationsEnabled = !_notificationsEnabled;
    await _secureStorage.write(
      key: _notificationsKey,
      value: _notificationsEnabled.toString(),
    );
    notifyListeners();
  }

  // Set notifications enabled
  Future<void> setNotifications(bool value) async {
    _notificationsEnabled = value;
    await _secureStorage.write(
      key: _notificationsKey,
      value: _notificationsEnabled.toString(),
    );
    notifyListeners();
  }

  // Get current theme data
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  // Get language name
  String get languageName => LocalizationService.getLanguageName(_language);
}
