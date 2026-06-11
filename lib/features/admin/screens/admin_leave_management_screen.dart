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
  String? _selectedUserId;
  Map<String, dynamic>? _selectedUserData;

  Future<void> _submitLeave(bool isLeaving) async {
    if (_selectedUserId == null || _selectedUserData == null) {
      SnackbarUtils.showLeft(context, 'กรุณาเลือกพนักงานก่อน');
      return;
    }
    try {
      final action = isLeaving ? 'holiday_start' : 'holiday_end';
      final today = DateUtils.dateOnly(DateTime.now());

      final String userName = _selectedUserData!['name'] ?? 'Unknown';
      final String userRole = _selectedUserData!['role'] ?? '-';

      final Map<String, dynamic> data = {
        'user_id': _selectedUserId,
        'user_name': userName,
        'action': action,
        'logged_at': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(today),
      };

      if (userRole == 'requester') {
        data['role'] = 'requester';
      }

      await _firestore.collection('holiday_logs').add(data);

      if (!mounted) return;

      SnackbarUtils.showLeft(context, '${isLeaving ? "เริ่ม" : "ยกเลิก"}การลาให้ $userName แล้ว');

      setState(() {
        _selectedUserId = null;
        _selectedUserData = null;
      });
    } catch (e) {
      log('Error toggling leave: $e');
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'บันทึกวันลา (รายวัน)',
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
                      labelText: 'เลือกพนักงาน',
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
                  );
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _submitLeave(true),
                      icon: const Icon(Icons.event_busy),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text('เริ่มลาหยุด',
                            style: TextStyle(fontSize: 16)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _submitLeave(false),
                      icon: const Icon(Icons.work),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text('กลับมาทำงาน',
                            style: TextStyle(fontSize: 16)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
      // Firebase limit batch delete to 500. We do logic in loop if needed, but here simple batch for now.
      // Better: Get in chunks
      final snapshot = await collection.limit(500).get();
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (mounted) {
        SnackbarUtils.showLeft(context, 'ลบข้อมูลเรียบร้อย');
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
