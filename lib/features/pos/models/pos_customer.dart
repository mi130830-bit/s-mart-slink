class PosCustomer {
  final int id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? address;
  final double currentDebt;
  final String? nickname;
  final String? code;
  final String? lineUserId; // ✅ Correct column for Line OA

  PosCustomer({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.address,
    this.currentDebt = 0.0,
    this.nickname,
    this.code,
    this.lineUserId,
  });

  // ✅ Compatibility Getters
  String get name => fullName;
  String? get phoneNumber => phone;

  String get fullName {
    String name = '$firstName $lastName'.trim();
    if (nickname != null && nickname!.isNotEmpty) {
      name += ' ($nickname)';
    }
    return name;
  }

  factory PosCustomer.fromMap(Map<String, dynamic> map) {
    // 1. Try to get firstName/lastName directly
    String fname =
        map['firstName'] ?? map['firstname'] ?? map['first_name'] ?? '';
    String lname = map['lastName'] ?? map['lastname'] ?? map['last_name'] ?? '';

    // 2. If both are empty, try to parse from 'name' field (common in API)
    if (fname.isEmpty && lname.isEmpty) {
      final String? combinedName = map['name']?.toString();
      if (combinedName != null && combinedName.isNotEmpty) {
        final parts = combinedName.trim().split(' ');
        if (parts.isNotEmpty) {
          fname = parts.first;
          if (parts.length > 1) {
            lname = parts.sublist(1).join(' ');
          }
        }
      }
    }

    return PosCustomer(
      id: int.tryParse(map['id'].toString()) ?? 0,
      firstName: fname,
      lastName: lname,
      phone: map['phone']?.toString(),
      address: map['address']?.toString(),
      currentDebt: double.tryParse((map['currentDebt'] ??
                  map['currentdebt'] ??
                  map['current_debt'] ??
                  0)
              .toString()) ??
          0.0,
      nickname: map['nickname']?.toString(),
      code: map['code']?.toString(),
      lineUserId: map['line_user_id']?.toString() ??
          map['lineUserId']?.toString(), // Added lineUserId fallback
    );
  }
}
