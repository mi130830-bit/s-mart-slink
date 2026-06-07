// ไฟล์: lib/models/user.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.fcmToken,
  });

  // ✅ Getter 'id' เพื่อให้ Compatible กับโค้ดที่เรียกใช้ .id (เช่น Dropdown/Dialog ใช้งานร่วมกับ Model อื่น)
  String get id => uid;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return UserModel(
          uid: doc.id, email: '', name: 'Guest', role: UserRole.unknown);
    }

    final roleString = data['role']?.toString().toLowerCase() ?? 'unknown';

    UserRole parsedRole;
    switch (roleString) {
      case 'admin':
        parsedRole = UserRole.admin;
        break;
      case 'requester':
        parsedRole = UserRole.requester;
        break;
      case 'driver':
        parsedRole = UserRole.driver;
        break;
      case 'hr':
        parsedRole = UserRole.hr;
        break;
      case 'gas_station':
        parsedRole = UserRole.gasStation;
        break;
      case 'pending':
        parsedRole = UserRole.pending;
        break;
      default:
        parsedRole = UserRole.unknown;
    }

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: parsedRole,
      fcmToken: data['fcmToken'],
    );
  }

  Map<String, dynamic> toFirestore() {
    String roleStr = role.name;
    if (role == UserRole.gasStation) {
      roleStr = 'gas_station';
    }
    return {
      'email': email,
      'name': name,
      'role': roleStr,
      'fcmToken': fcmToken,
    };
  }

  // ✅ โค้ด copyWith ต้องวางที่ไฟล์นี้ครับ
  UserModel copyWith({
    String? email,
    String? name,
    UserRole? role,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
