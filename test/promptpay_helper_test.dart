import 'package:flutter_test/flutter_test.dart';
import 'package:s_link/features/pos/services/promptpay_helper.dart';

void main() {
  group('PromptPayHelper', () {
    test('normalizes every supported Thai phone format identically', () {
      final domestic = PromptPayHelper.generatePayload(
        '0921223385',
        amount: 550,
      );
      final international = PromptPayHelper.generatePayload(
        '+66921223385',
        amount: 550,
      );
      final digitsOnly = PromptPayHelper.generatePayload(
        '66921223385',
        amount: 550,
      );

      expect(international, domestic);
      expect(digitsOnly, domestic);
      expect(domestic, contains('01130066921223385'));
      expect(domestic, contains('5406550.00'));
    });

    test('rejects an invalid phone number', () {
      expect(
        () => PromptPayHelper.generatePayload('921223385', amount: 550),
        throwsFormatException,
      );
    });
  });
}
