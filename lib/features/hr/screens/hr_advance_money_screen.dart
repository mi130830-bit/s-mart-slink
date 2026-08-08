import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:s_link/features/auth/models/user.dart';
import 'package:s_link/features/auth/services/user_service.dart';
import 'package:s_link/features/hr/services/hr_api_service.dart';
import 'package:s_link/utils/snackbar_utils.dart';

class HrAdvanceMoneyScreen extends StatefulWidget {
  const HrAdvanceMoneyScreen({super.key});

  @override
  State<HrAdvanceMoneyScreen> createState() => _HrAdvanceMoneyScreenState();
}

class _HrAdvanceMoneyScreenState extends State<HrAdvanceMoneyScreen> {
  final HrApiService _hrApi = HrApiService();
  late Future<List<Map<String, dynamic>>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _requestsFuture = _hrApi.getAdvances();
    if (mounted) setState(() {});
  }

  Future<void> _showAddRequestDialog() async {
    final users = await UserService().getAllUsers();
    if (!mounted) return;

    UserModel? selectedUser;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final installmentCtrl = TextEditingController();
    var isInstallment = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('สร้างคำขอเบิกเงินล่วงหน้า'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<UserModel>(
                    decoration: const InputDecoration(
                      labelText: 'พนักงาน',
                      border: OutlineInputBorder(),
                    ),
                    items: users
                        .where((user) => user.role.name != 'pending')
                        .map((user) => DropdownMenuItem(
                              value: user,
                              child: Text(user.name),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => selectedUser = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'จำนวนเงิน (บาท)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'เหตุผล/หมายเหตุ',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('หักเป็นงวด (แบ่งจ่าย)'),
                    value: isInstallment,
                    onChanged: (value) =>
                        setDialogState(() => isInstallment = value),
                  ),
                  if (isInstallment)
                    TextField(
                      controller: installmentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ยอดหักต่องวด (บาท)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
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
                  final amount = double.tryParse(amountCtrl.text);
                  final installment = double.tryParse(installmentCtrl.text);
                  if (selectedUser == null || amount == null || amount <= 0) {
                    SnackbarUtils.showLeft(context, 'กรุณากรอกข้อมูลให้ครบถ้วน',
                        isError: true);
                    return;
                  }
                  if (isInstallment &&
                      (installment == null || installment <= 0 || installment > amount)) {
                    SnackbarUtils.showLeft(context, 'ยอดหักต่องวดไม่ถูกต้อง',
                        isError: true);
                    return;
                  }
                  try {
                    await _hrApi.createAdvance({
                      'user_id': selectedUser!.id,
                      'amount': amount,
                      'reason': reasonCtrl.text.trim(),
                      'installment_amount': isInstallment ? installment : null,
                    });
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    SnackbarUtils.showLeft(context, 'บันทึกคำขอเบิกเงินสำเร็จ');
                    _reload();
                  } catch (e) {
                    if (context.mounted) {
                      SnackbarUtils.showLeft(context, 'บันทึกไม่สำเร็จ: $e',
                          isError: true);
                    }
                  }
                },
                child: const Text('บันทึก'),
              ),
            ],
          ),
        ),
      );
    } finally {
      amountCtrl.dispose();
      reasonCtrl.dispose();
      installmentCtrl.dispose();
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await _hrApi.updateAdvanceStatus(id, status);
      if (!mounted) return;
      SnackbarUtils.showLeft(context,
          status == 'APPROVED' ? 'อนุมัติรายการแล้ว' : 'ไม่อนุมัติรายการแล้ว');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('เบิกเงินล่วงหน้า & อนุมัติ'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRequestDialog,
        icon: const Icon(Icons.add),
        label: const Text('ทำเรื่องเบิก'),
        backgroundColor: Colors.green,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}'));
          final requests = snapshot.data ?? const [];
          if (requests.isEmpty) return const Center(child: Text('ยังไม่มีรายการขอเบิกเงิน'));
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final data = requests[index];
                final status = (data['status'] ?? 'PENDING').toString().toUpperCase();
                final amount = double.tryParse('${data['amount']}') ?? 0;
                final date = DateTime.tryParse('${data['created_at']}');
                final color = status == 'APPROVED'
                    ? Colors.green
                    : status == 'REJECTED'
                        ? Colors.red
                        : Colors.orange;
                final label = status == 'APPROVED'
                    ? 'อนุมัติแล้ว'
                    : status == 'REJECTED'
                        ? 'ไม่อนุมัติ'
                        : 'รออนุมัติ';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text('${data['employee_name'] ?? '-'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          Chip(label: Text(label), backgroundColor: color.withValues(alpha: .12), side: BorderSide.none),
                        ]),
                        Text('จำนวนเงิน: ฿${NumberFormat('#,##0.00').format(amount)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        Text('เหตุผล: ${data['reason'] ?? '-'}'),
                        if (date != null) Text('วันที่ขอ: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        if (status == 'PENDING') ...[
                          const Divider(height: 24),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            TextButton(onPressed: () => _updateStatus('${data['id']}', 'REJECTED'), child: const Text('ไม่อนุมัติ', style: TextStyle(color: Colors.red))),
                            const SizedBox(width: 8),
                            ElevatedButton(onPressed: () => _updateStatus('${data['id']}', 'APPROVED'), child: const Text('อนุมัติ')),
                          ]),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
