import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/hr/screens/attendance_screen.dart' as s_link_attendance;
import 'package:s_link/features/dashboard/screens/requester_view.dart';
import 'package:s_link/features/dashboard/screens/driver_view.dart';
import 'package:s_link/features/settings/screens/driver_qr_screen.dart';

class EmployeeDashboard extends StatelessWidget {
  final bool isRequester;

  const EmployeeDashboard({super.key, required this.isRequester});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isRequester ? 'ส.บริการ (พนักงานหน้าร้าน)' : 'พนักงานหลังบ้าน'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
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
                  'เมนูหลัก (Main Menu)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    // การ์ด 1: จัดการงานประจำวัน
                    _buildMenuCard(
                      context,
                      title: 'จัดการงาน',
                      subtitle: isRequester 
                          ? 'รอส่ง, ส่งแล้ว, ของหมด' 
                          : 'ส่งของ, รับเอง, เช็คของ',
                      icon: Icons.assignment,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => isRequester ? const RequesterView() : const DriverView()
                          ),
                        );
                      },
                    ),

                    // การ์ด 2: ลงชื่อเข้างาน
                    _buildMenuCard(
                      context,
                      title: 'ลงชื่อเข้างาน',
                      subtitle: 'สแกนนิ้วเข้า-ออกงาน',
                      icon: Icons.fingerprint,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const s_link_attendance.AttendanceScreen()
                          ),
                        );
                      },
                    ),

                    // การ์ด 3: QR รับเงิน (Driver เท่านั้น)
                    if (!isRequester)
                      _buildMenuCard(
                        context,
                        title: 'QR รับเงิน',
                        subtitle: 'เปิด QR PromptPay\nเก็บเงินปลายทาง',
                        icon: Icons.qr_code_2,
                        color: Colors.deepPurple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DriverQrScreen(),
                            ),
                          );
                        },
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

  Widget _buildMenuCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap
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
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: color),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
