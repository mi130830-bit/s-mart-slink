import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/pos/models/pos_product.dart';

import 'package:s_link/features/pos/providers/cart_provider.dart';
import 'package:s_link/features/pos/repositories/pos_repository.dart'; // Changed from ApiService

import 'package:s_link/features/pos/screens/cart_screen.dart'; // Added

class MiniPosScreen extends StatefulWidget {
  const MiniPosScreen({super.key});

  @override
  State<MiniPosScreen> createState() => _MiniPosScreenState();
}

class _MiniPosScreenState extends State<MiniPosScreen> {
  final PosRepository _repo = PosRepository(); // Use Repository (Hybrid)
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final List<PosProduct> _products = [];
  bool _isLoading = false;
  // bool _hasMore = true; // Repo method returns plain list, no pagination for search
  // int _page = 1; // Not used in repo search
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    // _scrollController.addListener(_onScroll); // Repo returns all matches
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // void _onScroll() { ... } // Removed

  Future<void> _fetchProducts({bool refresh = false}) async {
    // Note: getAllProducts in repo doesn't support pagination yet, returns all/limit
    setState(() => _isLoading = true);

    try {
      final results =
          await _repo.getAllProducts(searchTerm: _searchQuery.trim());

      if (mounted) {
        setState(() {
          _products.clear();
          _products.addAll(results);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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

  void _processPayment() {
    if (context.read<CartProvider>().itemCount == 0) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    ).then((result) {
      if (result == true) {
        // Order Completed
        _fetchProducts(refresh: true);
      }
    });
  }

  // Customer Search Dialog

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ขายสินค้า (POS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchProducts(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding:
                const EdgeInsets.all(8.0), // increased padding for better touch
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: _onSearch,
            ),
          ),

          // 3. Product List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('ไม่พบสินค้า',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return _buildProductItem(product);
                        },
                      ),
          ),

          // 4. Cart Summary Bar
          if (cart.itemCount > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: 0.1), // ✅ Fix: withValues
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cart.itemCount} รายการ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '฿${cart.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _processPayment,
                    icon: const Icon(Icons.payment),
                    label: const Text('ชำระเงิน'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            )
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
              ? Image.network(product.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
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
          children: [
            Text('Stock: ${product.stockQuantity.toStringAsFixed(0)}'),
            Text(
              '฿${product.retailPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_shopping_cart, color: Colors.teal),
          onPressed: () {
            context.read<CartProvider>().addItem(product);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('เพิ่ม ${product.name} แล้ว'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
        onTap: () {
          context.read<CartProvider>().addItem(product);
        },
      ),
    );
  }
}
