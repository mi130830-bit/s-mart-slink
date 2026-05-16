// ไฟล์: lib/screens/admin/driver_holiday_log_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// ✅ [เพิ่ม] Import เพื่อโหลดข้อมูลภาษาไทย
import 'package:intl/date_symbol_data_local.dart';

class DriverHolidayLogScreen extends StatefulWidget {
  const DriverHolidayLogScreen({super.key});

  @override
  State<DriverHolidayLogScreen> createState() => _DriverHolidayLogScreenState();
}

class _DriverHolidayLogScreenState extends State<DriverHolidayLogScreen> {
  // วันเริ่มต้นสัปดาห์ปัจจุบัน (วันจันทร์ของสัปดาห์ที่ต้องการแสดง)
  late DateTime _startDate;
  // วันสิ้นสุดสัปดาห์ปัจจุบัน (วันเสาร์ของสัปดาห์ที่ต้องการแสดง)
  late DateTime _endDate;

  // ✅ [เพิ่ม] ตัวแปรเช็คสถานะการโหลดภาษา
  bool _isLocaleReady = false;

  @override
  void initState() {
    super.initState();

    // ✅ [เพิ่ม] โหลดข้อมูลวันที่ภาษาไทย ('th') ก่อนเริ่มทำงาน
    initializeDateFormatting('th', null).then((_) {
      if (mounted) {
        setState(() {
          _isLocaleReady = true;
        });
      }
    });

    _calculateCurrentWeek();
  }

  // ✅ [ฟังก์ชัน] คำนวณช่วงสัปดาห์ (จันทร์ - เสาร์)
  void _calculateCurrentWeek() {
    final now = DateUtils.dateOnly(DateTime.now());

    // ตั้งต้นให้เป็นวันจันทร์ของสัปดาห์ปัจจุบัน
    int daysToMonday = now.weekday - DateTime.monday;

    // ถ้าวันนี้เป็นวันอาทิตย์ (7) จะต้องถอยไป 6 วันเพื่อหาวันจันทร์ที่แล้ว
    if (now.weekday == DateTime.sunday) {
      daysToMonday = 6;
    }

    _startDate = now.subtract(Duration(days: daysToMonday));

    // วันเสาร์ (start_date + 5 วัน)
    _endDate = _startDate.add(const Duration(days: 5));
  }

  // ✅ [ฟังก์ชัน] เลื่อนไปสัปดาห์ก่อนหน้า/ถัดไป
  void _changeWeek(int offset) {
    setState(() {
      _startDate = _startDate.add(Duration(days: 7 * offset));
      _endDate = _endDate.add(Duration(days: 7 * offset));
    });
  }

  // ✅ [ฟังก์ชัน] ดึงข้อมูลการลาหยุดตามช่วงวันที่
  Future<Map<String, List<DateTime>>> _fetchHolidayLogs() async {
    // 1. ดึง logs ทั้งหมดในช่วงวันที่ที่เลือก (action: holiday_start เท่านั้น)
    final snapshot = await FirebaseFirestore.instance
        .collection('holiday_logs')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        // ใช้เวลาสิ้นสุดของวันเสาร์ (วันอาทิตย์เที่ยงคืน)
        .where('date',
            isLessThanOrEqualTo:
                Timestamp.fromDate(_endDate.add(const Duration(days: 1))))
        .where('action', isEqualTo: 'holiday_start')
        .orderBy('date', descending: true)
        .get();

    // 2. จัดกลุ่ม logs ตาม user_id
    Map<String, List<DateTime>> driverHolidays = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final userId = data['user_id'] as String;
      // ใช้ชื่อจาก log ซึ่งควรเป็นชื่อพนักงาน
      final userName = data['user_name'] as String;
      final date = (data['date'] as Timestamp).toDate();

      // ใช้ key เป็น user_id+user_name
      final key = '$userId|$userName';

      if (!driverHolidays.containsKey(key)) {
        driverHolidays[key] = [];
      }
      // บันทึกเฉพาะวันที่
      driverHolidays[key]!.add(DateUtils.dateOnly(date));
    }

    return driverHolidays;
  }

  // ✅ [UI] Build ตารางสรุปรายสัปดาห์
  Widget _buildWeeklySummaryTable(Map<String, List<DateTime>> driverHolidays) {
    // หัวข้อวันในสัปดาห์ (จันทร์-เสาร์)
    List<DateTime> weekDays = [];
    for (int i = 0; i < 6; i++) {
      // 0=จันทร์, 5=เสาร์
      weekDays.add(_startDate.add(Duration(days: i)));
    }

    final driverKeys = driverHolidays.keys.toList()
      ..sort((a, b) =>
          a.split('|')[1].compareTo(b.split('|')[1])); // จัดเรียงตามชื่อ

    if (driverKeys.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(30),
        child: Text('ไม่พบประวัติการลาหยุดในสัปดาห์นี้',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        dataRowMaxHeight: 60,
        columns: [
          const DataColumn(
              label: Text('พนักงาน',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          // หัวคอลัมน์วันที่
          ...weekDays.map((date) => DataColumn(
                label: Text(
                  // ตรงนี้คือจุดที่เคย Error ถ้าไม่ได้ Initialize Locale
                  '${DateFormat('E', 'th').format(date)}\n${DateFormat('dd/MM').format(date)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              )),
          const DataColumn(
              label: Text('รวม (วัน)',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: driverKeys.map((key) {
          final parts = key.split('|');
          // final userId = parts[0];
          final userName = parts[1];
          final holidayDates = driverHolidays[key]!;

          int totalDays = 0;
          List<DataCell> dayCells = [];

          for (var day in weekDays) {
            final isHoliday = holidayDates.contains(day);
            if (isHoliday) {
              totalDays++;
            }

            dayCells.add(
              DataCell(
                Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isHoliday
                          ? Colors.orange.shade100
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: isHoliday ? Colors.orange : Colors.transparent,
                          width: 1),
                    ),
                    child: Center(
                      child: isHoliday
                          ? const Icon(Icons.flight_takeoff,
                              color: Colors.orange, size: 18)
                          : const Text('-',
                              style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            );
          }

          return DataRow(cells: [
            DataCell(Text(userName,
                style: const TextStyle(fontWeight: FontWeight.bold))),
            ...dayCells,
            DataCell(Text(totalDays.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold))),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ [เพิ่ม] ถ้าภาษายังโหลดไม่เสร็จ ให้แสดง Loading เพื่อป้องกัน Error
    if (!_isLocaleReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ใช้วันเริ่มต้นและสิ้นสุดที่คำนวณไว้ (เมื่อภาษาโหลดเสร็จแล้วจะทำงานได้ปกติ)
    final startOfWeek = DateFormat('d MMM yyyy', 'th').format(_startDate);
    final endOfWeek = DateFormat('d MMM yyyy', 'th').format(_endDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการลาหยุดพนักงาน'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => _changeWeek(-1),
                ),
                Column(
                  children: [
                    const Text('สรุปรายสัปดาห์ (จันทร์ - เสาร์)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$startOfWeek - $endOfWeek',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.pink)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  // ป้องกันการไปสัปดาห์ที่ยังไม่ถึง (ถ้าวันเสาร์ของสัปดาห์ที่กำลังดูยังไม่ผ่านไป)
                  onPressed:
                      _endDate.isBefore(DateUtils.dateOnly(DateTime.now()))
                          ? () => _changeWeek(1)
                          : null,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<Map<String, List<DateTime>>>(
              // กำหนด key เพื่อให้ FutureBuilder ถูกเรียกใหม่เมื่อช่วงวันเปลี่ยน
              key: ValueKey(_startDate),
              future: _fetchHolidayLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('ไม่พบข้อมูลการลาหยุด'));
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _buildWeeklySummaryTable(snapshot.data!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
