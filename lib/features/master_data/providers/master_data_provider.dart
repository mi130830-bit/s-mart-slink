// ไฟล์: lib/providers/master_data_provider.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:s_link/core/services/master_data_service.dart';
import 'package:s_link/features/master_data/models/deliverer.dart';
import 'package:s_link/features/master_data/models/car.dart';

class MasterDataProvider with ChangeNotifier {
  final MasterDataService _masterDataService;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  List<DelivererModel> _deliverers = [];
  List<CarModel> _cars = [];
  bool _isLoading = false;

  List<DelivererModel> get deliverers => _deliverers;
  List<CarModel> get cars => _cars;
  List<CarModel> get vehicles => _cars; // Alias for UI compatibility
  bool get isLoading => _isLoading;

  MasterDataProvider(this._masterDataService);

  Future<void> loadMasterData() async {
    // โหลดครั้งเดียว ไม่ Listen
    try {
      _isLoading = true;
      notifyListeners();

      log('MasterDataProvider: Loading master data (One-time fetch)...');
      _deliverers = await _masterDataService.getDeliverersOnce();
      _cars = await _masterDataService.getCarsOnce();

      log('MasterDataProvider: Loaded ${_deliverers.length} deliverers and ${_cars.length} cars.');
    } catch (e) {
      log('MasterDataProvider Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // เรียกเมื่อมีการเพิ่ม/ลบ ข้อมูล เพื่อ refresh (Manual Refresh)
  Future<void> refreshMasterData() async => await loadMasterData();

  // Backward Compatibility (แต่ข้างในเปลี่ยนเป็น Load Once)
  void startListeningToMasterData() {
    loadMasterData();
  }

  void stopListening() {
    // No-op for Future based approach, just clear local data if needed
    _deliverers = [];
    _cars = [];
    notifyListeners();
  }

  // --- Actions ---
  Future<void> addDeliverer(String name) async =>
      await _masterDataService.addDeliverer(name);
  Future<void> updateDeliverer(String id, String newName) async =>
      await _masterDataService.updateDeliverer(id, newName);
  Future<void> deleteDeliverer(String id) async =>
      await _masterDataService.deleteDeliverer(id);

  Future<void> addCar(String name, String licensePlate) async =>
      await _masterDataService.addCar(name, licensePlate);
  Future<void> updateCar(String id, String newName, String newPlate) async =>
      await _masterDataService.updateCar(id, newName, newPlate);
  Future<void> deleteCar(String id) async =>
      await _masterDataService.deleteCar(id);

  // 1. ฟังก์ชันค้นหาลูกค้าจากเบอร์โทร
  Future<Map<String, dynamic>?> findCustomerByPhone(String phone) async {
    try {
      final query = await _firestore
          .collection('customers')
          .where('phone_number',
              isEqualTo: phone) // ✅ แก้ key เป็น phone_number
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }
    } catch (e) {
      log('Error finding customer: $e');
    }
    return null;
  }

  // 2. ฟังก์ชันบันทึกข้อมูลลูกค้า (ใช้สำหรับ Create Job)
  Future<String> saveCustomerInfo({
    String? customerId,
    required String name,
    required String phone,
    required String address,
    GeoPoint? location,
  }) async {
    try {
      final dataToSave = {
        'name': name,
        'phone_number': phone, // เดิมเป็น 'phone' -> แก้เป็น 'phone_number'
        'address': address,
        'last_updated': FieldValue.serverTimestamp(),
        'is_active': true,
      };

      if (location != null) {
        dataToSave['location'] = location;
      }

      // กรณี 1: มี ID ลูกค้าเดิม -> อัปเดต
      if (customerId != null && customerId.isNotEmpty) {
        await _firestore
            .collection('customers')
            .doc(customerId)
            .set(dataToSave, SetOptions(merge: true));
        log('Updated existing customer: $customerId');
        return customerId;
      }
      // กรณี 2: ไม่มี ID -> ค้นหาจากเบอร์โทร (phone_number) หรือ สร้างใหม่
      else {
        final query = await _firestore
            .collection('customers')
            .where('phone_number', isEqualTo: phone) // ✅ แก้ตรงนี้ด้วย
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          // เจอเบอร์ซ้ำ -> อัปเดตตัวเดิม
          final docRef = query.docs.first.reference;
          await docRef.set(dataToSave, SetOptions(merge: true));
          log('Updated customer by phone: $phone');
          return docRef.id;
        } else {
          // ไม่เจอ -> สร้างใหม่
          dataToSave['created_at'] = FieldValue.serverTimestamp();
          final docRef =
              await _firestore.collection('customers').add(dataToSave);
          log('Created new customer: $name');
          return docRef.id;
        }
      }
    } catch (e) {
      log('Error saving customer info: $e');
      rethrow;
    }
  }

  // ✅ 3. ฟังก์ชันอัปเดตพิกัดลูกค้า (ใช้สำหรับ Complete Job) - รับแค่ 2 ตัว
  Future<void> updateCustomerLocation(
      String customerId, GeoPoint location) async {
    try {
      // ⚠️ ต้องเช็คว่า customerId ไม่ใช่ null/empty ในโค้ดเรียกใช้แล้ว
      await _firestore.collection('customers').doc(customerId).set(
          {'location': location, 'last_updated': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      log('Updated customer location for ID: $customerId');
    } catch (e) {
      log('Error updating customer location: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
