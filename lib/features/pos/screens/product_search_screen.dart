import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/providers/cart_provider.dart';
import 'package:s_link/features/pos/repositories/pos_repository.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final PosRepository _repo = PosRepository();
  final TextEditingController _searchController = TextEditingController();
  final List<PosProduct> _products = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final results =
          await _repo.getAllProducts(searchTerm: _searchController.text.trim());
      if (mounted) {
        setState(() {
          _products.clear();
          _products.addAll(results);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาสินค้า (Search Products)'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'พิมพ์ชื่อสินค้า หรือ บาร์โค้ด...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearch,
              autofocus: true,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('ไม่พบสินค้า'))
                    : ListView.separated(
                        itemCount: _products.length,
                        separatorBuilder: (ctx, i) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final product = _products[i];
                          return ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade200,
                              child: product.imageUrl?.isNotEmpty == true
                                  ? Image.network(product.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image))
                                  : const Icon(Icons.inventory,
                                      color: Colors.grey),
                            ),
                            title: Text(product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'Stock: ${product.stockQuantity.toStringAsFixed(0)} | ฿${product.retailPrice.toStringAsFixed(2)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_shopping_cart,
                                  color: Colors.green),
                              onPressed: () {
                                context.read<CartProvider>().addItem(product);
                                Navigator.pop(
                                    context); // Pop back after selection
                              },
                            ),
                            onTap: () {
                              context.read<CartProvider>().addItem(product);
                              Navigator.pop(
                                  context); // Pop back after selection
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
