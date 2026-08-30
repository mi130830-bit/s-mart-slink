import 'dart:async';
import 'package:flutter/material.dart';
import 'package:s_link/features/pos/repositories/pos_repository.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'scanner_screen.dart';

class PriceCheckScreen extends StatefulWidget {
  const PriceCheckScreen({super.key});

  @override
  State<PriceCheckScreen> createState() => _PriceCheckScreenState();
}

class _PriceCheckScreenState extends State<PriceCheckScreen> {
  final _searchController = TextEditingController();
  final _repo = PosRepository();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  List<PosProduct> _products = [];
  PosProduct? _selectedProduct;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Auto focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final text = query.trim();
    if (text.isEmpty) {
      setState(() {
        _products = [];
        _selectedProduct = null;
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchProduct(text, isAutoSearch: true);
    });
  }

  Future<void> _searchProduct(String term, {bool isAutoSearch = false}) async {
    _debounceTimer?.cancel();
    final query = term.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (!isAutoSearch) {
        _selectedProduct = null;
        _products = [];
      }
    });

    try {
      final results = await _repo.getAllProducts(searchTerm: query);
      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _errorMessage = 'ไม่พบสินค้า "$query"';
          _products = [];
          _selectedProduct = null;
        });
      } else if (results.length == 1) {
        setState(() {
          _selectedProduct = results.first;
          _products = results;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _products = results;
          _selectedProduct = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'เกิดข้อผิดพลาด: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    _focusNode.requestFocus();
    setState(() {
      _selectedProduct = null;
      _products = [];
      _errorMessage = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedProduct == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedProduct != null) {
          setState(() => _selectedProduct = null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectedProduct != null
                ? 'รายละเอียดราคา'
                : 'เช็คราคาสินค้า (Price Check)',
          ),
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          leading: _selectedProduct != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'กลับไปรายการค้นหา',
                  onPressed: () {
                    setState(() => _selectedProduct = null);
                  },
                )
              : null,
          actions: [
            if (_selectedProduct != null ||
                _products.isNotEmpty ||
                _searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'ล้างการค้นหา',
                onPressed: _resetSearch,
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search & Scan Bar
              TextField(
                controller: _searchController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: 'สแกนบาร์โค้ด หรือ พิมพ์ชื่อสินค้า',
                  hintText: 'เช่น ปูนเสือ, วงบ่อ, ตะปู, รหัสบาร์โค้ด...',
                  prefixIcon: const Icon(Icons.search, color: Colors.orange),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'ล้างข้อความ',
                          onPressed: _resetSearch,
                        ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.orange),
                        tooltip: 'ค้นหา',
                        onPressed: () => _searchProduct(_searchController.text),
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner,
                            color: Colors.orange),
                        tooltip: 'สแกนบาร์โค้ด',
                        onPressed: () async {
                          final code = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ScannerScreen()),
                          );
                          if (code != null &&
                              code is String &&
                              code.isNotEmpty) {
                            _searchController.text = code;
                            _searchProduct(code);
                          }
                        },
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.orange.shade700, width: 2),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (value) => _searchProduct(value),
              ),
              const SizedBox(height: 16),

              // Content Area
              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.orange),
                        SizedBox(height: 12),
                        Text('กำลังค้นหาสินค้า...',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 72, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.red,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _resetSearch,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองค้นหาใหม่'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                          ),
                        )
                      ],
                    ),
                  ),
                )
              else if (_selectedProduct != null)
                Expanded(child: _buildProductDetail(_selectedProduct!))
              else if (_products.isNotEmpty)
                Expanded(child: _buildProductList())
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner,
                            size: 90, color: Colors.orange.shade200),
                        const SizedBox(height: 16),
                        const Text(
                          'พร้อมเช็คราคา',
                          style: TextStyle(
                              color: Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'พิมพ์ชื่อสินค้าเพื่อค้นหา หรือกดปุ่มสแกนบาร์โค้ด',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetail(PosProduct product) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            elevation: 6,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Name
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Barcode & Stock
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'บาร์โค้ด: ${product.barcode.isNotEmpty ? product.barcode : "-"}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: product.stockQuantity > 0
                              ? Colors.blue.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: product.stockQuantity > 0
                                ? Colors.blue.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Text(
                          'สต็อก: ${product.stockQuantity.toStringAsFixed(product.stockQuantity.truncateToDouble() == product.stockQuantity ? 0 : 2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: product.stockQuantity > 0
                                ? Colors.blue.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Price Label & Big Number
                  const Text(
                    'ราคาขายปลีก (Retail Price)',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '฿${product.retailPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.green.shade700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _selectedProduct = null);
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: Text(
                            _products.length > 1
                                ? 'กลับรายการ (${_products.length})'
                                : 'กลับหน้ารายการ',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.orange.shade700),
                            foregroundColor: Colors.orange.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _resetSearch,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ค้นหาใหม่'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
          child: Text(
            'พบสินค้า ${_products.length} รายการ (แตะเพื่อดูราคา):',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final p = _products[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade50,
                    child:
                        Icon(Icons.inventory_2, color: Colors.orange.shade700),
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        'Barcode: ${p.barcode.isNotEmpty ? p.barcode : "-"}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'สต็อก: ${p.stockQuantity.toStringAsFixed(p.stockQuantity.truncateToDouble() == p.stockQuantity ? 0 : 1)}',
                        style: TextStyle(
                          color: p.stockQuantity > 0
                              ? Colors.blue.shade700
                              : Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '฿${p.retailPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  onTap: () {
                    setState(() => _selectedProduct = p);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
