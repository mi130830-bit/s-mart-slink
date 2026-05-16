// ไฟล์: lib/models/car.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CarModel {
  final String id; // Document ID จาก Firestore
  final String name; // ชื่อรถ/ทะเบียน (เช่น "รถกระบะ 7890")
  final String licensePlate; // ทะเบียนรถเต็ม
  final bool isAvailable; // สถานะพร้อมใช้งานหรือไม่

  CarModel({
    required this.id,
    required this.name,
    required this.licensePlate,
    this.isAvailable = true,
  });

  // Factory constructor สำหรับการสร้าง Object จาก Firestore Document
  factory CarModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return CarModel(
          id: doc.id,
          name: 'Unknown Car',
          licensePlate: 'N/A',
          isAvailable: false);
    }

    return CarModel(
      id: doc.id,
      name: data['name'] ?? '',
      licensePlate: data['licensePlate'] ?? '',
      isAvailable: data['isAvailable'] ?? true, // ตั้งค่า default เป็น true
    );
  }

  // Method สำหรับการส่งข้อมูลกลับไป Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'licensePlate': licensePlate,
      'isAvailable': isAvailable,
    };
  }

  // Method สำหรับการคัดลอกและแก้ไข (Copy With)
  CarModel copyWith({
    String? name,
    String? licensePlate,
    bool? isAvailable,
  }) {
    return CarModel(
      id: id,
      name: name ?? this.name,
      licensePlate: licensePlate ?? this.licensePlate,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
