// ไฟล์: lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';

// Import Services & Models
import 'package:s_link/features/auth/services/auth_service.dart';
import 'package:s_link/features/auth/services/user_service.dart';
import 'package:s_link/core/services/notification_service.dart';
import 'package:s_link/features/auth/models/user.dart';

class AuthenticationProvider with ChangeNotifier {
  final AuthService _authService;
  final UserService _userService;

  User? _firebaseUser; // Firebase User (จาก FirebaseAuth)
  UserModel? _currentUser; // Custom UserModel (จาก Firestore)
  bool _isLoading = false;

  // Getter
  User? get firebaseUser => _firebaseUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  // ตรวจสอบว่าล็อกอินสมบูรณ์หรือไม่ (ต้องมีทั้ง Firebase User และข้อมูลใน Firestore)
  bool get isAuthenticated => _firebaseUser != null && _currentUser != null;

  AuthenticationProvider(this._authService, this._userService) {
    // 1. เริ่มฟังสถานะ Auth ทันที (Login/Logout)
    _authService.userStream.listen(_onAuthStateChanged);

    // 2. เริ่มฟังสถานะ ID Token Change เพื่อจัดการการต่ออายุอัตโนมัติ (Role Update)
    FirebaseAuth.instance.idTokenChanges().listen(_onIdTokenChanged);
  }

  // ----------------------------------------------------
  // Core Logic 1: จัดการการเปลี่ยนแปลงสถานะ Auth (Login/Logout)
  // ----------------------------------------------------
  Future<void> _onAuthStateChanged(User? user) async {
    _isLoading = true;
    notifyListeners();

    _firebaseUser = user;

    if (user == null) {
      // กรณี Logout หรือยังไม่ล็อกอิน
      _currentUser = null;
      log('Auth State: User is logged out.');
    } else {
      // กรณี Login สำเร็จ -> ไปดึงข้อมูล User Profile
      log('Auth State: Firebase User logged in (${user.uid}).');

      try {
        // ✅ บังคับ Refresh Token ทันทีเมื่อ Login เพื่อให้ได้ Custom Claims (Role) ล่าสุด
        await user.getIdToken(true);
        log('Auth State: Token force refreshed. Custom Claims updated.');

        // ดึงข้อมูล User Profile จาก Firestore
        _currentUser = await _userService.getUserById(user.uid);

        if (_currentUser == null) {
          // ป้องกันการเข้าถึงด้วยบัญชีที่ไม่มี User Profile ใน Firestore
          log('Warning: No user profile found for ${user.uid}. Signing out...');
          await _authService.signOut();
        } else {
          log('Auth State: Profile loaded for ${_currentUser!.name} (Role: ${_currentUser!.role.name})');

          // ✅ บันทึก FCM Token เพื่อรับ Notifications
          await NotificationService.registerFCMToken(user.uid);

          // ✅ Topic Subscription handled by UserService automatically
          // Note: Previously checked role here, but moved to centralized logic.
        }
      } catch (e) {
        log('Error fetching user profile or refreshing token: $e');
        _currentUser = null;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // ----------------------------------------------------
  // Core Logic 2: จัดการเมื่อ ID Token ถูกต่ออายุอัตโนมัติ
  // ----------------------------------------------------
  Future<void> _onIdTokenChanged(User? user) async {
    if (user != null && _firebaseUser != null && _currentUser != null) {
      final idTokenResult = await user.getIdTokenResult(false);
      final tokenRole = idTokenResult.claims?['role'];

      if (tokenRole == null ||
          tokenRole != _currentUser!.role.name.toLowerCase()) {
        log('Token Refresh Detected: Re-fetching user profile to ensure latest role/claims.');

        _isLoading = true;
        notifyListeners();

        try {
          _currentUser = await _userService.getUserById(user.uid);
          log('Token Refresh: Profile updated (New Role: ${_currentUser?.role.name}).');
        } catch (e) {
          log('Error re-fetching profile during Token Refresh: $e');
        } finally {
          _isLoading = false;
          notifyListeners();
        }
      }
    }
  }

  // ----------------------------------------------------
  // UI Actions
  // ----------------------------------------------------

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signInWithEmail(email, password);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      log('Login Error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      // ✅ ลบ FCM Token ก่อน Logout
      if (_firebaseUser != null) {
        await NotificationService.removeFCMToken(_firebaseUser!.uid);
        // Unsubscribe จาก topics ทั้งหมดผ่าน UserService (single source of truth)
        _userService.unsubscribeAllTopics();
      }

      await _authService.signOut();
    } catch (e) {
      log('Logout Error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ ดึงข้อมูล User ใหม่จาก Firestore (ใช้หลัง update ชื่อ/role)
  Future<void> refreshCurrentUser() async {
    if (_firebaseUser == null) return;
    try {
      _currentUser = await _userService.getUserById(_firebaseUser!.uid);
      notifyListeners();
    } catch (e) {
      log('Error refreshing user: $e');
    }
  }

  // ----------------------------------------------------
  // Utility: ตรวจสอบ Role
  // ----------------------------------------------------
  bool get isUserAdmin {
    return _currentUser?.role.name.toLowerCase() == 'admin';
  }

  bool get isUserDriver {
    return _currentUser?.role.name.toLowerCase() == 'driver';
  }

  bool get isUserRequester {
    return _currentUser?.role.name.toLowerCase() == 'requester';
  }

  // ✅ [เพิ่มใหม่] ตรวจสอบสถานะ HR
  bool get isUserHr {
    return _currentUser?.role.name.toLowerCase() == 'hr';
  }

  // ✅ [เพิ่มใหม่] ตรวจสอบสถานะรอการอนุมัติ
  bool get isUserPending {
    return _currentUser?.role.name.toLowerCase() == 'pending';
  }
}
