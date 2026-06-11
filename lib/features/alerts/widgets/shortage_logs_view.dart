import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/alerts/providers/alert_log_provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';

class ShortageLogsView extends StatefulWidget {
  const ShortageLogsView({super.key});

  @override
  State<ShortageLogsView> createState() => _ShortageLogsViewState();
}

class _ShortageLogsViewState extends State<ShortageLogsView> {
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  bool _canDelete(AuthenticationProvider authProvider) {
    final role = authProvider.currentUser?.role.name.toLowerCase();
    return role == 'admin' || role == 'requester';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    SnackbarUtils.showLeft(context, 'คัดลอก "$text" แล้ว');
  }

  Future<void> _markAsOrdered(BuildContext context, dynamic alertId) async {
    try {
      await Provider.of<AlertLogProvider>(context, listen: false).markAsOrdered(alertId);
      if (context.mounted) {
        SnackbarUtils.showLeft(context, 'อัปเดตสถานะเป็น "สั่งแล้ว"');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showLeft(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _deleteAlertInstant(BuildContext context, dynamic alertId) async {
    try {
      await Provider.of<AlertLogProvider>(context, listen: false).markAsDone(alertId);
      if (context.mounted) {
        SnackbarUtils.showLeft(context, 'ลบรายการเรียบร้อย', isError: true);
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showLeft(context, 'Error: $e', isError: true);
      }
    }
  }

  void _confirmDeleteAlert(BuildContext context, dynamic alertId, String alertName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบรายการ "$alertName" ใช่ไหม?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAlertInstant(context, alertId);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmOrderAlert(BuildContext context, dynamic alertId, String alertName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันสถานะสั่งของ'),
        content: Text('เปลี่ยนสถานะ "$alertName" เป็น "สั่งแล้ว" ใช่ไหม?\n(รายการจะหายไปอัตโนมัติใน 6 ชม.)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              Navigator.pop(ctx);
              await _markAsOrdered(context, alertId);
            },
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int currentPage, int totalPages, {bool isFooter = false}) {
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
            onPressed: currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'หน้า $currentPage / $totalPages',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: currentPage < totalPages ? () => setState(() => _currentPage++) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final canDeleteAlert = _canDelete(authProvider);

    return Consumer<AlertLogProvider>(
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
        final endIndex = (startIndex + _itemsPerPage) > totalItems ? totalItems : (startIndex + _itemsPerPage);

        final currentDisplayAlerts = (totalItems > 0) ? allAlerts.sublist(startIndex, endIndex) : [];

        return Column(
          children: [
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (alertProvider.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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
                          const Icon(Icons.error_outline, size: 60, color: Colors.red),
                          const SizedBox(height: 8),
                          Text(
                            'เกิดข้อผิดพลาด',
                            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                          ),
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
                              Provider.of<AlertLogProvider>(context, listen: false)
                                  .startListeningToAlertsAndLogs(authProvider.currentUser?.role.name);
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
                              const Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
                              const SizedBox(height: 8),
                              Text('ไม่มีรายการค้าง', style: TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(0),
                          itemCount: currentDisplayAlerts.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final alert = currentDisplayAlerts[index];
                            final realIndex = startIndex + index + 1;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade50,
                                foregroundColor: Colors.teal,
                                radius: 18,
                                child: Text(
                                  '$realIndex',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              title: Text(
                                alert.itemName,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                              ),
                              subtitle: Text(
                                'แจ้งโดย: ${alert.reportedBy ?? '-'} | เวลา: ${_formatDate(alert.createdAt)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Order Method
                                  if (alert.orderedAt != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue.shade200),
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
                                      icon: const Icon(Icons.check_circle_outline),
                                      tooltip: 'สั่งของแล้ว',
                                      color: Colors.blue,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmOrderAlert(context, alert.id, alert.itemName),
                                    ),
                                  const SizedBox(width: 8), // Gap
                                  // Copy
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    tooltip: 'คัดลอก',
                                    color: Colors.teal,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _copyToClipboard(context, alert.itemName),
                                  ),
                                  const SizedBox(width: 8), // Gap
                                  // Delete
                                  if (canDeleteAlert)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 22),
                                      tooltip: 'ลบรายการ',
                                      color: Colors.red.shade400,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDeleteAlert(context, alert.id, alert.itemName),
                                    ),
                                ],
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            );
                          },
                        ),
            ),

            _buildPaginationControls(_currentPage, totalPages, isFooter: true),
          ],
        );
      },
    );
  }
}
