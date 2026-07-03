// ไฟล์: lib/screens/master_data/driver_list_screen.dart

import 'package:flutter/material.dart';
import 'package:s_link/features/auth/services/user_service.dart';
import 'package:s_link/features/auth/models/user.dart';
import 'package:s_link/features/auth/models/user_role.dart';
import 'package:s_link/utils/snackbar_utils.dart';

class DriverListScreen extends StatefulWidget {
  const DriverListScreen({super.key});

  @override
  State<DriverListScreen> createState() => _DriverListScreenState();
}

class _DriverListScreenState extends State<DriverListScreen> {
  final UserService _userService = UserService();
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _userService.getAllUsers();
      setState(() {
        _users = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        SnackbarUtils.showLeft(context, 'โหลดข้อมูลพนักงานไม่สำเร็จ: $e', isError: true);
      }
    }
  }

  void _showEditUserDialog(BuildContext context, UserModel user) {
    final nameController = TextEditingController(text: user.name);
    UserRole selectedRole = user.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (sbCtx, setDialogState) => AlertDialog(
          title: const Text('แก้ไขข้อมูลพนักงาน'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'ตำแหน่ง (Role)'),
                items: UserRole.values.map((role) {
                  String label = role.name;
                  switch (role) {
                    case UserRole.admin:
                      label = 'Admin (ผู้ดูแลระบบ)';
                      break;
                    case UserRole.requester:
                      label = 'Requester (พนักงานหน้าร้าน)';
                      break;
                    case UserRole.driver:
                      label = 'Driver (พนักงานขับรถ)';
                      break;
                    case UserRole.hr:
                      label = 'HR (ฝ่ายบุคคล)';
                      break;
                    case UserRole.gasStation:
                      label = 'Gas Station (เด็กปั้ม)';
                      break;
                    case UserRole.pending:
                      label = 'Pending (รออนุมัติ)';
                      break;
                    case UserRole.unknown:
                      label = 'Unknown (ไม่ระบุ)';
                      break;
                  }
                  return DropdownMenuItem<UserRole>(
                    value: role,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedRole = val;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                try {
                  String roleStr = selectedRole.name;
                  if (selectedRole == UserRole.gasStation) {
                    roleStr = 'gas_station';
                  }
                  await _userService.updateUser(
                    user.uid,
                    nameController.text.trim(),
                    roleStr,
                  );
                  if (sbCtx.mounted) {
                    Navigator.pop(sbCtx);
                    _loadUsers();
                    SnackbarUtils.showLeft(sbCtx, 'บันทึกข้อมูลสำเร็จ');
                  }
                } catch (e) {
                  debugPrint('Error: $e');
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบพนักงาน'),
        content: Text('ต้องการลบพนักงาน "${user.name}" ออกจากระบบใช่ไหม?\nการลบนี้จะทำให้พนักงานไม่สามารถล็อกอินได้อีก และชื่อจะถูกนำออกจากฐานข้อมูล'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _userService.deleteUser(user.uid);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _loadUsers();
                  SnackbarUtils.showLeft(ctx, 'ลบพนักงานสำเร็จ');
                }
              } catch (e) {
                debugPrint('Error: $e');
              }
            },
            child: const Text('ลบพนักงาน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการข้อมูลพนักงาน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('ยังไม่มีข้อมูลพนักงาน'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (ctx, i) {
                    final user = _users[i];
                    String roleLabel = user.role.name;
                    IconData roleIcon = Icons.person;
                    Color roleColor = Colors.grey;

                    switch (user.role) {
                      case UserRole.admin:
                        roleLabel = 'Admin (ผู้ดูแลระบบ)';
                        roleIcon = Icons.admin_panel_settings;
                        roleColor = Colors.red;
                        break;
                      case UserRole.requester:
                        roleLabel = 'Requester (พนักงานหน้าร้าน)';
                        roleIcon = Icons.assignment_ind;
                        roleColor = Colors.orange;
                        break;
                      case UserRole.driver:
                        roleLabel = 'Driver (พนักงานขับรถ)';
                        roleIcon = Icons.local_shipping;
                        roleColor = Colors.blue;
                        break;
                      case UserRole.hr:
                        roleLabel = 'HR (ฝ่ายบุคคล)';
                        roleIcon = Icons.group;
                        roleColor = Colors.purple;
                        break;
                      case UserRole.gasStation:
                        roleLabel = 'Gas Station (เด็กปั้ม)';
                        roleIcon = Icons.local_gas_station;
                        roleColor = Colors.teal;
                        break;
                      case UserRole.pending:
                        roleLabel = 'Pending (รออนุมัติ)';
                        roleIcon = Icons.hourglass_empty;
                        roleColor = Colors.amber;
                        break;
                      default:
                        roleLabel = 'ไม่ระบุ';
                        roleIcon = Icons.person;
                        roleColor = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: roleColor.withValues(alpha: 0.2),
                          child: Icon(roleIcon, color: roleColor),
                        ),
                        title: Text(user.name),
                        subtitle: Text('สิทธิ์: $roleLabel\nUsername: ${user.email.replaceAll('@s-link.local', '')}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditUserDialog(context, user);
                            } else if (value == 'delete') {
                              _confirmDelete(context, user);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('แก้ไขข้อมูล'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('ลบพนักงาน'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
