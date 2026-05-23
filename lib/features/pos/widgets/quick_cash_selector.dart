import 'package:flutter/material.dart';

class QuickCashSelector extends StatelessWidget {
  final double totalAmount;
  final ValueChanged<double> onCashSelected;

  const QuickCashSelector({
    super.key,
    required this.totalAmount,
    required this.onCashSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _buildChip(totalAmount, 'พอดี'),
        _buildChip(100, '100'),
        _buildChip(500, '500'),
        _buildChip(1000, '1000'),
      ],
    );
  }

  Widget _buildChip(double amount, String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () => onCashSelected(amount),
    );
  }
}
