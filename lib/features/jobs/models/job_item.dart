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
      qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      location: json['location'] ?? '',
      isWarehouse: json['is_warehouse'] ?? false,
    );
  }

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
