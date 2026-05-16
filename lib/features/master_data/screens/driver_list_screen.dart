// ไฟล์: lib/screens/master_data/driver_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/master_data/providers/master_data_provider.dart';
import 'package:s_link/features/master_data/models/deliverer.dart';

class DriverListScreen extends StatefulWidget {
  const DriverListScreen({super.key});

  @override
  State<DriverListScreen> createState() => _DriverListScreenState();
}

class _DriverListScreenState extends State<DriverListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        Provider.of<MasterDataProvider>(context, listen: false)
            .startListeningToMasterData();
      }
    });
  }

  // ฟังก์ชันแสดง Dialog สำหรับเพิ่ม หรือ แก้ไข
  void _showDriverDialog(BuildContext context, {DelivererModel? driver}) {
    final isEditing = driver != null;
    final nameController =
        TextEditingController(text: isEditing ? driver.name : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'แก้ไขข้อมูล' : 'เพิ่มคนขับใหม่'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final provider =
                    Provider.of<MasterDataProvider>(context, listen: false);
                try {
                  if (isEditing) {
                    await provider.updateDeliverer(
                        driver.id, nameController.text.trim());
                  } else {
                    await provider.addDeliverer(nameController.text.trim());
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  debugPrint('Error: $e');
                }
              }
            },
            child: Text(isEditing ? 'บันทึก' : 'เพิ่ม'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ "$name" ออกจากระบบใช่ไหม?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await Provider.of<MasterDataProvider>(context, listen: false)
                  .deleteDeliverer(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MasterDataProvider>(context);
    final drivers = provider.deliverers;

    return Scaffold(
      appBar: AppBar(title: const Text('จัดการข้อมูลคนขับ')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : drivers.isEmpty
              ? const Center(child: Text('ยังไม่มีข้อมูล'))
              : ListView.builder(
                  itemCount: drivers.length,
                  itemBuilder: (ctx, i) {
                    final driver = drivers[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              driver.isActive ? Colors.green : Colors.grey,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(driver.name),
                        subtitle: Text(
                            driver.isActive ? 'สถานะ: ปกติ' : 'สถานะ: พักงาน'),
                        trailing: PopupMenuButton(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showDriverDialog(context, driver: driver);
                            } else if (value == 'delete') {
                              _confirmDelete(context, driver.id, driver.name);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('แก้ไข')
                                ])),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('ลบ')
                                ])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDriverDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
