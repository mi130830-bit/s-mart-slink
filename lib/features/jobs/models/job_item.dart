class JobItem {
  final String name;
  final double qty;
  final double price;
  final double total;
  final String location;
  final bool isWarehouse;

  const JobItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
    this.location = '',
    this.isWarehouse = false,
  });

  factory JobItem.fromJson(Map<String, dynamic> json) {
    return JobItem(
      name: json['name'] ?? '',
      // SQLite/API payloads may represent numbers as either num or String.
      // Normalize both forms so an old cached item cannot hide every item in
      // its job when one numeric field is serialized as text.
      qty: _asDouble(json['qty']),
      price: _asDouble(json['price']),
      total: _asDouble(json['total']),
      location: json['location'] ?? '',
      isWarehouse: json['is_warehouse'] ?? false,
    );
  }

  static double _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0.0;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'qty': qty,
      'price': price,
      'total': total,
      'location': location,
      'is_warehouse': isWarehouse,
    };
  }
}
