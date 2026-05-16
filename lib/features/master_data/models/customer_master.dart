// ไฟล์: lib/models/customer_master.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerMaster {
  final String id;
  final String name;
  final String phoneNumber;
  final String address;
  final GeoPoint? location;
  final DateTime lastUpdated;

  CustomerMaster({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.address,
    this.location,
    required this.lastUpdated,
  });

  // ✅ 1. เพิ่ม factory fromFirestore ที่ขาดหายไป (เพื่อให้ดึงข้อมูลมาแสดงได้)
  factory CustomerMaster.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return CustomerMaster(
        id: doc.id,
        name: 'Unknown',
        phoneNumber: '',
        address: '',
        lastUpdated: DateTime.now(),
      );
    }

    return CustomerMaster(
      id: doc.id,
      name: data['name'] ?? '',
      // ใช้ key ให้ตรงกับ toFirestore (phone_number)
      phoneNumber: data['phone_number'] ?? '',
      address: data['address'] ?? '',
      location: data['location'] as GeoPoint?,
      lastUpdated:
          (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ✅ 2. method toFirestore (สำหรับบันทึกข้อมูล)
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone_number': phoneNumber,
      'address': address,
      'location': location,
      'last_updated': Timestamp.fromDate(lastUpdated),
    };
  }
}
