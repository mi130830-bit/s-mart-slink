// ไฟล์: lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลส่วนตัว')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              user.email,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(user.role.name.toUpperCase()),
              backgroundColor: Colors.blue.shade50,
              labelStyle: const TextStyle(
                  color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // Menu List
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('ตั้งค่า (Coming Soon)'),
              onTap: () {},
            ),
            const Divider(),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await authProvider.logout();
                  // Main.dart จะเด้งไปหน้า Login เองอัตโนมัติ
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout),
                label: const Text('ออกจากระบบ'),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Version 1.0.0 (S-Link OpsMate)',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
