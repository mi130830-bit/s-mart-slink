import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';

// Import Screens
import 'package:s_link/features/admin/screens/admin_leave_management_screen.dart';
import 'package:s_link/features/jobs/screens/admin_job_list_screen.dart';
import 'package:s_link/features/hr/screens/attendance_screen.dart' as s_link_attendance;
import 'hr_override_attendance_screen.dart';
import 'hr_advance_money_screen.dart';
import 'package:s_link/features/pos/screens/shop_menu_screen.dart';

class HrDashboard extends StatelessWidget {
  const HrDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ระบบจัดการบุคคล (HR)'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthenticationProvider>().logout();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เมนูจัดการบุคคล',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildMenuCard(
                    context,
                    title: 'ตรวจสอบ\nวันมาวันลา',
                    icon: Icons.fact_check,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLeaveManagementScreen()));
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'ลงเวลา\nเข้างานตัวเอง',
                    icon: Icons.fingerprint,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const s_link_attendance.AttendanceScreen()));
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'เข้างานแทน',
                    icon: Icons.co_present,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HrOverrideAttendanceScreen()));
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'ทำเรื่องเบิกเงิน\nและอนุมัติ',
                    icon: Icons.request_quote,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HrAdvanceMoneyScreen()));
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'รายการงานจัดส่ง\n(ตรวจสอบ/ปล่อยรถ)',
                    icon: Icons.local_shipping,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminJobListScreen()));
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'หน้าร้าน (Shop)',
                    icon: Icons.storefront,
                    color: Colors.deepOrange,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopMenuScreen()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {
    required String title,
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
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
