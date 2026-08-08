import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:s_link/features/auth/services/user_service.dart';
import 'package:s_link/features/auth/models/user.dart';
import 'package:s_link/features/hr/services/attendance_service.dart';
import 'package:s_link/features/hr/models/attendance_model.dart';
import 'package:s_link/features/hr/services/hr_api_service.dart';

class HrOverrideAttendanceScreen extends StatefulWidget {
  const HrOverrideAttendanceScreen({super.key});

  @override
  State<HrOverrideAttendanceScreen> createState() =>
      _HrOverrideAttendanceScreenState();
}

class _HrOverrideAttendanceScreenState
    extends State<HrOverrideAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final HrApiService _hrApi = HrApiService();
  final DateTime _selectedDate = DateTime.now();
  late Future<List<Map<String, dynamic>>> _attendanceFuture;

  @override
  void initState() {
    super.initState();
    _reloadAttendance();
  }

  void _reloadAttendance() {
    _attendanceFuture = _hrApi.getAttendance(
      DateFormat('yyyy-MM-dd').format(_selectedDate),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showOverrideDialog(
      UserModel user, AttendanceLog? existingLog) async {
    final now = DateTime.now();
    bool isCheckIn = existingLog == null || existingLog.checkInTime == null;
    final checkoutTime = DateTime(now.year, now.month, now.day, 17, 0);
    final displayTime = isCheckIn ? now : checkoutTime;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCheckIn ? 'ลงเวลาเข้างานแทน' : 'ลงเวลาออกงานแทน'),
        content: Text(
            'ยืนยันลงเวลาให้ ${user.name} ในเวลา ${DateFormat('HH:mm').format(displayTime)} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCheckIn ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      final config = await _attendanceService.getStoreConfig();
      final lat = config['lat'] ?? 0.0;
      final lng = config['lng'] ?? 0.0;

      if (isCheckIn) {
        final log = AttendanceLog(
          id: '',
          userId: user.id,
          userName: user.name,
          checkInTime: now,
          checkInLat: lat,
          checkInLng: lng,
          date: DateFormat('yyyy-MM-dd').format(now),
          status: 'PRESENT_OVERRIDE',
        );
        await _attendanceService.checkIn(log, requireServer: true);
      } else {
        await _attendanceService.checkOut(
          user.id,
          lat,
          lng,
          outTime: checkoutTime,
          requireServer: true,
        );
      }

      if (mounted) {
        SnackbarUtils.showLeft(context, 'บันทึกเวลาแทนสำเร็จ');
        _reloadAttendance();
      }
    } on AttendanceSyncException {
      if (mounted) {
        SnackbarUtils.showLeft(
          context,
          'บันทึกไว้ในเครื่องแล้ว แต่ยังส่งเข้า POS ไม่สำเร็จ กรุณากดรีเฟรชเมื่อระบบออนไลน์',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เข้างานแทน (HR Override)'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _reloadAttendance,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: FutureBuilder<List<UserModel>>(
        future: UserService().getAllUsers(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userSnapshot.hasError) {
            return Center(child: Text('Error: ${userSnapshot.error}'));
          }

          final users = userSnapshot.data ?? [];
          final activeUsers =
              users.where((u) => u.role.name != 'pending').toList();

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _attendanceFuture,
            builder: (context, logSnapshot) {
              if (logSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (logSnapshot.hasError) {
                return Center(
                    child: Text('โหลดข้อมูลไม่สำเร็จ: ${logSnapshot.error}'));
              }
              final logs = logSnapshot.data ?? const [];
              final logMap = <String, AttendanceLog>{};
              for (final data in logs) {
                final logData =
                    AttendanceLog.fromJson(data, '${data['user_id'] ?? ''}');
                logMap[logData.userId] = logData;
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: activeUsers.length,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (context, index) {
                  final user = activeUsers[index];
                  final userLog = logMap[user.id];

                  final hasCheckIn = userLog?.checkInTime != null;
                  final hasCheckOut = userLog?.checkOutTime != null;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(user.name.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(user.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ตำแหน่ง: ${user.role.name}'),
                        if (hasCheckIn)
                          Text(
                              'เข้างาน: ${DateFormat('HH:mm').format(userLog!.checkInTime!)}',
                              style: const TextStyle(color: Colors.green)),
                        if (userLog?.tempOutTime != null)
                          Text(
                              'ออกชั่วคราว: ${DateFormat('HH:mm').format(userLog!.tempOutTime!)}',
                              style: const TextStyle(color: Colors.orange)),
                        if (userLog?.backToWorkTime != null)
                          Text(
                              'กลับมาทำงาน: ${DateFormat('HH:mm').format(userLog!.backToWorkTime!)}',
                              style: const TextStyle(color: Colors.blue)),
                        if (hasCheckOut)
                          Text(
                              'ออกงาน: ${DateFormat('HH:mm').format(userLog!.checkOutTime!)}',
                              style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                    trailing: hasCheckOut
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(
                            onPressed: () => _showOverrideDialog(user, userLog),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  hasCheckIn ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child:
                                Text(hasCheckIn ? 'ออกงานให้' : 'เข้างานให้'),
                          ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
