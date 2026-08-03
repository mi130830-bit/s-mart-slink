// ไฟล์: lib/models/job.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:s_link/features/master_data/models/customer.dart';
import 'package:s_link/features/master_data/models/delivery_team_item.dart';
import 'package:s_link/features/jobs/models/job_item.dart'; // ✅ Import JobItem

// Export เพื่อให้ไฟล์อื่นเรียกผ่าน job.dart ได้ (Backward Compatibility)
export 'package:s_link/features/master_data/models/customer.dart';
export 'package:s_link/features/master_data/models/delivery_team_item.dart';

class Job {
  final String id;
  final int? localOrderId; // ✅ Added localOrderId
  final String status; // 'pending', 'completed', 'requested'
  final String? customerId;
  final Customer customer;
  final String createdBy;
  final String? driverId;
  final List<String> driverIds;
  final List<String>? vehicleIds;
  final String? proofImage;
  final GeoPoint? proofLocation;
  final GeoPoint? destinationLocation;
  final String? details;
  final double? price; // New field from Firestore
  final List<String> billImageUrls;
  final List<DeliveryTeamItem> deliveryTeam;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isDepartureApproved; // เพิ่มฟิลด์
  final String jobType; // ✅ Added jobType
  final List<JobItem> items; // ✅ Added items list
  final String? paymentMethod; // ✅ 'cash' or 'credit'

  // Getter สำหรับรองรับโค้ดเก่าที่ใช้รูปเดียว
  String? get billImageUrl =>
      billImageUrls.isNotEmpty ? billImageUrls.first : null;

  const Job({
    required this.id,
    this.localOrderId, // ✅ Init
    required this.status,
    this.customerId,
    required this.customer,
    required this.createdBy,
    this.driverId,
    this.driverIds = const [],
    this.vehicleIds,
    this.proofImage,
    this.proofLocation,
    this.destinationLocation,
    this.details,
    this.price,
    this.billImageUrls = const [],
    required this.deliveryTeam,
    required this.createdAt,
    this.completedAt,
    this.isDepartureApproved = false, // Default false
    this.jobType = 'delivery', // ✅ Default to delivery
    this.items = const [], // ✅ Default empty
    this.paymentMethod, // ✅ Added paymentMethod
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? getNullableDate(dynamic timestamp) {
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is String) return DateTime.tryParse(timestamp);
      if (timestamp is DateTime) return timestamp;
      return null;
    }

    Customer parseCustomer(dynamic customerData) {
      if (customerData is Map) {
        return Customer.fromJson(Map<String, dynamic>.from(customerData));
      }
      if (customerData is String && customerData.isNotEmpty) {
        try {
          final decoded = jsonDecode(customerData);
          if (decoded is Map) return Customer.fromJson(Map<String, dynamic>.from(decoded));
        } catch (_) {}
      }
      return const Customer(name: '-', address: '', phoneNumber: '');
    }

    List<String> parseBillImages(Map<String, dynamic> data) {
      final billData = data['bill_image_urls'] ?? data['bill_image_url'];
      if (billData == null) return [];
      if (billData is List) return billData.map((e) => e.toString()).toList();
      if (billData is String && billData.isNotEmpty) {
        try {
          final decoded = jsonDecode(billData);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
          return [decoded.toString()];
        } catch (_) {
          if (billData.contains(',')) {
            return billData.split(',').map((e) => e.trim()).toList();
          }
          return [billData];
        }
      }
      return [];
    }

    List<String> parseDriverIds(Map<String, dynamic> data) {
      if (data['driver_ids'] != null && data['driver_ids'] is List) {
        return (data['driver_ids'] as List).map((e) => e.toString()).toList();
      }
      if (data['driver_id'] != null) {
        return [data['driver_id'].toString()];
      }
      return [];
    }

    List<dynamic> parseItems(dynamic itemsData) {
      if (itemsData == null) return [];
      if (itemsData is List) return itemsData;
      if (itemsData is String && itemsData.isNotEmpty) {
        try {
          final decoded = jsonDecode(itemsData);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
      return [];
    }

    List<DeliveryTeamItem> parseDeliveryTeam(dynamic teamData) {
      List<dynamic> list = [];
      if (teamData is List) {
        list = teamData;
      } else if (teamData is String && teamData.isNotEmpty) {
        try {
          final decoded = jsonDecode(teamData);
          if (decoded is List) list = decoded;
        } catch (_) {}
      }

      return list.map((item) {
        try {
          if (item is Map) {
            return DeliveryTeamItem.fromJson(Map<String, dynamic>.from(item));
          }
          return const DeliveryTeamItem(id: 'unknown', name: 'Unknown', type: 'driver');
        } catch (_) {
          return const DeliveryTeamItem(id: 'error', name: 'Error Parsing', type: 'driver');
        }
      }).toList();
    }

    List<String> parseVehicleIds(dynamic vehicleData) {
      if (vehicleData == null) return [];
      if (vehicleData is List) return vehicleData.map((e) => e.toString()).toList();
      if (vehicleData is String && vehicleData.isNotEmpty) {
        try {
          final decoded = jsonDecode(vehicleData);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
          return [decoded.toString()];
        } catch (_) {}
      }
      return [];
    }

    return Job(
      id: doc.id,
      localOrderId: int.tryParse((data['localOrderId'] ?? data['order_id'])?.toString() ?? ''),
      status: data['status'] ?? 'pending',
      customerId: data['customer_id'],
      customer: parseCustomer(data['customer']),
      createdBy: data['created_by'] ?? '',
      driverId: data['driver_id'],
      driverIds: parseDriverIds(data),
      vehicleIds: parseVehicleIds(data['vehicle_ids']),
      proofImage: data['proof_image'],
      proofLocation: data['proof_location'] as GeoPoint?,
      destinationLocation: data['destination_location'] as GeoPoint?,
      details: data['details'],
      price: (data['price'] as num?)?.toDouble(),
      billImageUrls: parseBillImages(data),
      items: (parseItems(data['items'])).map((item) {
        try {
          return JobItem.fromJson(Map<String, dynamic>.from(item as Map));
        } catch (_) {
          return const JobItem(name: 'Unknown', qty: 1, price: 0, total: 0);
        }
      }).toList(),
      deliveryTeam: parseDeliveryTeam(data['delivery_team']),
      createdAt: getNullableDate(data['created_at']) ?? DateTime.now(),
      completedAt: getNullableDate(data['completed_at']),
      isDepartureApproved: data['is_departure_approved'] ?? false,
      jobType: data['job_type'] ?? 'delivery',
      paymentMethod: data['payment_method'],
    );
  }

  /// ✅ Factory: แปลงจาก delivery_history (MySQL via API) → Job
  /// ใช้สำหรับ Tab "งานที่เสร็จแล้ว" ที่ดึงจาก POS Backend แทน Firebase
  factory Job.fromHistory(Map<String, dynamic> row) {
    DateTime? parseDate(dynamic val) {
      if (val == null || val.toString().isEmpty) return null;
      try { return DateTime.parse(val.toString()); } catch (_) { return null; }
    }

    final completedAt = parseDate(row['completedAt']);
    final driverName = row['driverName']?.toString() ?? '';
    final vehiclePlate = row['vehiclePlate']?.toString() ?? '';

    // สร้าง delivery team จาก driverName + vehiclePlate
    final team = <DeliveryTeamItem>[];
    if (driverName.isNotEmpty) {
      final names = driverName.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      for (var name in names) {
        team.add(DeliveryTeamItem(id: 'h_driver_$name', name: name, type: 'driver'));
      }
    }
    if (vehiclePlate.isNotEmpty) {
      team.add(DeliveryTeamItem(id: 'h_car', name: vehiclePlate, type: 'car'));
    }

    GeoPoint? destLocation;
    final locUrl = row['locationUrl']?.toString() ?? '';
    if (locUrl.isNotEmpty && locUrl.contains('q=')) {
      final q = locUrl.split('q=').last;
      final parts = q.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) {
          destLocation = GeoPoint(lat, lng);
        }
      }
    } else if (row['destinationLat'] != null && row['destinationLng'] != null) {
      final lat = double.tryParse(row['destinationLat'].toString());
      final lng = double.tryParse(row['destinationLng'].toString());
      if (lat != null && lng != null) {
        destLocation = GeoPoint(lat, lng);
      }
    }

    String? proofImg = row['billImageUrl']?.toString();
    if (proofImg != null && proofImg.trim().isEmpty) {
      proofImg = null; // Prevent displaying empty image widgets
    }

    return Job(
      id: 'history_${row['id'] ?? row['orderId']}',
      localOrderId: int.tryParse(row['orderId']?.toString() ?? '0'),
      status: 'completed',
      customer: Customer(
        name: row['customerName']?.toString() ?? '-',
        address: row['customerAddress']?.toString() ?? '',
        phoneNumber: row['customerPhone']?.toString() ?? '',
      ),
      createdBy: driverName,
      price: double.tryParse(row['totalAmount']?.toString() ?? '0'),
      deliveryTeam: team,
      createdAt: completedAt ?? DateTime.now(),
      completedAt: completedAt,
      isDepartureApproved: true,
      jobType: row['jobType']?.toString() ?? 'delivery',
      details: row['note']?.toString(),
      destinationLocation: destLocation,
      proofImage: proofImg,
    );
  }

  Job copyWith({
    String? id,
    int? localOrderId, // ✅ Param
    String? status,
    String? customerId,
    Customer? customer,
    String? createdBy,
    String? driverId,
    List<String>? driverIds,
    List<String>? vehicleIds,
    String? proofImage,
    GeoPoint? proofLocation,
    GeoPoint? destinationLocation,
    String? details,
    double? price,
    List<String>? billImageUrls,
    List<DeliveryTeamItem>? deliveryTeam,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? isDepartureApproved,
    String? jobType,
    String? paymentMethod, // ✅ Param
    List<JobItem>? items, // ✅ Param
  }) {
    return Job(
      id: id ?? this.id,
      localOrderId: localOrderId ?? this.localOrderId, // ✅ Assign
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
      customer: customer ?? this.customer,
      createdBy: createdBy ?? this.createdBy,
      driverId: driverId ?? this.driverId,
      driverIds: driverIds ?? this.driverIds,
      vehicleIds: vehicleIds ?? this.vehicleIds,
      proofImage: proofImage ?? this.proofImage,
      proofLocation: proofLocation ?? this.proofLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      details: details ?? this.details,
      price: price ?? this.price,
      billImageUrls: billImageUrls ?? this.billImageUrls,
      deliveryTeam: deliveryTeam ?? this.deliveryTeam,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      isDepartureApproved: isDepartureApproved ?? this.isDepartureApproved,
      jobType: jobType ?? this.jobType,
      paymentMethod: paymentMethod ?? this.paymentMethod, // ✅ Assign
      items: items ?? this.items, // ✅ Assign
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'localOrderId': localOrderId, // ✅ Save
      'status': status,
      'customer_id': customerId,
      'customer': customer.toJson(),
      'created_by': createdBy,
      'driver_id': driverId,
      'driver_ids': driverIds,
      'vehicle_ids': vehicleIds,
      'proof_image': proofImage,
      'proof_location': proofLocation,
      'destination_location': destinationLocation,
      'details': details,
      'price': price,
      'bill_image_urls': billImageUrls,
      'delivery_team': deliveryTeam.map((item) => item.toJson()).toList(),
      'created_at': Timestamp.fromDate(createdAt),
      'completed_at':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'is_departure_approved': isDepartureApproved, // Save to Firestore
      'job_type': jobType, // ✅ Save jobType
      'payment_method': paymentMethod, // ✅ Save paymentMethod
      'items': items.map((e) => e.toJson()).toList(), // ✅ Save items
    };
  }
}
