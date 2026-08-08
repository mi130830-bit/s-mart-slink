import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';

// Import Screens
import 'package:s_link/features/pos/screens/shop_menu_screen.dart';
import 'package:s_link/features/jobs/screens/admin_job_list_screen.dart';
import 'package:s_link/features/dashboard/screens/requester_view.dart';
import 'package:s_link/features/dashboard/screens/driver_view.dart';
import 'package:s_link/features/hr/screens/attendance_screen.dart'
    as s_link_attendance;
import 'package:s_link/features/settings/screens/driver_qr_screen.dart';
import 'package:s_link/features/alerts/screens/stock_alert_screen.dart';
import 'package:s_link/features/shop_log/screens/work_log_history_screen.dart';
import 'package:s_link/features/admin/screens/driver_stats_screen.dart';
import 'package:s_link/features/admin/screens/admin_leave_management_screen.dart';
import 'package:s_link/features/hr/screens/hr_override_attendance_screen.dart';
import 'package:s_link/features/hr/screens/hr_advance_money_screen.dart';
import 'package:s_link/features/settings/screens/settings_screen.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final user = authProvider.currentUser;
    final roleName = user?.role.name.toLowerCase() ?? '';

    // เช็คสิทธิ์ต่างๆ
    final isAdmin = roleName == 'admin';
    final isHr = roleName == 'hr';
    final isRequester = roleName == 'requester';
    final isDriver = roleName == 'driver';

    return Scaffold(
      appBar: AppBar(
        title: const Text('แผงควบคุม (Management Console)'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: () => authProvider.logout(),
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'ออกจากระบบ',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'เมนูหลัก (Main Menu)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    // 1. หน้าร้าน (Shop)
                    if (isAdmin || isHr || isRequester)
                      _buildMenuCard(
                        context,
                        title: 'หน้าร้าน (Shop)',
                        icon: Icons.storefront,
                        color: Colors.deepOrange,
                        onTap: () =>
                            _navigateTo(context, const ShopMenuScreen()),
                      ),

                    // 2. จัดการงานจัดส่ง (Logistics)
                    if (isAdmin || isHr || isRequester || isDriver)
                      _buildMenuCard(
                        context,
                        title: 'จัดการงานจัดส่ง',
                        subtitle: isRequester
                            ? 'รอส่ง, ส่งแล้ว, ของหมด'
                            : (isDriver ? 'ส่งของ, รับเอง, เช็คของ' : null),
                        icon: Icons.local_shipping,
                        color: Colors.indigo,
                        onTap: () {
                          if (isAdmin || isHr) {
                            _navigateTo(context, const AdminJobListScreen());
                          } else if (isRequester) {
                            _navigateTo(context, const RequesterView());
                          } else if (isDriver) {
                            _navigateTo(context, const DriverView());
                          }
                        },
                      ),

                    // 3. ลงเวลาเข้างาน (Attendance)
                    if (isAdmin || isHr || isRequester || isDriver)
                      _buildMenuCard(
                        context,
                        title: 'ลงเวลาเข้างาน',
                        icon: Icons.fingerprint,
                        color: Colors.teal,
                        onTap: () => _navigateTo(context,
                            const s_link_attendance.AttendanceScreen()),
                      ),

                    // 4. QR รับเงิน (Receive Money)
                    if (isDriver)
                      _buildMenuCard(
                        context,
                        title: 'QR รับเงิน',
                        icon: Icons.qr_code_2,
                        color: Colors.deepPurple,
                        onTap: () =>
                            _navigateTo(context, const DriverQrScreen()),
                      ),

                    // 5. สินค้าใกล้หมดสต็อก (Stock Alerts)
                    if (authProvider.canManageStockAlerts)
                      _buildMenuCard(
                        context,
                        title: 'สินค้าใกล้หมดสต็อก',
                        icon: Icons.warning_amber_rounded,
                        color: Colors.red,
                        onTap: () =>
                            _navigateTo(context, const StockAlertScreen()),
                      ),

                    // 6. ประวัติงานร้าน (Shop Work Logs)
                    if (isAdmin)
                      _buildMenuCard(
                        context,
                        title: 'ประวัติงานร้าน',
                        icon: Icons.cleaning_services,
                        color: Colors.purple,
                        onTap: () =>
                            _navigateTo(context, const WorkLogHistoryScreen()),
                      ),

                    // 7. สถิติคนขับ (Driver Stats)
                    if (isAdmin)
                      _buildMenuCard(
                        context,
                        title: 'สถิติคนขับ',
                        icon: Icons.bar_chart,
                        color: Colors.blueAccent,
                        onTap: () =>
                            _navigateTo(context, const DriverStatsScreen()),
                      ),

                    // 8. อนุมัติวันลา (Manage Leave)
                    if (isAdmin || isHr)
                      _buildMenuCard(
                        context,
                        title: 'อนุมัติวันลา',
                        icon: Icons.fact_check,
                        color: Colors.blue,
                        onTap: () => _navigateTo(
                            context, const AdminLeaveManagementScreen()),
                      ),

                    // 9. เข้างานแทน (Override Attendance)
                    if (isAdmin || isHr)
                      _buildMenuCard(
                        context,
                        title: 'เข้างานแทน',
                        icon: Icons.co_present,
                        color: Colors.orange,
                        onTap: () => _navigateTo(
                            context, const HrOverrideAttendanceScreen()),
                      ),

                    // 10. เบิกเงินและอนุมัติ (Advance Money)
                    if (isAdmin || isHr)
                      _buildMenuCard(
                        context,
                        title: 'เบิกเงินและอนุมัติ',
                        icon: Icons.request_quote,
                        color: Colors.green,
                        onTap: () =>
                            _navigateTo(context, const HrAdvanceMoneyScreen()),
                      ),

                    // 11. ตั้งค่า (Settings)
                    if (isAdmin)
                      _buildMenuCard(
                        context,
                        title: 'ตั้งค่า (Settings)',
                        icon: Icons.settings,
                        color: Colors.grey.shade700,
                        onTap: () =>
                            _navigateTo(context, const SettingsScreen()),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.2),
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: color, width: 4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
