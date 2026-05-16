// ไฟล์: lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:s_link/core/config/app_constants.dart';
import 'package:s_link/core/services/startup_service.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/core/providers/theme_provider.dart';
import 'package:s_link/features/admin/providers/export_provider.dart';
import 'package:s_link/features/jobs/providers/job_provider.dart';
import 'package:s_link/features/settings/screens/pos_config_screen.dart';
import 'package:s_link/features/admin/screens/user_approval_screen.dart';
import 'package:s_link/features/master_data/screens/driver_list_screen.dart';
import 'package:s_link/features/master_data/screens/car_list_screen.dart';
//import 'package:s_link/features/settings/screens/printer_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ------------------------------------------------------------------
  // UI HANDLERS & LOGIC
  // ------------------------------------------------------------------

  void _showEditNameDialog(
      BuildContext context, String currentName, String uid) {
    final nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขชื่อแสดงผล'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'ชื่อใหม่'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  final newName = nameController.text.trim();
                  final batch = FirebaseFirestore.instance.batch();

                  final userRef =
                      FirebaseFirestore.instance.collection('users').doc(uid);
                  batch.update(userRef, {'name': newName});

                  final delivererRef = FirebaseFirestore.instance
                      .collection('deliverers')
                      .doc(uid);
                  batch.set(
                      delivererRef, {'name': newName}, SetOptions(merge: true));

                  await batch.commit();

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('บันทึกชื่อเรียบร้อย')),
                    );
                  }
                } catch (e) {
                  debugPrint('Error updating name: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('เกิดข้อผิดพลาด: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDataAndShareFile(
      BuildContext context,
      Future<List<List<dynamic>>> Function() dataFetcher,
      String reportName) async {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('กำลังสร้างไฟล์ $reportName...')));

    // ปิดการทำงานชั่วคราวเนื่องจากยังไม่ได้ติดตั้ง path_provider และ share_plus
    /*
    try {
      // 1. ดึงข้อมูล
      final List<List<dynamic>> rawData = await dataFetcher();

      // 2. แปลงเป็น CSV String
      String csv = const ListToCsvConverter().convert(rawData);

      // 3. หา Path ชั่วคราวในเครื่อง
      final directory = await getTemporaryDirectory();
      // ตั้งชื่อไฟล์ (ตัดช่องว่างออก)
      final fileName = '${reportName.replaceAll(' ', '_')}.csv';
      final path = '${directory.path}/$fileName';
      final file = File(path);

      // 4. เขียนไฟล์ (เติม \uFEFF เพื่อให้ Excel อ่านภาษาไทยออก)
      await file.writeAsString('\uFEFF$csv', encoding: utf8);

      // 5. แชร์ไฟล์ (Logic สำหรับ share_plus v12.0.1)
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // ✅ สร้าง object XFile จาก path
        final xFile = XFile(path);

        // ✅ เรียกใช้ Share.shareXFiles (คำสั่งมาตรฐานของ v12)
        // หมายเหตุ: ถ้า IDE ยังขีดเส้นใต้สีเหลือง (Deprecated) ให้ลองกดเมนู "Restart Analysis Server"
        // หรือ Flutter Clean ดูครับ เพราะโค้ดนี้ถูกต้องตาม Doc v12 แล้ว
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    */
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ฟีเจอร์ Export ถูกปิดใช้งานชั่วคราว')),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ล้างข้อมูลสำเร็จ: ลบไปแล้ว $deletedCount รายการ'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ลบไม่สำเร็จ ($e)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSoundPicker(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentSound =
        prefs.getString('notification_sound') ?? AppConstants.notificationSound;

    if (!context.mounted) return;

    final player = AudioPlayer();

    await showDialog(
      context: context,
      builder: (ctx) {
        String tempSelected = currentSound;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('เลือกเสียงแจ้งเตือน'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: AppConstants.availableSounds.length,
                  itemBuilder: (context, index) {
                    final sound = AppConstants.availableSounds[index];
                    return RadioListTile<String>(
                      title: Text(sound),
                      value: sound,
                      // ignore: deprecated_member_use
                      groupValue: tempSelected,
                      // ignore: deprecated_member_use
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => tempSelected = val);
                          // Play sound preview
                          try {
                            player.stop();
                            player.play(AssetSource('sounds/$val.mp3'));
                          } catch (e) {
                            debugPrint('Error playing sound: $e');
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    player.dispose();
                    Navigator.pop(ctx);
                  },
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    player
                        .dispose(); // Ensure dispose before async work or exit

                    await prefs.setString('notification_sound', tempSelected);
                    await StartupService
                        .setupNotificationChannel(); // Update Channel logic
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      // Force reload parent if needed, but snackbar is ok
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'บันทึกเสียง "$tempSelected" แล้ว (จะมีผลกับการแจ้งเตือนใหม่)')),
                      );
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Ensure player is disposed if dialog is dismissed via back button or tap outside
      try {
        player.dispose();
      } catch (e) {
        // Already disposed
      }
    });
  }

  // ------------------------------------------------------------------
  // UI BUILDER
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final exportProvider = Provider.of<ExportProvider>(context, listen: false);
    final user = authProvider.currentUser;

    // Determine Roles
    final isDriver = authProvider.isUserDriver;

    final isAdmin = authProvider.isUserAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('การตั้งค่า (Settings)'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'ออกจากระบบ',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('ยืนยัน'),
                  content: const Text('ต้องการออกจากระบบใช่หรือไม่?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('ยกเลิก')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        authProvider.logout();
                      },
                      child: const Text('ออกจากระบบ',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: themeProvider.isDarkMode ? null : Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Modern Header ---
            Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                            )
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          child: Text(
                            user?.name.substring(0, 1).toUpperCase() ?? 'U',
                            style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (user != null) {
                            _showEditNameDialog(context, user.name, user.uid);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit,
                              size: 20, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'User Name',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.teal.shade50,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- System Management (Admin) ---
                  if (isAdmin) ...[
                    _buildSectionHeader('การจัดการระบบ (System Management)'),
                    Card(
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          _buildModernTile(
                            icon: Icons.how_to_reg,
                            color: Colors.teal,
                            title: 'Approve Users',
                            subtitle: 'อนุมัติผู้ใช้งานใหม่',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const UserApprovalScreen())),
                          ),
                          _buildDivider(),
                          _buildModernTile(
                            icon: Icons.local_shipping,
                            color: Colors.orange,
                            title: 'Manage Cars',
                            subtitle: 'จัดการข้อมูลรถขนส่ง',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CarListScreen())),
                          ),
                          _buildDivider(),
                          _buildModernTile(
                            icon: Icons.person_pin_circle,
                            color: Colors.blue,
                            title: 'Manage Drivers',
                            subtitle: 'จัดการข้อมูลคนขับรถ',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const DriverListScreen())),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- General Settings ---
                  _buildSectionHeader('ทั่วไป (General)'),
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        // PromptPay ID Setting
                        FutureBuilder<String>(
                          future: SharedPreferences.getInstance().then(
                              (prefs) => prefs.getString('promptpay_id') ?? ''),
                          builder: (context, snapshot) {
                            final current = snapshot.data?.isNotEmpty == true
                                ? snapshot.data!
                                : 'ยังไม่ได้ตั้งค่า';
                            return _buildModernTile(
                              icon: Icons.qr_code,
                              color: Colors.purple,
                              title: 'PromptPay ID (สำหรับ QR รับเงิน)',
                              subtitle: current,
                              onTap: () {
                                final controller = TextEditingController(
                                    text: snapshot.data ?? '');
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('ตั้งค่า PromptPay ID'),
                                    content: TextField(
                                      controller: controller,
                                      decoration: const InputDecoration(
                                          labelText:
                                              'เบอร์โทรศัพท์ หรือ เลขบัตรประชาชน',
                                          hintText:
                                              '08xxxxxxxx หรือ 1xxxxxxxxxxxx'),
                                      keyboardType: TextInputType.number,
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('ยกเลิก')),
                                      ElevatedButton(
                                          onPressed: () async {
                                            final val = controller.text.trim();
                                            if (val.isNotEmpty) {
                                              final prefs =
                                                  await SharedPreferences
                                                      .getInstance();
                                              await prefs.setString(
                                                  'promptpay_id', val);
                                              // ignore: use_build_context_synchronously
                                              Navigator.pop(ctx);
                                              // ignore: use_build_context_synchronously
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'บันทึกเรียบร้อย')));
                                            }
                                          },
                                          child: const Text('บันทึก')),
                                    ],
                                  ),
                                ).then((_) {
                                  // Refresh UI
                                  (context as Element).markNeedsBuild();
                                });
                              },
                            );
                          },
                        ),
                        _buildDivider(),
                        FutureBuilder<String>(
                          future: SharedPreferences.getInstance().then(
                              (prefs) =>
                                  prefs.getString('pos_device_id') ?? ''),
                          builder: (context, snapshot) {
                            final current = snapshot.data?.isNotEmpty == true
                                ? snapshot.data!
                                : 'Auto (POS_MASTER)';
                            return _buildModernTile(
                              icon: Icons.monitor_weight_outlined,
                              color: Colors.blueGrey,
                              title: 'POS Device ID (จับคู่เครื่อง)',
                              subtitle: current,
                              onTap: () {
                                final controller =
                                    TextEditingController(text: snapshot.data);
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('ระบุรหัสเครื่อง POS'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: controller,
                                          decoration: const InputDecoration(
                                            labelText: 'Device UUID',
                                            hintText:
                                                'ว่าง = ส่งหาเครื่องหลัก (MASTER)',
                                            helperText:
                                                'ปล่อยว่างเพื่อใช้โหมดอัตโนมัติ',
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('ยกเลิก')),
                                      ElevatedButton(
                                          onPressed: () async {
                                            final val = controller.text.trim();
                                            final prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            if (val.isEmpty) {
                                              await prefs
                                                  .remove('pos_device_id');
                                            } else {
                                              await prefs.setString(
                                                  'pos_device_id', val);
                                            }
                                            // ignore: use_build_context_synchronously
                                            Navigator.pop(ctx);
                                            // ignore: use_build_context_synchronously
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'บันทึกเรียบร้อย')));
                                          },
                                          child: const Text('บันทึก')),
                                    ],
                                  ),
                                ).then((_) {
                                  (context as Element).markNeedsBuild();
                                });
                              },
                            );
                          },
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.dark_mode_outlined,
                                color: Colors.deepPurple),
                          ),
                          title: const Text('โหมดกลางคืน (Dark Mode)',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Switch(
                            value: themeProvider.isDarkMode,
                            activeThumbColor: Colors.teal,
                            onChanged: (value) {
                              themeProvider.toggleTheme(value);
                            },
                          ),
                        ),
                        _buildDivider(),
                        FutureBuilder<String>(
                          future: SharedPreferences.getInstance().then(
                              (prefs) =>
                                  prefs.getString('notification_sound') ??
                                  AppConstants.notificationSound),
                          builder: (context, snapshot) {
                            final current = snapshot.data ?? 'Loading...';
                            return _buildModernTile(
                              icon: Icons.notifications_active,
                              color: Colors.orange,
                              title: 'เสียงแจ้งเตือน',
                              subtitle: current,
                              onTap: () => _showSoundPicker(context),
                            );
                          },
                        ),
                        /* 
                        // ❌ Removed: ใช้ Remote Print แทน ไม่ต้องตั้งค่า Printer ในมือถือ
                        _buildDivider(),
                        _buildModernTile(
                          icon: Icons.print,
                          color: Colors.indigo,
                          title: 'ตั้งค่าเครื่องพิมพ์ (Printer)',
                          subtitle: 'เลือกเครื่องพิมพ์ใบเสร็จ/ใบส่งของ',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const PrinterSettingsScreen())),
                        ),
                        */
                        if (!isDriver) ...[
                          _buildDivider(),
                          _buildModernTile(
                            icon: Icons.cloud_sync,
                            color: Colors.blueAccent,
                            title: 'ตั้งค่าการเชื่อมต่อ (API)',
                            subtitle: 'Cloudflare Tunnel URL',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PosConfigScreen())),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Data & Reports (Admin) ---
                  if (isAdmin) ...[
                    _buildSectionHeader('ข้อมูลและรายงาน (Data & Reports)'),
                    Card(
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          _buildModernTile(
                            icon: Icons.bar_chart,
                            color: Colors.indigo,
                            title: 'รายงานสถิติผู้ดำเนินการ',
                            onTap: () => _exportDataAndShareFile(
                                context,
                                exportProvider.getJobCountReportData,
                                'Job Count Stats'),
                          ),
                          _buildDivider(),
                          _buildModernTile(
                            icon: Icons.event_busy,
                            color: Colors.red,
                            title: 'รายงานประวัติการลา',
                            onTap: () => _exportDataAndShareFile(
                                context,
                                exportProvider.getAbsenceReportData,
                                'Absence Report'),
                          ),
                          _buildDivider(),
                          _buildModernTile(
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

                  // Version Info
                  const Center(
                    child: Text(
                      'Version 2.0.0',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildModernTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: Colors.grey.shade600))
          : null,
      trailing:
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
    );
  }

  Widget _buildDivider() {
    return Divider(
        height: 1, indent: 70, endIndent: 20, color: Colors.grey.shade100);
  }
}
