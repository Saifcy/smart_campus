import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _departmentController = TextEditingController();

  File? _profileImage;
  final _imagePicker = ImagePicker();
  bool _isLoading = false;

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
  void initState() {
    super.initState();

    // Initialize fields with current user data
    final user = Provider.of<AuthController>(context, listen: false).user;
    if (user != null) {
      _usernameController.text = user.username;
      _gradeController.text = user.grade ?? '';
      _departmentController.text = user.department ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
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

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );

      try {
        final success = await authController.updateProfile(
          username: _usernameController.text.trim(),
          grade: _gradeController.text.trim(),
          department: _departmentController.text.trim(),
          profilePhoto: _profileImage,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Get.back();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authController.error ?? 'Failed to update profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Get profile image from either file or url
  ImageProvider? _getProfileImage(UserModel user) {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    } else if (user.profilePhotoUrl != null &&
        user.profilePhotoUrl!.isNotEmpty) {
      return NetworkImage(user.profilePhotoUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authController = Provider.of<AuthController>(context);
    final UserModel? user = authController.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
        backgroundColor: isDarkMode ? AppTheme.darkNavy : AppTheme.electricBlue,
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
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _getProfileImage(user),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Change Photo',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Username field
                  CustomTextField(
                    label: 'Username',
                    hint: 'Enter your username',
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

                  // Grade field with dropdown
                  DropdownButtonFormField<String>(
                    value:
                        _grades.contains(_gradeController.text)
                            ? _gradeController.text
                            : null,
                    decoration: InputDecoration(
                      labelText: 'Grade',
                      prefixIcon: const Icon(Icons.school_outlined),
                      filled: true,
                      fillColor:
                          isDarkMode
                              ? const Color(0xFF1A2B45)
                              : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items:
                        _grades
                            .map(
                              (grade) => DropdownMenuItem(
                                value: grade,
                                child: Text(grade),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _gradeController.text = value;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a grade';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Department field with dropdown
                  DropdownButtonFormField<String>(
                    value:
                        _departments.contains(_departmentController.text)
                            ? _departmentController.text
                            : null,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      prefixIcon: const Icon(Icons.business_outlined),
                      filled: true,
                      fillColor:
                          isDarkMode
                              ? const Color(0xFF1A2B45)
                              : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items:
                        _departments
                            .map(
                              (department) => DropdownMenuItem(
                                value: department,
                                child: Text(department),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _departmentController.text = value;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a department';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Update button
                  CustomButton(
                    text: 'Update Profile',
                    onPressed: _updateProfile,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
