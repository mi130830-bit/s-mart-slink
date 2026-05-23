import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentSuccessDialog extends StatefulWidget {
  final int orderId;
  final bool autoPrint;
  final VoidCallback onContinue;

  const PaymentSuccessDialog({
    super.key,
    required this.orderId,
    required this.autoPrint,
    required this.onContinue,
  });

  @override
  State<PaymentSuccessDialog> createState() => _PaymentSuccessDialogState();
}

class _PaymentSuccessDialogState extends State<PaymentSuccessDialog> {
  bool _printSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrint) {
      _sendPrintCommand(widget.orderId);
      _printSent = true;
    }
  }

  Future<void> _sendPrintCommand(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String posDeviceId = prefs.getString('pos_device_id') ?? '';

      if (posDeviceId.isEmpty) {
        debugPrint('⚠️ pos_device_id not set, using default POS_MASTER');
        posDeviceId = 'POS_MASTER';
      }

      debugPrint('📡 [S-Link] Preparing to send PRINT_RECEIPT for Order #$orderId to Device: $posDeviceId');
      
      final docRef = await FirebaseFirestore.instance.collection('commands').add({
        'command': 'PRINT_RECEIPT',
        'payload': {'order_id': orderId},
        'target_device_id': posDeviceId,
        'status': 'PENDING',
        'created_at': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ [S-Link] Command Sent Successfully! Doc ID: ${docRef.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🖨️ ส่งคำสั่งพิมพ์ไปที่ $posDeviceId สำเร็จ'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Send Print Command Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 32),
          SizedBox(width: 10),
          Text('ชำระเงินสำเร็จ!', style: TextStyle(color: Colors.green)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('บิลเลขที่ #${widget.orderId}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_printSent)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.print, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(child: Text('ส่งคำสั่งปริ้นท์ไปยัง POS แล้ว')),
                ],
              ),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.print),
          label: Text(_printSent ? 'ปริ้นท์ซ้ำ' : '🖨️ ปริ้นท์ใบเสร็จ'),
          style: TextButton.styleFrom(foregroundColor: Colors.blue),
          onPressed: () {
            _sendPrintCommand(widget.orderId);
            setState(() => _printSent = true);
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          onPressed: widget.onContinue,
          child: const Text('ขายต่อ ✓'),
        ),
      ],
    );
  }
}
