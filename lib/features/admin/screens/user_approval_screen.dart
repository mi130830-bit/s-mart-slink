// ไฟล์: lib/screens/admin/user_approval_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:s_link/features/auth/models/user.dart';
// import '../../models/user_role.dart'; // ถ้าจำเป็นต้องใช้ Enum

class UserApprovalScreen extends StatelessWidget {
  const UserApprovalScreen({super.key});

  // ฟังก์ชันอัปเดต Role (อนุมัติ)
  Future<void> _updateUserRole(
      BuildContext context, String uid, String newRole) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'role': newRole,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อนุมัติเรียบร้อย!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('อนุมัติพนักงานใหม่ (Pending)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query ดึงเฉพาะคนที่ role == 'pending'
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('ไม่มีรายการรออนุมัติ',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final user = UserModel.fromFirestore(docs[index]);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 40, color: Colors.teal),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                Text('Username: ${user.email.replaceAll('@s-link.local', '')}',
                                    style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('เลือกตำแหน่งเพื่ออนุมัติ:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateUserRole(context, user.uid, 'driver'),
                                  icon: const Icon(Icons.local_shipping),
                                  label: const Text('Driver'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _updateUserRole(
                                      context, user.uid, 'requester'),
                                  icon: const Icon(Icons.assignment_ind),
                                  label: const Text('Requester'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateUserRole(context, user.uid, 'hr'),
                                  icon: const Icon(Icons.group),
                                  label: const Text('HR'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _updateUserRole(
                                      context, user.uid, 'gas_station'),
                                  icon: const Icon(Icons.local_gas_station),
                                  label: const Text('Gas Station'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _updateUserRole(
                                      context, user.uid, 'admin'),
                                  icon: const Icon(Icons.admin_panel_settings),
                                  label: const Text('Admin (ผู้ดูแลระบบ)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
