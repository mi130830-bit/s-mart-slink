import 'package:s_link/utils/snackbar_utils.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/pos/models/pos_customer.dart';
import 'package:s_link/features/pos/providers/cart_provider.dart';
import 'package:s_link/features/pos/repositories/pos_repository.dart';
import 'package:s_link/features/pos/screens/payment_screen.dart';
import 'package:s_link/features/pos/screens/product_search_screen.dart';
import 'package:s_link/features/pos/widgets/customer_search_dialog.dart'; // Added

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _barcodeController =
      TextEditingController(); // Added
  final FocusNode _barcodeFocus = FocusNode(); // Added

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  void _showCustomerSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CustomerSearchDialog(repo: _repo),
    ).then((result) {
      if (!mounted) return;
      if (result != null && result is PosCustomer) {
        context.read<CartProvider>().setCustomer(result);
      } else if (result == 'CLEAR' || result == null) {
        // Handle "General Customer" or strictly clear if 'CLEAR'
        // If result is null (Back button), usually we do nothing?
        // But in previous logic: "General Customer" was also kind of null.
        // Let's check if the user intended to clear.
        if (result == 'CLEAR') {
          context.read<CartProvider>().setCustomer(null);
        }
      }
    });
  }

  Future<void> _onBarcodeSubmit(String value) async {
    if (value.trim().isEmpty) return;

    // Simple logic: Scan -> Add first match -> Clear
    try {
      final results = await _repo.getAllProducts(searchTerm: value.trim());
      if (!mounted) return;

      if (results.isNotEmpty) {
        // Find exact match if possible, or take first
        final exact = results.firstWhere((p) => p.barcode == value.trim(),
            orElse: () => results.first);

        context.read<CartProvider>().addItem(exact);
        _barcodeController.clear();
        _barcodeFocus.requestFocus(); // Keep focus

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        SnackbarUtils.showLeft(context, 'เพิ่ม ${exact.name} แล้ว');
      } else {
        SnackbarUtils.showLeft(context, 'ไม่พบสินค้า (Product not found)', isError: true);
        _barcodeController.clear();
        _barcodeFocus.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openProductSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
    ).then((_) {
      // Refresh? Cart is updated via Provider, so UI updates automatically.
      _barcodeFocus.requestFocus();
    });
  }

  Future<void> _showEditQuantityDialog(dynamic item) async {
    // Format: 1.0 -> 1, 1.5 -> 1.5
    final String initialText = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toString();

    final TextEditingController qtyCtrl =
        TextEditingController(text: initialText);
    final FocusNode focusNode = FocusNode();

    // Select all text when the dialog is shown
    // We delay slightly to ensure the text field is rendered and focused
    Future.delayed(const Duration(milliseconds: 50), () {
      if (focusNode.hasFocus) {
        qtyCtrl.selection =
            TextSelection(baseOffset: 0, extentOffset: qtyCtrl.text.length);
      }
    });

    final val = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('แก้ไขจำนวน: ${item.product.name}'),
        content: TextField(
          controller: qtyCtrl,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'จำนวน (Quantity)',
            border: OutlineInputBorder(),
            suffixText: 'ชิ้น',
          ),
          onSubmitted: (val) {
            Navigator.of(ctx).pop(val);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(qtyCtrl.text);
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );

    if (val != null && val.toString().isNotEmpty) {
      final double? newQty = double.tryParse(val);
      if (newQty != null && newQty > 0) {
        if (!mounted) return;
        context.read<CartProvider>().updateQuantity(item.product.id, newQty);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final customer = cart.customer;
    final bool isTablet = MediaQuery.of(context).size.shortestSide > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตะกร้าสินค้า (Cart)'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Removed the Add button from AppBar as we have one in body now?
          // User said "Create search button NEXT TO barcode slot".
          // So I can remove the one in AppBar to avoid clutter, or keep it.
          // Let's keep it for now or remove if redundancy is bad.
          // User said "Take the button in the middle out... create search button next to barcode".
          // The button in the middle was the "Back" button in empty state.
          // I will remove the AppBar action too to force usage of the new UI.
        ],
      ),
      body: Column(
        children: [
          // 1. Customer Selection
          Card(
            margin: const EdgeInsets.all(8),
            color: customer != null ? Colors.green.shade50 : Colors.white,
            elevation: 2,
            child: ListTile(
              // Adjust density for Tablet logic inside Cart Screen heavily used?
              // The user asked for dialog icon size.
              // But let's also apply compact to this main tile if tablet.
              visualDensity:
                  isTablet ? VisualDensity.compact : VisualDensity.standard,
              leading: Icon(Icons.person,
                  color: customer != null ? Colors.green : Colors.grey),
              title: Text(
                customer != null ? customer.name : 'ลูกค้าทั่วไป (General)',
                style: TextStyle(
                    fontWeight:
                        customer != null ? FontWeight.bold : FontWeight.normal),
              ),
              subtitle:
                  customer != null ? Text(customer.phoneNumber ?? '-') : null,
              trailing: const Icon(Icons.search), // Search Icon
              onTap: _showCustomerSearchDialog,
            ),
          ),

          // 2. Barcode & Search Row (New)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    focusNode: _barcodeFocus,
                    decoration: const InputDecoration(
                      hintText: 'สแกนบาร์โค้ด (Scan Barcode)...',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: _onBarcodeSubmit,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _openProductSearch,
                  icon: const Icon(Icons.list),
                  tooltip: 'ค้นหาสินค้า (Search)',
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),

          // 3. Cart Items
          Expanded(
            child: cart.items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('ไม่มีสินค้าในตะกร้า',
                            style: TextStyle(fontSize: 18, color: Colors.grey)),
                        // Removed Back Button
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cart.items.length,
                    separatorBuilder: (ctx, i) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final item = cart.items[i];
                      return ListTile(
                        visualDensity: isTablet
                            ? VisualDensity.compact
                            : VisualDensity.standard,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: item.product.imageUrl?.isNotEmpty == true
                              ? Image.network(item.product.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image))
                              : const Icon(Icons.inventory, color: Colors.grey),
                        ),
                        title: Text(item.product.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                if (item.quantity > 1) {
                                  cart.updateQuantity(
                                      item.product.id, item.quantity - 1);
                                }
                              },
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            InkWell(
                              onTap: () => _showEditQuantityDialog(item),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 4),
                                child: Text(
                                  item.quantity % 1 == 0
                                      ? item.quantity.toInt().toString()
                                      : item.quantity.toString(),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                cart.updateQuantity(
                                    item.product.id, item.quantity + 1);
                              },
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '฿${(item.quantity * item.product.retailPrice).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  '@ ${item.product.retailPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                cart.removeItem(item.product.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ยอดรวมทั้งหมด',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('฿${cart.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: cart.itemCount == 0
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PaymentScreen()),
                          ).then((result) {
                            if (!context.mounted) return;
                            if (result == true) {
                              Navigator.pop(context, true); // Success, go back
                            }
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('ชำระเงิน (Checkout)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
