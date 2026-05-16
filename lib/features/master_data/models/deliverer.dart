// ไฟล์: lib/models/deliverer.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DelivererModel {
  final String id; // Document ID จาก Firestore
  final String name; // ชื่อที่ใช้แสดง (เช่น "สมชาย คนขยัน")
  final bool isActive; // สถานะพร้อมทำงานหรือไม่

  DelivererModel({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  // Factory constructor สำหรับการสร้าง Object จาก Firestore Document
  factory DelivererModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return DelivererModel(
          id: doc.id, name: 'Unknown Deliverer', isActive: false);
    }

    return DelivererModel(
      id: doc.id,
      name: data['name'] ?? '',
      isActive: data['isActive'] ?? true, // ตั้งค่า default เป็น true
    );
  }

  // Method สำหรับการส่งข้อมูลกลับไป Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'isActive': isActive,
    };
  }

  // Method สำหรับการคัดลอกและแก้ไข (Copy With)
  DelivererModel copyWith({
    String? name,
    bool? isActive,
  }) {
    return DelivererModel(
      id: id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }
}
