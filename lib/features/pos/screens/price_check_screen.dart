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
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _searchProduct(String term) async {
    if (term.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedProduct = null;
      _products = [];
    });

    try {
      final results = await _repo.getAllProducts(searchTerm: term.trim());
      if (results.isEmpty) {
        setState(() => _errorMessage = 'ไม่พบสินค้า "$term"');
      } else if (results.length == 1) {
        setState(() => _selectedProduct = results.first);
      } else {
        setState(() => _products = results);
      }
    } catch (e) {
      setState(() => _errorMessage = 'เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _isLoading = false);
      _searchController.clear();
    }
  }

  void _resetSearch() {
    _searchController.clear();
    _focusNode.requestFocus();
    setState(() {
      _selectedProduct = null;
      _products = [];
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เช็คราคาสินค้า'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: 'สแกนบาร์โค้ด หรือ พิมพ์ชื่อสินค้า',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _resetSearch,
                      ),
                    IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () async {
                          final code = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ScannerScreen()),
                          );
                          if (code != null && code is String) {
                            _searchProduct(code);
                          }
                        }),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => _searchProduct(value),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style:
                              const TextStyle(fontSize: 24, color: Colors.red)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _resetSearch,
                        child: const Text('ลองใหม่'),
                      )
                    ],
                  ),
                ),
              ),
            if (_selectedProduct != null)
              Expanded(child: _buildProductDetail(_selectedProduct!)),
            if (_products.isNotEmpty && _selectedProduct == null)
              Expanded(child: _buildProductList()),
            if (!_isLoading &&
                _products.isEmpty &&
                _selectedProduct == null &&
                _errorMessage == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner,
                          size: 100, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      Text(
                        'รอรับข้อมูล...',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetail(PosProduct product) {
    return Center(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Barcode: ${product.barcode}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              const Text(
                'ราคาขาย (Price)',
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Text(
                '฿${product.retailPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                  onPressed: _resetSearch,
                  icon: const Icon(Icons.refresh),
                  label: const Text('เช็ครายการอื่น'))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.builder(
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final p = _products[index];
        return Card(
          child: ListTile(
            title: Text(p.name),
            subtitle: Text('Barcode: ${p.barcode}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              setState(() => _selectedProduct = p);
            },
          ),
        );
      },
    );
  }
}
