import 'pos_product.dart';

class CartItem {
  final PosProduct product;
  double quantity;

  CartItem({
    required this.product,
    this.quantity = 1.0,
  });

  double get total => product.retailPrice * quantity;
}
