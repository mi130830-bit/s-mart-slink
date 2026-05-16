// ไฟล์: lib/screens/master_data/car_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/master_data/providers/master_data_provider.dart';
import 'package:s_link/features/master_data/models/car.dart';

class CarListScreen extends StatefulWidget {
  const CarListScreen({super.key});

  @override
  State<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends State<CarListScreen> {
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

  void _showCarDialog(BuildContext context, {CarModel? car}) {
    final isEditing = car != null;
    final nameController =
        TextEditingController(text: isEditing ? car.name : '');
    final plateController =
        TextEditingController(text: isEditing ? car.licensePlate : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'แก้ไขข้อมูลรถ' : 'เพิ่มรถใหม่'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'ชื่อรถ/ยี่ห้อ')),
            TextField(
                controller: plateController,
                decoration: const InputDecoration(labelText: 'ทะเบียน')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  plateController.text.isNotEmpty) {
                final provider =
                    Provider.of<MasterDataProvider>(context, listen: false);
                if (isEditing) {
                  await provider.updateCar(car.id, nameController.text.trim(),
                      plateController.text.trim());
                } else {
                  await provider.addCar(
                      nameController.text.trim(), plateController.text.trim());
                }
                if (ctx.mounted) Navigator.pop(ctx);
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
        content: Text('ต้องการลบรถ "$name" ใช่ไหม?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await Provider.of<MasterDataProvider>(context, listen: false)
                  .deleteCar(id);
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
    final cars = provider.cars;

    return Scaffold(
      appBar: AppBar(title: const Text('จัดการข้อมูลรถ')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : cars.isEmpty
              ? const Center(child: Text('ยังไม่มีข้อมูล'))
              : ListView.builder(
                  itemCount: cars.length,
                  itemBuilder: (ctx, i) {
                    final car = cars[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.directions_car,
                                color: Colors.white)),
                        title: Text(car.name),
                        subtitle: Text(car.licensePlate),
                        trailing: PopupMenuButton(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showCarDialog(context, car: car);
                            } else if (value == 'delete') {
                              _confirmDelete(context, car.id, car.name);
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
        onPressed: () => _showCarDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
