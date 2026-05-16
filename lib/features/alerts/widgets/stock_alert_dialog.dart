// ไฟล์: lib/widgets/stock_alert_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/alerts/services/shortage_repository.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';

/// Dialog สำหรับแจ้งของหมด
/// ใช้ได้จาก Job Detail Screen หรือที่ไหนก็ได้ที่ต้องการรายงานของหมด
class StockAlertDialog extends StatefulWidget {
  final String customerName;
  final String? customerShop;
  final String? customerId;

  const StockAlertDialog({
    super.key,
    required this.customerName,
    this.customerShop,
    this.customerId,
  });

  @override
  State<StockAlertDialog> createState() => _StockAlertDialogState();
}

class _StockAlertDialogState extends State<StockAlertDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _productController.dispose();
    super.dispose();
  }

  Future<void> _submitAlert() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider =
          Provider.of<AuthenticationProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      // ✅ ใช้ ShortageRepository (API) แทน StockAlertService (Firestore)
      final shortageRepo = ShortageRepository();
      // สร้างชื่อรายการที่มีข้อมูลลูกค้าสำหรับ context
      final itemDesc =
          '${_productController.text.trim()} (${widget.customerName})';
      await shortageRepo.createShortage(itemDesc, currentUser.uid);

      if (!mounted) return;

      // แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ แจ้งของหมดเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('📦 แจ้งของหมด'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ลูกค้า: ${widget.customerName}${widget.customerShop != null ? ' (${widget.customerShop})' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _productController,
              decoration: const InputDecoration(
                labelText: 'สินค้าที่หมด',
                hintText: 'เช่น น้ำดื่ม 600ml, ขนมปัง, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณาระบุสินค้าที่หมด';
                }
                return null;
              },
              enabled: !_isSubmitting,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitAlert,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('แจ้งเตือน Admin'),
        ),
      ],
    );
  }
}

/// Helper function สำหรับเรียกใช้ dialog ได้ง่ายๆ
Future<bool?> showStockAlertDialog(
  BuildContext context, {
  required String customerName,
  String? customerShop,
  String? customerId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => StockAlertDialog(
      customerName: customerName,
      customerShop: customerShop,
      customerId: customerId,
    ),
  );
}
