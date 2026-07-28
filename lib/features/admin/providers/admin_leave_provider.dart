import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

class AdminLeaveProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Form State ---
  String? selectedUserId;
  Map<String, dynamic>? selectedUserData;

  String leaveType = 'PERSONAL';
  String leaveFormat = 'FULL_DAY';

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

  double totalDays = 1.0;
  final TextEditingController reasonController = TextEditingController();

  // --- History State ---
  DateTime historySelectedDate = DateTime.now();

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  // --- Form Logic ---
  void setSelectedUser(String? id, Map<String, dynamic>? data) {
    selectedUserId = id;
    selectedUserData = data;
    notifyListeners();
  }

  void setLeaveType(String type) {
    leaveType = type;
    notifyListeners();
  }

  void setLeaveFormat(String format) {
    leaveFormat = format;
    if (format != 'FULL_DAY') {
      endDate = startDate;
    }
    calculateTotalDays();
    notifyListeners();
  }

  void calculateTotalDays() {
    if (leaveFormat == 'FULL_DAY') {
      final diff = endDate.difference(startDate).inDays;
      totalDays = (diff >= 0 ? diff + 1 : 1).toDouble();
    } else if (leaveFormat == 'HALF_MORNING' || leaveFormat == 'HALF_AFTERNOON') {
      totalDays = 0.5;
    } else if (leaveFormat == 'HOURLY') {
      final start = DateTime(startDate.year, startDate.month, startDate.day,
          startTime.hour, startTime.minute);
      final end = DateTime(startDate.year, startDate.month, startDate.day,
          endTime.hour, endTime.minute);
      final diffHours = end.difference(start).inMinutes / 60.0;
      totalDays = double.parse((diffHours / 8.0).toStringAsFixed(2));
      if (totalDays < 0) totalDays = 0;
    }
    notifyListeners();
  }

  void setStartDate(DateTime date) {
    startDate = date;
    if (leaveFormat != 'FULL_DAY' || endDate.isBefore(startDate)) {
      endDate = date;
    }
    calculateTotalDays();
  }

  void setEndDate(DateTime date) {
    endDate = date;
    if (endDate.isBefore(startDate)) {
      startDate = date;
    }
    calculateTotalDays();
  }

  void setStartTime(TimeOfDay time) {
    startTime = time;
    calculateTotalDays();
  }

  void setEndTime(TimeOfDay time) {
    endTime = time;
    calculateTotalDays();
  }

  Future<void> submitLeave({
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    if (selectedUserId == null || selectedUserData == null) {
      onError('กรุณาเลือกพนักงานก่อน');
      return;
    }
    if (totalDays <= 0) {
      onError('จำนวนวันลาไม่ถูกต้อง');
      return;
    }

    try {
      final start = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          leaveFormat == 'HOURLY' ? startTime.hour : 0,
          leaveFormat == 'HOURLY' ? startTime.minute : 0);

      final end = DateTime(
          leaveFormat == 'FULL_DAY' ? endDate.year : startDate.year,
          leaveFormat == 'FULL_DAY' ? endDate.month : startDate.month,
          leaveFormat == 'FULL_DAY' ? endDate.day : startDate.day,
          leaveFormat == 'HOURLY' ? endTime.hour : 23,
          leaveFormat == 'HOURLY' ? endTime.minute : 59);

      final String userName = selectedUserData!['name'] ?? 'Unknown';
      final String userRole = selectedUserData!['role'] ?? '-';

      final Map<String, dynamic> data = {
        'user_id': selectedUserId,
        'employee_id': selectedUserId,
        'user_name': userName,
        'action': 'holiday_start',
        'logged_at': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(start),
        'leave_type': leaveType,
        'leave_format': leaveFormat,
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
        'total_days': totalDays,
        'reason': reasonController.text.trim(),
        'status': 'PENDING',
      };
      
      if (userRole == 'requester') {
        data['role'] = 'requester';
      }

      await _firestore.collection('holiday_logs').add(data);

      onSuccess('บันทึกใบลาให้ $userName เรียบร้อย (รออนุมัติ)');

      // Reset form
      selectedUserId = null;
      selectedUserData = null;
      reasonController.clear();
      totalDays = 1.0;
      leaveFormat = 'FULL_DAY';
      leaveType = 'PERSONAL';
      startDate = DateTime.now();
      endDate = DateTime.now();
      notifyListeners();
    } catch (e) {
      log('Error submitting leave: $e');
      onError('เกิดข้อผิดพลาด: $e');
    }
  }

  // --- History Logic ---
  void changeHistoryDate(int offset) {
    historySelectedDate = historySelectedDate.add(Duration(days: offset));
    notifyListeners();
  }

  void setHistoryDate(DateTime date) {
    historySelectedDate = date;
    notifyListeners();
  }

  Future<void> deleteAllHistory({
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final collection = _firestore.collection('holiday_logs');
      final snapshot = await collection.limit(500).get();
      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      onSuccess('ลบข้อมูลเรียบร้อย');
    } catch (e) {
      onError('เกิดข้อผิดพลาด: $e');
    }
  }

  Stream<QuerySnapshot> getUsersStream() {
    return _firestore
        .collection('users')
        .where('role', whereIn: ['driver', 'requester'])
        .snapshots();
  }

  Stream<QuerySnapshot> getHistoryStream() {
    final startOfDay = DateTime(historySelectedDate.year, historySelectedDate.month, historySelectedDate.day);
    final endOfDay = DateTime(historySelectedDate.year, historySelectedDate.month, historySelectedDate.day, 23, 59, 59);

    return _firestore
        .collection('holiday_logs')
        .where('logged_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('logged_at', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('logged_at', descending: true)
        .snapshots();
  }
}
