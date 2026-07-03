import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/models/user.dart';
import 'package:s_link/features/auth/models/user_role.dart';
import 'package:s_link/features/auth/services/user_service.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';

class AccountSettingsSection extends StatelessWidget {
  final UserModel? user;
  final bool isAdmin;
  final bool isDriver;

  const AccountSettingsSection({
    super.key,
    required this.user,
    required this.isAdmin,
    required this.isDriver,
  });

  String _roleLabel({required bool isAdmin, required bool isDriver}) {
    if (user == null) return 'ไม่ทราบ (Unknown)';
    return switch (user!.role) {
      UserRole.admin     => 'ผู้ดูแลระบบ (Admin)',
      UserRole.driver    => 'คนขับรถ (Driver)',
      UserRole.requester => 'ผู้สั่งงาน (Requester)',
      UserRole.hr        => 'HR / ฝ่ายบุคคล',
      UserRole.gasStation => 'เด็กปั๊ม (Gas Station)',
      UserRole.pending   => 'รออนุมัติ (Pending)',
      UserRole.unknown   => 'ไม่ทราบ (Unknown)',
    };
  }
  void _showEditNameDialog(BuildContext context, String currentName, String uid) {
    final nameController = TextEditingController(text: currentName);
    final userService = UserService();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขชื่อแสดงผล'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'ชื่อใหม่'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                try {
                  // ✅ ใช้ UserService เพื่ออัปเดตชื่อ (Sync users + deliverers พร้อมกัน)
                  await userService.updateUser(
                    uid,
                    newName,
                    user?.role.name ?? 'pending',
                  );
                  if (!context.mounted) return;
                  // โป้ให้ AuthProvider refresh profile เพื่อ UI อัปเดตทันที
                  final auth = Provider.of<AuthenticationProvider>(context, listen: false);
                  await auth.refreshCurrentUser();
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  SnackbarUtils.showLeft(context, 'บันทึกชื่อเรียบร้อย');
                } catch (e) {
                  debugPrint('Error updating name: $e');
                  if (context.mounted) {
                    SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    _showEditNameDialog(context, user!.name, user!.uid);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 20, color: Colors.teal),
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
            user?.email ?? 'No Email',
            style: TextStyle(fontSize: 14, color: Colors.teal.shade100),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(isAdmin ? Icons.admin_panel_settings : Icons.person,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _roleLabel(isAdmin: isAdmin, isDriver: isDriver),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('ออนไลน์',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
