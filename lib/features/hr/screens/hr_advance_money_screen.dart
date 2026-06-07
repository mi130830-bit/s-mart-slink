// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:s_link/features/auth/services/user_service.dart';
import 'package:s_link/features/auth/models/user.dart';

class HrAdvanceMoneyScreen extends StatefulWidget {
  const HrAdvanceMoneyScreen({super.key});

  @override
  State<HrAdvanceMoneyScreen> createState() => _HrAdvanceMoneyScreenState();
}

class _HrAdvanceMoneyScreenState extends State<HrAdvanceMoneyScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _showAddRequestDialog() async {
    final users = await UserService().getAllUsers();
    if (!mounted) return;

    UserModel? selectedUser;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final installmentCtrl = TextEditingController();
    bool isInstallment = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('📝 สร้างคำขอเบิกเงินล่วงหน้า'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<UserModel>(
                          isExpanded: true,
                          hint: const Text('เลือกพนักงาน'),
                          value: selectedUser,
                          items: users.map((u) {
                            return DropdownMenuItem<UserModel>(
                              value: u,
                              child: Text(u.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => selectedUser = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: 'จำนวนเงิน (บาท)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(labelText: 'เหตุผล/หมายเหตุ', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('รูปแบบการหักเงินคืน', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    RadioListTile<bool>(
                      title: const Text('หักทั้งหมดรวดเดียว'),
                      value: false,
                      groupValue: isInstallment,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => isInstallment = val!),
                    ),
                    RadioListTile<bool>(
                      title: const Text('หักเป็นงวด (แบ่งจ่าย)'),
                      value: true,
                      groupValue: isInstallment,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => isInstallment = val!),
                    ),
                    if (isInstallment) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: installmentCtrl,
                        decoration: const InputDecoration(labelText: 'จำนวนเงินที่หักต่องวด (บาท)', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedUser == null || amountCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0) return;

                    double? installmentAmount;
                    if (isInstallment) {
                      installmentAmount = double.tryParse(installmentCtrl.text);
                      if (installmentAmount == null || installmentAmount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('กรุณาระบุยอดหักต่องวดให้ถูกต้อง')),
                        );
                        return;
                      }
                      if (installmentAmount > amount) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ยอดหักต่องวดต้องไม่เกินยอดเบิกทั้งหมด')),
                        );
                        return;
                      }
                    }

                    final nav = Navigator.of(ctx);
                    final sm = ScaffoldMessenger.of(context);

                    final data = {
                      'employee_id': selectedUser!.id,
                      'employee_name': selectedUser!.name,
                      'amount': amount,
                      'reason': reasonCtrl.text.trim(),
                      'status': 'pending',
                      'created_at': FieldValue.serverTimestamp(),
                      'synced_to_sql': false,
                    };
                    
                    if (isInstallment && installmentAmount != null) {
                      data['installment_amount'] = installmentAmount;
                    }

                    await _firestore.collection('advance_money_requests').add(data);

                    if (mounted) {
                      nav.pop();
                      sm.showSnackBar(
                        const SnackBar(content: Text('บันทึกคำขอเบิกเงินสำเร็จ')),
                      );
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await _firestore.collection('advance_money_requests').doc(docId).update({
      'status': newStatus,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เบิกเงินล่วงหน้า & อนุมัติ'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRequestDialog,
        icon: const Icon(Icons.add),
        label: const Text('ทำเรื่องเบิก'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('advance_money_requests')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีรายการขอเบิกเงิน'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final name = data['employee_name'] ?? 'Unknown';
              final amount = data['amount'] ?? 0.0;
              final reason = data['reason'] ?? '';
              final status = data['status'] ?? 'pending';
              final createdAt = data['created_at'] as Timestamp?;

              Color statusColor = Colors.grey;
              String statusText = 'รออนุมัติ';
              if (status == 'approved') {
                statusColor = Colors.green;
                statusText = 'อนุมัติแล้ว';
              } else if (status == 'rejected') {
                statusColor = Colors.red;
                statusText = 'ไม่อนุมัติ';
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                  color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'จำนวนเงิน: ฿${NumberFormat('#,##0.00').format(amount)}',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('เหตุผล: $reason'),
                      if (createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'วันที่ขอ: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate())}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                      if (status == 'pending') ...[
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _updateStatus(docId, 'rejected'),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('ไม่อนุมัติ'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _updateStatus(docId, 'approved'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: const Text('อนุมัติ'),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
