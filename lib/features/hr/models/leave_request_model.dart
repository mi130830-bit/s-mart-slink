import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequest {
  final String id;
  final String userId;
  final String userName;
  final String leaveType; // SICK, PERSONAL, VACATION
  final String leaveFormat; // FULL_DAY, HALF_DAY_MORNING, HALF_DAY_AFTERNOON
  final DateTime startDate;
  final DateTime endDate;
  final double totalDays;
  final String? reason;
  final String status; // PENDING, APPROVED, REJECTED, CANCELLED
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LeaveRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.leaveType,
    required this.leaveFormat,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    this.reason,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory LeaveRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaveRequest(
      id: doc.id,
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? '',
      leaveType: data['leave_type'] ?? 'PERSONAL',
      leaveFormat: data['leave_format'] ?? 'FULL_DAY',
      startDate: (data['start_date'] as Timestamp).toDate(),
      endDate: (data['end_date'] as Timestamp).toDate(),
      totalDays: (data['total_days'] ?? 0).toDouble(),
      reason: data['reason'],
      status: data['status'] ?? 'PENDING',
      createdAt: data['created_at'] != null ? (data['created_at'] as Timestamp).toDate() : null,
      updatedAt: data['updated_at'] != null ? (data['updated_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'user_name': userName,
      'leave_type': leaveType,
      'leave_format': leaveFormat,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'total_days': totalDays,
      'reason': reason,
      'status': status,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
