// ไฟล์: lib/screens/jobs/complete_job_form.dart

import 'package:s_link/utils/snackbar_utils.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/jobs/providers/job_provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/master_data/providers/master_data_provider.dart';

import 'package:connectivity_plus/connectivity_plus.dart'; // ✅ Add
import 'package:s_link/features/pos/services/pos_api_service.dart';

class CompleteJobForm extends StatefulWidget {
  final Job job;
  const CompleteJobForm({super.key, required this.job});

  @override
  State<CompleteJobForm> createState() => _CompleteJobFormState();
}

class _CompleteJobFormState extends State<CompleteJobForm> {
  final List<File> _imageFiles = [];
  bool _isLoading = false;
  final _picker = ImagePicker();

  bool _updateCustomerLocation = true;
  bool _isCodCollected = false;
  final TextEditingController _codAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill COD amount if applicable (only for credit jobs)
    if (_isCodJob()) {
      _codAmountController.text = widget.job.price!.toStringAsFixed(2);
    }
  }

  bool _isCodJob() {
    // COD is only applicable if there is a price AND the payment method is 'credit' (or missing/empty for older jobs)
    final method = widget.job.paymentMethod?.trim().toLowerCase();
    return widget.job.price != null &&
        widget.job.price! > 0 &&
        (method == null || method.isEmpty || method == 'credit' || method == 'cod');
  }

  @override
  void dispose() {
    _codAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 30, // บีบอัดให้เล็กที่สุดเท่าที่จะพอดูรู้เรื่อง
        maxWidth: 600, // ลดขนาดความกว้างลงอีกเพื่อประหยัดพื้นที่
      );
      if (pickedFile != null) {
        setState(() {
          _imageFiles.clear();
          _imageFiles.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูป'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากอัลบั้ม'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _uploadProofImage() async {
    if (_imageFiles.isEmpty) return '';
    try {
      final file = _imageFiles.first;
      // ✅ Upload through our Notebook / POS Server API (api.namecheap.work) instead of Firebase Storage
      final proofUrl = await PosApiService().uploadProofImage(
        imageFile: file,
        jobId: widget.job.id,
      );

      if (proofUrl != null && proofUrl.isNotEmpty) {
        return proofUrl;
      }
      return '';
    } catch (e) {
      debugPrint('Error uploading image to notebook: $e');
      return '';
    }
  }

  Future<void> _getCurrentLocationAndSubmit() async {

    if (_isCodJob() && _isCodCollected) {
      final amount = double.tryParse(_codAmountController.text);
      if (amount == null || amount <= 0) {
        _showError('กรุณาระบุยอดเงิน COD ที่ถูกต้อง');
        return;
      }
    }

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'กรุณาเปิด GPS (Location Service) ก่อน';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'ต้องเปิด Location เพื่อยืนยันจุดส่งของ';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'สิทธิ์ Location ถูกปิดถาวร กรุณาไปที่ตั้งค่าเพื่อเปิดสิทธิ์';
      }

      // ลองหาพิกัดปัจจุบัน (รอ 10 วิ)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        // ถ้าหาไม่เจอ หรือ Timeout ให้ลองใช้พิกัดล่าสุดแทน (Fallback)
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        throw 'ไม่สามารถระบุตำแหน่งได้ กรุณาตรวจสอบ GPS หรือย้ายไปพื้นที่โล่ง';
      }

      GeoPoint proofLocation = GeoPoint(position.latitude, position.longitude);
      await _submitForm(proofLocation);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'ระบุพิกัดไม่สำเร็จ: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitForm(GeoPoint proofLocation) async {

    double? codAmount;
    if (_isCodJob() && _isCodCollected) {
      codAmount = double.tryParse(_codAmountController.text);
    }

    try {
      final authProvider =
          Provider.of<AuthenticationProvider>(context, listen: false);
      final jobProvider = Provider.of<JobProvider>(context, listen: false);
      final masterData =
          Provider.of<MasterDataProvider>(context, listen: false);

      // อัปเดตพิกัดลูกค้า
      if (_updateCustomerLocation && widget.job.customerId != null) {
        await masterData.updateCustomerLocation(
            widget.job.customerId!, proofLocation);
      }

      // เตรียมข้อมูลทีม (ใช้ข้อมูลเดิมจาก Job ที่อนุมัติมาแล้ว)
      List<Map<String, dynamic>> deliveryTeam =
          widget.job.deliveryTeam.map((e) => e.toJson()).toList();

      // ✅ Connectivity Check: If offline, don't upload image, just pass local path
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOffline =
          connectivityResult.contains(ConnectivityResult.none);

      String proofValue = '';
      if (_imageFiles.isNotEmpty) {
        if (isOffline) {
          // Use local path (first image in list)
          proofValue = _imageFiles.first.path;
          debugPrint('CompleteJobForm: Offline mode. Using local path for sync.');
        } else {
          // Upload image if online
          proofValue = await _uploadProofImage();
        }
      }

      // ส่งข้อมูลปิดงาน
      await jobProvider.completeJob(
        widget.job.id,
        authProvider.currentUser!.uid,
        proofValue,
        proofLocation,
        deliveryTeam,
        collectedCod: codAmount,
        customerId: widget.job.customerId,
        orderId: widget.job.localOrderId,
      );



      if (mounted) {
        final message = isOffline
            ? '✅ บันทึกงานไว้ออฟไลน์แล้ว (จะซิงค์เมื่อมีเน็ต)'
            : '✅ ปิดงานเรียบร้อยแล้ว!';

        SnackbarUtils.showLeft(context, message);
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('บันทึกไม่ผ่าน: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    SnackbarUtils.showLeft(context, message, isError: true);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ปิดงาน/ส่งมอบสินค้า'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageFiles.isNotEmpty) ...[
              Center(
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        image: DecorationImage(
                          image: FileImage(_imageFiles.first),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                      onPressed: () => setState(() => _imageFiles.clear()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              OutlinedButton.icon(
                onPressed: _showImagePickerOptions,
                icon: const Icon(Icons.camera_alt, color: Colors.grey),
                label: const Text('ถ่ายรูปหลักฐาน (ถ้าต้องการ / ไม่บังคับ)', style: TextStyle(color: Colors.grey)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // ✅ COD Section (เฉพาะบิลเงินเชื่อ หรือบิลที่ยังไม่ระบุการชำระเงินแต่มี price)
            if (_isCodJob())
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _isCodCollected,
                          activeColor: Colors.orange,
                          onChanged: (val) {
                            setState(() => _isCodCollected = val ?? false);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'รับเงินค่าสินค้า/COD แล้ว',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange),
                          ),
                        ),
                        const Icon(Icons.attach_money, color: Colors.orange),
                      ],
                    ),
                    if (_isCodCollected)
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 8.0, left: 40, right: 16),
                        child: TextFormField(
                          controller: _codAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'ยอดเงินที่รับจริง (บาท)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.money),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _updateCustomerLocation,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() => _updateCustomerLocation = val ?? true);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'บันทึกพิกัดปัจจุบัน เป็นที่อยู่ลูกค้า\n(แนะนำให้ติ๊ก ถ้ามาส่งถึงที่)',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const Icon(Icons.pin_drop, color: Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _getCurrentLocationAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(_isCodJob() ? Icons.payments : Icons.check_circle),
                label: Text(
                  _isLoading
                      ? 'กำลังบันทึกข้อมูล...'
                      : _isCodJob()
                          ? 'ยืนยันปิดงาน + รับเงิน (COD)'
                          : 'ยืนยันการปิดงาน',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
