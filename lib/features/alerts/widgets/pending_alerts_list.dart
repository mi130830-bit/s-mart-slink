import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/alerts/providers/alert_log_provider.dart';
import 'package:s_link/features/alerts/models/shortage_log_model.dart';
import 'package:s_link/features/pos/screens/scanner_screen.dart';

class PendingAlertsList extends StatefulWidget {
  final Future<void> Function(List<String> items) onSubmit;

  const PendingAlertsList({
    super.key,
    required this.onSubmit,
  });

  @override
  State<PendingAlertsList> createState() => _PendingAlertsListState();
}

class _PendingAlertsListState extends State<PendingAlertsList> {
  final List<String> _pendingItems = [];
  bool _isSubmitting = false;

  void _addItemToPending(String text) {
    final cleanText = text.trim();
    if (cleanText.isNotEmpty) {
      setState(() {
        _pendingItems.add(cleanText);
      });
    }
  }

  void _removeItemFromPending(int index) {
    setState(() {
      _pendingItems.removeAt(index);
    });
  }

  Future<void> _submitAll() async {
    if (_pendingItems.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(List.from(_pendingItems));
      if (mounted) {
        setState(() {
          _pendingItems.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เพิ่มรายการของหมด / แจ้งซ่อม',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            return Autocomplete<ProductSearchResult>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<ProductSearchResult>.empty();
                }
                final provider = Provider.of<AlertLogProvider>(context, listen: false);
                return await provider.searchProducts(textEditingValue.text);
              },
              displayStringForOption: (option) => option.name,
              onSelected: (selection) {
                _addItemToPending(selection.name);
              },
              fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          hintText: 'ค้นหาสินค้า / สแกน หรือ พิมพ์เอง...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (val) {
                          _addItemToPending(val);
                          textController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Mobile Scanner Button
                    IconButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ScannerScreen(),
                          ),
                        );
                        if (result != null && result is String) {
                          textController.text = result;
                          // Trigger direct adding if it's a barcode
                          _addItemToPending(result);
                          textController.clear();
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                      ),
                      tooltip: 'สแกนสินค้า',
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        _addItemToPending(textController.text);
                        textController.clear();
                      },
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(backgroundColor: Colors.teal),
                    ),
                  ],
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option.name),
                            subtitle: option.barcode != null ? Text(option.barcode!) : null,
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          if (_pendingItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pendingItems.asMap().entries.map((entry) {
                return InputChip(
                  label: Text(entry.value),
                  onDeleted: () => _removeItemFromPending(entry.key),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  backgroundColor: Colors.teal.shade50,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitAll,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSubmitting
                    ? 'กำลังบันทึก...'
                    : 'ยืนยันแจ้งเตือนทั้งหมด (${_pendingItems.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
