import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/alerts/models/shortage_log_model.dart';
import 'package:s_link/features/alerts/providers/alert_log_provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/pos/screens/scanner_screen.dart'; // Mobile Scanner

class StockAlertScreen extends StatefulWidget {
  final bool isEmbedded;
  const StockAlertScreen({super.key, this.isEmbedded = false});

  @override
  State<StockAlertScreen> createState() => _StockAlertScreenState();
}

class _StockAlertScreenState extends State<StockAlertScreen> {
  final _itemController = TextEditingController();
  final List<String> _pendingItems = [];
  bool _isSubmitting = false;

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider =
            Provider.of<AuthenticationProvider>(context, listen: false);
        final userRole = authProvider.currentUser?.role.name;
        Provider.of<AlertLogProvider>(context, listen: false)
            .startListeningToAlertsAndLogs(userRole);
      }
    });
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  void _addItemToPending() {
    final text = _itemController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _pendingItems.add(text);
        _itemController.clear();
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
      final authProvider =
          Provider.of<AuthenticationProvider>(context, listen: false);
      final alertProvider =
          Provider.of<AlertLogProvider>(context, listen: false);
      final uid = authProvider.currentUser?.uid ?? 'unknown';

      // Use Future.wait for parallel execution
      final futures =
          _pendingItems.map((item) => alertProvider.createAlert(item, uid));
      await Future.wait(futures);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('แจ้งเตือน ${_pendingItems.length} รายการเรียบร้อย!'),
              backgroundColor: Colors.teal),
        );
        setState(() {
          _pendingItems.clear();
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _markAsOrdered(dynamic alertId) async {
    try {
      await Provider.of<AlertLogProvider>(context, listen: false)
          .markAsOrdered(alertId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('อัปเดตสถานะเป็น "สั่งแล้ว"'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAlertInstant(dynamic alertId) async {
    try {
      await Provider.of<AlertLogProvider>(context, listen: false)
          .markAsDone(alertId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ลบรายการเรียบร้อย'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDeleteAlert(dynamic alertId, String alertName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบรายการ "$alertName" ใช่ไหม?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAlertInstant(alertId);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmOrderAlert(dynamic alertId, String alertName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันสถานะสั่งของ'),
        content: Text(
            'เปลี่ยนสถานะ "$alertName" เป็น "สั่งแล้ว" ใช่ไหม?\n(รายการจะหายไปอัตโนมัติใน 6 ชม.)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              Navigator.pop(ctx);
              await _markAsOrdered(alertId);
            },
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('คัดลอก "$text" แล้ว'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget _buildPaginationControls(int currentPage, int totalPages,
      {bool isFooter = false}) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.5),
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed:
                currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('หน้า $currentPage / $totalPages',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            onPressed: currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  bool _canDelete(AuthenticationProvider authProvider) {
    final role = authProvider.currentUser?.role.name.toLowerCase();
    return role == 'admin' || role == 'requester';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final canDeleteAlert = _canDelete(authProvider);

    Widget content = Consumer<AlertLogProvider>(
      builder: (context, alertProvider, child) {
        final allAlerts = alertProvider.openAlerts;
        final totalItems = allAlerts.length;
        final totalPages = (totalItems / _itemsPerPage).ceil();

        if (_currentPage > totalPages && totalPages > 0) {
          _currentPage = totalPages;
        } else if (totalPages == 0) {
          _currentPage = 1;
        }

        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage) > totalItems
            ? totalItems
            : (startIndex + _itemsPerPage);

        final currentDisplayAlerts =
            (totalItems > 0) ? allAlerts.sublist(startIndex, endIndex) : [];

        return Column(
          children: [
            // Entry Form
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('เพิ่มรายการของหมด / แจ้งซ่อม',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (context, constraints) {
                    return Autocomplete<ProductSearchResult>(
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<ProductSearchResult>.empty();
                        }
                        final provider = Provider.of<AlertLogProvider>(context,
                            listen: false);
                        return await provider
                            .searchProducts(textEditingValue.text);
                      },
                      displayStringForOption: (option) => option.name,
                      onSelected: (selection) {
                        _itemController.text = selection.name;
                        _addItemToPending();
                      },
                      fieldViewBuilder: (context, textController, focusNode,
                          onFieldSubmitted) {
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: textController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  hintText:
                                      'ค้นหาสินค้า / สแกน หรือ พิมพ์เอง...',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  isDense: true,
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onSubmitted: (val) {
                                  _itemController.text = val;
                                  _addItemToPending();
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
                                  // Optional: trigger search immediately if needed
                                }
                              },
                              icon: const Icon(Icons.qr_code_scanner),
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.blue.shade50,
                                  foregroundColor: Colors.blue.shade700),
                              tooltip: 'สแกนสินค้า',
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () {
                                _itemController.text = textController.text;
                                _addItemToPending();
                                textController.clear();
                              },
                              icon: const Icon(Icons.add),
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.teal),
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
                                    subtitle: option.barcode != null
                                        ? Text(option.barcode!)
                                        : null,
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
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
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
            ),

            const Divider(height: 1, thickness: 1),

            // List Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'รายการแจ้งเตือน ($totalItems รายการ)',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold),
                  ),
                  if (alertProvider.isLoading)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),

            _buildPaginationControls(_currentPage, totalPages),

            // List Body
            Expanded(
              child: alertProvider.errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 60, color: Colors.red),
                          const SizedBox(height: 8),
                          Text('เกิดข้อผิดพลาด',
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold)),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              alertProvider.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Provider.of<AlertLogProvider>(context,
                                      listen: false)
                                  .startListeningToAlertsAndLogs(
                                      authProvider.currentUser?.role.name);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('ลองใหม่'),
                          )
                        ],
                      ),
                    )
                  : currentDisplayAlerts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 60, color: Colors.green),
                              const SizedBox(height: 8),
                              Text('ไม่มีรายการค้าง',
                                  style:
                                      TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(0),
                          itemCount: currentDisplayAlerts.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final alert = currentDisplayAlerts[index];
                            final realIndex = startIndex + index + 1;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade50,
                                foregroundColor: Colors.teal,
                                radius: 18,
                                child: Text('$realIndex',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ),
                              title: Text(
                                alert.itemName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 16),
                              ),
                              subtitle: Text(
                                'แจ้งโดย: ${alert.reportedBy ?? '-'} | เวลา: ${_formatDate(alert.createdAt)}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Order Method
                                  if (alert.orderedAt != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.blue.shade200),
                                      ),
                                      child: Text(
                                        'สั่งแล้ว',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(
                                          Icons.check_circle_outline),
                                      tooltip: 'สั่งของแล้ว',
                                      color: Colors.blue,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmOrderAlert(
                                          alert.id, alert.itemName),
                                    ),
                                  const SizedBox(width: 8), // Gap
                                  // Copy
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    tooltip: 'คัดลอก',
                                    color: Colors.teal,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () =>
                                        _copyToClipboard(alert.itemName),
                                  ),
                                  const SizedBox(width: 8), // Gap
                                  // Delete
                                  if (canDeleteAlert)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 22),
                                      tooltip: 'ลบรายการ',
                                      color: Colors.red.shade400,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDeleteAlert(
                                          alert.id, alert.itemName),
                                    ),
                                ],
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                            );
                          },
                        ),
            ),

            _buildPaginationControls(_currentPage, totalPages, isFooter: true),
          ],
        );
      },
    );

    if (widget.isEmbedded) {
      return Scaffold(body: content);
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('แจ้งของหมด/ซ่อมบำรุง'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: content,
      );
    }
  }
}
