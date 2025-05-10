import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_constants.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({Key? key, required this.email})
    : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isLoading = false;
  bool _verified = false;
  String? _errorMessage;
  Timer? _checkVerificationTimer;

  @override
  void initState() {
    super.initState();
    // Start checking for verification status
    _startVerificationCheck();
  }

  void _startVerificationCheck() {
    // Check every 5 seconds if the user has verified their email
    _checkVerificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkEmailVerified(),
    );
  }

  Future<void> _checkEmailVerified() async {
    final authController = Provider.of<AuthController>(context, listen: false);

    try {
      // Refresh the user to get the latest email verification status
      final isVerified = await authController.isEmailVerified();

      if (isVerified) {
        _checkVerificationTimer?.cancel();
        setState(() {
          _verified = true;
        });

        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Automatically transition to login after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          // Force reload the current user to ensure Firebase Auth state is updated
          FirebaseAuth.instance.currentUser?.reload();

          // Sign out the current user to force a clean login state
          authController.signOut().then((_) {
            // Navigate to login screen with verified flag
            Get.offAllNamed(
              AppConstants.loginRoute,
              arguments: {'from_verification': true},
            );
          });
        });
      }
    } catch (e) {
      // Continue checking
    }
  }

  Future<void> _resendVerificationEmail(AuthController authController) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await authController.sendEmailVerification();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent to ${widget.email}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              authController.error ?? 'Failed to send verification email';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _checkVerificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Email Verification'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        // Only allow going back to login if verified
        automaticallyImplyLeading: _verified,
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email verification icon
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.electricBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _verified ? Icons.check_circle : Icons.email_outlined,
                      size: 64,
                      color: _verified ? Colors.green : AppTheme.electricBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  _verified ? 'Email Verified!' : 'Verify Your Email',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  _verified
                      ? 'Your email has been successfully verified. You can now proceed to login.'
                      : 'We\'ve sent a verification link to ${widget.email}. Please check your email and click the verification link to activate your account.',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (!_verified) ...[
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDarkMode
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your account is suspended until you verify your email. Please check your inbox (and spam folder) for the verification link.',
                          style: TextStyle(
                            color:
                                isDarkMode
                                    ? Colors.blue[100]
                                    : Colors.blue[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Resend verification email button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: ElevatedButton.icon(
                      onPressed:
                          _isLoading
                              ? null
                              : () => _resendVerificationEmail(authController),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.electricBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      icon:
                          _isLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.refresh),
                      label: const Text(
                        'Resend Verification Email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Return to login
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Get.offAllNamed(
                          AppConstants.loginRoute,
                          arguments: {'from_verification': true},
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Return to Login'),
                    ),
                  ),
                ] else ...[
                  // Verified - proceed to login
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Get.offAllNamed(
                          AppConstants.loginRoute,
                          arguments: {'from_verification': true},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'Proceed to Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
