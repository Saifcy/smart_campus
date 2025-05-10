import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/services/firebase_service.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/app_constants.dart';
import '../core/utils/serialization_helpers.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:async';

// String extension for capitalized text
extension StringExtension on String {
  String toCapitalized() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : '';
}

// Define the UserModel extension for copyWith
extension UserModelExtension on UserModel {
  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? grade,
    String? department,
    String? profilePhotoUrl,
    DateTime? createdAt,
    bool? emailVerified,
    bool? isAdmin,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      grade: grade ?? this.grade,
      department: department ?? this.department,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      emailVerified: emailVerified ?? this.emailVerified,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}

class AuthController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  UserModel? _user;
  String? _error;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _rememberMe = false;
  bool _isDisposed = false;
  StreamSubscription? _authStateSubscription;

  // For Google sign-in
  String? _googleEmail;

  // Persistence keys
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userDataKey = 'user_data';
  static const String _rememberMeKey = 'remember_me';

  // Add these constants for storing complete user session data
  static const String _userTokenKey = 'user_token';
  static const String _userSessionKey = 'user_session';
  static const String _lastLoginTimeKey = 'last_login_time';
  static const String _sessionExpiryKey = 'session_expiry';

  // Getters
  UserModel? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;

  // For testing purposes
  FirebaseService get firebaseService => _firebaseService;

  // Initialize controller and listen to auth state changes
  Future<void> init() async {
    try {
      // First, try to restore the session from local storage
      final bool sessionRestored = await _tryRestoreLocalSession();

      if (sessionRestored) {
        // If we restored the session from local storage, we don't need to continue
        _isInitialized = true;
        notifyListeners();
        return;
      }

      // If local session restoration failed, fall back to the regular flow
      final forceSignout = await _secureStorage.read(key: 'force_signout');
      final isForceSignout = forceSignout == 'true';

      // Check if Remember Me is enabled
      final isRememberMe = await isRememberMeEnabled();

      // Get the current Firebase user
      final currentUser = FirebaseAuth.instance.currentUser;

      // Only force sign out if Remember Me is explicitly disabled AND force signout is set
      if ((!isRememberMe && isForceSignout) || isForceSignout) {
        // Clear saved data
        await _clearAllUserData();

        // Sign out from Firebase if user is signed in
        if (currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }

        // Clear the force signout flag
        await _secureStorage.delete(key: 'force_signout');

        _user = null;
        _isAuthenticated = false;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      // If we have a Firebase user but Remember Me wasn't explicitly set, default to true
      if (currentUser != null &&
          await _secureStorage.read(key: _rememberMeKey) == null) {
        await _secureStorage.write(key: _rememberMeKey, value: 'true');
      }

      // Only set up auth state listener if Remember Me is true
      if (isRememberMe) {
        // Listen for auth state changes but with reduced frequency
        _setupAuthStateListener();
      }

      // Try to load user from Firebase or storage
      if (currentUser != null) {
        await _loadUserData(currentUser.uid);

        // Save the session data for future local restoration
        await _saveLocalSession(currentUser);
      } else {
        // Try to load from storage as fallback
        await _loadUserFromStorage();
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Set up auth state listener with reduced frequency
  void _setupAuthStateListener() {
    // Cancel any existing subscription
    _authStateSubscription?.cancel();

    // Subscribe to auth state changes with a debounce
    _authStateSubscription = _firebaseService.authStateChanges
    // .debounce(Duration(seconds: 5)) // Only process changes every 5 seconds
    .listen(_handleAuthStateChange);
  }

  // Handle Firebase auth state changes
  void _handleAuthStateChange(User? firebaseUser) async {
    try {
      // Skip processing if we're in the middle of another operation
      if (_isLoading) return;

      // Get the user's remember me preference
      final rememberMe = await _secureStorage.read(key: _rememberMeKey);
      final isRememberMe = rememberMe == 'true';

      // If Remember Me is false, don't process auth state changes at all
      if (!isRememberMe) return;

      if (firebaseUser == null) {
        // User is signed out, but check if we have a valid local session before clearing
        final hasLocalSession = await _tryRestoreLocalSession();

        // If we restored a local session, don't clear anything
        if (hasLocalSession) return;

        // No local session, user is truly signed out
        _user = null;
        _isAuthenticated = false;

        // Only navigate to login if we're not already there and there's a route context
        if (Get.currentRoute != AppConstants.loginRoute &&
            Get.currentRoute != AppConstants.splashRoute) {
          Get.offAllNamed(AppConstants.loginRoute);
        }

        notifyListeners();
        return;
      }

      // Don't reload Firebase user too frequently to avoid "too many attempts" errors
      final lastLoginTimeStr = await _secureStorage.read(
        key: _lastLoginTimeKey,
      );
      if (lastLoginTimeStr != null) {
        final lastLoginTime = DateTime.parse(lastLoginTimeStr);
        final timeSinceLastLogin = DateTime.now().difference(lastLoginTime);

        // If we've checked within the last 30 minutes, don't reload the user
        if (timeSinceLastLogin.inMinutes < 30) {
          debugPrint('Skipping Firebase user reload - checked recently');
          return;
        }
      }

      // Only reload user occasionally
      try {
        await firebaseUser.reload();
      } catch (e) {
        // If reload fails, just use the current state
        debugPrint('Firebase user reload failed: $e');
      }

      // Check if email is verified
      final isEmailVerified = firebaseUser.emailVerified;

      // Save the current time as last login time
      await _secureStorage.write(
        key: _lastLoginTimeKey,
        value: DateTime.now().toIso8601String(),
      );

      // User is signed in, try to load their data
      try {
        final userDoc = await _firebaseService.getDocument(
          collection: AppConstants.usersCollection,
          documentId: firebaseUser.uid,
        );

        if (userDoc.exists) {
          // Save user data to secure storage for Remember Me
          await _saveUserData(userDoc);

          // Convert Firestore data to UserModel
          final userData = userDoc.data() as Map<String, dynamic>;
          userData['id'] = firebaseUser.uid; // Ensure ID is set

          // Check if user is an admin
          final bool isAdmin = userData['isAdmin'] ?? false;
          final bool isAdminEmail =
              firebaseUser.email?.endsWith('admin.com') ?? false;

          // Automatically consider admin users as verified
          final bool effectivelyVerified =
              isEmailVerified || isAdmin || isAdminEmail;

          // Update emailVerified field with latest status from Firebase or admin status
          userData['emailVerified'] = effectivelyVerified;

          // Update Firestore document with latest verification status if needed
          if ((isEmailVerified != userData['emailVerified']) ||
              (isAdmin && !userData['emailVerified']) ||
              (isAdminEmail && !userData['emailVerified'])) {
            await _firebaseService.updateDocument(
              collection: AppConstants.usersCollection,
              documentId: firebaseUser.uid,
              data: {
                'emailVerified': effectivelyVerified,
                'accountStatus': 'active',
              },
            );
          }

          _user = UserModel.fromMap(userData);

          // Admin users are always considered authenticated
          _isAuthenticated = effectivelyVerified;

          // Save the authentication state
          await _secureStorage.write(key: 'user_authenticated', value: 'true');

          // Save session for local restoration
          await _saveLocalSession(firebaseUser);

          // Only redirect if we're not already on the right page and not in an operation
          if (!_isLoading &&
              effectivelyVerified &&
              Get.currentRoute != AppConstants.homeRoute &&
              Get.currentRoute != AppConstants.splashRoute) {
            Get.offAllNamed(AppConstants.homeRoute);
          }
          // If not verified and not already on verification screen, redirect there
          else if (!_isLoading &&
              !effectivelyVerified &&
              !Get.currentRoute.contains(AppConstants.emailVerificationRoute) &&
              Get.currentRoute != AppConstants.splashRoute) {
            Get.offAllNamed(
              AppConstants.emailVerificationRoute,
              arguments: {'email': firebaseUser.email ?? ''},
            );
          }
        } else {
          // Skip creating documents in the background - let the explicit sign-in do that
          debugPrint(
            'User exists in Auth but not in Firestore - waiting for explicit sign-in',
          );
        }
      } catch (e) {
        // Log but don't crash on background Firestore errors
        debugPrint('Error in auth state change: $e');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error in auth state change: $e');
    }
  }

  // Method to try restoring user session from local storage without Firebase
  Future<bool> _tryRestoreLocalSession() async {
    try {
      // Check if Remember Me is enabled - if not, don't try to restore
      final rememberMe = await _secureStorage.read(key: _rememberMeKey);
      if (rememberMe != 'true') return false;

      // Check if we have a session stored
      final userData = await _secureStorage.read(key: _userDataKey);
      final sessionExpiry = await _secureStorage.read(key: _sessionExpiryKey);

      if (userData == null || sessionExpiry == null) return false;

      // Check if the session has expired
      final expiryTime = DateTime.parse(sessionExpiry);
      if (DateTime.now().isAfter(expiryTime)) {
        // Session expired, clean up and don't restore
        await _clearAllUserData();
        return false;
      }

      // Session is valid - restore it
      final userMap = jsonDecode(userData) as Map<String, dynamic>;

      // Convert createdAt string to DateTime if needed
      if (userMap['createdAt'] != null) {
        userMap['createdAt'] = _convertToDateTime(userMap['createdAt']);
      }

      // Create user model
      _user = UserModel.fromMap(userMap);
      _isAuthenticated = true;

      // Extend session expiry time (add 7 days from now)
      await _updateSessionExpiry();

      debugPrint('✅ Successfully restored user session from local storage');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error restoring local session: $e');
      return false;
    }
  }

  // Save complete user session data locally
  Future<void> _saveLocalSession(User firebaseUser) async {
    try {
      // Check if Remember Me is enabled
      final rememberMe = await _secureStorage.read(key: _rememberMeKey);
      if (rememberMe != 'true') return;

      // Get user token for offline validation later
      final token = await firebaseUser.getIdToken();

      // Save token
      await _secureStorage.write(key: _userTokenKey, value: token);

      // Save last login time
      await _secureStorage.write(
        key: _lastLoginTimeKey,
        value: DateTime.now().toIso8601String(),
      );

      // Set session expiry (7 days from now)
      await _updateSessionExpiry();

      // Also save user session data (more complete than just the token)
      final sessionData = {
        'uid': firebaseUser.uid,
        'email': firebaseUser.email,
        'displayName': firebaseUser.displayName,
        'photoURL': firebaseUser.photoURL,
        'emailVerified': firebaseUser.emailVerified,
      };

      await _secureStorage.write(
        key: _userSessionKey,
        value: jsonEncode(sessionData),
      );

      debugPrint('✅ Saved user session data locally for Remember Me');
    } catch (e) {
      debugPrint('⚠️ Error saving local session: $e');
    }
  }

  // Update session expiry time
  Future<void> _updateSessionExpiry() async {
    // Set session expiry (7 days from now)
    final expiryTime = DateTime.now().add(Duration(days: 7));
    await _secureStorage.write(
      key: _sessionExpiryKey,
      value: expiryTime.toIso8601String(),
    );
  }

  // Load user data from secure storage
  Future<void> _loadUserFromStorage() async {
    try {
      final userData = await _secureStorage.read(key: 'user_data');
      final rememberMe = await _secureStorage.read(key: 'remember_me');

      // Set remember me state
      _rememberMe = rememberMe == 'true';

      if (userData != null) {
        final userMap = jsonDecode(userData) as Map<String, dynamic>;

        // Convert createdAt string to DateTime if needed
        if (userMap['createdAt'] != null) {
          userMap['createdAt'] = _convertToDateTime(userMap['createdAt']);
        }

        // Create user model
        _user = UserModel.fromMap(userMap);
        _isAuthenticated = true;
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  // Try to sign in with stored credentials
  Future<void> _tryAutoLogin() async {
    try {
      final forceSignout = await _secureStorage.read(key: 'force_signout');
      if (forceSignout == 'true') {
        await _secureStorage.delete(key: 'force_signout');
        return;
      }

      // Auto login is already handled by Firebase Auth persistence
      // So we don't need to do anything here
    } catch (e) {
      _error = e.toString();
    }
  }

  // Save user data to secure storage
  Future<void> _saveUserData([DocumentSnapshot? userDoc]) async {
    try {
      if (userDoc != null) {
        // Save user data from document snapshot
        final userData = userDoc.data() as Map<String, dynamic>;
        userData['id'] = userDoc.id; // Ensure ID is included

        _user = UserModel.fromMap(userData);

        await _secureStorage.write(
          key: _userDataKey,
          value: jsonEncode(_user!.toMap()),
        );
      } else if (_user != null) {
        // Save data from current user model
        await _secureStorage.write(
          key: _userDataKey,
          value: jsonEncode(_user!.toMap()),
        );
      } else {
        return;
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  // Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    required String grade,
    required String department,
    File? profilePhoto,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if email is an admin email
      final bool isAdmin = email.endsWith('admin.com');

      // Sign up with Firebase
      await _firebaseService.signUp(
        email: email,
        password: password,
        username: username,
        grade: grade,
        department: department,
        profilePhoto: profilePhoto,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Helper method to load user data
  Future<void> _loadUserData(String userId) async {
    try {
      // Get user document from Firestore
      final userDoc = await _firebaseService.getDocument(
        collection: AppConstants.usersCollection,
        documentId: userId,
      );

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        userData['id'] = userId; // Add ID to the data

        // Update the user model
        _user = UserModel.fromMap(userData);
        _isAuthenticated = true;

        // Save user data to secure storage (regardless of Remember Me, we need it while the app is running)
        await _secureStorage.write(
          key: _userDataKey,
          value: jsonEncode(_user!.toMap()),
        );

        // Save user ID for quick access
        await _secureStorage.write(key: _userIdKey, value: userId);
      } else {
        throw Exception('User data not found');
      }
    } catch (e) {
      throw Exception('Failed to load user data: $e');
    }
  }

  // Helper method to convert Firebase errors to user-friendly messages
  String _getErrorMessage(dynamic error) {
    String errorMessage = 'An unknown error occurred';

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'email-already-in-use':
          errorMessage = 'This email is already registered.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'This operation is not allowed.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Check your connection.';
          break;
        default:
          errorMessage = 'Error: ${error.message}';
      }
    } else {
      errorMessage = error.toString();
    }

    return errorMessage;
  }

  // Sign in user
  Future<bool> signIn(String email, String password, bool rememberMe) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Save Remember Me preference - do this first and clearly
      await _secureStorage.write(
        key: _rememberMeKey,
        value: rememberMe.toString(),
      );

      // If Remember Me is disabled, make sure to clear the force signout flag
      // because we're explicitly logging in now
      await _secureStorage.delete(key: 'force_signout');

      // Attempt sign in
      final userCredential = await _firebaseService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Authentication failed');
      }

      // Mark as authenticated regardless of Remember Me setting
      await _secureStorage.write(key: 'user_authenticated', value: 'true');

      // Load and save user data
      await _loadUserData(userCredential.user!.uid);

      // If Remember Me is enabled, save the complete session locally
      if (rememberMe) {
        await _saveLocalSession(userCredential.user!);
      }

      _isLoading = false;
      notifyListeners();

      // Check if user's email is verified before navigating
      if (_user != null && _user!.emailVerified) {
        // Navigate to home screen after successful login
        Get.offAllNamed(AppConstants.homeRoute);
      } else if (_user != null) {
        // Navigate to email verification screen if email is not verified
        Get.offAllNamed(
          AppConstants.emailVerificationRoute,
          arguments: {'email': email},
        );
      }

      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign out user
  Future<bool> signOut() async {
    try {
      // Get the current user ID before signing out
      final userId = _user?.id;

      // Clear all user data regardless of Remember Me setting on explicit sign out
      await _clearAllUserData();

      // Sign out from Firebase
      await _firebaseService.signOut();

      // Clear user data
      _user = null;
      _isAuthenticated = false;

      // Set force signout flag to prevent auto login on restart
      await _secureStorage.write(key: 'force_signout', value: 'true');

      _error = null;
      notifyListeners();

      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  // Helper method to clear all user data from secure storage
  Future<void> _clearAllUserData() async {
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _userEmailKey);
    await _secureStorage.delete(key: _userDataKey);
    await _secureStorage.delete(key: 'user_authenticated');
    await _secureStorage.delete(key: _userTokenKey);
    await _secureStorage.delete(key: _userSessionKey);
    await _secureStorage.delete(key: _lastLoginTimeKey);
    await _secureStorage.delete(key: _sessionExpiryKey);
  }

  // Sign in with Google
  Future<bool> signInWithGoogle({required bool rememberMe}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Save Remember Me setting
      await _secureStorage.write(
        key: _rememberMeKey,
        value: rememberMe.toString(),
      );

      // Sign in with Google
      final userCredential = await _firebaseService.signInWithGoogle();

      // Get user data from Firestore or create if new
      if (userCredential.user != null) {
        await _loadUserData(userCredential.user!.uid);

        // Set as authenticated
        _isAuthenticated = true;

        // If Remember Me is enabled, save the complete session locally
        if (rememberMe) {
          await _saveLocalSession(userCredential.user!);
        }

        // Navigate to home screen
        Get.offAllNamed(AppConstants.homeRoute);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.resetPassword(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Check if email is verified
  Future<bool> isEmailVerified() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Reload the user to get the latest verification status
      final user = _firebaseService.currentUser;
      if (user != null) {
        // Force refresh token and reload user
        await user.getIdToken(true);
        await user.reload();

        final isVerified = user.emailVerified;

        if (isVerified && _user != null) {
          // Update the user model with the new verification status
          _user = _user!.copyWith(emailVerified: true);

          // Update Firestore
          await _firebaseService.updateDocument(
            collection: AppConstants.usersCollection,
            documentId: _user!.id,
            data: {'emailVerified': true, 'accountStatus': 'active'},
          );

          _isAuthenticated = true;
          notifyListeners();

          debugPrint('✅ Email verification confirmed and user status updated');
        }

        _isLoading = false;
        notifyListeners();
        return isVerified;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Send email verification
  Future<bool> sendEmailVerification() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.sendEmailVerification();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? username,
    String? grade,
    String? department,
    File? profilePhoto,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Prepare update data
      final Map<String, dynamic> updateData = {};

      if (username != null && username.isNotEmpty) {
        updateData['username'] = username;
      }

      if (grade != null) {
        updateData['grade'] = grade;
      }

      if (department != null) {
        updateData['department'] = department;
      }

      // Upload profile photo if provided
      if (profilePhoto != null) {
        final photoUrl = await _firebaseService.uploadProfilePhoto(
          userId: _user!.id,
          file: profilePhoto,
        );

        updateData['profilePhotoUrl'] = photoUrl;
      }

      // Update Firestore document
      if (updateData.isNotEmpty) {
        await _firebaseService.updateDocument(
          collection: AppConstants.usersCollection,
          documentId: _user!.id,
          data: updateData,
        );

        // Update local user model
        _user = _user!.copyWith(
          username: username ?? _user!.username,
          grade: grade ?? _user!.grade,
          department: department ?? _user!.department,
          profilePhotoUrl:
              profilePhoto != null
                  ? updateData['profilePhotoUrl']
                  : _user!.profilePhotoUrl,
        );

        notifyListeners();
      }

      _isLoading = false;
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Clear errors
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Verify email with code
  Future<bool> verifyEmailWithCode({
    required String email,
    required String code,
  }) async {
    if (email.isEmpty || code.isEmpty) {
      _error = 'Email and verification code are required';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // This would be a real verification in a production app
      // For now, we'll just simulate success with the code "123456"
      bool success = code == "123456";

      if (success) {
        // Mark the user as verified in Firestore if we have their ID
        final user = _firebaseService.currentUser;
        if (user != null) {
          await _firebaseService.updateDocument(
            collection: AppConstants.usersCollection,
            documentId: user.uid,
            data: {'emailVerified': true},
          );
        }
      } else {
        _error = 'Invalid verification code';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Resend verification code
  Future<bool> resendVerificationCode(String email) async {
    if (email.isEmpty) {
      _error = 'Email is required';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.sendEmailVerification();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void notifyListeners() {
    // Avoid notifying if disposed
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  // Helper method to convert Timestamp to DateTime safely
  DateTime? _convertToDateTime(dynamic timestamp) {
    return SerializationHelpers.parseDateTime(timestamp);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authStateSubscription?.cancel();
    super.dispose();
  }

  // Helper method to format auth errors
  String _formatAuthError(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return error.toString();
  }

  // Helper method to create a user document
  Future<void> _createUserDocument(User user, String email) async {
    await _firebaseService.createDocument(
      collection: AppConstants.usersCollection,
      documentId: user.uid,
      data: {
        'id': user.uid,
        'email': email,
        'username': email.split('@')[0],
        'grade': 'Not specified',
        'department': 'Not specified',
        'profilePhotoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': user.emailVerified,
        'isAdmin': email.endsWith('admin.com'),
        'accountStatus': 'active',
      },
    );
  }

  // Helper method to get new user data
  Future<Map<String, dynamic>> _getNewUserData(User user) async {
    return {
      'id': user.uid,
      'email': user.email ?? '',
      'username': user.displayName ?? user.email?.split('@')[0] ?? 'User',
      'grade': 'Not specified',
      'department': 'Not specified',
      'profilePhotoUrl': user.photoURL,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'emailVerified': user.emailVerified,
      'isAdmin': user.email?.endsWith('admin.com') ?? false,
      'accountStatus': 'active',
    };
  }

  // Check if MFA verification is complete - simplified version that always returns true
  Future<bool> isMfaVerified() async {
    try {
      if (_user == null) {
        return false;
      }

      // This is a simplified implementation that always returns true
      // Replace with actual MFA verification if needed in the future
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if Remember Me is enabled
  Future<bool> isRememberMeEnabled() async {
    final rememberMe = await _secureStorage.read(key: _rememberMeKey);
    return rememberMe == 'true';
  }

  // Set Remember Me state
  Future<void> setRememberMe(bool value) async {
    await _secureStorage.write(key: _rememberMeKey, value: value.toString());
  }
}
