// ไฟล์: lib/screens/shop_log/create_work_log_screen.dart

import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/jobs/models/shop_work_log.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/alerts/providers/alert_log_provider.dart';

class CreateWorkLogScreen extends StatefulWidget {
  const CreateWorkLogScreen({super.key});

  @override
  State<CreateWorkLogScreen> createState() => _CreateWorkLogScreenState();
}

class _CreateWorkLogScreenState extends State<CreateWorkLogScreen> {
  // 📝 กำหนดรายการงานมาตรฐานที่นี่ (สามารถเพิ่ม/ลบ/แก้ไขชื่อได้ตามต้องการ)
  final List<String> _standardTasks = [
    'เสาไฟฟ้า 7ม.',
    'เสารั้ว',
    'เสารั้วมีรู',
    'เสาค้ำ',
    'เสาหลักแดน',
    'ฝาวงบ่อ60ซม. ตัน',
    'ฝาวงบ่อ60ซม. รูเล็ก',
    'ฝาวงบ่อ80ซม. ตัน',
    'ฝาวงบ่อ80ซม. รูเล็ก',
    'ฝาวงบ่อ100ซม. ตัน',
    'ฝาวงบ่อ100ซม.รูเล็ก',
    'ฝาวงบ่อ120ซม. ตัน',
    'ฝาวงบ่อ120ซม. รูเล็ก',
    // เพิ่มรายการต่อที่นี่...
  ];

  final Map<String, TextEditingController> _qtyControllers = {};
  final _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // สร้าง Controller สำหรับแต่ละรายการ
    for (var task in _standardTasks) {
      _qtyControllers[task] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitLogSet() async {
    // รวบรวมข้อมูลจากฟอร์ม
    final List<WorkItem> itemsToSend = [];
    for (var task in _standardTasks) {
      final controller = _qtyControllers[task];
      final text = controller?.text.trim() ?? '';
      if (text.isNotEmpty) {
        final qty = double.tryParse(text);
        if (qty != null && qty > 0) {
          itemsToSend.add(WorkItem(
            description: task,
            quantity: qty,
            unit: 'หน่วย',
          ));
        }
      }
    }

    if (itemsToSend.isEmpty && _noteController.text.isEmpty) {
      SnackbarUtils.showLeft(context, 'กรุณาระบุจำนวนงานอย่างน้อย 1 รายการ');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider =
          Provider.of<AuthenticationProvider>(context, listen: false);
      final alertProvider =
          Provider.of<AlertLogProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) return;

      if (_noteController.text.isNotEmpty) {
        itemsToSend.add(WorkItem(
          description: '**หมายเหตุ: ${_noteController.text}**',
          quantity: 0,
          unit: '-',
        ));
      }

      await alertProvider.createWorkLog(currentUser.uid, itemsToSend);

      if (mounted) {
        SnackbarUtils.showLeft(context, 'บันทึกงานเรียบร้อย! ✅');
        // **แก้ไข: ไม่ต้อง pop แต่ให้เคลียร์ค่าแทน**
        setState(() {
          for (var controller in _qtyControllers.values) {
            controller.clear();
          }
          _noteController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ตัด Scaffold/AppBar ออก เพื่อให้เป็นส่วนหนึ่งของ Tab
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text Header
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('แบบฟอร์มบันทึกงาน',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ),

          // Input Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 5)
              ],
            ),
            child: Column(
              children: _standardTasks.map((task) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(task, style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _qtyControllers[task],
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: '0',
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('หน่วย', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'หมายเหตุเพิ่มเติม (ถ้ามี)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: !_isLoading ? _submitLogSet : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('บันทึกข้อมูล', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
