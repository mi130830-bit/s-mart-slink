import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:s_link/features/jobs/models/job.dart';

class EditJobDialog extends StatefulWidget {
  final Job job;
  final Future<void> Function(Map<String, dynamic>, List<File>) onSave;

  const EditJobDialog({
    super.key,
    required this.job,
    required this.onSave,
  });

  @override
  State<EditJobDialog> createState() => _EditJobDialogState();
}

class _EditJobDialogState extends State<EditJobDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _detailsCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _latCtrl;

  List<String> _currentImages = [];
  final List<File> _newImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final job = widget.job;
    _nameCtrl = TextEditingController(text: job.customer.name);
    _phoneCtrl = TextEditingController(text: job.customer.phoneNumber);
    _addressCtrl = TextEditingController(text: job.customer.address);
    _detailsCtrl = TextEditingController(text: job.details ?? '');
    _priceCtrl = TextEditingController(text: job.price?.toString() ?? '');
    _latCtrl = TextEditingController(
        text: job.destinationLocation != null
            ? '${job.destinationLocation!.latitude}, ${job.destinationLocation!.longitude}'
            : '');
    _currentImages = List.from(job.billImageUrls);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    _priceCtrl.dispose();
    _latCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage(
      imageQuality: 50,
      maxWidth: 800,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _newImages.addAll(pickedFiles.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    GeoPoint? newLoc;
    if (_latCtrl.text.isNotEmpty && _latCtrl.text.contains(',')) {
      try {
        final parts = _latCtrl.text.split(',');
        newLoc = GeoPoint(double.parse(parts[0].trim()), double.parse(parts[1].trim()));
      } catch (e) {/* ignore */}
    }

    final updates = {
      'customer': {
        'name': _nameCtrl.text,
        'phoneNumber': _phoneCtrl.text,
        'address': _addressCtrl.text,
      },
      'details': _detailsCtrl.text,
      'price': double.tryParse(_priceCtrl.text) ?? 0.0,
      'bill_image_urls': _currentImages,
      'items': [], // Clear items to fallback to details view
      if (newLoc != null) 'destination_location': newLoc,
    };

    try {
      await widget.onSave(updates, _newImages);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('แก้ไขรายละเอียดงาน'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อลูกค้า')),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์')),
            TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'ที่อยู่'), maxLines: 2),
            TextField(
              controller: _latCtrl,
              decoration: const InputDecoration(labelText: 'พิกัด GPS', hintText: '13.xxxx, 100.xxxx'),
            ),
            TextField(controller: _detailsCtrl, decoration: const InputDecoration(labelText: 'รายละเอียดงาน'), maxLines: 3),
            TextField(
              controller: _priceCtrl,
              decoration: const InputDecoration(labelText: 'ยอดเก็บเงิน (COD)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text('รูปภาพบิล / สินค้า:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._currentImages.map((url) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _currentImages.remove(url);
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )),
                ..._newImages.map((file) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _newImages.remove(file);
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )),
                InkWell(
                  onTap: _pickImages,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add_a_photo, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('บันทึก'),
        ),
      ],
    );
  }
}

Future<void> showEditJobDialog(
  BuildContext context,
  Job job,
  Future<void> Function(Map<String, dynamic>, List<File>) onSave,
) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => EditJobDialog(
      job: job,
      onSave: onSave,
    ),
  );
}
