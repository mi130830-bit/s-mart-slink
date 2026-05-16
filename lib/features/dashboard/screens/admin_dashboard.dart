// ไฟล์: lib/screens/dashboard/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';

// Import หน้าจอต่างๆ
import 'package:s_link/features/jobs/screens/admin_job_list_screen.dart';
import 'package:s_link/features/alerts/screens/stock_alert_screen.dart';
import 'package:s_link/features/shop_log/screens/work_log_history_screen.dart';
import 'package:s_link/features/admin/screens/driver_stats_screen.dart';
// CreateJobScreen removed — สร้างงานจาก POS Desktop แทน
// ✅ [เพิ่ม] Import หน้าจอประวัติการลาหยุด
import 'package:s_link/features/admin/screens/admin_leave_management_screen.dart';

// ✅ เปลี่ยน Import Settings ไปที่โฟลเดอร์ config

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ส.บริการ (Admin)'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          // ปุ่ม Logout มุมขวาบน
          // ปุ่ม Logout มุมขวาบน (เหลือแค่รูปประตู)
          IconButton(
            onPressed: () => authProvider.logout(),
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'ออกจากระบบ',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Management Console',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Grid เมนู
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    // 1. Stock Alerts
                    _buildMenuCard(
                      context,
                      title: 'Stock Alerts',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StockAlertScreen())),
                    ),

                    // 2. Shop Work Logs
                    _buildMenuCard(
                      context,
                      title: 'Shop Work Logs',
                      icon: Icons.cleaning_services,
                      color: Colors.purple,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WorkLogHistoryScreen())),
                    ),

                    // 3. All Jobs
                    _buildMenuCard(
                      context,
                      title: 'All Jobs',
                      icon: Icons.assignment,
                      color: Colors.green,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminJobListScreen())),
                    ),

                    // 4. Driver Stats
                    _buildMenuCard(
                      context,
                      title: 'Driver Stats',
                      icon: Icons.bar_chart,
                      color: Colors.indigo,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DriverStatsScreen())),
                    ),

                    // 8. Manage Leave (Driver & Requester)
                    _buildMenuCard(
                      context,
                      title: 'Manage Leave',
                      icon: Icons.timelapse, // Icon นาฬิกาหรือปฏิทินบ่งบอกเวลา
                      color: Colors.pink,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AdminLeaveManagementScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 80), // เว้นที่ให้ FAB
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              // 🛠️ แก้ไข: เปลี่ยน color.withOpacity(0.2) เป็น color.withValues(alpha: 0.2)
              backgroundColor: color.withValues(alpha: 0.2),
              radius: 30,
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
