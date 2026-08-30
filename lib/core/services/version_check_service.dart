// ไฟล์: lib/core/services/version_check_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:s_link/features/auth/models/user_role.dart';

class VersionCheckService {
  /// ฟังก์ชันตรวจสอบเวอร์ชันแบบแยกตามบทบาท (Role-Aware Update)
  static Future<void> checkVersion(
    BuildContext context, {
    UserRole? role,
  }) async {
    try {
      // 1. ดึงข้อมูลเวอร์ชันปัจจุบันของเครื่อง
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 2. ดึงค่า config จาก Firestore (ตรวจสอบทั้ง config/mobile_app และ app_settings/version_control)
      Map<String, dynamic> data = {};
      try {
        final configDoc = await FirebaseFirestore.instance
            .collection('config')
            .doc('mobile_app')
            .get();
        if (configDoc.exists && configDoc.data() != null) {
          data = configDoc.data()!;
        } else {
          final settingsDoc = await FirebaseFirestore.instance
              .collection('app_settings')
              .doc('version_control')
              .get();
          if (settingsDoc.exists && settingsDoc.data() != null) {
            data = settingsDoc.data()!;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching version config: $e');
      }

      // 3. คำนวณเวอร์ชันขั้นต่ำเฉพาะของ Role นั้นๆ (ค่า Default: Driver/Requester=119, Admin=120)
      final fallbackMin = _parseInt(data['min_required_build_number']) ?? 119;
      int minBuild = fallbackMin;
      final bool forceUpdateAll = data['force_update_all'] == true;

      if (role != null) {
        switch (role) {
          case UserRole.driver:
            minBuild = _parseInt(data['min_driver_version']) ??
                _parseInt(data['min_driver_build_number']) ??
                119;
            break;
          case UserRole.requester:
            minBuild = _parseInt(data['min_requester_version']) ??
                _parseInt(data['min_requester_build_number']) ??
                121;
            break;
          case UserRole.admin:
            minBuild = _parseInt(data['min_admin_version']) ??
                _parseInt(data['min_admin_build_number']) ??
                121;
            break;
          case UserRole.gasStation:
            minBuild = _parseInt(data['min_gas_station_version']) ?? 119;
            break;
          case UserRole.hr:
            minBuild = _parseInt(data['min_hr_version']) ?? 119;
            break;
          default:
            minBuild = fallbackMin;
        }
      }

      final String androidUrl = data['play_store_url']?.toString() ?? '';
      final bool isBelowMin = currentBuild < minBuild || forceUpdateAll;

      debugPrint(
          '🔍 [VersionCheck] Role: ${role?.name}, Current Build: $currentBuild, Required Min: $minBuild, IsBelowMin: $isBelowMin');

      // 4. การจัดการอัปเดตผ่าน Google Play InAppUpdate บน Android
      if (!kDebugMode && Platform.isAndroid) {
        try {
          final info = await InAppUpdate.checkForUpdate();
          if (info.updateAvailability == UpdateAvailability.updateAvailable) {
            if (isBelowMin && info.immediateUpdateAllowed) {
              // บังคับอัปเดตทันที เฉพาะคนที่เวอร์ชันต่ำกว่าเกณฑ์ของ Role ตนเอง
              debugPrint('🚀 Triggering Immediate Update for ${role?.name}');
              await InAppUpdate.performImmediateUpdate();
              return;
            } else if (info.flexibleUpdateAllowed) {
              // ถ้ายังไม่ถึงเกณฑ์บังคับ ให้ดาวน์โหลดเบื้องหลังแบบไม่ขัดจังหวะการทำงาน
              debugPrint('📦 Starting Flexible Update in background');
              await InAppUpdate.startFlexibleUpdate();
              return;
            }
          }
        } catch (e) {
          debugPrint('⚠️ InAppUpdate check failed: $e');
        }
      }

      // 5. Fallback Dialog สำหรับเครื่องที่ไม่ได้ลงผ่าน Play InAppUpdate หรือกรณีจำเป็น
      if (isBelowMin && androidUrl.isNotEmpty && context.mounted) {
        _showForceUpdateDialog(context, androidUrl);
      }
    } catch (e) {
      debugPrint('❌ Version check failed: $e');
    }
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
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
              'เวอร์ชันที่คุณใช้งานอยู่จำเป็นต้องได้รับการอัปเดต กรุณาอัปเดตแอปพลิเคชันเพื่อการใช้งานที่ถูกต้องและราบรื่น'),
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
