// ไฟล์: lib/models/customer.dart

class Customer {
  final String name;
  final String address;
  final String phoneNumber;
  final String? lineUserId;

  const Customer({
    required this.name,
    required this.address,
    required this.phoneNumber,
    this.lineUserId,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      lineUserId:
          json['line_user_id'] ?? json['lineUserId'], // Handle both cases
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phoneNumber': phoneNumber,
      'line_user_id': lineUserId,
    };
  }
}
