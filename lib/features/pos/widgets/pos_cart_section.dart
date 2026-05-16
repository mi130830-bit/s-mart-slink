import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/models/pos_customer.dart';

class PosCartSection extends StatelessWidget {
  final Map<int, int> cart;
  final List<PosProduct> products;
  final PosCustomer? selectedCustomer;
  final bool isDeliveryMode;
  final TextEditingController deliveryAddressController;
  final Function(int, int) onUpdateQty;
  final Function(int, int) onSetQty; // New callback
  final Function(bool) onDeliveryModeChanged;
  final VoidCallback onCheckout;

  const PosCartSection({
    super.key,
    required this.cart,
    required this.products,
    required this.selectedCustomer,
    required this.isDeliveryMode,
    required this.deliveryAddressController,
    required this.onUpdateQty,
    required this.onSetQty, // Required
    required this.onDeliveryModeChanged,
    required this.onCheckout,
  });

  // Helper to show quantity dialog
  Future<void> _showQtyDialog(
      BuildContext context, int currentQty, Function(int) onConfirm) async {
    final ctrl = TextEditingController(text: currentQty.toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขจำนวน'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'จำนวน',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            Navigator.pop(ctx);
            final val = int.tryParse(ctrl.text);
            if (val != null) onConfirm(val);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final val = int.tryParse(ctrl.text);
              if (val != null) onConfirm(val);
            },
            child: const Text('ตกลง'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Logic to map cart to products (copied from MiniPosScreen)
    final cartItems = cart.entries.map((e) {
      final p = products.firstWhere((p) => p.id == e.key,
          orElse: () => PosProduct(
              id: e.key,
              barcode: '?',
              name: 'Unknown',
              retailPrice: 0,
              stockQuantity: 0));
      return MapEntry(p, e.value);
    }).toList();

    final total =
        cartItems.fold(0.0, (sum, e) => sum + (e.key.retailPrice * e.value));

    return Container(
      color: Colors.white, // Background for visibility
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ตะกร้าสินค้า',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (selectedCustomer != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text('ลูกค้า: ${selectedCustomer!.fullName}',
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold)),
            ),
          const Divider(),
          // --- Delivery Option ---
          if (selectedCustomer != null)
            Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('แจ้งส่งของ (Delivery)'),
                    subtitle: const Text('สร้างใบงานส่งของให้ไรเดอร์'),
                    value: isDeliveryMode,
                    onChanged: onDeliveryModeChanged,
                  ),
                  if (isDeliveryMode)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: deliveryAddressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ที่อยู่จัดส่ง',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (selectedCustomer != null) const Divider(),

          Expanded(
            child: cartItems.isEmpty
                ? const Center(child: Text('ยังไม่มีสินค้า'))
                : ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (ctx, i) {
                      final item = cartItems[i];
                      final p = item.key;
                      final qty = item.value;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${NumberFormat.currency(symbol: '฿').format(p.retailPrice)} x $qty'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red),
                              onPressed: () => onUpdateQty(p.id, -1),
                            ),
                            InkWell(
                              onTap: () => _showQtyDialog(context, qty, (val) {
                                onSetQty(p.id, val);
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('$qty',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.green),
                              onPressed: () => onUpdateQty(p.id, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  'ยอดรวม: ${NumberFormat.currency(symbol: '฿').format(total)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: cartItems.isEmpty ? null : onCheckout,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12)),
                child: const Text('ชำระเงิน',
                    style: TextStyle(color: Colors.white)),
              )
            ],
          )
        ],
      ),
    );
  }
}
