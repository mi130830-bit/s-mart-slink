import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/repositories/pos_repository.dart';
import 'package:s_link/features/pos/screens/scanner_screen.dart';

class StockReceiveScreen extends StatefulWidget {
  const StockReceiveScreen({super.key});

  @override
  State<StockReceiveScreen> createState() => _StockReceiveScreenState();
}

class _StockReceiveScreenState extends State<StockReceiveScreen> {
  final _searchController = TextEditingController();
  final _repo = PosRepository();
  final FocusNode _focusNode = FocusNode();

  // Map<ProductId, QuantityToAdd>
  final Map<int, double> _receivingItems = {};
  // Ordered list for display
  final List<PosProduct> _scannedProducts = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String code) async {
    if (code.trim().isEmpty) return;
    _searchController.clear();

    setState(() => _isLoading = true);

    try {
      final results = await _repo.getAllProducts(searchTerm: code);

      if (results.isNotEmpty) {
        // Assume exact match or first result
        final product = results.firstWhere(
            (p) => p.barcode == code || p.barcode.endsWith(code),
            orElse: () => results.first);

        _addProduct(product);
      } else {
        if (mounted) {
          SnackbarUtils.showLeft(context, 'ไม่พบสินค้า: $code', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'Error: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
      _focusNode.requestFocus();
    }
  }

  void _addProduct(PosProduct product) {
    setState(() {
      if (!_receivingItems.containsKey(product.id)) {
        // New item
        _scannedProducts.insert(0, product);
        _receivingItems[product.id] = 1.0; // Default add 1
      } else {
        // Increment existing
        _receivingItems[product.id] = (_receivingItems[product.id] ?? 0) + 1;
      }
    });
  }

  void _updateQty(int productId, double newQty) {
    if (newQty < 1) return;
    setState(() {
      _receivingItems[productId] = newQty;
    });
  }

  void _removeProduct(int productId) {
    setState(() {
      _receivingItems.remove(productId);
      _scannedProducts.removeWhere((p) => p.id == productId);
    });
  }

  Future<void> _saveReceiving() async {
    if (_receivingItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันรับของเข้า'),
        content: Text(
            'ต้องการเพิ่มสต็อกจำนวน ${_receivingItems.length} รายการใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยืนยัน')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> items = [];
      _receivingItems.forEach((pid, qty) {
        items.add({
          'productId': pid,
          'quantity': qty,
        });
      });

      // Call the new addStock method
      final success = await _repo.addStock(items);

      if (mounted) {
        if (success) {
          SnackbarUtils.showLeft(context, '✅ รับของเข้าเรียบร้อย (สต็อกเพิ่มขึ้น)');
          setState(() {
            _receivingItems.clear();
            _scannedProducts.clear();
          });
        } else {
          SnackbarUtils.showLeft(context, '❌ บันทึกไม่สำเร็จ', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'Error saving: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รับของเข้า (Stock In)'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _receivingItems.isEmpty ? null : _saveReceiving,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search/Scan Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: 'สแกนสินค้าเพื่อรับเข้า',
                prefixIcon: const Icon(Icons.qr_code_2),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final code = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScannerScreen()),
                    );
                    if (code != null && code is String) {
                      _handleScan(code);
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: _handleScan,
              textInputAction: TextInputAction.next,
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green.shade50,
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('สินค้า',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 3,
                    child: Text('จำนวนรับ',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 40),
              ],
            ),
          ),

          // List
          Expanded(
            child: _scannedProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.system_update_alt,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text('สแกนสินค้าเพื่อเริ่มรับของ',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _scannedProducts.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = _scannedProducts[i];
                      final qty = _receivingItems[p.id] ?? 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            // Product Name
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      '${p.barcode} (คงเหลือ: ${p.stockQuantity})',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            // Qty Input
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red),
                                    onPressed: () => _updateQty(p.id, qty - 1),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    iconSize: 24,
                                  ),
                                  Container(
                                    constraints:
                                        const BoxConstraints(minWidth: 40),
                                    alignment: Alignment.center,
                                    child: Text(
                                      qty.toStringAsFixed(0),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline,
                                        color: Colors.green),
                                    onPressed: () => _updateQty(p.id, qty + 1),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    iconSize: 24,
                                  ),
                                ],
                              ),
                            ),
                            // Remove
                            SizedBox(
                              width: 32,
                              child: IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.grey),
                                onPressed: () => _removeProduct(p.id),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Button
          if (_scannedProducts.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveReceiving,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle),
                  label: Text(
                      'ยืนยันรับของเข้า (${_scannedProducts.length} รายการ)'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
