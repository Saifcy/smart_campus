import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import '../utils/app_constants.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

class FirebaseService {
  // Firebase instances
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  late final FirebaseStorage _storage;
  late final GoogleSignIn _googleSignIn;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Track if user explicitly signed out
  bool _isSignedOut = false;
  bool get isSignedOut => _isSignedOut;

  // Constructor
  FirebaseService() {
    // Initialize authentication service
    _auth = FirebaseAuth.instance;

    // Try to ensure App Check is initialized
    _initializeAppCheck();

    // Initialize Cloud Firestore
    _firestore = FirebaseFirestore.instance;

    // Initialize Firebase Storage
    _storage = FirebaseStorage.instance;

    // Initialize Google Sign In
    _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  }

  // Make sure App Check is properly initialized
  Future<void> _initializeAppCheck() async {
    try {
      // Check if App Check is already initialized
      final appCheck = FirebaseAppCheck.instance;
      if (appCheck.app != null) {
        try {
          // Force activate app check with debug provider
          await appCheck.activate(
            androidProvider: AndroidProvider.debug,
            appleProvider: AppleProvider.debug,
          );
        } catch (activationError) {
          if (activationError.toString().contains('Too many attempts')) {
            // Don't retry here, just log and continue - main.dart handles this better
          } else {
          }
        }
      }
    } catch (e) {
    }
  }

  // Authentication methods

  // Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String username,
    required String grade,
    required String department,
    File? profilePhoto,
  }) async {
    try {
      // Reset sign out flag
      _isSignedOut = false;

      // Create user account with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Add user information to Firestore
      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;

        // Create user document in Firestore
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .set({
              'id': userId,
              'email': email,
              'username': username,
              'grade': grade,
              'department': department,
              'profilePhotoUrl': null,
              'createdAt': FieldValue.serverTimestamp(),
              'emailVerified': false,
              'isAdmin': email.endsWith('admin.com'),
            });

        // Upload profile photo if provided
        if (profilePhoto != null) {
          final photoUrl = await uploadProfilePhoto(
            userId: userId,
            file: profilePhoto,
          );

          // Update user document with profile photo URL
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userId)
              .update({'profilePhotoUrl': photoUrl});
        }

        // Send email verification
        await userCredential.user!.sendEmailVerification();
      }

      return userCredential;
    } catch (e) {
      throw _handleFirebaseAuthError(e);
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Reset sign out flag
      _isSignedOut = false;

      // Try to reduce firebase reCAPTCHA errors
      await Future.delayed(const Duration(milliseconds: 500));

      // Sign in with Firebase Auth with persistence
      final userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw FirebaseAuthException(
                code: 'timeout',
                message:
                    'Login request timed out. Please check your internet connection.',
              );
            },
          );

      // Store email for remember me functionality if needed
      await _secureStorage.read(key: 'remember_me').then((rememberMe) {
        if (rememberMe == 'true') {
          _secureStorage.write(key: 'saved_email', value: email);
        }
      });

      return userCredential;
    } catch (e) {
      // Special handling for network errors
      if (e.toString().contains('network')) {
        // Network error handling logic
      }

      // Special handling for credential errors
      if (e.toString().contains('credential')) {
        // Check if the user exists first before reporting wrong password
        try {
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          if (methods.isEmpty) {
            throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'No user found with this email address',
            );
          }
        } catch (_) {
          // Ignore errors from this check
        }
      }

      throw _handleFirebaseAuthError(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _isSignedOut = true;
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleFirebaseAuthError(e);
    }
  }

  // Get document from Firestore
  Future<DocumentSnapshot> getDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      return await _firestore.collection(collection).doc(documentId).get();
    } catch (e) {
      throw Exception('Failed to get document: $e');
    }
  }

  // Get collection from Firestore
  Future<QuerySnapshot> getCollection({
    required String collection,
    List<List<dynamic>> filters = const [],
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      // Apply filters if any
      for (final filter in filters) {
        if (filter.length == 3) {
          query = query.where(
            filter[0],
            isEqualTo: filter[1] == '==' ? filter[2] : null,
          );
        }
      }

      // Apply ordering if specified
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      // Apply limit if specified
      if (limit != null) {
        query = query.limit(limit);
      }

      return await query.get();
    } catch (e) {
      throw Exception('Failed to get collection: $e');
    }
  }

  // Upload profile photo
  Future<String> uploadProfilePhoto({
    required String userId,
    required File file,
  }) async {
    try {
      // Create reference to the file location in Firebase Storage
      final storageRef = _storage.ref().child(
        '${AppConstants.profilePhotosStorage}/$userId.jpg',
      );

      // Upload file
      await storageRef.putFile(file);

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile photo: $e');
    }
  }

  // Create a document in Firestore
  Future<void> createDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).set(data);
    } catch (e) {
      throw Exception('Failed to create document: $e');
    }
  }

  // Update a document in Firestore
  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).update(data);
    } catch (e) {
      throw Exception('Failed to update document: $e');
    }
  }

  // Delete a document from Firestore
  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  // Authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      throw Exception('Failed to send email verification: $e');
    }
  }

  // Check if email verification is complete
  Future<bool> isEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Reload user to get the latest info
        await user.reload();
        return user.emailVerified;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Reset sign out flag
      _isSignedOut = false;

      // Clear any previous Google sign-in state to avoid silent sign-in with previous account
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        // Continue anyway, this isn't critical
      }

      // Try to verify if Google Play Services is available before proceeding
      if (Platform.isAndroid) {
        try {
          await _googleSignIn.isSignedIn();
        } catch (e) {
          if (e.toString().contains(
            'com.google.android.gms.common.api.ApiException',
          )) {
            throw Exception(
              'Google Play Services issue detected. Please ensure Google Play Services is updated on your device and try again.',
            );
          }
        }
      }

      // Use a try-catch specifically for the sign-in call to better handle API exceptions
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn().timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            throw Exception('Google sign-in timed out. Please try again.');
          },
        );
      } catch (signInError) {
        // Check specifically for API exception 10
        if (signInError.toString().contains('ApiException: 10')) {
          throw Exception(
            'Google Play Services error: The developers console project is not properly configured. Please ensure Google Sign In is enabled in Firebase console and SHA certificate fingerprints are correctly set up.',
          );
        }

        // Check for other common API exceptions
        if (signInError.toString().contains('ApiException')) {
          throw Exception(
            'Google Play Services error. Please ensure Google Play Services is updated on your device and try again.',
          );
        }

        // Rethrow other errors
        throw signInError;
      }

      // Handle user cancellation
      if (googleUser == null) {
        throw Exception('Sign in cancelled by user');
      }

      // Request authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Make sure we have tokens
      if (googleAuth.accessToken == null) {
        throw Exception('Failed to get Google access token');
      }

      if (googleAuth.idToken == null) {
        throw Exception('Failed to get Google ID token');
      }

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase (this creates a new user if one doesn't exist)
      final userCredential = await _auth
          .signInWithCredential(credential)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Firebase sign-in timed out. Please check your internet connection and try again.',
              );
            },
          );

      // Update or create user document in Firestore
      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

        if (isNewUser) {
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userId)
              .set({
                'id': userId,
                'email': userCredential.user!.email,
                'username':
                    userCredential.user!.displayName ??
                    googleUser.displayName ??
                    'Google User',
                'grade': 'Not specified',
                'department': 'Not specified',
                'profilePhotoUrl':
                    userCredential.user!.photoURL ?? googleUser.photoUrl,
                'createdAt': FieldValue.serverTimestamp(),
                'emailVerified':
                    true, // Google accounts are verified by default
                'isAdmin': false,
              });
        } else {
          // Update last login timestamp for existing users
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userId)
              .update({'lastLogin': FieldValue.serverTimestamp()})
              .catchError((e) {
                // Non-fatal error - log but don't fail the sign-in process
              });
        }
      }

      return userCredential;
    } catch (e) {
      // Try to clean up gracefully to prevent hanging authentication state
      try {
        await _googleSignIn.signOut().timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
      } catch (cleanupError) {
        // Ignore cleanup errors
      }

      // Classify and convert error
      if (e.toString().contains('network')) {
        throw Exception(
          'Network error during sign-in. Please check your internet connection and try again.',
        );
      } else if (e.toString().contains('timeout')) {
        throw Exception('Sign-in process timed out. Please try again.');
      } else if (e.toString().contains('cancelled') ||
          e.toString().contains('canceled')) {
        throw Exception('Sign-in was cancelled.');
      } else if (e.toString().contains('credential')) {
        throw Exception(
          'Authentication error: Invalid credentials. Please try again with a different Google account.',
        );
      } else if (e.toString().contains(
        'ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL',
      )) {
        throw Exception(
          'An account already exists with the same email but different sign-in method. Please sign in using the original method.',
        );
      } else if (e.toString().contains('ApiException: 10')) {
        throw Exception(
          'Google Sign-In is not correctly configured. Please ensure your SHA fingerprints are added to Firebase project, and Google Sign-In is enabled in Firebase console.',
        );
      } else if (e.toString().contains('ApiException')) {
        throw Exception(
          'Google Play Services error. Please ensure Google Play Services is updated on your device and try again.',
        );
      } else {
        throw _handleFirebaseAuthError(e);
      }
    }
  }

  // Helper methods

  // Generate a verification code
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Handle Firebase Auth errors
  Exception _handleFirebaseAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      // Map Firebase Auth error codes to user-friendly messages
      switch (error.code) {
        case 'user-not-found':
          return Exception(
            'No user found with this email. Please check the email or register a new account.',
          );
        case 'wrong-password':
          return Exception(
            'The password you entered is incorrect. Please try again.',
          );
        case 'invalid-credential':
          return Exception(
            'The supplied auth credential is incorrect, malformed or has expired.',
          );
        case 'email-already-in-use':
          return Exception(
            'This email is already registered. Please use a different email or try logging in.',
          );
        case 'weak-password':
          return Exception(
            'The password is too weak. Please use a stronger password.',
          );
        case 'invalid-email':
          return Exception(
            'The email address is not valid. Please enter a valid email.',
          );
        case 'account-exists-with-different-credential':
          return Exception(
            'An account already exists with the same email but different sign-in credentials.',
          );
        case 'invalid-verification-code':
          return Exception(
            'The verification code is invalid. Please try again.',
          );
        case 'user-disabled':
          return Exception(
            'This user account has been disabled. Please contact support.',
          );
        case 'too-many-requests':
          return Exception(
            'Too many unsuccessful login attempts. Please try again later or reset your password.',
          );
        case 'operation-not-allowed':
          return Exception(
            'This sign-in method is not allowed. Please contact support.',
          );
        case 'network-request-failed':
          return Exception(
            'A network error occurred. Please check your internet connection and try again.',
          );
        case 'unauthorized-domain':
        case 'unauthorized-continue-uri':
        case 'auth/unauthorized-continue-uri':
          return Exception(
            'Firebase domain error: Please check your connectivity. This error may occur in test mode. If the issue persists, contact the administrator.',
          );
        default:
          // Check for domain allowlist errors in message
          if (error.message != null &&
              (error.message.toString().contains('domain') ||
                  error.message.toString().contains('allowlist') ||
                  error.message.toString().contains('allow list'))) {
            return Exception(
              'Firebase domain authorization error: Please check your connectivity or contact the administrator if the issue persists.',
            );
          }
          return Exception('Authentication error: ${error.message}');
      }
    } else {
      return Exception('Authentication error: $error');
    }
  }

  // Push Notifications
  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (e) {
      // Handle errors but don't throw to prevent app crashes
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (e) {
      // Handle errors but don't throw to prevent app crashes
    }
  }

  // Create a test account for development purposes
  Future<void> createTestAccountIfNotExists() async {
    try {
      const testEmail = 'test@example.com';
      const testPassword = '123456';

      // Check if account exists
      final methods = await _auth.fetchSignInMethodsForEmail(testEmail);

      if (methods.isEmpty) {
        // Account doesn't exist, create it

        // Create the account
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );

        // Add user to Firestore
        if (userCredential.user != null) {
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userCredential.user!.uid)
              .set({
                'id': userCredential.user!.uid,
                'email': testEmail,
                'username': 'Test User',
                'grade': 'Test Grade',
                'department': 'Computer Science',
                'profilePhotoUrl': null,
                'createdAt': FieldValue.serverTimestamp(),
                'emailVerified': true,
                'isAdmin': false,
                'mfaEnabled': false,
              });
        }
      }
    } catch (e) {
      // Error handling
    }
  }

  // Create a new user document
  Future<bool> createUserDocument(
    User user, {
    String? username,
    String? grade,
    String? department,
  }) async {
    try {
      final String email = user.email ?? '';
      final bool isAdmin = email.endsWith('admin.com');

      final Map<String, dynamic> data = {
        'email': email,
        'username': username ?? email.split('@')[0],
        'grade': grade,
        'department': department,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified':
            user.emailVerified || isAdmin, // Consider admin emails as verified
        'isAdmin': isAdmin,
        'mfaEnabled': false, // Default to no MFA
        'twoStepVerificationEnabled':
            true, // Enable two-step verification by default
        'accountStatus': 'active',
      };

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(data);

      return true;
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  // Helper function to convert any Map to Map<String, dynamic>
  Map<String, dynamic> _convertToStringDynamicMap(Map map) {
    final Map<String, dynamic> result = {};
    map.forEach((key, value) {
      if (key is String) {
        if (value is Map && value is! Map<String, dynamic>) {
          result[key] = _convertToStringDynamicMap(value);
        } else {
          result[key] = value;
        }
      }
    });
    return result;
  }

  // Helper to generate unique verification ID - private method
  String _generateVerificationId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
