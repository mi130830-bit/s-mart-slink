// ไฟล์: lib/services/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:s_link/features/auth/models/user.dart';
import 'package:s_link/features/auth/models/user_role.dart';

class UserService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  // 1. บันทึกข้อมูล User ใหม่
  Future<void> saveNewUser(
      String uid, String email, String name, UserRole role) async {
    final userRef = _firestore.collection('users').doc(uid);
    String? fcmToken;
    try {
      fcmToken = await _fcm.getToken();
    } catch (e) {
      log('FCM Token generation failed: $e');
    }

    final newUser = UserModel(
      uid: uid,
      email: email,
      name: name,
      role: role,
      fcmToken: fcmToken,
    );

    await userRef.set(newUser.toFirestore());

    // สมัคร Topic ตาม Role
    _handlePostRegisterSubscription(role);
  }

  // ✅ 1.5 ดึงรายชื่อพนักงานขับรถทั้งหมด (สำหรับหน้า Assign Job)
  Future<List<UserModel>> getDrivers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          // .orderBy('name') // ❌ Disable orderBy to avoid Index issues clearly
          .get();

      final users =
          snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();

      // ✅ Sort in Dart instead
      users.sort((a, b) => a.name.compareTo(b.name));

      log('User Service: Found ${users.length} drivers');
      return users;
    } catch (e, stack) {
      log('Error getting drivers: $e\n$stack');
      return [];
    }
  }

  // ✅ ดึงรายชื่อพนักงานทั้งหมด
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      users.sort((a, b) => a.name.compareTo(b.name));
      return users;
    } catch (e, stack) {
      log('Error getting all users: $e\n$stack');
      return [];
    }
  }

  // ✅ 1.6 ดึงรายชื่อพนักงานทั้งหมด (สำหรับทีมส่งของ - Delivery Team)
  Future<List<UserModel>> getDeliveryStaff() async {
    try {
      // ดึงหมดเลย ทั้ง Admin, Driver, Requester
      final snapshot = await _firestore.collection('users').get();

      final users =
          snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();

      // Filter: เอาเฉพาะคนที่มี Role ที่น่าจะไปส่งของได้ (เผื่อมี role อื่นๆ ในอนาคต)
      // แต่ตอนนี้เอาหมดเลยก็ได้ เพื่อความยืดหยุ่น
      // users.removeWhere((u) => u.role == UserRole.unknown);

      // Sort
      users.sort((a, b) => a.name.compareTo(b.name));

      log('User Service: Found ${users.length} staff members');
      return users;
    } catch (e, stack) {
      log('Error getting delivery staff: $e\n$stack');
      return [];
    }
  }

  void _handlePostRegisterSubscription(UserRole role) {
    try {
      if (role == UserRole.gasStation) return;
      
      if (role == UserRole.admin) {
        _fcm.subscribeToTopic('admin_alerts');
      } else if (role == UserRole.driver) {
        _fcm.subscribeToTopic('driver_alerts');
      } else if (role == UserRole.requester) {
        // ✅ เพิ่ม: ให้ Requester เข้ากลุ่ม requester_alerts
        _fcm.subscribeToTopic('requester_alerts');
      }
    } catch (e) {
      log('FCM Subscription failed: $e');
    }
  }

  // 2. ดึงข้อมูล User และจัดการ Topic หลัง Login
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('role')) {
          _handlePostLogin(data['role'].toString(), uid);
        }
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      log('Error getting user data: $e');
      return null;
    }
  }

  void _handlePostLogin(String roleString, String uid) {
    try {
      // 1. ยกเลิกของเก่าให้หมดก่อน (Reset)
      _fcm.unsubscribeFromTopic('admin_alerts');
      _fcm.unsubscribeFromTopic('driver_alerts');
      _fcm.unsubscribeFromTopic('requester_alerts'); // ✅ เพิ่มการ Reset

      final role = roleString.toLowerCase();
      
      // หากเป็นเด็กปั้ม ไม่ต้องรับแจ้งเตือนใดๆ ทั้งสิ้น (รวมถึง direct push)
      if (role == 'gas_station' || role == 'gasstation') {
        return; 
      }
      
      if (role == 'admin') {
        _fcm.subscribeToTopic('admin_alerts');
      } else if (role == 'driver') {
        _fcm.subscribeToTopic('driver_alerts');
      } else if (role == 'requester') {
        // ✅ เพิ่ม: ให้ Requester เข้ากลุ่ม
        _fcm.subscribeToTopic('requester_alerts');
      }

      _updateFCMToken(uid);
    } catch (e) {
      log('FCM post-login setup failed: $e');
    }
  }

  Future<void> _updateFCMToken(String uid) async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': token,
        });
        log('FCM Token updated for user: $uid');
      }
    } catch (e) {
      log('FCM update failed: $e');
    }
  }

  void unsubscribeAllTopics() {
    try {
      _fcm.unsubscribeFromTopic('admin_alerts');
      _fcm.unsubscribeFromTopic('driver_alerts');
      _fcm.unsubscribeFromTopic('requester_alerts'); // ✅ เพิ่มการ Unsubscribe
    } catch (e) {
      log('FCM unsubscribe failed: $e');
    }
  }

  // ✅ อัปเดตข้อมูลพนักงาน (ชื่อและตำแหน่ง) พร้อมซิงค์เข้าตาราง deliverers เพื่อไม่ให้ส่งผลเสียต่อระบบประวัติจัดส่งและรายงาน
  Future<void> updateUser(String uid, String newName, String newRole) async {
    final batch = _firestore.batch();
    
    final userRef = _firestore.collection('users').doc(uid);
    batch.update(userRef, {
      'name': newName,
      'role': newRole,
    });

    final delivererRef = _firestore.collection('deliverers').doc(uid);
    if (newRole == 'driver' || newRole == 'requester') {
      batch.set(delivererRef, {
        'name': newName,
        'isActive': true,
      }, SetOptions(merge: true));
    } else {
      batch.delete(delivererRef);
    }

    await batch.commit();
  }

  // ✅ ลบข้อมูลพนักงานออกจากระบบ (กรณีเลิกจ้าง) พร้อมลบออกจากกลุ่มประวัติจัดส่งด้วย
  Future<void> deleteUser(String uid) async {
    final batch = _firestore.batch();
    
    final userRef = _firestore.collection('users').doc(uid);
    batch.delete(userRef);

    final delivererRef = _firestore.collection('deliverers').doc(uid);
    batch.delete(delivererRef);

    await batch.commit();
  }
}
