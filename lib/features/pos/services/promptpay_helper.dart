class PromptPayHelper {
  /// Generate EMVCo QR Payload for PromptPay
  /// [target]: Phone number (08xxxxxxxx) or TaxID (13 digits)
  /// [amount]: Amount to transfer (optional)
  static String generatePayload(String target, {double? amount}) {
    // 1. Sanitize Target
    target = target.replaceAll(RegExp(r'[^0-9]'), '');

    // 2. Determine Target Type
    String targetType;
    if (target.length >= 13) {
      targetType = '02'; // Tax ID
    } else {
      targetType = '01'; // Phone
      if (target.startsWith('0')) {
        target = '66${target.substring(1)}'; // Convert 08x -> 668x
      }
    }

    // 3. Build Data Fields
    final f00 = _f('00', '01'); // Payload Format Indicator
    final f01 = _f(
        '01', '11'); // Point of Initiation Method (11 = Dynamic, 12 = Static)

    // Merchant Account Information (29 = PromptPay)
    final merchantInfo = _serialize([
      _f('00', 'A000000677010111'), // AID for PromptPay
      _f(targetType, target), // Biller ID (Phone/Tax)
    ]);
    final f29 = _f('29', merchantInfo);

    final f53 = _f('53', '764'); // Currency Code (THB)
    final f58 = _f('58', 'TH'); // Country Code

    // Optional Amount
    String f54 = '';
    if (amount != null && amount > 0) {
      f54 = _f('54', amount.toStringAsFixed(2));
    }

    // 4. Combine Fields (except CRC)
    final rawData = '$f00$f01$f29$f53$f54$f58';

    // 5. Add CRC ('6304')
    final dataWithCrcTag = '${rawData}6304';

    // 6. Calculate CRC16
    final crc = _crc16(dataWithCrcTag);

    return '$dataWithCrcTag$crc';
  }

  static String _f(String id, String value) {
    return '$id${value.length.toString().padLeft(2, '0')}$value';
  }

  static String _serialize(List<String> fields) {
    return fields.join('');
  }

  static String _crc16(String data) {
    int crc = 0xFFFF;
    for (int i = 0; i < data.length; i++) {
      int x = (crc >> 8) ^ data.codeUnitAt(i);
      x ^= x >> 4;
      crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x;
      crc &= 0xFFFF;
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
