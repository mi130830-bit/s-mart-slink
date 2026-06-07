// ไฟล์: lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';
import 'user_service.dart';
import 'package:s_link/features/auth/models/user_role.dart';
import 'package:s_link/features/auth/models/user.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final UserService _userService = UserService();

  Stream<User?> get userStream => _auth.authStateChanges();

  Future<UserModel?> registerWithEmail(
    String email,
    String password,
    String name,
    UserRole initialRole,
  ) async {
    try {
      // 1. สร้าง User ใน Firebase Authentication
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        log('Auth created for ${user.uid}'); // Debug Log

        // 2. บันทึกข้อมูลลง Firestore (UserService)
        try {
          await _userService.saveNewUser(
            user.uid,
            email,
            name,
            initialRole,
          );
          log('Firestore profile created for ${user.uid}'); // Debug Log
        } catch (firestoreError) {
          // ถ้าบันทึก Firestore ไม่ได้ ให้ลบ Auth ทิ้งด้วย เพื่อไม่ให้ข้อมูลค้าง (Rollback)
          log('Firestore save failed: $firestoreError. Rolling back Auth...');
          await user.delete();
          throw Exception('Database Error: $firestoreError');
        }

        // 3. ดึงข้อมูลกลับมาเพื่อยืนยัน
        final createdUser = await _userService.getUserById(user.uid);
        
        // 4. บังคับ Logout ทันทีเพื่อไม่ให้ค้างหน้า Pending
        await _auth.signOut();
        
        return createdUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      log('Registration Auth failed: ${e.message}');
      rethrow; // ส่ง Error กลับไปให้ UI แสดงผล
    } catch (e) {
      log('Registration General Error: $e');
      rethrow;
    }
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        return await _userService.getUserById(user.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      log('Sign In failed: ${e.message}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    _userService.unsubscribeAllTopics();
    return await _auth.signOut();
  }
}
