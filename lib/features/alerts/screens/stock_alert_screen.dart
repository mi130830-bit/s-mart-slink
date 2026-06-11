import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/alerts/providers/alert_log_provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/alerts/widgets/pending_alerts_list.dart';
import 'package:s_link/features/alerts/widgets/shortage_logs_view.dart';

class StockAlertScreen extends StatefulWidget {
  final bool isEmbedded;
  const StockAlertScreen({super.key, this.isEmbedded = false});

  @override
  State<StockAlertScreen> createState() => _StockAlertScreenState();
}

class _StockAlertScreenState extends State<StockAlertScreen> {
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

  Future<void> _onSubmitPendingItems(List<String> items) async {
    try {
      final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
      final alertProvider = Provider.of<AlertLogProvider>(context, listen: false);
      final uid = authProvider.currentUser?.uid ?? 'unknown';

      final futures = items.map((item) => alertProvider.createAlert(item, uid));
      await Future.wait(futures);

      if (mounted) {
        SnackbarUtils.showLeft(context, 'แจ้งเตือน ${items.length} รายการเรียบร้อย!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'Error: $e', isError: true);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        PendingAlertsList(
          onSubmit: _onSubmitPendingItems,
        ),
        const Divider(height: 1, thickness: 1),
        const Expanded(
          child: ShortageLogsView(),
        ),
      ],
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
