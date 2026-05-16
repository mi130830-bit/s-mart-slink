// ไฟล์: lib/screens/jobs/job_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/jobs/providers/job_provider.dart';

import 'package:s_link/features/master_data/providers/master_data_provider.dart';
import 'package:s_link/features/common/screens/full_screen_image.dart';
// ✅ Import UserService & UserModel
import 'package:s_link/features/auth/services/user_service.dart';
import 'package:s_link/features/auth/models/user.dart';
// import 'package:s_link/features/jobs/services/location_service.dart'; // ✅ Import LocationService

import 'complete_job_form.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;
  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _isActionLoading = false;
  List<String> _selectedDriverIds = [];
  List<String> _selectedVehicleIds = [];

  @override
  void initState() {
    super.initState();
    // โหลดข้อมูลคนขับ/รถที่ถูกเลือกไว้แล้ว (ถ้ามี)
    if (widget.job.driverIds.isNotEmpty) {
      _selectedDriverIds = List.from(widget.job.driverIds);
    } else if (widget.job.driverId != null) {
      _selectedDriverIds = [widget.job.driverId!];
    }
    if (widget.job.vehicleIds != null) {
      _selectedVehicleIds = List.from(widget.job.vehicleIds!);
    }
  }

  // --- Logic Functions ---

  Future<void> _confirmDeleteJob() async {
    // 1. แสดง Dialog เพื่อขอคำยืนยัน และรอผลลัพธ์ True/False
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบงานนี้?'),
        content: const Text('การกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
            // คืนค่า false เมื่อกดยกเลิก
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            // คืนค่า true เมื่อกดยืนยัน
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('ยืนยันลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // 2. ถ้าผู้ใช้ไม่ได้กดยืนยัน (เป็น null หรือ false) ให้จบการทำงาน
    if (shouldDelete != true) return;

    // 3. เริ่มกระบวนการลบ
    if (!mounted) return; // เช็ค mounted ก่อนเริ่มงาน

    try {
      await Provider.of<JobProvider>(context, listen: false)
          .deleteJob(widget.job.id);

      // 4. หลังจากลบเสร็จ เช็ค mounted อีกครั้งก่อนใช้ context อัปเดต UI
      if (!mounted) return;

      Navigator.pop(context); // ปิดหน้า JobDetailScreen กลับไปหน้า List
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบงานเรียบร้อย')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Future<void> _launchGoogleMapsNavigation(double lat, double lng) async {
    // 1. ลองใช้ URL Scheme สำหรับ Google Maps Application
    final Uri appUrl = Uri.parse('google.navigation:q=$lat,$lng');
    // 2. URL สำรองสำหรับเปิดผ่าน Browser (Universal Link)
    final Uri webUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    try {
      // พยายามเปิดแอปฯ ก่อน (โดยไม่เช็ค canLaunchUrl เพื่อเลี่ยงปัญหา Android 11+ queries)
      if (!await launchUrl(appUrl, mode: LaunchMode.externalApplication)) {
        // ถ้าเปิดแอปฯ ไม่ได้ ให้เปิด Browser
        if (!await launchUrl(webUrl, mode: LaunchMode.externalApplication)) {
          throw 'Could not launch maps';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่สามารถเปิดแผนที่ได้')));
      }
    }
  }

  Future<void> _showEditJobDialog(Job job) async {
    final nameCtrl = TextEditingController(text: job.customer.name);
    final phoneCtrl = TextEditingController(text: job.customer.phoneNumber);
    final addressCtrl = TextEditingController(text: job.customer.address);
    final detailsCtrl = TextEditingController(text: job.details ?? '');
    final priceCtrl = TextEditingController(text: job.price?.toString() ?? '');

    final latCtrl = TextEditingController(
        text: job.destinationLocation != null
            ? '${job.destinationLocation!.latitude}, ${job.destinationLocation!.longitude}'
            : '');

    // Image logic
    List<String> currentImages = List.from(job.billImageUrls);
    List<File> newImages = [];
    final ImagePicker picker = ImagePicker();

    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while uploading
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('แก้ไขรายละเอียดงาน'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Fields ---
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'ชื่อลูกค้า'),
                  ),
                  TextField(
                    controller: phoneCtrl,
                    decoration:
                        const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
                  ),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'ที่อยู่'),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: latCtrl,
                    decoration: const InputDecoration(
                      labelText: 'พิกัด GPS',
                      hintText: '13.xxxx, 100.xxxx',
                    ),
                  ),
                  TextField(
                    controller: detailsCtrl,
                    decoration:
                        const InputDecoration(labelText: 'รายละเอียดงาน'),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: priceCtrl,
                    decoration:
                        const InputDecoration(labelText: 'ยอดเก็บเงิน (COD)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // --- Image Editing ---
                  const Text('รูปภาพบิล / สินค้า:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 1. Existing Images
                      ...currentImages.map((url) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(url,
                                    width: 80, height: 80, fit: BoxFit.cover),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      currentImages.remove(url);
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.red),
                                    child: const Icon(Icons.close,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )),
                      // 2. New Images
                      ...newImages.map((file) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(file,
                                    width: 80, height: 80, fit: BoxFit.cover),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      newImages.remove(file);
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.red),
                                    child: const Icon(Icons.close,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )),
                      // 3. Add Button
                      InkWell(
                        onTap: () async {
                          final pickedFiles = await picker.pickMultiImage(
                            imageQuality: 50,
                            maxWidth: 800,
                          );
                          if (pickedFiles.isNotEmpty) {
                            setDialogState(() {
                              newImages
                                  .addAll(pickedFiles.map((x) => File(x.path)));
                            });
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8)),
                          child:
                              const Icon(Icons.add_a_photo, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // --- Prepare Updates ---
                  GeoPoint? newLoc;
                  if (latCtrl.text.isNotEmpty && latCtrl.text.contains(',')) {
                    try {
                      final parts = latCtrl.text.split(',');
                      newLoc = GeoPoint(double.parse(parts[0].trim()),
                          double.parse(parts[1].trim()));
                    } catch (e) {/* ignore */}
                  }

                  // 1. Upload new images first
                  List<String> newUrls = [];
                  if (newImages.isNotEmpty) {
                    try {
                      // Show loading indicator conceptually by disabling button or showing dialog (simplified here)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('กำลังอัปโหลดรูปภาพ...')));

                      for (var file in newImages) {
                        final String fileName =
                            'bills/${DateTime.now().millisecondsSinceEpoch}_${newUrls.length}.jpg';
                        final ref =
                            FirebaseStorage.instance.ref().child(fileName);
                        await ref.putFile(file);
                        newUrls.add(await ref.getDownloadURL());
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Upload Error: $e')));
                      }
                      return;
                    }
                  }

                  // 2. Combine lists
                  final finalImageUrls = [...currentImages, ...newUrls];

                  final updates = {
                    'customer': {
                      'name': nameCtrl.text,
                      'phoneNumber': phoneCtrl.text,
                      'address': addressCtrl.text,
                    },
                    'details': detailsCtrl.text,
                    'price': double.tryParse(priceCtrl.text) ?? 0.0,
                    'bill_image_urls': finalImageUrls, // Update images
                    'items': [], // Clear items to fallback to details view
                    if (newLoc != null) 'destination_location': newLoc,
                  };

                  if (ctx.mounted) {
                    _performUpdateJob(ctx, job.id, updates);
                  }
                },
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _performUpdateJob(
      BuildContext ctx, String jobId, Map<String, dynamic> updates) async {
    final navigator = Navigator.of(ctx);
    try {
      await Provider.of<JobProvider>(context, listen: false)
          .updateJob(jobId, updates);
      if (mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตข้อมูลเรียบร้อย')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  void _viewProofLocation(GeoPoint proofLocation) {
    _launchGoogleMapsNavigation(
        proofLocation.latitude, proofLocation.longitude);
  }

  void _openImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: url)),
    );
  }

  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final currentUser = authProvider.currentUser;
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('งาน #${widget.job.id.substring(0, 4).toUpperCase()}'),
        actions: [
          // Delete button for Admin
          if (authProvider.isUserAdmin && !authProvider.isUserDriver)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteJob(),
            ),
          // Edit button for Admin or Requester
          if (authProvider.isUserAdmin || authProvider.isUserRequester)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditJobDialog(widget.job),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.job.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final jobSnapshot = snapshot.data!;
          if (!jobSnapshot.exists) {
            return const Center(child: Text('ไม่พบงานนี้แล้ว (อาจถูกลบ)'));
          }
          final currentJob = Job.fromFirestore(jobSnapshot);

          // final isDriver = authProvider.isUserDriver; // Unused
          final hasDriver =
              currentJob.driverId != null && currentJob.driverId!.isNotEmpty;
          final isMyJob = currentJob.driverId == currentUser?.uid ||
              (currentJob.driverIds.contains(currentUser?.uid)) ||
              (currentJob.deliveryTeam.any((m) => m.id == currentUser?.uid));
          final isCompleted = currentJob.status == 'completed';
          final isAdmin = authProvider.isUserAdmin;
          final isRequester = authProvider.isUserRequester;
          final canApprove = isAdmin || isRequester;

          // ✅ แก้ไข Logic การแสดงชื่อคนขับ: ให้หาจาก deliveryTeam ก่อน (แม่นยำกว่าเพราะเก็บ Snapshot ตอนปล่อยรถ)
          String? driverNameDisplay;
          if (isCompleted || hasDriver) {
            // ✅ เปลี่ยนจากหา 'driver' อย่างเดียว เป็นหาทั้ง 'driver' หรือ 'staff'
            final driverInTeam = currentJob.deliveryTeam.firstWhereOrNull(
                (d) => d.type == 'driver' || d.type == 'staff');
            if (driverInTeam != null) {
              driverNameDisplay = driverInTeam.name;
            } else {
              // Fallback: Try Master Data (Legacy)
              final d = masterDataProvider.deliverers
                  .firstWhereOrNull((d) => d.id == currentJob.driverId);
              driverNameDisplay = d?.name;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Status Card
                _buildStatusCard(
                    currentJob, isCompleted, hasDriver, driverNameDisplay),

                if (!isCompleted) ...[
                  _buildMapButton(currentJob.customer.address,
                      currentJob.destinationLocation),
                ],

                const SizedBox(height: 16),

                // 2. Customer Info
                _buildSectionTitle('ข้อมูลลูกค้า'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Colors.blue),
                    title: Text(currentJob.customer.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('โทร: ${currentJob.customer.phoneNumber}'),
                        Text('ที่อยู่: ${currentJob.customer.address}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 16),

                // 3. รายละเอียดงาน & บิล
                if ((currentJob.details != null &&
                        currentJob.details!.isNotEmpty) ||
                    currentJob.billImageUrl != null) ...[
                  // 3. รายละเอียดงาน & บิล (Updated Logic to fix duplication)
                  _buildSectionTitle('รายละเอียดงาน'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (currentJob.items.isNotEmpty) ...[
                            // ✅ New Logic: Items Available
                            Builder(builder: (context) {
                              // 1. Try Extract Note (First line of details if it's not an item)
                              String? note;
                              if (currentJob.details != null &&
                                  currentJob.details!.isNotEmpty) {
                                final lines = currentJob.details!.split('\n');
                                if (lines.isNotEmpty) {
                                  final first = lines.first.trim();
                                  if (first.isNotEmpty &&
                                      !first.startsWith('-')) {
                                    note = first;
                                  }
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Show Note in Yellow Box (Like user wanted)
                                  if (note != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.amber.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_note,
                                              color: Colors.brown),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              note,
                                              style: const TextStyle(
                                                  color: Colors.brown,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Show Items List Cleanly
                                  ...currentJob.items.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                          Text(
                                            'x${item.qty % 1 == 0 ? item.qty.toInt() : item.qty.toStringAsFixed(1)}',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              );
                            }),
                          ] else ...[
                            // ⚠️ Legacy Fallback: No items list, show raw details
                            if (currentJob.details != null &&
                                currentJob.details!.isNotEmpty)
                              Text(currentJob.details!,
                                  style: const TextStyle(fontSize: 16)),
                          ],

                          // Price & Bill Image (Common)
                          if (currentJob.price != null &&
                              currentJob.price! > 0) ...[
                            const SizedBox(height: 10),
                            const Divider(),
                            Text(
                              'ยอดเก็บเงิน (COD): ฿${currentJob.price!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                            ),
                          ],
                          if (currentJob.billImageUrl != null) ...[
                            const SizedBox(height: 10),
                            const Text('รูปบิล/ใบสั่งของ:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey)),
                            const SizedBox(height: 5),
                            GestureDetector(
                              onTap: () => _openImage(currentJob.billImageUrl!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(currentJob.billImageUrl!,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 4. Proof & Team
                if (isCompleted) ...[
                  _buildSectionTitle('หลักฐานการส่งงาน (Proof)'),
                  _buildProofSection(currentJob),
                  const SizedBox(height: 24),
                  _buildSectionTitle('ทีมจัดส่ง & รถที่ใช้'),
                  _buildDeliveryTeamList(currentJob.deliveryTeam),
                  const SizedBox(height: 24),
                ],

                // 5. Action Buttons
                // ✅ แก้ไข: ปุ่มปิดงานควรเห็นเฉพาะผู้ที่มีส่วนเกี่ยวข้องจริงๆ (MyJob, Admin, หรือคนสร้างงาน)
                // เพื่อป้องกันพนักงานคนอื่นที่ไม่ได้เกี่ยวข้องกันกดมั่ว ซึ่งอาจติด Security Rules ทำให้ปิดไม่ได้
                if (isAdmin || isRequester || isMyJob)
                  if (!isCompleted && currentJob.isDepartureApproved)
                    _buildCompleteButton(currentJob),

                // 6. Admin Approval Button
                if (canApprove &&
                    !currentJob.isDepartureApproved &&
                    !isCompleted)
                  _buildApprovalButton(masterDataProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildApprovalButton(MasterDataProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      // margin: const EdgeInsets.only(top: 20),
      child: ElevatedButton.icon(
        onPressed:
            _isActionLoading ? null : () => _showApprovalDialog(provider),
        icon: const Icon(Icons.verified_user),
        label: const Text('ตรวจสอบและปล่อยรถ', style: TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _showApprovalDialog(MasterDataProvider provider) async {
    List<String> tempDriverIds = List.from(_selectedDriverIds);
    List<String> tempVehicleIds = List.from(_selectedVehicleIds);

    // ✅ Load All Staff (Users) from Firestore
    List<UserModel> availableStaff = [];
    try {
      availableStaff = await UserService().getDrivers();
    } catch (e) {
      // If error, empty list
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // ✅ Use ONLY Firebase Users (as requested for correctness)
            // This ensures we have the correct UID for assignment.

            String getNames(List<String> ids, List<dynamic> source) {
              if (ids.isEmpty) return 'ยังไม่ได้เลือก';
              final names = <String>[];
              for (var id in ids) {
                // Handle UserModel vs CarModel (both have id/name/uid?)
                // CarModel uses 'id'. UserModel uses 'uid'.

                final found = source.firstWhereOrNull((e) {
                  if (e is UserModel) return e.uid == id;
                  // Assuming CarModel has 'id' property
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

            return AlertDialog(
              title: const Text('อนุมัติปล่อยรถ'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'กรุณาเลือก ทีมส่งของ และ รถ ที่จะออกไปส่งงานนี้',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),

                    // Driver Selector
                    if (availableStaff.isEmpty)
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

                    const Text('ทีมส่งของ (Delivery Team)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: availableStaff.isEmpty
                          ? null
                          : () async {
                              await _showMultiSelectDialog(
                                title: 'เลือกทีมส่งของ',
                                items: availableStaff, // ✅ All Staff
                                selectedIds: tempDriverIds,
                                onConfirm: (val) {
                                  setDialogState(() => tempDriverIds = val);
                                },
                              );
                            },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down)),
                        child: Text(getNames(tempDriverIds, availableStaff)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Selector (Still use Master Data)
                    const Text('รถ / ยานพาหนะ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: () async {
                        await _showMultiSelectDialog(
                          title: 'เลือกรถ',
                          items: provider.vehicles,
                          selectedIds: tempVehicleIds,
                          onConfirm: (val) {
                            setDialogState(() => tempVehicleIds = val);
                          },
                        );
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down)),
                        child:
                            Text(getNames(tempVehicleIds, provider.vehicles)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update main state and proceed
                    setState(() {
                      _selectedDriverIds = tempDriverIds;
                      _selectedVehicleIds = tempVehicleIds;
                    });

                    if (_selectedDriverIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('กรุณาเลือกทีมงานอย่างน้อย 1 คน')));
                      return;
                    }
                    Navigator.pop(ctx);
                    _handleApprove();
                  },
                  child: const Text('ยืนยันและปล่อยรถ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- UI Helpers ---

  Widget _buildDeliveryTeamList(List<DeliveryTeamItem> team) {
    if (team.isEmpty) return const Text('-');
    return Card(
      child: Column(
        children: team.map((item) {
          final isCar = item.type == 'car';
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isCar ? Colors.orange.shade100 : Colors.blue.shade100,
              child: Icon(isCar ? Icons.local_shipping : Icons.person,
                  color: isCar ? Colors.orange : Colors.blue),
            ),
            title: Text(item.name),
            subtitle: Text(isCar ? 'พาหนะ' : 'พนักงาน'),
          );
        }).toList(),
      ),
    );
  }

  bool _isCodJob(Job job) {
    // COD is only applicable if there is a price AND the payment method is 'credit' (or missing for older jobs)
    final method = job.paymentMethod?.trim().toLowerCase();
    return job.price != null &&
        job.price! > 0 &&
        (method == null || method.isEmpty || method == 'credit');
  }

  Widget _buildCompleteButton(Job job) {
    // แก้ไข: ปุ่มส่งงานจะโชว์เฉพาะเมื่องานได้รับการอนุมัติให้ออกรถแล้วเท่านั้น
    final bool isApproved = job.isDepartureApproved;
    final bool hasCod = _isCodJob(job);

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: !isApproved
            ? null
            : () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CompleteJobForm(job: job)));
              },
        icon: Icon(hasCod ? Icons.payments : Icons.check_circle_outline),
        label: Text(
            !isApproved
                ? 'รอ Admin อนุมัติการออกรถ'
                : hasCod
                    ? 'ปิดงาน + รับเงินสด (COD)'
                    : 'ปิดงาน / ส่งหลักฐาน',
            style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
            backgroundColor: isApproved
                ? (hasCod ? Colors.orange.shade700 : Colors.red)
                : Colors.grey,
            foregroundColor: Colors.white),
      ),
    );
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
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: ListBody(
                children: items.map((item) {
                  final isSelected = tempSelected.contains(item.id);
                  return CheckboxListTile(
                    value: isSelected,
                    title: Text(item.name),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          tempSelected.add(item.id);
                        } else {
                          tempSelected.remove(item.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก')),
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

  Future<void> _handleApprove() async {
    setState(() => _isActionLoading = true);
    try {
      final masterData =
          Provider.of<MasterDataProvider>(context, listen: false);

      // ✅ Fetch **All Staff** again (or use UserService cache)
      final allStaff = await UserService().getDeliveryStaff();
      if (!mounted) return;

      final List<DeliveryTeamItem> team = [];
      for (var id in _selectedDriverIds) {
        // Look in All Staff (Users) first
        final d = allStaff.firstWhereOrNull((x) => x.uid == id);
        if (d != null) {
          // ✅ Use 'staff' type to represent generic team member
          // (or 'driver' if you really need to keep legacy compatibility strictly,
          // but 'staff' is better for "helpers + drivers" concept)
          team.add(DeliveryTeamItem(type: 'staff', name: d.name, id: d.uid));
        } else {
          // Fallback to MasterData (Legacy)
          final legacy =
              masterData.deliverers.firstWhereOrNull((x) => x.id == id);
          if (legacy != null) {
            team.add(DeliveryTeamItem(
                type: 'staff', name: legacy.name, id: legacy.id));
          }
        }
      }
      for (var id in _selectedVehicleIds) {
        final v = masterData.vehicles.firstWhereOrNull((x) => x.id == id);
        if (v != null) {
          team.add(DeliveryTeamItem(
              type: 'vehicle', // Or 'car'
              name: v.name,
              id: v.id,
              licensePlate: v.licensePlate));
        }
      }

      await Provider.of<JobProvider>(context, listen: false)
          .approveJobDeparture(
        widget.job.id,
        driverIds: _selectedDriverIds,
        vehicleIds: _selectedVehicleIds,
        deliveryTeam: team,
      );

      // ✅ GPS Tracking is disabled as per user request (Play Store Policy)
      // await LocationService().startTracking();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('บันทึกข้อมูลและอนุมัติปล่อยรถแล้ว! 🚀'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Widget _buildMapButton(String address, GeoPoint? destination) {
    return Container(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () {
          if (destination != null) {
            _launchGoogleMapsNavigation(
                destination.latitude, destination.longitude);
          } else {
            final String query = Uri.encodeComponent(address);
            final url = Uri.parse(
                'https://www.google.com/maps/dir/?api=1&destination=$query');
            launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        icon: const Icon(Icons.map, size: 18),
        label:
            Text(destination != null ? 'นำทางด้วย GPS' : 'ค้นหาแผนที่จากชื่อ'),
        style: TextButton.styleFrom(
            foregroundColor: destination != null ? Colors.green : Colors.blue),
      ),
    );
  }

  Widget _buildProofSection(Job job) {
    final proofLocation = job.proofLocation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (job.proofImage != null)
          GestureDetector(
            onTap: () => _openImage(job.proofImage!),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(job.proofImage!,
                    height: 200, width: double.infinity, fit: BoxFit.cover),
                const Icon(Icons.zoom_in,
                    color: Colors.white,
                    size: 40,
                    shadows: [Shadow(blurRadius: 5, color: Colors.black)]),
              ],
            ),
          ),
        const SizedBox(height: 10),
        if (proofLocation != null)
          TextButton.icon(
            onPressed: () => _viewProofLocation(proofLocation),
            icon: const Icon(Icons.location_on, color: Colors.red),
            label: Text(
                'ดูจุดที่ส่งงาน (${proofLocation.latitude.toStringAsFixed(5)}, ${proofLocation.longitude.toStringAsFixed(5)})'),
          ),
      ],
    );
  }

  Widget _buildStatusCard(
      Job job, bool isCompleted, bool hasDriver, String? driverName) {
    // ... existing ...
    final authProvider =
        Provider.of<AuthenticationProvider>(context, listen: false);
    final isAdmin = authProvider.isUserAdmin;
    final isRequester = authProvider.isUserRequester;
    final canApprove = isAdmin || isRequester;

    Color cardColor;
    String text;
    IconData icon;

    if (isCompleted) {
      cardColor = Colors.grey;
      text = 'ส่งสำเร็จเรียบร้อย';
      icon = Icons.check_circle;
    } else if (!job.isDepartureApproved) {
      // สถานะ: รอแอดมินอนุมัติ (กำลังขึ้นของ)
      cardColor = Colors.purple;
      text = 'รอแอดมินอนุมัติออกส่ง (กำลังขึ้นของ)';
      icon = Icons.hourglass_top;
    } else {
      // อนุมัติแล้ว (กำลังเดินทาง) - รวมกรณี hasDriver หรือไม่ก็ตาม
      cardColor = Colors.blue;
      text = 'กำลังดำเนินการโดย: ${driverName ?? "คนขับรถ"}';
      icon = Icons.local_shipping;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: cardColor),
          const SizedBox(height: 8),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: cardColor)),
          if (!job.isDepartureApproved && !isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                canApprove
                    ? '(ตรวจสอบความเรียบร้อยแล้วกดปุ่มด้านล่าง)'
                    : '(กรุณารอการอนุมัติปล่อยรถจากเจ้าหน้าที่)',
                style: TextStyle(fontSize: 12, color: cardColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
