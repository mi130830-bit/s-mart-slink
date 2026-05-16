class PosProduct {
  final int id;
  final String barcode;
  final String name;
  final double retailPrice;
  final double stockQuantity;
  final String? imageUrl;
  final String
      categoryId; // Keep as string or int depending on DB, assume int usually but safe as string for display

  PosProduct({
    required this.id,
    required this.barcode,
    required this.name,
    required this.retailPrice,
    required this.stockQuantity,
    this.imageUrl,
    this.categoryId = '0',
  });

  factory PosProduct.fromMap(Map<String, dynamic> map) {
    return PosProduct(
      id: int.tryParse(map['id'].toString()) ?? 0,
      barcode: map['barcode']?.toString() ?? '',
      name: map['name']?.toString() ?? 'No Name',
      retailPrice: double.tryParse(map['retailPrice'].toString()) ??
          double.tryParse(
              map['price'].toString()) ?? // API sometimes returns 'price'
          0.0,
      stockQuantity: double.tryParse(map['stockQuantity'].toString()) ?? 0.0,
      imageUrl: map['imageUrl']?.toString(),
      // API uses 'category_id', MySQL uses 'categoryId'
      categoryId: map['categoryId']?.toString() ??
          map['category_id']?.toString() ??
          '0',
    );
  }
}
