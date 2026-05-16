import 'dart:async';
import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  final PosApiService _apiService = PosApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final List<PosProduct> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _products.clear();
        _page = 1;
        _hasMore = true;
      });
    }

    setState(() => _isLoading = true);

    try {
      final newProducts = await _apiService.getProducts(
        page: _page,
        limit: 20,
        search: _searchQuery,
      );

      if (mounted) {
        setState(() {
          if (newProducts.isEmpty) {
            _hasMore = false;
          } else {
            _products.addAll(newProducts);
            _page++;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query.trim();
        _fetchProducts(refresh: true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการสินค้า (Product Manager)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchProducts(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาสินค้า (ชื่อ/บาร์โค้ด)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _onSearch,
            ),
          ),

          // Product List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchProducts(refresh: true),
              child: _products.isEmpty && !_isLoading
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: const Center(child: Text('ไม่พบสินค้า')),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _products.length + (_hasMore ? 1 : 0),
                      // Optimization: Fixed height for better performance
                      itemExtent: 88.0,
                      itemBuilder: (context, index) {
                        if (index == _products.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            ),
                          );
                        }
                        final product = _products[index];
                        return _buildProductItem(product);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(PosProduct product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: product.imageUrl?.isNotEmpty == true
              ? CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image, color: Colors.grey),
                )
              : const Icon(Icons.inventory, color: Colors.grey),
        ),
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Stock: ${product.stockQuantity.toStringAsFixed(0)}',
              style: TextStyle(
                color: product.stockQuantity > 0 ? Colors.black87 : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              'ราคา: ฿${product.retailPrice.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'แก้ไขข้อมูล (Edit)',
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditProductDialog(product),
            ),
            IconButton(
              tooltip: 'รับสินค้าเข้า (Stock In)',
              icon: const Icon(Icons.add_box, color: Colors.green),
              onPressed: () => _showStockDialog(product, mode: 'ADD'),
            ),
            IconButton(
              tooltip: 'ปรับสต็อก (Set Stock)',
              icon: const Icon(Icons.edit_note, color: Colors.orange),
              onPressed: () => _showStockDialog(product, mode: 'SET'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(PosProduct product) {
    final nameController = TextEditingController(text: product.name);
    final priceController =
        TextEditingController(text: product.retailPrice.toString());
    final barcodeController = TextEditingController(text: product.barcode);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขสินค้า'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'ชื่อสินค้า'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'ระบุชื่อสินค้า' : null,
                ),
                TextFormField(
                  controller: barcodeController,
                  decoration: const InputDecoration(labelText: 'บาร์โค้ด'),
                ),
                TextFormField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'ราคาขาย'),
                  validator: (v) => double.tryParse(v ?? '') == null
                      ? 'ราคาไม่ถูกต้อง'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            child: const Text('บันทึก'),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newName = nameController.text.trim();
                final newPrice = double.parse(priceController.text);
                final newBarcode = barcodeController.text.trim();

                Navigator.pop(ctx);

                try {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('กำลังบันทึก...')));

                  await _apiService.updateProduct(product.id, {
                    'name': newName,
                    'retailPrice': newPrice,
                    'price': newPrice, // For redundancy
                    'barcode': newBarcode,
                  });

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('แก้ไขสำเร็จ'),
                    backgroundColor: Colors.green,
                  ));
                  _fetchProducts(refresh: true);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showStockDialog(PosProduct product, {required String mode}) {
    final TextEditingController qtyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(mode == 'ADD' ? 'รับสินค้าเข้า' : 'ปรับสต็อก (Set)'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('สินค้า: ${product.name}'),
                const SizedBox(height: 8),
                Text(
                    'สต็อกปัจจุบัน: ${product.stockQuantity.toStringAsFixed(0)}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        mode == 'ADD' ? 'จำนวนที่รับเข้า' : 'จำนวนสต็อกจริง',
                    hintText: 'ระบุตัวเลข',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'กรุณาระบุจำนวน';
                    if (double.tryParse(val) == null) return 'ตัวเลขไม่ถูกต้อง';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              child: const Text('ยืนยัน'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final inputQty = double.parse(qtyController.text);

                  // Calculate new quantity
                  double newQty;
                  String note;
                  if (mode == 'ADD') {
                    newQty = product.stockQuantity + inputQty;
                    note = 'Remote In: Add $inputQty';
                  } else {
                    newQty = inputQty;
                    note = 'Remote Check: Set to $inputQty';
                  }

                  Navigator.pop(ctx); // Close dialog first

                  // Call API
                  try {
                    // Show Loading
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('กำลังบันทึก...')),
                    );

                    await _apiService.adjustStock(
                      productId: product.id,
                      newQuantity: newQty,
                      note: note,
                    );

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('บันทึกสำเร็จ'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Refresh list to show new stock
                    _fetchProducts(refresh: true);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เกิดข้อผิดพลาด: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
