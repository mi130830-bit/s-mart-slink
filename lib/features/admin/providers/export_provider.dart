// ไฟล์: lib/providers/export_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:developer';
import 'package:excel/excel.dart';

import 'package:s_link/features/jobs/services/job_service.dart';
import 'package:s_link/core/services/master_data_service.dart';
import 'package:s_link/features/master_data/models/delivery_team_item.dart';

class ExportProvider with ChangeNotifier {
  final JobService _jobService;
  final MasterDataService _masterDataService;

  ExportProvider(this._jobService, this._masterDataService);

  // ----------------------------------------------------
  // I. ABSENCE REPORT (คงเดิม)
  // ----------------------------------------------------
  Future<List<List<dynamic>>> getAbsenceReportData(DateTime start, DateTime end) async {
    log('ExportProvider: Fetching Absence Report from ${start.toIso8601String()} to ${end.toIso8601String()}');
    // Ensure end date includes the whole day
    final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final snapshot = await FirebaseFirestore.instance
        .collection('holiday_logs')
        .where('action', isEqualTo: 'holiday_start')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .get();

    List<List<dynamic>> csvData = [
      ['Name', 'Date (DD/MM/YYYY)']
    ];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String name = data['user_name'] ?? 'Unknown';

      DateTime? date;
      if (data['date'] is Timestamp) {
        date = (data['date'] as Timestamp).toDate();
      } else if (data['logged_at'] is Timestamp) {
        date = (data['logged_at'] as Timestamp).toDate();
      }

      if (date != null) {
        final String dateStr = DateFormat('dd/MM/yyyy').format(date);
        csvData.add([name, dateStr]);
      }
    }
    return csvData;
  }

  // ----------------------------------------------------
  // II. DELIVERY REPORT (แก้ไข: เอาคนขับหลักออก)
  // ----------------------------------------------------
  Future<List<List<dynamic>>> getDeliveryReportData(DateTime start, DateTime end) async {
    log('ExportProvider: Fetching Delivery Report...');

    final completedJobs = await _jobService.getCompletedJobsByDateRange(start, end);

    List<List<dynamic>> csvData = [
      [
        'Customer Name',
        'Helpers Only',
        'Car License Plate'
      ] // เปลี่ยนหัวข้อให้ชัดเจน
    ];

    for (var job in completedJobs) {
      // ✅ กรองเอาเฉพาะ "ทีมงาน" (ไม่ใช่รถ)
      // เปลี่ยนจาก logic เดิมที่แยก driver/helper เป็นการรวมทุกคนที่ไม่ใช่ 'car' หรือ 'vehicle'

      final teamNames = job.deliveryTeam
          .where((m) => m.type != 'car' && m.type != 'vehicle')
          .map((m) => m.name)
          .join(', ');

      // ดึงทะเบียนรถ (เหมือนเดิม)
      final carPlate = job.deliveryTeam
          .where((m) =>
              (m.type == 'car' || m.type == 'vehicle') &&
              m.licensePlate != null)
          .map((m) => m.licensePlate!)
          .join(', ');

      csvData.add([
        job.customer.name,
        teamNames, // รวมทุกคนในช่องนี้
        carPlate,
      ]);
    }

    return csvData;
  }

  // ----------------------------------------------------
  // II.b DELIVERY REPORT (Excel - Separate Sheets)
  // ----------------------------------------------------
  Future<List<int>?> getDeliveryReportExcel(DateTime start, DateTime end) async {
    log('ExportProvider: Generating Delivery Report (Excel)...');

    final completedJobs = await _jobService.getCompletedJobsByDateRange(start, end);
    if (completedJobs.isEmpty) return null;

    // 1. Create Excel Object
    var excel = Excel.createExcel();

    // 2. Group jobs by Car
    Map<String, List<dynamic>> groupedJobs = {};
    for (var job in completedJobs) {
      final carItem = job.deliveryTeam.firstWhere(
          (m) => m.type == 'car' || m.type == 'vehicle',
          orElse: () =>
              const DeliveryTeamItem(type: 'none', name: '-', id: ''));

      String carInfo = carItem.licensePlate ?? carItem.name;
      if (carInfo == '-' || carInfo.isEmpty) carInfo = 'ไม่ระบุรถ';

      if (!groupedJobs.containsKey(carInfo)) {
        groupedJobs[carInfo] = [];
      }
      groupedJobs[carInfo]!.add(job);
    }

    // 3. Process each group to its own sheet
    for (var entry in groupedJobs.entries) {
      String sheetName = entry.key.replaceAll(RegExp(r'[\\/*?\[\]:]'), '_');
      if (sheetName.length > 31) {
        sheetName = sheetName.substring(0, 31);
      }
      
      Sheet sheetObject = excel[sheetName];

      // Define Header
      List<String> header = [
        'วันที่',
        'เวลา',
        'No.',
        'Customer Name',
        'Address',
        'Delivery Team', // ทีมส่งของ (รวม Driver + Helpers)
        'GPS Link'
      ];
      sheetObject.appendRow(header.map((e) => TextCellValue(e)).toList());

      // Sort Jobs (Optional: Sort by completed date for better readability)
      List<dynamic> jobs = entry.value;
      jobs.sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));

      int index = 1;
      for (var job in jobs) {
        // Date and Time
        final targetDate = job.completedAt ?? job.createdAt;
        final dateStr = DateFormat('dd/MM/yyyy').format(targetDate);
        final timeStr = DateFormat('HH:mm:ss').format(targetDate);

        // Find Delivery Team (All Humans)
        final teamNames = job.deliveryTeam
            .where((m) => m.type != 'car' && m.type != 'vehicle')
            .map((m) => m.name)
            .join(', ');

        // GPS Link
        String mapLink = '-';
        if (job.proofLocation != null) {
          final lat = job.proofLocation!.latitude;
          final lng = job.proofLocation!.longitude;
          mapLink = 'https://maps.google.com/?q=$lat,$lng';
        } else if (job.destinationLocation != null) {
          final lat = job.destinationLocation!.latitude;
          final lng = job.destinationLocation!.longitude;
          mapLink = 'https://maps.google.com/?q=$lat,$lng';
        }

        List<CellValue> row = [
          TextCellValue(dateStr),
          TextCellValue(timeStr),
          IntCellValue(index++),
          TextCellValue(job.customer.name),
          TextCellValue(job.customer.address ?? ''),
          TextCellValue(teamNames),
          TextCellValue(mapLink),
        ];

        sheetObject.appendRow(row);
      }
    }

    // 4. Remove default 'Sheet1' if it exists and we aren't using it
    if (excel.tables.keys.contains('Sheet1') && !groupedJobs.keys.contains('Sheet1')) {
      excel.delete('Sheet1');
    }

    // 5. Save
    return excel.save();
  }

  // ----------------------------------------------------
  // III. JOB COUNT REPORT (คงเดิม)
  // ----------------------------------------------------
  Future<List<List<dynamic>>> getJobCountReportData(DateTime start, DateTime end) async {
    log('ExportProvider: Fetching Job Count Report...');

    final completedJobs = await _jobService.getCompletedJobsByDateRange(start, end);
    final deliverers = await _masterDataService.getAllDeliverersForReport();

    final Map<String, String> delivererNames = {
      for (var d in deliverers) d.id: d.name
    };

    final Map<String, int> stats = {};
    for (var job in completedJobs) {
      for (var member in job.deliveryTeam) {
        if (member.type != 'car') {
          final personId = member.id;
          stats[personId] = (stats[personId] ?? 0) + 1;
        }
      }
    }

    final List<MapEntry<String, int>> sortedStats = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<List<dynamic>> csvData = [
      ['Name', 'Total Jobs']
    ];

    for (var entry in sortedStats) {
      final name = delivererNames[entry.key] ?? 'Unknown (${entry.key})';
      csvData.add([
        name,
        entry.value,
      ]);
    }

    return csvData;
  }
}
