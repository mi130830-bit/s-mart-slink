// ไฟล์: lib/services/version_check_service.dart

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheckService {
  // ฟังก์ชันตรวจสอบเวอร์ชัน
  static Future<void> checkVersion(BuildContext context) async {
    try {
      // 1. ดึงข้อมูลเวอร์ชันปัจจุบันของเครื่อง
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 2. ดึงค่า config จาก Firestore
      DocumentSnapshot config = await FirebaseFirestore.instance
          .collection('config')
          .doc('mobile_app')
          .get();

      if (!config.exists) return;

      final data = config.data() as Map<String, dynamic>;

      // ✅ จุดที่แก้ไข: เพิ่มความปลอดภัยในการแปลงค่า (Safe Parsing)
      // ป้องกัน Error กรณี Firestore เก็บค่าเป็น String ("12") หรือ Number (12)
      int minBuild = 0;
      var minBuildData = data['min_required_build_number'];

      if (minBuildData is int) {
        minBuild = minBuildData;
      } else if (minBuildData is String) {
        minBuild = int.tryParse(minBuildData) ?? 0;
      }

      String androidUrl = data['play_store_url'] ?? '';

      // 3. เปรียบเทียบ: ถ้าเวอร์ชันเครื่อง ต่ำกว่า ขั้นต่ำ -> บังคับอัปเดต
      if (currentBuild < minBuild) {
        if (context.mounted) {
          _showForceUpdateDialog(context, androidUrl);
        }
      }
    } catch (e) {
      debugPrint('Version check failed: $e');
    }
  }

  static void _showForceUpdateDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false, // ห้ามกดปิดที่ว่าง
      builder: (context) => PopScope(
        canPop: false, // ห้ามกดปุ่ม Back ของเครื่อง
        child: AlertDialog(
          title: const Text('มีการอัปเดตใหม่ 🚀'),
          content: const Text(
              'เวอร์ชันที่คุณใช้งานอยู่เก่าเกินไป กรุณาอัปเดตแอปพลิเคชันเพื่อการใช้งานที่สมบูรณ์และแก้ไขข้อผิดพลาด'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // เปิด Play Store
                if (url.isNotEmpty) {
                  launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('อัปเดตทันที'),
            ),
          ],
        ),
      ),
    );
  }
}
