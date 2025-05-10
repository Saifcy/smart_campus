import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String username;
  final String grade;
  final String department;
  final String? profilePhotoUrl;
  final DateTime? createdAt;
  final bool emailVerified;
  final bool isAdmin;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.grade,
    required this.department,
    this.profilePhotoUrl,
    this.createdAt,
    this.emailVerified = false,
    this.isAdmin = false,
  });

  // Create a mock user for demo purposes
  static UserModel createMockUser(String email) {
    return UserModel(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      username: email.split('@')[0],
      grade: 'Student',
      department: 'Computer Science',
      profilePhotoUrl: null,
      createdAt: DateTime.now(),
      isAdmin: email.endsWith('@admin.com'),
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'grade': grade,
      'department': department,
      'profilePhotoUrl': profilePhotoUrl,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'emailVerified': emailVerified,
      'isAdmin': isAdmin,
    };
  }

  // Convert to JSON string
  String toJson() => json.encode(toMap());

  // Create UserModel from Firestore Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      grade: map['grade'] ?? 'Not specified',
      department: map['department'] ?? 'Not specified',
      profilePhotoUrl: map['profilePhotoUrl'],
      createdAt:
          map['createdAt'] != null
              ? (map['createdAt'] is Timestamp
                  ? (map['createdAt'] as Timestamp).toDate()
                  : DateTime.fromMillisecondsSinceEpoch(map['createdAt']))
              : null,
      emailVerified: map['emailVerified'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
    );
  }

  // Create from JSON string
  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, username: $username, grade: $grade, department: $department, profilePhotoUrl: $profilePhotoUrl, createdAt: $createdAt, emailVerified: $emailVerified, isAdmin: $isAdmin)';
  }

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
