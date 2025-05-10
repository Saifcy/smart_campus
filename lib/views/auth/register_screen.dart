import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _gradeController = TextEditingController();
  final _departmentController = TextEditingController();

  File? _profileImage;
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedGrade;
  String? _selectedDepartment;

  final List<String> _departments = [
    'Computer Science',
    'Engineering',
    'Business',
    'Medicine',
    'Arts',
    'Law',
    'Sciences',
  ];

  final List<String> _grades = [
    'Junior',
    'Senior',
    'Graduate',
    'Faculty',
    'Staff',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _gradeController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedImage != null) {
      setState(() {
        _profileImage = File(pickedImage.path);
      });
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        final username = _usernameController.text.trim();

        final authController = Provider.of<AuthController>(
          context,
          listen: false,
        );

        final bool success = await authController.signUp(
          email: email,
          password: password,
          username: username,
          grade: _gradeController.text.trim(),
          department: _departmentController.text.trim(),
          profilePhoto: _profileImage,
        );

        if (success) {
          // Navigate to email verification screen
          Get.offNamed(
            AppConstants.emailVerificationRoute,
            arguments: {'email': email},
          );
        } else {
          setState(() {
            _errorMessage = authController.error ?? 'Registration failed';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('register'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile image picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.electricBlue.withOpacity(0.2),
                      backgroundImage:
                          _profileImage != null
                              ? FileImage(_profileImage!) as ImageProvider
                              : null,
                      child:
                          _profileImage == null
                              ? const Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: AppTheme.electricBlue,
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'profile_photo'.tr,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Username field
                  CustomTextField(
                    label: 'username'.tr,
                    hint: 'Mohamed Emad',
                    controller: _usernameController,
                    prefixIcon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email field
                  CustomTextField(
                    label: 'email'.tr,
                    hint: 'email@example.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Grade field (dropdown)
                  CustomTextField(
                    label: 'grade'.tr,
                    hint: 'Select your grade',
                    controller: _gradeController,
                    prefixIcon: Icons.school_outlined,
                    readOnly: true,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor:
                            isDarkMode ? const Color(0xFF1A2B45) : Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder:
                            (context) => ListView.builder(
                              shrinkWrap: true,
                              itemCount: _grades.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(_grades[index]),
                                  onTap: () {
                                    setState(() {
                                      _gradeController.text = _grades[index];
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                      );
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your grade';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Department field (dropdown)
                  CustomTextField(
                    label: 'department'.tr,
                    hint: 'Select your department',
                    controller: _departmentController,
                    prefixIcon: Icons.business_outlined,
                    readOnly: true,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor:
                            isDarkMode ? const Color(0xFF1A2B45) : Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder:
                            (context) => ListView.builder(
                              shrinkWrap: true,
                              itemCount: _departments.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(_departments[index]),
                                  onTap: () {
                                    setState(() {
                                      _departmentController.text =
                                          _departments[index];
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                      );
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your department';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  CustomTextField(
                    label: 'password'.tr,
                    hint: '••••••••',
                    controller: _passwordController,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm password field
                  CustomTextField(
                    label: 'confirm_password'.tr,
                    hint: '••••••••',
                    controller: _confirmPasswordController,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getFormattedErrorMessage(_errorMessage!),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Register button
                  CustomButton(
                    text: 'register'.tr,
                    onPressed: _register,
                    isLoading: authController.isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'already_have_account'.tr,
                        style: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.back();
                        },
                        child: Text(
                          'login'.tr,
                          style: const TextStyle(
                            color: AppTheme.electricBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getFormattedErrorMessage(String error) {
    if (error.contains('email-already-in-use')) {
      return 'This email is already registered. Please use a different email or try logging in.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Please use a stronger password.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your internet connection and try again.';
    } else {
      return error;
    }
  }
}
