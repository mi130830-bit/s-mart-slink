import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/pos_product.dart';
import '../models/pos_customer.dart'; // Added

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  PosCustomer? _customer; // Added

  List<CartItem> get items => _items;
  PosCustomer? get customer => _customer; // Added

  double get totalAmount => _items.fold(0, (sum, item) => sum + item.total);
  int get itemCount => _items.length;

  // Added: Set Customer
  void setCustomer(PosCustomer? customer) {
    _customer = customer;
    notifyListeners();
  }

  void addItem(PosProduct product) {
    // Optional: Check stock constraint if needed, but POS usually allows overriding
    // if (product.stockQuantity <= 0) return;

    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      _items[index].quantity += 1.0;
    } else {
      _items.add(CartItem(product: product, quantity: 1.0));
    }
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(int productId, double quantity) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _customer = null; // Clear customer too
    notifyListeners();
  }
}
