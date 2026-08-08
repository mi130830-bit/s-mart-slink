import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'package:s_link/features/hr/services/hr_api_service.dart';

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
  final HrApiService _hrApi = HrApiService();
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
      await _hrApi.createLeave({
        'user_id': _selectedUserId,
        'leave_type': _leaveType,
        'leave_format': _leaveFormat,
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
        'total_days': _totalDays,
        'reason': _reasonController.text.trim(),
      });

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
  final HrApiService _hrApi = HrApiService();
  late Future<List<Map<String, dynamic>>> _leavesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _leavesFuture = _hrApi.getLeaves();
    if (mounted) setState(() {});
  }

  String _formatDisplayDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _changeDate(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
    });
    _reload();
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
      _reload();
    }
  }

  Future<void> _updateLeaveStatus(String id, String status) async {
    try {
      await _hrApi.updateLeaveStatus(id, status);
      if (!mounted) return;
      SnackbarUtils.showLeft(
          context, status == 'APPROVED' ? 'อนุมัติใบลาแล้ว' : 'ไม่อนุมัติใบลาแล้ว');
      _reload();
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'บันทึกรายการไม่สำเร็จ: $e',
            isError: true);
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
                      onPressed: () {
                        setState(() => _selectedDate = DateTime.now());
                        _reload();
                      },
                      icon: const Icon(Icons.today, color: Colors.blue),
                      tooltip: 'กลับไปวันนี้',
                    )
                ],
              ),
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.refresh, color: Colors.teal),
                tooltip: 'รีเฟรชข้อมูลจาก POS',
              ),
            ],
          ),
        ),

        // --- 2. List View ---
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _leavesFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('ไม่สามารถโหลดข้อมูลได้: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final leaves = (snapshot.data ?? const []).where((leave) {
                final start = DateTime.tryParse('${leave['start_date']}');
                final end = DateTime.tryParse('${leave['end_date']}');
                return start != null && end != null &&
                    !start.isAfter(endOfDay) && !end.isBefore(startOfDay);
              }).toList();
              if (leaves.isEmpty) {
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
                itemCount: leaves.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = leaves[index];
                  final status = '${data['status'] ?? 'PENDING'}'.toUpperCase();
                  final isPending = status == 'PENDING';
                  final statusColor = status == 'APPROVED'
                      ? Colors.green
                      : status == 'REJECTED'
                          ? Colors.red
                          : Colors.orange;
                  final statusText = status == 'APPROVED'
                      ? 'อนุมัติแล้ว'
                      : status == 'REJECTED'
                          ? 'ไม่อนุมัติ'
                          : 'รออนุมัติ';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      child: Icon(Icons.beach_access, color: statusColor),
                    ),
                    title: Text('${data['employee_name'] ?? 'Unknown'}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${data['leave_type'] ?? '-'} • ${data['total_days'] ?? '-'} วัน\n${data['reason'] ?? '-'}'),
                    isThreeLine: true,
                    trailing: isPending
                        ? Wrap(spacing: 4, children: [
                            IconButton(
                              tooltip: 'ไม่อนุมัติ',
                              onPressed: () =>
                                  _updateLeaveStatus('${data['id']}', 'REJECTED'),
                              icon: const Icon(Icons.close, color: Colors.red),
                            ),
                            IconButton(
                              tooltip: 'อนุมัติ',
                              onPressed: () =>
                                  _updateLeaveStatus('${data['id']}', 'APPROVED'),
                              icon: const Icon(Icons.check, color: Colors.green),
                            ),
                          ])
                        : Chip(
                            label: Text(statusText,
                                style: TextStyle(color: statusColor, fontSize: 12)),
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
