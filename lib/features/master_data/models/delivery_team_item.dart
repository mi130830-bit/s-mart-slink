// ไฟล์: lib/models/delivery_team_item.dart

class DeliveryTeamItem {
  final String type;
  final String name;
  final String id;
  // รองรับทะเบียนรถ (ถ้าเป็นรถ)
  final String? licensePlate;

  const DeliveryTeamItem({
    required this.type,
    required this.name,
    required this.id,
    this.licensePlate,
  });

  factory DeliveryTeamItem.fromJson(Map<String, dynamic> json) {
    return DeliveryTeamItem(
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      id: json['id'] ?? '',
      licensePlate: json['licensePlate'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'type': type,
      'name': name,
      'id': id,
    };
    if (licensePlate != null) {
      data['licensePlate'] = licensePlate;
    }
    return data;
  }
}
