import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/jobs/providers/job_provider.dart';

import 'package:s_link/features/master_data/providers/master_data_provider.dart';
import 'package:s_link/features/common/screens/full_screen_image.dart';
import 'package:s_link/features/auth/services/user_service.dart';
import 'package:s_link/features/auth/models/user.dart';

import 'complete_job_form.dart';
import 'widgets/job_detail/edit_job_dialog.dart';
import 'widgets/job_detail/approve_departure_dialog.dart';
import 'widgets/job_detail/job_status_card.dart';
import 'widgets/job_detail/job_detail_items.dart';

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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบงานนี้?'),
        content: const Text('การกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('ยืนยันลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    if (!mounted) return;

    try {
      await Provider.of<JobProvider>(context, listen: false)
          .deleteJob(widget.job.id);

      if (!mounted) return;

      Navigator.pop(context);
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
    final Uri appUrl = Uri.parse('google.navigation:q=$lat,$lng');
    final Uri webUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    try {
      if (!await launchUrl(appUrl, mode: LaunchMode.externalApplication)) {
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

  void _showEditJobDialog(Job job) {
    showEditJobDialog(context, job, (updates, newImages) => _performUpdateJob(context, job.id, updates, newImages));
  }

  Future<void> _performUpdateJob(
      BuildContext ctx, String jobId, Map<String, dynamic> updates, List<File> newImages) async {
    final navigator = Navigator.of(ctx);
    final provider = Provider.of<JobProvider>(ctx, listen: false);
    try {
      if (newImages.isNotEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กำลังอัปโหลดรูปภาพ...')));
        final newUrls = await provider.uploadJobImages(newImages);
        final currentImages = List<String>.from(updates['bill_image_urls'] ?? []);
        updates['bill_image_urls'] = [...currentImages, ...newUrls];
      }

      await provider.updateJob(jobId, updates);
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

          final hasDriver =
              currentJob.driverId != null && currentJob.driverId!.isNotEmpty;
          final isMyJob = currentJob.driverId == currentUser?.uid ||
              (currentJob.driverIds.contains(currentUser?.uid)) ||
              (currentJob.deliveryTeam.any((m) => m.id == currentUser?.uid));
          final isCompleted = currentJob.status == 'completed';
          final isAdmin = authProvider.isUserAdmin;
          final isRequester = authProvider.isUserRequester;
          final canApprove = isAdmin || isRequester;

          String? driverNameDisplay;
          if (isCompleted || hasDriver) {
            final driverInTeam = currentJob.deliveryTeam.firstWhereOrNull(
                (d) => d.type == 'driver' || d.type == 'staff');
            if (driverInTeam != null) {
              driverNameDisplay = driverInTeam.name;
            } else {
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
                JobStatusCard(
                  job: currentJob,
                  driverName: driverNameDisplay,
                  canApprove: canApprove,
                ),

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

                // 3. รายละเอียดงาน & บิล
                if ((currentJob.details != null &&
                        currentJob.details!.isNotEmpty) ||
                    currentJob.billImageUrl != null) ...[
                  _buildSectionTitle('รายละเอียดงาน'),
                  JobDetailItems(
                    job: currentJob,
                    onOpenImage: _openImage,
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
    List<UserModel> availableStaff = [];
    try {
      availableStaff = await UserService().getDrivers();
    } catch (e) {
      // If error, empty list
    }

    if (!mounted) return;

    await showApproveDepartureDialog(
      context: context,
      availableStaff: availableStaff,
      vehicles: provider.vehicles,
      initialDriverIds: _selectedDriverIds,
      initialVehicleIds: _selectedVehicleIds,
      onConfirm: (drivers, vehicles) {
        setState(() {
          _selectedDriverIds = drivers;
          _selectedVehicleIds = vehicles;
        });
        _handleApprove();
      },
    );
  }

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
    final method = job.paymentMethod?.trim().toLowerCase();
    return job.price != null &&
        job.price! > 0 &&
        (method == null || method.isEmpty || method == 'credit');
  }

  Widget _buildCompleteButton(Job job) {
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

  Future<void> _handleApprove() async {
    setState(() => _isActionLoading = true);
    try {
      final masterData =
          Provider.of<MasterDataProvider>(context, listen: false);

      final allStaff = await UserService().getDeliveryStaff();
      if (!mounted) return;

      final List<DeliveryTeamItem> team = [];
      for (var id in _selectedDriverIds) {
        final d = allStaff.firstWhereOrNull((x) => x.uid == id);
        if (d != null) {
          team.add(DeliveryTeamItem(type: 'staff', name: d.name, id: d.uid));
        } else {
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
              type: 'vehicle',
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('บันทึกข้อมูลและอนุมัติปล่อยรถแล้ว! 🚀'),
            backgroundColor: Colors.green),
      );
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
