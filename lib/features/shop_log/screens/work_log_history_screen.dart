// ไฟล์: lib/screens/shop_log/work_log_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:s_link/features/alerts/providers/alert_log_provider.dart';
import 'package:s_link/features/master_data/providers/master_data_provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/master_data/models/deliverer.dart';

class WorkLogHistoryScreen extends StatefulWidget {
  const WorkLogHistoryScreen({super.key});

  @override
  State<WorkLogHistoryScreen> createState() => _WorkLogHistoryScreenState();
}

class _WorkLogHistoryScreenState extends State<WorkLogHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final authProvider =
            Provider.of<AuthenticationProvider>(context, listen: false);
        final userRole = authProvider.currentUser?.role.name;

        Provider.of<AlertLogProvider>(context, listen: false)
            .startListeningToAlertsAndLogs(userRole);

        Provider.of<MasterDataProvider>(context, listen: false)
            .startListeningToMasterData();
      }
    });
  }

  // ✅ แก้ไข: ตัด parameter context ออก ใช้ context ของ State แทนเพื่อลดความสับสน
  Future<void> _confirmDelete(String logId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบประวัติการทำงานนี้ใช่ไหม?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // ถ้ากดเลิก หรือปิดไปก่อน
    if (confirm != true) return;

    // ✅ Check 1: เช็คว่าหน้าจอยังอยู่ไหม ก่อนเรียก Provider
    if (!mounted) return;

    try {
      await Provider.of<AlertLogProvider>(context, listen: false)
          .deleteWorkLog(logId);

      // ✅ Check 2: เช็คว่าหน้าจอยังอยู่ไหม หลัง await เสร็จ ก่อนแสดง SnackBar
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบรายการเรียบร้อย')),
      );
    } catch (e) {
      // ✅ Check 3: เช็คอีกรอบกรณี Error
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final isAdmin = authProvider.isUserAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติงานหลังบ้าน'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<AlertLogProvider, MasterDataProvider>(
        builder: (context, logProvider, masterProvider, child) {
          if (logProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = logProvider.allWorkLogs;

          if (logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('ไม่มีประวัติการทำงาน',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];

              final dateStr =
                  DateFormat('dd/MM/yyyy HH:mm').format(log.loggedAt);

              DelivererModel? deliverer;
              try {
                deliverer = masterProvider.deliverers.firstWhere(
                  (d) => d.id == log.delivererId,
                );
              } catch (_) {
                deliverer = null;
              }

              final delivererName = deliverer != null
                  ? deliverer.name
                  : 'ID: ${log.delivererId.substring(0, 5)}...';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: const Icon(Icons.build, color: Colors.purple),
                  ),
                  title: Text('วันที่: $dateStr'),
                  subtitle: Text('ผู้บันทึก: $delivererName'),
                  children: [
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('รายการที่ทำ:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...log.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                        child: Text('• ${item.description}')),
                                    Text('${item.quantity} ${item.unit}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )),
                          if (isAdmin) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                // ✅ ไม่ต้องส่ง context แล้ว เพราะใช้ของ State
                                onPressed: () => _confirmDelete(log.id),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                label: const Text('ลบรายการนี้',
                                    style: TextStyle(color: Colors.red)),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
