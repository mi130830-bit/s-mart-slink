import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:s_link/features/alerts/services/alert_log_service.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/repositories/pos_repository.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
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
  // Live search suggestions
  final List<PosProduct> _suggestions = [];

  bool _isLoading = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final text = query.trim();
    if (text.isEmpty) {
      setState(_suggestions.clear);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await _apiService.getProducts(search: text, limit: 15);
        if (!mounted || _searchController.text.trim() != text) return;
        setState(() {
          _suggestions
            ..clear()
            ..addAll(results);
        });
      } catch (e) {
        debugPrint('⚠️ StockCheck search suggestions error: $e');
      }
    });
  }

  void _selectSuggestion(PosProduct product) {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(_suggestions.clear);
    _addProductToMap(product);
    _focusNode.requestFocus();
  }

  Future<void> _handleScan(String code) async {
    final text = code.trim();
    if (text.isEmpty) return;

    // 1. ถ้ามี suggestions อยู่แล้ว ให้ตรวจสอบก่อน
    if (_suggestions.isNotEmpty) {
      final exact = _suggestions.where(
          (p) => p.barcode == text || p.barcode.endsWith(text));
      if (exact.isNotEmpty) {
        _selectSuggestion(exact.first);
        return;
      }
      if (_suggestions.length == 1) {
        _selectSuggestion(_suggestions.first);
        return;
      }
      SnackbarUtils.showLeft(context, 'พบสินค้า ${_suggestions.length} รายการ กรุณาแตะเลือกรายการที่ต้องการ');
      return;
    }

    // 2. ดึงข้อมูลจาก API
    setState(() => _isLoading = true);

    try {
      final results = await _apiService.getProducts(search: text, limit: 15);

      if (results.isNotEmpty) {
        final exact = results.where(
            (p) => p.barcode == text || p.barcode.endsWith(text));

        if (exact.isNotEmpty) {
          _searchController.clear();
          _addProductToMap(exact.first);
        } else if (results.length == 1) {
          _searchController.clear();
          _addProductToMap(results.first);
        } else {
          setState(() {
            _suggestions
              ..clear()
              ..addAll(results);
          });
          if (mounted) {
            SnackbarUtils.showLeft(context, 'พบสินค้า ${results.length} รายการ กรุณาแตะเลือกรายการที่ต้องการ');
          }
        }
      } else {
        if (mounted) {
          SnackbarUtils.showLeft(context, 'ไม่พบสินค้า: $text', isError: true);
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

  Future<void> _showEditCountDialog(PosProduct product, double currentCount) async {
    final countController = TextEditingController(text: currentCount.toStringAsFixed(0));
    final newCount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ระบุจำนวนนับ: ${product.name}'),
        content: TextField(
          controller: countController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'จำนวนนับจริง',
            border: OutlineInputBorder(),
            suffixText: 'ชิ้น',
          ),
          onSubmitted: (val) {
            final parsed = double.tryParse(val.trim());
            Navigator.pop(ctx, parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(countController.text.trim());
              Navigator.pop(ctx, parsed);
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );

    if (newCount != null) {
      _updateCount(product.id, newCount);
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
      _countedStock[productId] = newCount < 0 ? 0 : newCount;
    });
  }

  void _removeProduct(int productId) {
    setState(() {
      _countedStock.remove(productId);
      _scannedProducts.removeWhere((p) => p.id == productId);
    });
  }

  Widget _buildImageStatusBadge(PosProduct p, int index) {
    final hasImage = p.imageUrl != null && p.imageUrl!.trim().isNotEmpty;
    return InkWell(
      onTap: () => _pickAndUploadProductImage(p, index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: hasImage ? Colors.green.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasImage ? Colors.green.shade300 : Colors.grey.shade300,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasImage ? Icons.check_circle : Icons.camera_alt_outlined,
              size: 13,
              color: hasImage ? Colors.green.shade700 : Colors.grey.shade700,
            ),
            const SizedBox(width: 3),
            Text(
              hasImage ? 'มีรูปแล้ว' : 'ถ่ายรูป',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: hasImage ? Colors.green.shade700 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProductImage(PosProduct p, int index) async {
    if (p.id <= 0) {
      SnackbarUtils.showLeft(context, '⚠️ ไม่สามารถอัปโหลดรูปสินค้าชั่วคราวได้');
      return;
    }

    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    File? imageFile;

    if (isDesktop) {
      // บน Windows Desktop ให้เปิดหน้าต่างเลือกไฟล์รูปภาพโดยตรง
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) {
          imageFile = File(result.files.single.path!);
        }
      } catch (e) {
        debugPrint('⚠️ FilePicker error on desktop: $e');
      }
    } else {
      // บน Mobile (Android / iOS) ให้แสดงตัวเลือก ถ่ายรูปด้วยกล้อง หรือ เลือกจากอัลบั้ม
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'ถ่ายรูป/อัปโหลดภาพ: ${p.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('ถ่ายรูปด้วยกล้อง'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('เลือกจากแกลเลอรี'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: source,
          maxWidth: 600,
          maxHeight: 600,
          imageQuality: 70,
        );
        if (picked != null) {
          imageFile = File(picked.path);
        }
      } catch (e) {
        debugPrint('⚠️ ImagePicker error, trying FilePicker fallback: $e');
        try {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
          );
          if (result != null && result.files.single.path != null) {
            imageFile = File(result.files.single.path!);
          }
        } catch (fpe) {
          debugPrint('⚠️ FilePicker fallback failed: $fpe');
        }
      }
    }

    if (imageFile == null) return;

    try {
      if (!mounted) return;
      SnackbarUtils.showLeft(context, '⏳ กำลังอัปโหลดรูปภาพ...');

      final uploadedUrl = await _apiService.uploadProductImage(
        productId: p.id,
        imageFile: imageFile,
      );

      if (!mounted) return;

      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        SnackbarUtils.showLeft(context, '✅ อัปโหลดรูป "${p.name}" เรียบร้อย');
        setState(() {
          final updatedProduct = PosProduct(
            id: p.id,
            barcode: p.barcode,
            name: p.name,
            retailPrice: p.retailPrice,
            stockQuantity: p.stockQuantity,
            imageUrl: uploadedUrl,
            categoryId: p.categoryId,
          );
          _scannedProducts[index] = updatedProduct;
        });
      } else {
        SnackbarUtils.showLeft(context, '❌ อัปโหลดรูปภาพไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
      }
    } catch (e) {
      debugPrint('⚠️ Error uploading product image: $e');
      if (mounted) {
        SnackbarUtils.showLeft(context, '❌ เกิดข้อผิดพลาด: $e');
      }
    }
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

      // ✅ ดึงชื่อพนักงานผู้ตรวจนับจาก AuthenticationProvider
      String currentUserName = 'App User';
      try {
        final authProvider =
            Provider.of<AuthenticationProvider>(context, listen: false);
        final user = authProvider.currentUser;
        if (user != null) {
          currentUserName =
              user.name.trim().isNotEmpty ? user.name.trim() : (user.email.isNotEmpty ? user.email : 'App User');
        }
      } catch (e) {
        debugPrint('⚠️ Cannot get auth user in StockCheck: $e');
      }

      // ✅ Update ผ่าน API (บันทึก MySQL + Ledger)
      final success = await PosRepository().updateStock(
        stockUpdates,
        user: currentUserName,
        note: 'S-Link Stock Check (by $currentUserName)',
      );

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
          // Search/Scan Bar with Dropdown Suggestions
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: _onSearchChanged,
                  onSubmitted: _handleScan,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'พิมพ์ชื่อสินค้า หรือสแกนบาร์โค้ด',
                    hintText: 'เช่น ปูน, สายไฟ, ท่อ, หรือรหัสบาร์โค้ด',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            tooltip: 'ล้างคำค้นหา',
                            onPressed: () {
                              _searchController.clear();
                              _searchDebounce?.cancel();
                              setState(_suggestions.clear);
                              _focusNode.requestFocus();
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: 'เปิดกล้องสแกน',
                          onPressed: () async {
                            final code = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ScannerScreen()),
                            );
                            if (code != null && code is String) {
                              _handleScan(code);
                            }
                          },
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                // Dropdown Suggestions List
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.orange.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          color: Colors.orange.shade50,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ผลการค้นหา (${_suggestions.length} รายการ - แตะเพื่อเลือก):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(_suggestions.clear),
                                child: const Icon(Icons.close, size: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, index) {
                              final p = _suggestions[index];
                              final hasImg = p.imageUrl != null && p.imageUrl!.trim().isNotEmpty;
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.inventory_2, color: Colors.orange),
                                title: Text(
                                  p.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'บาร์โค้ด: ${p.barcode.isEmpty ? "-" : p.barcode} • สต๊อก: ${p.stockQuantity.toStringAsFixed(0)}',
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasImg)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.green.shade300, width: 0.5),
                                        ),
                                        child: Text(
                                          '📷 มีรูปแล้ว',
                                          style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  '฿${p.retailPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () => _selectSuggestion(p),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
                        Text('พิมพ์ชื่อหรือสแกนเพื่อเพิ่มรายการสินค้า',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _scannedProducts.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
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
                            // Product Name & Image Badge
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 3,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (p.barcode.isNotEmpty)
                                        Text(p.barcode,
                                            style: const TextStyle(
                                                fontSize: 12, color: Colors.grey)),
                                      _buildImageStatusBadge(p, i),
                                    ],
                                  ),
                                  if (diff != 0) ...[
                                    const SizedBox(height: 2),
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
                                ],
                              ),
                            ),
                            // System Stock
                            Expanded(
                              flex: 1,
                              child: Text(
                                sysStock.toStringAsFixed(0),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            // Counted Input
                            Expanded(
                              flex: 3,
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
                                  InkWell(
                                    onTap: () => _showEditCountDialog(p, count),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(minWidth: 36),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        color: Colors.grey.shade50,
                                      ),
                                      child: Text(
                                        count.toStringAsFixed(0),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18),
                                      ),
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
