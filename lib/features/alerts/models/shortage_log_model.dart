class ShortageLogModel {
  final int id;
  final String itemName;
  final String status; // 'open', 'ordered', 'done'
  final String? reportedBy;
  final DateTime createdAt;
  final DateTime? orderedAt;

  ShortageLogModel({
    required this.id,
    required this.itemName,
    required this.status,
    this.reportedBy,
    required this.createdAt,
    this.orderedAt,
  });

  factory ShortageLogModel.fromMap(Map<String, dynamic> map) {
    return ShortageLogModel(
      id: int.parse(map['id'].toString()),
      itemName: map['item_name'] ?? '',
      status: map['status'] ?? 'open',
      reportedBy: map['reported_by'],
      createdAt:
          DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now(),
      orderedAt: map['ordered_at'] != null
          ? DateTime.tryParse(map['ordered_at'].toString())
          : null,
    );
  }
}

class ProductSearchResult {
  final String name;
  final String? barcode;

  ProductSearchResult({required this.name, this.barcode});

  factory ProductSearchResult.fromMap(Map<String, dynamic> map) {
    return ProductSearchResult(
      name: map['name'].toString(),
      barcode: map['barcode']?.toString(),
    );
  }

  @override
  String toString() => name;
}
