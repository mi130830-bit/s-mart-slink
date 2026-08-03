import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';

// Import Services & Models
import 'package:s_link/features/auth/services/auth_service.dart';
import 'package:s_link/features/auth/services/user_service.dart';
import 'package:s_link/features/auth/models/user.dart';
import 'package:s_link/features/auth/models/user_role.dart';

class AuthenticationProvider with ChangeNotifier {
  final AuthService _authService;
  final UserService _userService;

  String? _jwtToken;
  UserModel? _currentUser; // Custom UserModel (จาก Firestore)
  bool _isLoading = false;

  // Getter
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get jwtToken => _jwtToken;

  // ตรวจสอบว่าล็อกอินสมบูรณ์หรือไม่ (มี JWT token + currentUser)
  bool get isAuthenticated => _currentUser != null;

  AuthenticationProvider(this._authService, this._userService) {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null && token.isNotEmpty) {
      log('Auth State: JWT Token found, user is considered logged in.');
      _jwtToken = token;
      // Decode JWT payload to restore _currentUser without re-login
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
          );
          // Import UserModel + UserRole to reconstruct
          // We'll just mark as logged-in with a minimal user from token
          _currentUser = UserModel(
            uid: payload['id']?.toString() ?? '0',
            email: payload['username']?.toString() ?? '',
            name: payload['employee_name']?.toString() ?? payload['username']?.toString() ?? 'Unknown',
            role: _mapRole(payload['role']?.toString() ?? 'CASHIER'),
          );
          log('Auth State: Restored user from JWT: ${_currentUser!.name}');
        }
      } catch (e) {
        log('Auth State: Failed to decode JWT: $e');
        // Token invalid — clear it
        await prefs.remove('jwt_token');
        _currentUser = null;
      }
    } else {
      log('Auth State: User is logged out.');
    }

    // 🔥 Ensure Firebase is also logged in
    if (_currentUser != null && FirebaseAuth.instance.currentUser == null) {
      try {
        final offPass = prefs.getString('offline_password');
        if (offPass != null) {
          String firebasePassword = offPass;
          if (firebasePassword.length < 6) {
            firebasePassword = firebasePassword.padRight(6, '0');
          }
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: 'user${_currentUser!.id}@s-link.local',
            password: firebasePassword,
          );
          log('Firebase Auto-Login successful on startup.');
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
          try {
            final offPass = prefs.getString('offline_password');
            if (offPass != null) {
              String firebasePassword = offPass;
              if (firebasePassword.length < 6) {
                firebasePassword = firebasePassword.padRight(6, '0');
              }
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: 'user${_currentUser!.id}@s-link.local',
                password: firebasePassword,
              );
              log('Firebase user auto-created and logged in on startup.');
            }
          } catch (createErr) {
            log('⚠️ Firebase auto-create failed on startup: $createErr');
          }
        } else {
          log('⚠️ Firebase Auto-Login failed on startup: $e');
        }
      } catch (e) {
        log('⚠️ Firebase Auto-Login failed on startup: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // ----------------------------------------------------
  // UI Actions
  // ----------------------------------------------------

  Future<void> login(String username, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      _currentUser = await _authService.login(username, password);
      if (_currentUser != null) {
          log('Auth State: Profile loaded for ${_currentUser!.name} (Role: ${_currentUser!.role.name})');
          // API URL is configured locally — no longer synced from Firebase
      }
      
      _isLoading = false;
      notifyListeners();
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

      _userService.unsubscribeAllTopics();

      await _authService.logout();
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      log('Logout Error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ ดึงข้อมูล User ใหม่จาก Firestore (ใช้หลัง update ชื่อ/role)
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;
    try {
      _currentUser = await _userService.getUserById(_currentUser!.uid);
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

  // ----------------------------------------------------
  // Private Helpers
  // ----------------------------------------------------
  UserRole _mapRole(String roleStr) {
    switch (roleStr.toUpperCase()) {
      case 'ADMIN': return UserRole.admin;
      case 'DRIVER': return UserRole.driver;
      case 'HR': return UserRole.hr;
      case 'GAS_STATION': return UserRole.gasStation;
      case 'CASHIER':
      default: return UserRole.requester;
    }
  }
}
