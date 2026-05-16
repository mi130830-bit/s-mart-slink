import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:s_link/features/jobs/models/job.dart';

class JobExportService {
  /// Export jobs to an Excel file, grouping them by Driver/Vehicle into separate sheets.
  static Future<void> exportJobsToExcel(
      List<Job> jobs, DateTime startDate, DateTime endDate) async {
    if (jobs.isEmpty) {
      throw Exception('ไม่มีข้อมูลงานในช่วงเวลาที่เลือก');
    }

    var excel = Excel.createExcel();
    // ลบ default sheet 'Sheet1' ออกทีหลัง (ถ้าไม่ได้ใช้)
    bool hasAddedSheet = false;

    // 1. Group jobs
    // สร้างกลุ่มตามชื่อคนขับ/รถ
    Map<String, List<Job>> groupedJobs = {};

    for (var job in jobs) {
      // ดึงชื่อคนขับ หรือ รถ
      String groupName = 'ไม่ระบุคนขับ';
      if (job.isDepartureApproved && job.deliveryTeam.isNotEmpty) {
        // หาคนขับ
        DeliveryTeamItem? driver;
        try {
          driver = job.deliveryTeam.firstWhere((e) => e.type == 'driver');
        } catch (_) {}
        
        // หารถ
        DeliveryTeamItem? car;
        try {
          car = job.deliveryTeam.firstWhere((e) => e.type == 'car');
        } catch (_) {}

        if (driver != null && car != null) {
          groupName = '${driver.name} (${car.name})';
        } else if (driver != null) {
          groupName = driver.name;
        } else if (car != null) {
          groupName = car.name;
        }
      }

      // นำชื่อกลุ่มมาใช้เป็นชื่อ Sheet, โดยจำกัดความยาว (Excel Sheet Name Max 31 chars)
      String sheetName = groupName.replaceAll(RegExp(r'[\\/*?\[\]]'), '_');
      if (sheetName.length > 31) {
        sheetName = sheetName.substring(0, 31);
      }

      if (!groupedJobs.containsKey(sheetName)) {
        groupedJobs[sheetName] = [];
      }
      groupedJobs[sheetName]!.add(job);
    }

    // 2. สร้าง Sheet และเติมข้อมูล
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    for (var entry in groupedJobs.entries) {
      String sheetName = entry.key;
      List<Job> sheetJobs = entry.value;

      Sheet sheet = excel[sheetName];
      hasAddedSheet = true;

      // หัวตาราง
      sheet.appendRow([
        TextCellValue('วันที่'),
        TextCellValue('ลูกค้า'),
        TextCellValue('สถานที่ส่ง'),
        TextCellValue('เบอร์โทร'),
        TextCellValue('คนขับ/รถ'),
        TextCellValue('ยอดเงิน'),
        TextCellValue('Google Maps ลิงก์'),
      ]);

      // ข้อมูล
      for (var job in sheetJobs) {
        final dateStr = dateFormat.format(job.createdAt);
        final customerName = job.customer.name;
        final address = job.customer.address;
        final phone = job.customer.phoneNumber;
        
        // หาชื่อคนขับ (แสดงในคอลัมน์)
        String driverLabel = 'ไม่ระบุ';
        if (job.deliveryTeam.isNotEmpty) {
           driverLabel = job.deliveryTeam.map((e) => e.name).join(', ');
        }
        
        // ยอดเงิน
        final priceStr = job.price != null ? job.price.toString() : '0.0';

        // พิกัด (Google Maps URL)
        String mapLink = '-';
        if (job.destinationLocation != null) {
          final lat = job.destinationLocation!.latitude;
          final lng = job.destinationLocation!.longitude;
          mapLink = 'https://maps.google.com/?q=$lat,$lng';
        }

        sheet.appendRow([
          TextCellValue(dateStr),
          TextCellValue(customerName),
          TextCellValue(address),
          TextCellValue(phone),
          TextCellValue(driverLabel),
          TextCellValue(priceStr),
          TextCellValue(mapLink), // Excel package sometimes supports formula, but text is safer for mobile opening
        ]);
      }
    }

    // ลบ Sheet1 เริ่มต้น
    if (hasAddedSheet && excel.tables.containsKey('Sheet1') && groupedJobs.keys.first != 'Sheet1') {
      excel.delete('Sheet1');
    }

    // 3. บันทึกและแชร์ไฟล์
    final dateFmt = DateFormat('yyMMdd_HHmm');
    final fileName = 'DeliveryReport_${dateFmt.format(DateTime.now())}.xlsx';
    
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    
    final bytes = excel.encode()!;
    await file.writeAsBytes(bytes);

    // แชร์ไฟล์ (เลี่ยง warning deprecation ไปก่อนเพราะ SharePlus API ใหม่ยังอยู่ในช่วงเปลี่ยนผ่าน)
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'รายงานการส่งของ ${DateFormat('dd/MM/yyyy').format(startDate)} ถึง ${DateFormat('dd/MM/yyyy').format(endDate)}',
    );
  }
}
