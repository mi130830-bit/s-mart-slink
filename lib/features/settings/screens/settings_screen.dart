import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/core/providers/theme_provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/settings/screens/widgets/account_settings_section.dart';
import 'package:s_link/features/settings/screens/widgets/connection_settings_section.dart';
import 'package:s_link/features/settings/screens/widgets/data_reports_section.dart';
import 'package:s_link/features/settings/screens/widgets/pos_config_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
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
            AccountSettingsSection(
              user: user,
              isAdmin: isAdmin,
              isDriver: isDriver,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PosConfigSection(
                    isAdmin: isAdmin,
                    isDriver: isDriver,
                  ),
                  const ConnectionSettingsSection(),
                  const SizedBox(height: 24),
                  DataReportsSection(isAdmin: isAdmin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
