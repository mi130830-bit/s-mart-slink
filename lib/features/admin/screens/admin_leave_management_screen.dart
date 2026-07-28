import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

class AdminLeaveManagementScreen extends StatefulWidget {
  const AdminLeaveManagementScreen({super.key});

  @override
  State<AdminLeaveManagementScreen> createState() =>
      _AdminLeaveManagementScreenState();
}

class _AdminLeaveManagementScreenState
    extends State<AdminLeaveManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('จัดการวันลา (Admin)'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          bottom: const TabBar(
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal,
            tabs: [
              Tab(text: 'จัดการรายวัน'),
              Tab(text: 'ประวัติการลา'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminLeaveControlView(),
            _AdminLeaveHistoryView(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. หน้าจัดการ (Control View) - โค้ดใหม่ แบบฟอร์มสไตล์ POS
// ---------------------------------------------------------------------------
class _AdminLeaveControlView extends StatefulWidget {
  const _AdminLeaveControlView();

  @override
  State<_AdminLeaveControlView> createState() => _AdminLeaveControlViewState();
}

class _AdminLeaveControlViewState extends State<_AdminLeaveControlView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? _selectedUserId;
  Map<String, dynamic>? _selectedUserData;

  String _leaveType = 'PERSONAL';
  String _leaveFormat = 'FULL_DAY';

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  double _totalDays = 1.0;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _calculateTotalDays() {
    if (_leaveFormat == 'FULL_DAY') {
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
      final diff = end.difference(start).inDays;
      _totalDays = (diff >= 0 ? diff + 1 : 1).toDouble();
    } else if (_leaveFormat == 'HALF_MORNING' ||
        _leaveFormat == 'HALF_AFTERNOON') {
      _totalDays = 0.5;
    } else if (_leaveFormat == 'HOURLY') {
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day,
          _startTime.hour, _startTime.minute);
      final end = DateTime(_startDate.year, _startDate.month, _startDate.day,
          _endTime.hour, _endTime.minute);
      final diffHours = end.difference(start).inMinutes / 60.0;
      _totalDays = double.parse((diffHours / 8.0).toStringAsFixed(2));
      if (_totalDays < 0) _totalDays = 0;
    }
    setState(() {});
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_leaveFormat != 'FULL_DAY' || _endDate.isBefore(_startDate)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = picked;
          }
        }
      });
      _calculateTotalDays();
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      _calculateTotalDays();
    }
  }

  Future<void> _submitLeave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null || _selectedUserData == null) {
      SnackbarUtils.showLeft(context, 'กรุณาเลือกพนักงานก่อน');
      return;
    }
    if (_totalDays <= 0) {
      SnackbarUtils.showLeft(context, 'จำนวนวันลาไม่ถูกต้อง', isError: true);
      return;
    }

    try {
      final start = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _leaveFormat == 'HOURLY' ? _startTime.hour : 0,
          _leaveFormat == 'HOURLY' ? _startTime.minute : 0);

      final end = DateTime(
          _leaveFormat == 'FULL_DAY' ? _endDate.year : _startDate.year,
          _leaveFormat == 'FULL_DAY' ? _endDate.month : _startDate.month,
          _leaveFormat == 'FULL_DAY' ? _endDate.day : _startDate.day,
          _leaveFormat == 'HOURLY' ? _endTime.hour : 23,
          _leaveFormat == 'HOURLY' ? _endTime.minute : 59);

      final String userName = _selectedUserData!['name'] ?? 'Unknown';
      final String userRole = _selectedUserData!['role'] ?? '-';

      final Map<String, dynamic> data = {
        'user_id': _selectedUserId,
        'employee_id': _selectedUserId,
        'user_name': userName,
        'action': 'holiday_start',
        'logged_at': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(start),
        'leave_type': _leaveType,
        'leave_format': _leaveFormat,
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
        'total_days': _totalDays,
        'reason': _reasonController.text.trim(),
        'status': 'PENDING',
      };
      
      if (userRole == 'requester') {
        data['role'] = 'requester';
      }

      await _firestore.collection('holiday_logs').add(data);

      if (!mounted) return;

      SnackbarUtils.showLeft(context, 'บันทึกใบลาให้ $userName เรียบร้อย (รออนุมัติ)');

      setState(() {
        _selectedUserId = null;
        _selectedUserData = null;
        _reasonController.clear();
        _totalDays = 1.0;
        _leaveFormat = 'FULL_DAY';
        _leaveType = 'PERSONAL';
        _startDate = DateTime.now();
        _endDate = DateTime.now();
      });
    } catch (e) {
      log('Error submitting leave: $e');
      if (!mounted) return;
      SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '➕ สร้างใบลา (Leave Request)',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .where('role', whereIn: ['driver', 'requester']).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final users = snapshot.data!.docs;
                    if (users.isEmpty) return const Text('ไม่พบรายชื่อพนักงาน');

                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'พนักงาน',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      initialValue: _selectedUserId,
                      items: users.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text('${data['name']} (${data['role']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedUserId = val;
                          _selectedUserData = users
                              .firstWhere((doc) => doc.id == val)
                              .data() as Map<String, dynamic>;
                        });
                      },
                      validator: (val) => val == null ? 'กรุณาเลือกพนักงาน' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'ประเภทการลา',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  initialValue: _leaveType,
                  items: const [
                    DropdownMenuItem(value: 'PERSONAL', child: Text('ลากิจ (Personal Leave)')),
                    DropdownMenuItem(value: 'SICK', child: Text('ลาป่วย (Sick Leave)')),
                    DropdownMenuItem(value: 'VACATION', child: Text('ลาพักร้อน (Vacation)')),
                    DropdownMenuItem(value: 'MATERNITY', child: Text('ลาคลอด (Maternity)')),
                    DropdownMenuItem(value: 'OTHER', child: Text('อื่นๆ (Other)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _leaveType = val);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'รูปแบบการลา',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  initialValue: _leaveFormat,
                  items: const [
                    DropdownMenuItem(value: 'FULL_DAY', child: Text('ลาเต็มวัน (Full Day)')),
                    DropdownMenuItem(value: 'HALF_MORNING', child: Text('ลาครึ่งวันเช้า (Morning)')),
                    DropdownMenuItem(value: 'HALF_AFTERNOON', child: Text('ลาครึ่งวันบ่าย (Afternoon)')),
                    DropdownMenuItem(value: 'HOURLY', child: Text('ลาระบุเวลา (Hourly)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _leaveFormat = val;
                        _endDate = _startDate;
                        _calculateTotalDays();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_leaveFormat == 'FULL_DAY')
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
                          child: InputDecorator(
                            decoration: InputDecoration(labelText: 'วันที่เริ่มลา', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, false),
                          child: InputDecorator(
                            decoration: InputDecoration(labelText: 'ถึงวันที่', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text('${_endDate.day}/${_endDate.month}/${_endDate.year}'),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: 'วันที่ลา', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_leaveFormat == 'HOURLY')
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, true),
                          child: InputDecorator(
                            decoration: InputDecoration(labelText: 'ตั้งแต่เวลา', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text(_startTime.format(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, false),
                          child: InputDecorator(
                            decoration: InputDecoration(labelText: 'ถึงเวลา', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text(_endTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_leaveFormat == 'HOURLY') const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calculate, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text('สรุปจำนวนวันลา: $_totalDays วัน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    labelText: 'เหตุผลการลา (ถ้ามี)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _submitLeave,
                  icon: const Icon(Icons.save),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('บันทึกใบลา', style: TextStyle(fontSize: 16)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. หน้าประวัติ (History View) - สร้างใหม่
// ---------------------------------------------------------------------------
class _AdminLeaveHistoryView extends StatefulWidget {
  const _AdminLeaveHistoryView();

  @override
  State<_AdminLeaveHistoryView> createState() => _AdminLeaveHistoryViewState();
}

class _AdminLeaveHistoryViewState extends State<_AdminLeaveHistoryView> {
  DateTime _selectedDate = DateTime.now();

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final dt = timestamp.toDate();
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _changeDate(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _deleteAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ ลบประวัติทั้งหมด'),
        content: const Text(
            'คุณต้องการลบข้อมูลประวัติการลา "ทั้งหมดในระบบ" ใช่หรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('ยืนยันลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    SnackbarUtils.showLeft(context, 'กำลังลบข้อมูล... กรุณารอสักครู่');

    try {
      final collection = FirebaseFirestore.instance.collection('holiday_logs');
      int totalDeleted = 0;
      while (true) {
        final snapshot = await collection.limit(500).get();
        if (snapshot.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        totalDeleted += snapshot.docs.length;
      }

      if (mounted) {
        SnackbarUtils.showLeft(context, 'ลบข้อมูลเรียบร้อยแล้ว $totalDeleted รายการ');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณช่วงเวลา Start/End ของวัน
    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    return Column(
      children: [
        // --- 1. Date Navigator & Delete Button ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date Nav
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    onPressed: () => _changeDate(-1),
                    splashRadius: 20,
                  ),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(
                            _formatDisplayDate(_selectedDate),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () => _changeDate(1),
                    splashRadius: 20,
                  ),
                  if (!DateUtils.isSameDay(_selectedDate, DateTime.now()))
                    IconButton(
                      onPressed: () =>
                          setState(() => _selectedDate = DateTime.now()),
                      icon: const Icon(Icons.today, color: Colors.blue),
                      tooltip: 'กลับไปวันนี้',
                    )
                ],
              ),
              // Delete All Button
              IconButton(
                onPressed: _deleteAllHistory,
                icon: const Icon(Icons.delete_forever, color: Colors.pink),
                tooltip: 'ลบประวัติทั้งหมด',
              ),
            ],
          ),
        ),

        // --- 2. List View ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('holiday_logs')
                .where('logged_at',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                .where('logged_at',
                    isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                .orderBy('logged_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // If index required, showed error
                return Center(
                    child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      'ไม่สามารถโหลดข้อมูลได้ (อาจต้องสร้าง Index): ${snapshot.error}',
                      style: const TextStyle(color: Colors.red)),
                ));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off,
                          size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text(
                          'ไม่มีประวัติการลาในวันที่ ${_formatDisplayDate(_selectedDate)}',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final userName = data['user_name'] ?? 'Unknown';
                  final action = data['action'] ?? '';
                  final loggedAt = data['logged_at'] as Timestamp?;

                  final isStart = action == 'holiday_start';

                  // แปล action เป็นภาษาไทย
                  String actionText =
                      isStart ? 'แจ้งลาหยุด' : 'แจ้งกลับมาทำงาน';
                  Color statusColor = isStart ? Colors.orange : Colors.green;
                  IconData statusIcon =
                      isStart ? Icons.beach_access : Icons.work;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      child: Icon(statusIcon, color: statusColor),
                    ),
                    title: Text(userName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('เวลา: ${_formatDate(loggedAt)}'),
                    trailing: Chip(
                      label: Text(
                        actionText,
                        style: TextStyle(color: statusColor, fontSize: 12),
                      ),
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      side: BorderSide.none,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
