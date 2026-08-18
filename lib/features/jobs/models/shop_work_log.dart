// ไฟล์: lib/models/shop_work_log.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Sub-Model: รายละเอียดงานที่ทำ (items)
class WorkItem {
  final String description; // รายการงานที่ทำ (เช่น จัดเรียงเหล็ก, ซ่อมรถเข็น)
  final double quantity; // จำนวนหรือปริมาณงานที่ทำ (เช่น 2 ชั่วโมง, 5 รายการ)
  final String unit; // หน่วย (เช่น 'ชั่วโมง', 'รายการ', 'ครั้ง')

  WorkItem({
    required this.description,
    this.quantity = 1.0,
    this.unit = 'ครั้ง',
  });

  factory WorkItem.fromJson(Map<String, dynamic> json) {
    return WorkItem(
      description: json['description'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? 'ครั้ง',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unit': unit,
    };
  }
}

class ShopWorkLogModel {
  final String id; // Document ID
  final List<WorkItem> items; // รายละเอียดงานที่ทำ (Array of Map ใน Firestore)
  final String delivererId; // UID ของคนที่ทำงานนั้นๆ
  final String? delivererName; // ชื่อผู้บันทึกจาก POS API (ถ้ามี)
  final DateTime loggedAt; // เวลาที่บันทึกงาน

  ShopWorkLogModel({
    required this.id,
    required this.items,
    required this.delivererId,
    this.delivererName,
    required this.loggedAt,
  });

  // Factory constructor สำหรับการสร้าง Object จาก Firestore Document
  factory ShopWorkLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return ShopWorkLogModel(
        id: doc.id,
        items: [],
        delivererId: '',
        delivererName: null,
        loggedAt: DateTime.now(),
      );
    }

    return ShopWorkLogModel(
      id: doc.id,
      delivererId: data['deliverer_id'] ?? '',
      delivererName: data['deliverer_name']?.toString(),
      loggedAt: (data['logged_at'] as Timestamp).toDate(),

      // แปลง List ของ Map เป็น List ของ WorkItem Objects
      items: (data['items'] as List<dynamic>?)
              ?.map((itemMap) => WorkItem.fromJson(itemMap))
              .toList() ??
          [],
    );
  }

  // Method สำหรับการส่งข้อมูลกลับไป Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'deliverer_id': delivererId,
      if (delivererName != null) 'deliverer_name': delivererName,
      'logged_at': Timestamp.fromDate(loggedAt),
      // แปลง List ของ WorkItem Objects กลับเป็น List ของ Map
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
