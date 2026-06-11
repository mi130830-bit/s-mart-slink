import 'package:s_link/utils/snackbar_utils.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart' as csv_lib;
import 'package:s_link/features/admin/providers/export_provider.dart';
import 'package:s_link/features/jobs/providers/job_provider.dart';
import 'package:s_link/features/settings/screens/widgets/settings_shared_ui.dart';

class DataReportsSection extends StatelessWidget {
  final bool isAdmin;

  const DataReportsSection({super.key, required this.isAdmin});

  Future<void> _exportDataWithDateRange(BuildContext context, String reportName, String type) async {
    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange == null) return;
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('กำลังสร้างไฟล์ $reportName...')));

    final exportProvider = Provider.of<ExportProvider>(context, listen: false);

    try {
      final directory = await getTemporaryDirectory();
      String path;
      XFile xFile;

      if (type == 'excel') {
        final List<int>? bytes = await exportProvider.getDeliveryReportExcel(pickedRange.start, pickedRange.end);
        if (bytes == null) throw Exception('ไม่มีข้อมูลในช่วงเวลาที่เลือก');

        final fileName = '${reportName.replaceAll(' ', '_')}.xlsx';
        path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsBytes(bytes);
        xFile = XFile(path);
      } else {
        List<List<dynamic>> rawData;
        if (type == 'job_count') {
          rawData = await exportProvider.getJobCountReportData(pickedRange.start, pickedRange.end);
        } else if (type == 'absence') {
          rawData = await exportProvider.getAbsenceReportData(pickedRange.start, pickedRange.end);
        } else {
           throw Exception('Unknown export type');
        }

        if (rawData.length <= 1) throw Exception('ไม่มีข้อมูลในช่วงเวลาที่เลือก');

        String csvStr = csv_lib.csv.encoder.convert(rawData);
        final fileName = '${reportName.replaceAll(' ', '_')}.csv';
        path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsString('\uFEFF$csvStr', encoding: utf8);
        xFile = XFile(path);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await SharePlus.instance.share(
          ShareParams(
            files: [xFile],
            text: 'Export ข้อมูล: $reportName',
          ),
        );
      }
    } catch (e) {
      debugPrint('Export Error: $e');
      if (context.mounted) {
        SnackbarUtils.showLeft(context, '❌ Export Failed: $e', isError: true);
      }
    }
  }

  Future<void> _handleDeleteCompletedJobs(BuildContext context) async {
    if (!context.mounted) return;

    final jobProvider = Provider.of<JobProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ ยืนยันการล้างประวัติงาน'),
        content: const Text(
            'คุณแน่ใจหรือไม่ว่าต้องการลบงานที่เสร็จแล้วทั้งหมด?\n\n*โปรดตรวจสอบว่าได้ Export ข้อมูลออกมาแล้ว*'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('ยืนยันลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('กำลังดำเนินการลบ...')));

    try {
      final deletedCount = await jobProvider.deleteExportedCompletedJobs();

      if (context.mounted) {
        SnackbarUtils.showLeft(context, '✅ ล้างข้อมูลสำเร็จ: ลบไปแล้ว $deletedCount รายการ');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showLeft(context, '❌ Error: ลบไม่สำเร็จ ($e)', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const SizedBox.shrink();

    return Column(
      children: [
        SettingsSharedUI.buildSectionHeader('ข้อมูลและรายงาน (Data & Reports)'),
        Card(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              SettingsSharedUI.buildModernTile(
                icon: Icons.table_view,
                color: Colors.green,
                title: 'รายงานการจัดส่งแยกตามรถ (Excel)',
                onTap: () => _exportDataWithDateRange(context, 'Delivery Report', 'excel'),
              ),
              SettingsSharedUI.buildDivider(),
              SettingsSharedUI.buildModernTile(
                icon: Icons.bar_chart,
                color: Colors.indigo,
                title: 'รายงานสถิติผู้ดำเนินการ (CSV)',
                onTap: () => _exportDataWithDateRange(context, 'Job Count Stats', 'job_count'),
              ),
              SettingsSharedUI.buildDivider(),
              SettingsSharedUI.buildModernTile(
                icon: Icons.event_busy,
                color: Colors.red,
                title: 'รายงานประวัติการลา (CSV)',
                onTap: () => _exportDataWithDateRange(context, 'Absence Report', 'absence'),
              ),
              SettingsSharedUI.buildDivider(),
              SettingsSharedUI.buildModernTile(
                icon: Icons.delete_sweep,
                color: Colors.red,
                title: 'ล้างข้อมูลประวัติงานที่เสร็จแล้ว',
                subtitle: 'ระวัง! ข้อมูลจะหายถาวร',
                onTap: () => _handleDeleteCompletedJobs(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
