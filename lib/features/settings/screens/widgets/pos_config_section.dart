import 'package:flutter/material.dart';
import 'package:s_link/features/admin/screens/user_approval_screen.dart';
import 'package:s_link/features/master_data/screens/car_list_screen.dart';
import 'package:s_link/features/master_data/screens/driver_list_screen.dart';
import 'package:s_link/features/settings/screens/pos_config_screen.dart';
import 'package:s_link/features/settings/screens/widgets/settings_shared_ui.dart';

class PosConfigSection extends StatelessWidget {
  final bool isAdmin;
  final bool isDriver;

  const PosConfigSection({
    super.key,
    required this.isAdmin,
    required this.isDriver,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isAdmin) ...[
          SettingsSharedUI.buildSectionHeader('การจัดการระบบ (System Management)'),
          Card(
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SettingsSharedUI.buildModernTile(
                  icon: Icons.how_to_reg,
                  color: Colors.teal,
                  title: 'Approve Users',
                  subtitle: 'อนุมัติผู้ใช้งานใหม่',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserApprovalScreen()),
                  ),
                ),
                SettingsSharedUI.buildDivider(),
                SettingsSharedUI.buildModernTile(
                  icon: Icons.local_shipping,
                  color: Colors.orange,
                  title: 'Manage Cars',
                  subtitle: 'จัดการข้อมูลรถขนส่ง',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CarListScreen()),
                  ),
                ),
                SettingsSharedUI.buildDivider(),
                SettingsSharedUI.buildModernTile(
                  icon: Icons.person_pin_circle,
                  color: Colors.blue,
                  title: 'Manage Drivers',
                  subtitle: 'จัดการข้อมูลคนขับรถ',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DriverListScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (!isDriver) ...[
          SettingsSharedUI.buildSectionHeader('ตั้งค่าระบบ POS (POS Config)'),
          Card(
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SettingsSharedUI.buildModernTile(
              icon: Icons.cloud_sync,
              color: Colors.blueAccent,
              title: 'ตั้งค่าการเชื่อมต่อ (API)',
              subtitle: 'Cloudflare Tunnel URL',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PosConfigScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ]
      ],
    );
  }
}
