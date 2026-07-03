// ไฟล์: lib/services/master_data_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'package:s_link/features/master_data/models/deliverer.dart';
import 'package:s_link/features/master_data/models/car.dart';

class MasterDataService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // ----------------------------------------------------
  // I. DELIVERER MANAGEMENT
  // ----------------------------------------------------

  final String _delivererCollection = 'deliverers';

  // ดึงรายการ Deliverer ทั้งหมด (Future — cost optimized)
  Future<List<DelivererModel>> getDeliverersOnce() async {
    final snapshot = await _firestore
        .collection(_delivererCollection)
        .orderBy('name', descending: false)
        .get();
    return snapshot.docs
        .map((doc) => DelivererModel.fromFirestore(doc))
        .toList();
  }

  // 2. เพิ่ม Deliverer ใหม่
  Future<void> addDeliverer(String name) async {
    try {
      final newDeliverer = DelivererModel(
        id: '',
        name: name,
        isActive: true,
      );
      await _firestore
          .collection(_delivererCollection)
          .add(newDeliverer.toFirestore());
      log('Deliverer added: $name');
    } catch (e) {
      log('Error adding deliverer: $e');
      throw Exception('Failed to add deliverer');
    }
  }

  // 3. แก้ไขชื่อ
  Future<void> updateDeliverer(String id, String newName) async {
    await _firestore.collection(_delivererCollection).doc(id).update({
      'name': newName,
    });
  }

  // 4. ลบ Deliverer
  Future<void> deleteDeliverer(String delivererId) async {
    try {
      await _firestore
          .collection(_delivererCollection)
          .doc(delivererId)
          .delete();
      log('Deliverer deleted: $delivererId');
    } catch (e) {
      log('Error deleting deliverer: $e');
      throw Exception('Failed to delete deliverer');
    }
  }

  // ----------------------------------------------------
  // II. CAR MANAGEMENT
  // ----------------------------------------------------

  final String _carCollection = 'cars';

  // ดึงรายการ Car ทั้งหมด (Future — cost optimized)
  Future<List<CarModel>> getCarsOnce() async {
    final snapshot = await _firestore
        .collection(_carCollection)
        .orderBy('name', descending: false)
        .get();
    return snapshot.docs.map((doc) => CarModel.fromFirestore(doc)).toList();
  }

  // 2. เพิ่ม Car ใหม่
  Future<void> addCar(String name, String licensePlate) async {
    try {
      final newCar = CarModel(
        id: '',
        name: name,
        licensePlate: licensePlate,
        isAvailable: true,
      );
      await _firestore.collection(_carCollection).add(newCar.toFirestore());
      log('Car added: $name ($licensePlate)');
    } catch (e) {
      log('Error adding car: $e');
      throw Exception('Failed to add car');
    }
  }

  // 3. แก้ไขชื่อและทะเบียน
  Future<void> updateCar(String id, String newName, String newPlate) async {
    await _firestore.collection(_carCollection).doc(id).update({
      'name': newName,
      'licensePlate': newPlate,
    });
  }

  // 4. ลบ Car
  Future<void> deleteCar(String carId) async {
    try {
      await _firestore.collection(_carCollection).doc(carId).delete();
      log('Car deleted: $carId');
    } catch (e) {
      log('Error deleting car: $carId');
      throw Exception('Failed to delete car');
    }
  }
}
