import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:s_link/features/alerts/services/alert_log_service.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/repositories/pos_repository.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';
import 'scanner_screen.dart';

class StockCheckScreen extends StatefulWidget {
  const StockCheckScreen({super.key});

  @override
  State<StockCheckScreen> createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends State<StockCheckScreen> {
  final _searchController = TextEditingController();
  final _apiService = PosApiService();
  final FocusNode _focusNode = FocusNode();

  // Map<ProductId, CountedQuantity>
  final Map<int, double> _countedStock = {};
  // Ordered list of products for display
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
    _searchController.clear(); // Clear immediately for next scan

    setState(() => _isLoading = true);

    try {
      final results = await _apiService.getProducts(search: code, limit: 10);

      if (results.isNotEmpty) {
        // Assume exact match or first result
        final product = results.firstWhere(
            (p) => p.barcode == code || p.barcode.endsWith(code),
            orElse: () => results.first);

        _addProductToMap(product);
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
      if (mounted) {
        setState(() => _isLoading = false);
        _focusNode.requestFocus();
      }
    }
  }

  void _addProductToMap(PosProduct product) {
    setState(() {
      if (!_countedStock.containsKey(product.id)) {
        // New item
        _scannedProducts.insert(0, product); // Add to top
        _countedStock[product.id] =
            product.stockQuantity.toDouble(); // Default to current system stock
      }
      // If item exists, we don't increment automatically for "Stock Count" usually
      // Just bring to top
      _scannedProducts.removeWhere((p) => p.id == product.id);
      _scannedProducts.insert(0, product);
    });
  }

  void _updateCount(int productId, double newCount) {
    setState(() {
      _countedStock[productId] = newCount;
    });
  }

  void _removeProduct(int productId) {
    setState(() {
      _countedStock.remove(productId);
      _scannedProducts.removeWhere((p) => p.id == productId);
    });
  }

  Future<void> _saveAdjustments() async {
    if (_countedStock.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันบันทึกสต๊อก (Remote)'),
        content: Text(
            'ต้องการบันทึกการปรับสต๊อก ${_countedStock.length} รายการใช่หรือไม่?'),
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

    // ... inside _saveAdjustments ...
    if (confirm != true) return;

    setState(() => _isLoading = true);

    // Show persistent loading dialog (Overlay) to prevent interaction
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // ... existing logic ...
      final List<Map<String, dynamic>> stockUpdates = [];

      for (var entry in _countedStock.entries) {
        final pid = entry.key;
        final count = entry.value;

        // Skip Work Log items (negative IDs = ไม่มีใน POS)
        if (pid < 0) {
          continue;
        }

        stockUpdates.add({
          'productId': pid,
          'newStock': count,
        });
      }

      if (stockUpdates.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        if (mounted) {
          // ...
        }
        return;
      }

      // ✅ Update ผ่าน MySQL ตรงๆ
      final success = await PosRepository().updateStock(stockUpdates);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final successCount = success ? stockUpdates.length : 0;
      final failCount = success ? 0 : stockUpdates.length;

      if (failCount == 0) {
        SnackbarUtils.showLeft(context, '✅ บันทึกสต๊อกเรียบร้อย ($successCount รายการ)');
        setState(() {
          _countedStock.clear();
          _scannedProducts.clear();
        });
      } else {
        // ...
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog if error
      // ...
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ดึงสต๊อกจากรายงานการทำงาน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('วันนี้'),
              onTap: () {
                Navigator.pop(ctx);
                final now = DateTime.now();
                _importLogs(
                  DateTime(now.year, now.month, now.day),
                  DateTime(now.year, now.month, now.day, 23, 59, 59),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('เมื่อวานนี้'),
              onTap: () {
                Navigator.pop(ctx);
                final now = DateTime.now();
                final yesterday = now.subtract(const Duration(days: 1));
                _importLogs(
                  DateTime(yesterday.year, yesterday.month, yesterday.day),
                  DateTime(yesterday.year, yesterday.month, yesterday.day, 23,
                      59, 59),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('7 วันย้อนหลัง'),
              onTap: () {
                Navigator.pop(ctx);
                final now = DateTime.now();
                final start = now.subtract(const Duration(days: 7));
                _importLogs(
                  start,
                  DateTime(now.year, now.month, now.day, 23, 59, 59),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('เลือกวันที่...'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  _importLogs(
                    DateTime(picked.year, picked.month, picked.day),
                    DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importLogs(DateTime start, DateTime end) async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Logs จาก Firestore
      final service = AlertLogService();
      final logs = await service.getWorkLogsByDateRange(start, end);

      if (logs.isEmpty) {
        if (mounted) {
          SnackbarUtils.showLeft(context, 'ไม่พบรายงานในช่วงเวลาที่เลือก');
        }
        return;
      }

      // 2. Aggregate รายการสินค้าจากทุก Log
      final Map<String, double> aggregated = {};
      final Map<String, String> units = {};
      for (var log in logs) {
        for (var item in log.items) {
          aggregated[item.description] =
              (aggregated[item.description] ?? 0) + item.quantity;
          units[item.description] = item.unit;
        }
      }

      // 3. ✅ ค้นหาสินค้าทีละชื่อผ่าน API (ไม่ต้องต่อ MySQL ตรงๆ)
      int matchCount = 0;
      int notFoundCount = 0;
      int tempIdCounter = -1;

      for (var entry in aggregated.entries) {
        final name = entry.key.trim();
        final qty = entry.value;
        final unit = units[entry.key] ?? 'ชิ้น';

        // ค้นหาผ่าน API
        PosProduct? match;
        try {
          final results = await _apiService.getProducts(search: name, limit: 5);
          if (results.isNotEmpty) {
            final nameLower = name.toLowerCase();
            // Exact match ก่อน
            for (var p in results) {
              if (p.name.trim().toLowerCase() == nameLower) {
                match = p;
                break;
              }
            }
            // Contains match
            match ??= results.firstWhere(
              (p) =>
                  p.name.contains(name) ||
                  name.contains(p.name.split(' ').first),
              orElse: () => results.first,
            );
          }
        } catch (e) {
          debugPrint('⚠️ API search failed for "$name": $e');
        }

        if (match != null) {
          _addProductToMap(match);
          _updateCount(match.id, qty);
          matchCount++;
        } else {
          final tempProduct = PosProduct(
            id: tempIdCounter--,
            barcode: '',
            name: '$name ($unit)',
            retailPrice: 0,
            stockQuantity: 0,
          );
          _addProductToMap(tempProduct);
          _updateCount(tempProduct.id, qty);
          notFoundCount++;
          debugPrint('⚠️ Not found in POS: "$name"');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ผูกสำเร็จ: $matchCount รายการ'
                '${notFoundCount > 0 ? ' (ไม่พบใน POS: $notFoundCount)' : ''}'),
            backgroundColor: notFoundCount == 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'Error importing: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เช็คสต๊อก (Stock Check)'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline),
            tooltip: 'ดึงข้อมูลจากรายงาน',
            onPressed: _showImportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _countedStock.isEmpty ? null : _saveAdjustments,
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
                labelText: 'สแกนสินค้านับสต๊อก',
                prefixIcon: const Icon(Icons.qr_code),
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

          // List Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('สินค้า',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('ระบบ',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 3,
                    child: Text('นับได้',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 40), // Delete icon space
              ],
            ),
          ),

          // Product List
          Expanded(
            child: _scannedProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text('เริ่มสแกนเพื่อเพิ่มรายการสินค้า',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _scannedProducts.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    // Optimization: Fixed height estimate (Calculated ~80-100 dependent on content)
                    // Since height varies with diff text, we use a prototype or cache extent.
                    // For simplicity and safety with variable content, we keep it standard but add cacheExtent.
                    cacheExtent: 500,
                    itemBuilder: (ctx, i) {
                      final p = _scannedProducts[i];
                      final sysStock = p.stockQuantity.toDouble();
                      final count = _countedStock[p.id] ?? sysStock;
                      final diff = count - sysStock;

                      return Container(
                        color: diff != 0 ? Colors.yellow.shade50 : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            // Product Name
                            Expanded(
                              flex: 3, // Reduced from 4
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(p.barcode,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  if (diff != 0)
                                    Text(
                                      'Diff: ${diff > 0 ? "+${diff.toStringAsFixed(0)}" : diff.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          color: diff > 0
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            // System Stock
                            Expanded(
                              flex: 1, // Reduced from 2
                              child: Text(
                                sysStock.toStringAsFixed(0),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            // Counted Input
                            Expanded(
                              flex: 3, // Kept at 3
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _updateCount(p.id, count - 1),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    iconSize: 22,
                                  ),
                                  Container(
                                    constraints:
                                        const BoxConstraints(minWidth: 30),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    child: Text(
                                      count.toStringAsFixed(0),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline,
                                        color: Colors.green),
                                    onPressed: () =>
                                        _updateCount(p.id, count + 1),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    iconSize: 22,
                                  ),
                                ],
                              ),
                            ),
                            // Remove Action
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
        ],
      ),
    );
  }
}
