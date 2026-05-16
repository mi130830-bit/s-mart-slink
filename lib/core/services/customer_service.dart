// ไฟล์: lib/services/customer_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'package:s_link/features/master_data/models/customer_master.dart';

class CustomerService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final String _collection = 'customers';

  // 1. ฟังก์ชันอัปเดตข้อมูลลูกค้าอัตโนมัติ
  Future<void> updateCustomerLocation({
    required String name,
    required String phoneNumber,
    required String address,
    required GeoPoint location,
  }) async {
    try {
      // ใช้เบอร์โทรเป็น Document ID (ลบขีด/ช่องว่างออก)
      final docId = phoneNumber.replaceAll(RegExp(r'\D'), '');

      if (docId.isEmpty) return;

      final docRef = _firestore.collection(_collection).doc(docId);

      await docRef.set({
        'name': name,
        'phone_number': phoneNumber,
        'address': address,
        'location': location,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      log('Customer $name location updated to $location');
    } catch (e) {
      log('Error updating customer location: $e');
    }
  }

  // 2. ฟังก์ชันค้นหาลูกค้าจากเบอร์โทร
  Future<CustomerMaster?> getCustomerByPhone(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.isEmpty) return null;

      final doc =
          await _firestore.collection(_collection).doc(cleanPhone).get();

      if (doc.exists) {
        final data = doc.data()!;

        // แปลง Timestamp อย่างปลอดภัย
        DateTime lastUpdated = DateTime.now();
        if (data['last_updated'] is Timestamp) {
          lastUpdated = (data['last_updated'] as Timestamp).toDate();
        }

        return CustomerMaster(
          id: doc.id,
          name: data['name'] ?? '',
          phoneNumber: data['phone_number'] ?? '',
          address: data['address'] ?? '',
          location: data['location'] as GeoPoint?,
          lastUpdated: lastUpdated,
        );
      }
      return null;
    } catch (e) {
      log('Error getting customer: $e');
      return null;
    }
  }
}
