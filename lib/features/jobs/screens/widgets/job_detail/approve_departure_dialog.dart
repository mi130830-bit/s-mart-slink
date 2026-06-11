import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:s_link/features/auth/models/user.dart';

class ApproveDepartureDialog extends StatefulWidget {
  final List<UserModel> availableStaff;
  final List<dynamic> vehicles;
  final List<String> initialDriverIds;
  final List<String> initialVehicleIds;
  final Function(List<String>, List<String>) onConfirm;

  const ApproveDepartureDialog({
    super.key,
    required this.availableStaff,
    required this.vehicles,
    required this.initialDriverIds,
    required this.initialVehicleIds,
    required this.onConfirm,
  });

  @override
  State<ApproveDepartureDialog> createState() => _ApproveDepartureDialogState();
}

class _ApproveDepartureDialogState extends State<ApproveDepartureDialog> {
  late List<String> _tempDriverIds;
  late List<String> _tempVehicleIds;

  @override
  void initState() {
    super.initState();
    _tempDriverIds = List.from(widget.initialDriverIds);
    _tempVehicleIds = List.from(widget.initialVehicleIds);
  }

  String _getNames(List<String> ids, List<dynamic> source) {
    if (ids.isEmpty) return 'ยังไม่ได้เลือก';
    final names = <String>[];
    for (var id in ids) {
      final found = source.firstWhereOrNull((e) {
        if (e is UserModel) return e.uid == id;
        try {
          return (e as dynamic).id == id;
        } catch (_) {
          return false;
        }
      });
      if (found != null) {
        names.add((found as dynamic).name);
      }
    }
    return names.join(', ');
  }

  Future<void> _showMultiSelectDialog({
    required String title,
    required List<dynamic> items,
    required List<String> selectedIds,
    required Function(List<String>) onConfirm,
  }) async {
    final List<String> tempSelected = List.from(selectedIds);
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: ListBody(
                children: items.map((item) {
                  final isSelected = tempSelected.contains(item.id ?? (item as UserModel).uid);
                  return CheckboxListTile(
                    value: isSelected,
                    title: Text(item.name),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (checked) {
                      setDialogState(() {
                        final itemId = item.id ?? (item as UserModel).uid;
                        if (checked == true) {
                          tempSelected.add(itemId);
                        } else {
                          tempSelected.remove(itemId);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
              ElevatedButton(
                onPressed: () {
                  onConfirm(tempSelected);
                  Navigator.pop(ctx);
                },
                child: const Text('ตกลง'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('อนุมัติปล่อยรถ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('กรุณาเลือก ทีมส่งของ และ รถ ที่จะออกไปส่งงานนี้', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            if (widget.availableStaff.isEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.orange.shade100,
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(child: Text('ไม่พบรายชื่อพนักงานในระบบ')),
                  ],
                ),
              ),
            const Text('ทีมส่งของ (Delivery Team)', style: TextStyle(fontWeight: FontWeight.bold)),
            InkWell(
              onTap: widget.availableStaff.isEmpty
                  ? null
                  : () async {
                      await _showMultiSelectDialog(
                        title: 'เลือกทีมส่งของ',
                        items: widget.availableStaff,
                        selectedIds: _tempDriverIds,
                        onConfirm: (val) {
                          setState(() => _tempDriverIds = val);
                        },
                      );
                    },
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.arrow_drop_down)),
                child: Text(_getNames(_tempDriverIds, widget.availableStaff)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('รถ / ยานพาหนะ', style: TextStyle(fontWeight: FontWeight.bold)),
            InkWell(
              onTap: () async {
                await _showMultiSelectDialog(
                  title: 'เลือกรถ',
                  items: widget.vehicles,
                  selectedIds: _tempVehicleIds,
                  onConfirm: (val) {
                    setState(() => _tempVehicleIds = val);
                  },
                );
              },
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.arrow_drop_down)),
                child: Text(_getNames(_tempVehicleIds, widget.vehicles)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_tempDriverIds.isEmpty) {
              SnackbarUtils.showLeft(context, 'กรุณาเลือกทีมงานอย่างน้อย 1 คน');
              return;
            }
            widget.onConfirm(_tempDriverIds, _tempVehicleIds);
          },
          child: const Text('ยืนยันและปล่อยรถ'),
        ),
      ],
    );
  }
}

Future<void> showApproveDepartureDialog({
  required BuildContext context,
  required List<UserModel> availableStaff,
  required List<dynamic> vehicles,
  required List<String> initialDriverIds,
  required List<String> initialVehicleIds,
  required Function(List<String>, List<String>) onConfirm,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ApproveDepartureDialog(
      availableStaff: availableStaff,
      vehicles: vehicles,
      initialDriverIds: initialDriverIds,
      initialVehicleIds: initialVehicleIds,
      onConfirm: (drivers, vehicles) {
        Navigator.pop(ctx);
        onConfirm(drivers, vehicles);
      },
    ),
  );
}
