import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:s_link/features/pos/providers/cart_provider.dart';
import 'package:s_link/features/pos/repositories/pos_repository.dart';
import 'package:s_link/features/pos/services/promptpay_helper.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/jobs/providers/job_provider.dart';
import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/jobs/models/job_item.dart'; // ✅ Import JobItem
import 'package:s_link/features/pos/services/pos_api_service.dart';
import 'package:s_link/features/pos/widgets/payment_success_dialog.dart';
import 'package:s_link/features/pos/widgets/quick_cash_selector.dart';
import 'package:uuid/uuid.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();

  // State
  String? _promptPayId;
  String? _qrPayload;
  bool _isDelivery = false;
  bool _shouldPrint = false;
  bool _isLoading = false;
  double _receivedAmount = 0.0;
  String _paymentMethod = 'CASH'; // 'CASH', 'PROMPTPAY', or 'CREDIT'
  String? _checkoutRequestId;
  bool _quoteLoading = false;
  int? _quoteMaxPoints;
  int? _quoteAvailablePoints;
  String? _quoteCartSignature;

  int get _pointsUsed => int.tryParse(_pointsController.text.trim()) ?? 0;
  String get _couponCode => _couponController.text.trim().toUpperCase();
  bool get _usesBenefit => _pointsUsed > 0 || _couponCode.isNotEmpty;

  @override
  void dispose() {
    _cashController.dispose();
    _pointsController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final promptPayId = prefs.getString('promptpay_id');
    // ✅ Default to true — ถ้าไม่เคยตั้งค่า ให้ปริ้นท์เป็น Default
    final autoPrint = prefs.getBool('auto_print_receipt') ?? true;

    if (!mounted) return;

    setState(() {
      _promptPayId = promptPayId;
      _shouldPrint = autoPrint;
      if (_promptPayId != null && _promptPayId!.isNotEmpty) {
        final total = context.read<CartProvider>().totalAmount;
        _qrPayload =
            PromptPayHelper.generatePayload(_promptPayId!, amount: total);
      }
    });
  }

  void _updateReceived(String value) {
    setState(() {
      _receivedAmount = double.tryParse(value) ?? 0.0;
    });
  }

  void _onQuickCash(double amount) {
    setState(() {
      _receivedAmount = amount;
      _cashController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _loadQuote({bool applyMax = false}) async {
    final cart = context.read<CartProvider>();
    if (cart.customer == null) {
      SnackbarUtils.showLeft(context, 'กรุณาเลือกลูกค้าก่อนตรวจสอบแต้ม');
      return;
    }
    if (applyMax && _couponCode.isNotEmpty) {
      setState(() {
        _couponController.clear();
        _checkoutRequestId = null;
      });
    }
    setState(() => _quoteLoading = true);
    try {
      final result = await _repo.getAuthoritativeCheckoutQuote(
        customerId: cart.customer!.id,
        items: cart.items
            .map((item) => {
                  'productId': item.product.id,
                  'quantity': item.quantity,
                })
            .toList(),
        pointsUsed: _pointsUsed,
        couponCode: _couponCode.isEmpty ? null : _couponCode,
      );
      if (!mounted) return;
      final max = int.tryParse(result['maxRedeemable']?.toString() ?? '') ?? 0;
      setState(() {
        _quoteMaxPoints = max;
        _quoteAvailablePoints =
            int.tryParse(result['availablePoints']?.toString() ?? '') ?? 0;
        if (applyMax) {
          _pointsController.text = max.toString();
          _checkoutRequestId = null;
        }
      });
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'ตรวจสอบสิทธิ์แต้มไม่สำเร็จ: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<void> _processPayment() async {
    final cart = context.read<CartProvider>();
    final total = cart.totalAmount;

    if (_usesBenefit && cart.customer == null) {
      SnackbarUtils.showLeft(context, 'กรุณาเลือกลูกค้าก่อนใช้แต้มหรือคูปอง');
      return;
    }
    if (_usesBenefit && _paymentMethod != 'CASH') {
      SnackbarUtils.showLeft(context,
          'สิทธิ์แต้มและคูปองใช้กับเงินสดเท่านั้นในตอนนี้ เพื่อให้ยอด QR/เครดิตไม่คลาดเคลื่อน');
      return;
    }

    // Validation
    if (_paymentMethod == 'CASH' && !_usesBenefit && _receivedAmount < total) {
      if (!mounted) return;
      SnackbarUtils.showLeft(
          context, 'ยอดเงินรับไม่เพียงพอ (Insufficient Cash)');
      return;
    }

    // CREDIT requires a customer
    if (_paymentMethod == 'CREDIT' && cart.customer == null) {
      if (!mounted) return;
      SnackbarUtils.showLeft(
          context, 'การขายสินเชื่อต้องระบุลูกค้า (Select customer first)');
      return;
    }

    // New Validation: Delivery requires Customer
    if (_isDelivery && cart.customer == null) {
      if (!mounted) return;
      SnackbarUtils.showLeft(context,
          'การส่งของด่วนต้องระบุลูกค้า (Please select customer for delivery)');
      return; // Stop here, do not create order
    }

    setState(() => _isLoading = true);

    try {
      // 1. Prepare Note
      String note = '';
      if (_isDelivery) {
        note = 'DELIVERY_REQ'; // Key for backend to trigger delivery workflow
      }

      // 2. Prepare items. Benefit checkout deliberately sends raw IDs/qty only.
      final items = cart.items.map((item) {
        return {
          'productId': item.product.id,
          'productName': item.product.name,
          'quantity': item.quantity,
          'price': item.product.retailPrice,
          'costPrice': 0.0, // Should come from product ideally
          'discount': 0.0, // ✅ Fix: Send discount 0 to prevent backend error
          'total':
              (item.product.retailPrice * item.quantity), // ✅ Fix: Send total
        };
      }).toList();

      // 3. Create Order
      int orderId;
      double completedGrandTotal = total;
      if (_usesBenefit) {
        _checkoutRequestId ??= const Uuid().v4();
        final rawItems = cart.items
            .map((item) => {
                  'productId': item.product.id,
                  'quantity': item.quantity,
                })
            .toList();
        final result = await _repo.createAuthoritativeCheckout(
          clientRequestId: _checkoutRequestId!,
          items: rawItems,
          customerId: cart.customer?.id,
          paymentMethod: _paymentMethod,
          receivedAmount: _receivedAmount,
          pointsUsed: _pointsUsed,
          couponCode: _couponCode.isEmpty ? null : _couponCode,
        );
        orderId = int.tryParse(result['orderId']?.toString() ?? '') ?? 0;
        completedGrandTotal =
            double.tryParse(result['grandTotal']?.toString() ?? '') ?? total;
        _receivedAmount =
            double.tryParse(result['received']?.toString() ?? '') ??
                _receivedAmount;
        final change = double.tryParse(result['change']?.toString() ?? '') ?? 0;
        if (mounted) {
          SnackbarUtils.showLeft(context,
              'ยอดสุทธิจาก POS ฿${completedGrandTotal.toStringAsFixed(2)} • เงินทอน ฿${change.toStringAsFixed(2)}');
        }
      } else {
        orderId = await _repo.createOrder(
          totalAmount: total,
          items: items,
          customerId: cart.customer?.id,
          paymentMethod: _paymentMethod,
          note: note.isNotEmpty ? note : null,
        );
      }

      if (orderId > 0) {
        if (!mounted) return;

        // Success Order
        final cartProvider = context.read<CartProvider>();
        // Check for Delivery Job Creation
        if (_isDelivery) {
          try {
            final currentUser =
                context.read<AuthenticationProvider>().currentUser;
            final posCustomer = cartProvider.customer!;

            // Create Job Items & Details Summary
            final jobItems = cart.items.map((cartItem) {
              return JobItem(
                name: cartItem.product.name,
                qty: cartItem.quantity,
                price: cartItem.product.retailPrice,
                total: cartItem.product.retailPrice * cartItem.quantity,
                location: '', // No location info available in PosProduct
                isWarehouse: false, // Default to Shop Front for Mobile POS
              );
            }).toList();

            final jobDetails = jobItems
                .map((item) => '- ${item.name} x${item.qty.toStringAsFixed(0)}')
                .join('\n');

            // Create Job
            final newJob = Job(
              id: 'temp', // Firestore generates ID
              localOrderId: orderId,
              status: 'pending', // Waiting for driver
              jobType: 'delivery',
              customerId: posCustomer.id.toString(),
              customer: Customer(
                name: posCustomer.name,
                address: posCustomer.address ?? 'ไม่ระบุที่อยู่',
                phoneNumber: posCustomer.phoneNumber ?? '-',
                lineUserId: posCustomer.lineUserId, // ✅ Pass LineUserID
              ),
              createdBy: currentUser?.uid ?? 'POS_USER',
              createdAt: DateTime.now(),
              deliveryTeam: [],
              items: jobItems, // ✅ Pass items
              details: jobDetails, // ✅ Pass details text summary
              paymentMethod:
                  _paymentMethod, // บอกให้คนขับรู้ว่าลูกค้าจ่ายแบบไหนมาแล้ว
              price: _paymentMethod == 'CREDIT'
                  ? completedGrandTotal
                  : 0.0, // สินเชื่อต้องเก็บปลายทาง (COD)
            );

            await context.read<JobProvider>().createNewJob(newJob);

            if (!mounted) return;

            // Trigger Line Notification (Fire & Forget)
            if (posCustomer.lineUserId != null &&
                posCustomer.lineUserId!.isNotEmpty) {
              final msg =
                  '🛒 ร้าน ส.บริการ ท่าข้าม ได้รับรายการสั่งซื้อของท่านแล้ว (#$orderId) \nกำลังดำเนินการจัดเตรียมสินค้าครับ... \n(เมื่อรถออกจากร้าน จะมีข้อความแจ้งเตือนอีกครั้งครับ)';
              // Use API Service directly
              PosApiService().sendLineMessage(posCustomer.lineUserId!, msg);
            }
          } catch (e) {
            if (!mounted) return;
            SnackbarUtils.showLeft(context, 'สร้างงานส่งของล้มเหลว: $e',
                isError: true);
          }
        }

        // ✅ Clear Cart
        cartProvider.clear();
        _checkoutRequestId = null;

        // ✅ Show Success Dialog with Print Option
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PaymentSuccessDialog(
            orderId: orderId,
            autoPrint: _shouldPrint,
            onContinue: () => Navigator.of(ctx).pop(),
          ),
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        throw Exception('Order ID returned 0'); // Simplified Check
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final cartSignature =
        '${cart.customer?.id ?? 0}:${cart.items.map((item) => '${item.product.id}x${item.quantity}').join(',')}';
    if (_quoteCartSignature != cartSignature) {
      _quoteCartSignature = cartSignature;
      _quoteMaxPoints = null;
      _quoteAvailablePoints = null;
    }
    final total = cart.totalAmount;
    final change = _receivedAmount - total;

    return Scaffold(
      appBar: AppBar(title: const Text('ชำระเงิน (Payment)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Total Amount Card
            Card(
              color: Theme.of(context).primaryColor,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('ยอดรวม (Total)',
                        style: TextStyle(color: Colors.white70, fontSize: 18)),
                    Text('฿${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold)),
                    if (cart.customer != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Chip(
                          label: Text('ลูกค้า: ${cart.customer!.name}'),
                          backgroundColor: Colors.white24,
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      ),
                    if (cart.customer != null) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _pointsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'ใช้แต้ม (เลือกอย่างใดอย่างหนึ่ง)',
                              prefixIcon: const Icon(Icons.stars_outlined),
                              helperText: _quoteAvailablePoints == null
                                  ? 'กด MAX เพื่อตรวจสอบแต้มจาก POS'
                                  : 'มี ${_quoteAvailablePoints!} แต้ม • ใช้ได้สูงสุด ${_quoteMaxPoints ?? 0}',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _checkoutRequestId = null;
                                _quoteMaxPoints = null;
                                _quoteAvailablePoints = null;
                                if (value.trim().isNotEmpty &&
                                    _couponCode.isNotEmpty) {
                                  _couponController.clear();
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _quoteLoading
                              ? null
                              : () => _loadQuote(applyMax: true),
                          child: _quoteLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('MAX'),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _couponController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'คูปอง LINE OA (เลือกอย่างใดอย่างหนึ่ง)',
                          prefixIcon: Icon(Icons.discount_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _checkoutRequestId = null;
                            _quoteMaxPoints = null;
                            _quoteAvailablePoints = null;
                            if (value.trim().isNotEmpty && _pointsUsed > 0) {
                              _pointsController.clear();
                            }
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Payment Method Selection
            const Text('เลือกวิธีการชำระเงิน',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'CASH',
                  icon: Icon(Icons.money),
                  label: Text('เงินสด'),
                ),
                ButtonSegment(
                  value: 'PROMPTPAY',
                  icon: Icon(Icons.qr_code),
                  label: Text('พร้อมเพย์'),
                ),
                ButtonSegment(
                  value: 'CREDIT',
                  icon: Icon(Icons.credit_score),
                  label: Text('สินเชื่อ'),
                ),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _paymentMethod = newSelection.first;
                  if (_paymentMethod == 'PROMPTPAY') {
                    _receivedAmount = total;
                  } else if (_paymentMethod == 'CREDIT') {
                    _receivedAmount = 0; // No cash collected for credit
                  } else {
                    _receivedAmount =
                        double.tryParse(_cashController.text) ?? 0.0;
                  }
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return Theme.of(context)
                          .primaryColor
                          .withValues(alpha: 0.2);
                    }
                    return null; // defer to the default
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            // 3. PromptPay QR (Show only if PROMPTPAY selected)
            if (_paymentMethod == 'PROMPTPAY' && _qrPayload != null) ...[
              const Text('สแกนจ่าย (PromptPay)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: _qrPayload!,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
            ],

            // 4. Cash & Change (Show only if CASH selected)
            if (_paymentMethod == 'CASH') ...[
              const Text('รับเงินสด (Cash)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'รับเงินมา (Received)',
                  prefixText: '฿ ',
                  border: OutlineInputBorder(),
                ),
                onChanged: _updateReceived,
              ),
              const SizedBox(height: 10),
              // Quick Cash Buttons
              QuickCashSelector(
                totalAmount: total,
                onCashSelected: _onQuickCash,
              ),
              const SizedBox(height: 20),

              // Change Display
              if (change >= 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('เงินทอน (Change):',
                          style: TextStyle(fontSize: 18, color: Colors.green)),
                      Text('฿${change.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const Divider(),
            ],

            // Credit info banner (show only when CREDIT selected)
            if (_paymentMethod == 'CREDIT') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade800),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'สินเชื่อ — ยอดจะถูกบันทึกเป็นหนี้ค้างชำระของลูกค้า',
                        style: TextStyle(
                            color: Colors.orange.shade900, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
            ],

            // 4. Delivery Option (Truck Icon)
            SwitchListTile(
              title: const Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.orange),
                  SizedBox(width: 10),
                  Text('ส่งของด่วน (Delivery)'),
                ],
              ),
              subtitle: const Text('แจ้งคนขับให้เข้ามารับของ'),
              value: _isDelivery,
              onChanged: (val) => setState(() => _isDelivery = val),
              activeTrackColor: Colors.orange,
            ),

            // 5. Print Receipt Toggle
            SwitchListTile(
              title: const Row(
                children: [
                  Icon(Icons.print, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('ปริ้นท์ใบเสร็จ (Print Receipt)'),
                ],
              ),
              subtitle: const Text('สั่งปริ้นท์ที่เครื่อง POS หน้าร้าน'),
              value: _shouldPrint,
              onChanged: (val) async {
                setState(() => _shouldPrint = val);
                final prefs = await SharedPreferences.getInstance();
                prefs.setBool('auto_print_receipt', val);
              },
              activeTrackColor: Colors.blue,
            ),

            const SizedBox(height: 30),

            // 5. Confirm Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ยืนยันชำระเงิน (Confirm Payment)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
