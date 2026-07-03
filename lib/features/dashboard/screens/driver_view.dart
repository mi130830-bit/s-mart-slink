// ไฟล์: lib/screens/dashboard/driver_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ✅ Import เพิ่มเติม

import 'package:s_link/features/jobs/providers/job_provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/jobs/screens/job_detail_screen.dart';
import 'package:s_link/features/shop_log/screens/create_work_log_screen.dart';

import 'package:s_link/features/dashboard/screens/pickup_screen.dart'; // ✅ Import PickupScreen
// Removed attendance_screen.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:s_link/core/config/app_constants.dart';
import 'package:s_link/core/services/startup_service.dart';

class DriverView extends StatefulWidget {
  const DriverView({super.key});

  @override
  State<DriverView> createState() => _DriverViewState();
}

class _DriverViewState extends State<DriverView> {

  @override
  void initState() {
    super.initState();
    _checkInitialHolidayStatus();
  }

  Future<void> _checkInitialHolidayStatus() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('driver_alerts');
    } catch (e) {
      debugPrint('Error subscribing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('พนักงานหลังบ้าน'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'ตั้งค่า',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('ตั้งค่า')),
                      body: const _DriverSettingsTab(),
                    );
                  }),
                );
              },
            ),
            // ปุ่ม Logout
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: () => authProvider.logout(),
              tooltip: 'ออกจากระบบ',
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              GestureDetector(
                onDoubleTap: () => _showDebugInfo(context),
                child: const Tab(
                    text: 'งานส่งของ', icon: Icon(Icons.local_shipping)),
              ),
              const Tab(text: 'ลูกค้ามารับของ', icon: Icon(Icons.shopping_bag)),
              const Tab(
                  text: 'เช็คของหลังบ้าน', icon: Icon(Icons.construction)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Tab 1: งานส่งของ
            _MyJobsTab(),

            // Tab 2: ลูกค้ามารับของ
            PickupScreen(),

            // Tab 3: เช็คของหลังบ้าน
            CreateWorkLogScreen(),
          ],
        ),
      ),
    );
  }

  void _showDebugInfo(BuildContext context) {
    final provider = Provider.of<JobProvider>(context, listen: false);
    final auth = Provider.of<AuthenticationProvider>(context, listen: false);
    final myUid = auth.currentUser?.uid ?? 'Unknown';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText('My UID: $myUid'),
              const Divider(),
              const Text('Pending Jobs:'),
              ...provider.pendingJobs.map((j) => SelectableText(
                  'Job: ${j.id}\nStatus: ${j.status}\nAppr: ${j.isDepartureApproved}\nDrivers: ${j.driverIds}\nWalkIn: ${j.customer.name.contains("Walk-in")}')),
              const Divider(),
              const Text('Assigned Jobs (Provider):'),
              ...provider.driverAssignedJobs.map((j) => SelectableText(
                  'Job: ${j.id}\nAppr: ${j.isDepartureApproved}\nDrivers: ${j.driverIds}')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }
}

class _MyJobsTab extends StatelessWidget {
  const _MyJobsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<JobProvider, AuthenticationProvider>(
      builder: (context, jobProvider, authProvider, child) {
        final isLoading = jobProvider.isLoading;

        // 1. งานมาใหม่
        final newJobs = jobProvider.pendingJobs.where((job) {
          final isPickupType =
              job.jobType == 'pickup' || job.jobType == 'customer_pickup';
          final isWalkIn = job.customer.name.toLowerCase().contains('walk-in');
          return !job.isDepartureApproved && !isPickupType && !isWalkIn;
        }).toList();

        // 2. งานกำลังดำเนินการ
        final myActiveJobs = jobProvider.driverAssignedJobs.where((job) {
          final isPickupType =
              job.jobType == 'pickup' || job.jobType == 'customer_pickup';
          final isWalkIn = job.customer.name.toLowerCase().contains('walk-in');
          return job.isDepartureApproved && !isPickupType && !isWalkIn;
        }).toList();

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            await jobProvider.refreshStreams();
          },
          child: (myActiveJobs.isEmpty && newJobs.isEmpty)
              ? ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(), // Allow refresh even if empty
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('ไม่มีงานในระบบ',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 18)),
                          const Text('ลากลงเพื่อรีเฟรช 🔄',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (myActiveJobs.isNotEmpty) ...[
                      _buildSectionHeader(
                          'งานกำลังดำเนินการ (${myActiveJobs.length})',
                          Icons.local_shipping,
                          Colors.blue),
                      ...myActiveJobs.map(
                          (job) => _buildJobCard(context, job, isMyJob: true)),
                      const SizedBox(height: 20),
                    ],
                    if (newJobs.isNotEmpty) ...[
                      _buildSectionHeader(
                          'งานมาใหม่ (รอรับ) (${newJobs.length})',
                          Icons.new_releases,
                          Colors.orange),
                      ...newJobs.map(
                          (job) => _buildJobCard(context, job, isMyJob: false)),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Job job, {required bool isMyJob}) {
    final isCompleted = job.status == 'completed';
    // ✅ Check if we should show "Close Job" button
    final canClose = isMyJob && job.isDepartureApproved && !isCompleted;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobDetailScreen(job: job),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: isMyJob
                        ? (isCompleted
                            ? Colors.green.shade100
                            : Colors.blue.shade100)
                        : Colors.orange.shade100,
                    child: Icon(
                      isMyJob
                          ? (isCompleted ? Icons.check : Icons.local_shipping)
                          : Icons.handshake,
                      color: isMyJob
                          ? (isCompleted ? Colors.green : Colors.blue)
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.customer.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(job.customer.address,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.grey
                                    : (!job.isDepartureApproved
                                        ? Colors.purple
                                        : (isMyJob
                                            ? Colors.blue
                                            : Colors.orange)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isCompleted
                                    ? 'ส่งแล้ว'
                                    : (!job.isDepartureApproved
                                        ? 'รอขึ้นของ'
                                        : (isMyJob
                                            ? 'กำลังดำเนินการ'
                                            : 'รอคนขับ')),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                            if (!isMyJob && job.isDepartureApproved) ...[
                              const SizedBox(width: 8),
                              const Text('แตะเพื่อรับงาน',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ],
                            if (!job.isDepartureApproved) ...[
                              const SizedBox(width: 8),
                              Builder(builder: (context) {
                                final role =
                                    Provider.of<AuthenticationProvider>(context,
                                            listen: false)
                                        .currentUser
                                        ?.role
                                        .name;
                                return Text(
                                    role == 'admin'
                                        ? 'รอแอดมินเช็คของ'
                                        : 'รอแอดมินเช็คของส่ง',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.purple));
                              }),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                ],
              ),
              // ✅ Add Action Button for Closing Job
              if (canClose) ...[
                const Divider(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JobDetailScreen(job: job),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('ปิดงานส่ง (ถึงที่หมายแล้ว)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverSettingsTab extends StatefulWidget {
  const _DriverSettingsTab();

  @override
  State<_DriverSettingsTab> createState() => _DriverSettingsTabState();
}

class _DriverSettingsTabState extends State<_DriverSettingsTab> {
  final AudioPlayer _player = AudioPlayer();
  String? _currentSound;

  @override
  void initState() {
    super.initState();
    _loadSound();
  }

  Future<void> _loadSound() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentSound = prefs.getString('notification_sound') ??
            AppConstants.notificationSound;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _setSound(String sound) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_sound', sound);
    await StartupService.setupNotificationChannel();

    if (mounted) {
      setState(() {
        _currentSound = sound;
      });

      // Play preview
      try {
        await _player.stop();
        await _player.play(AssetSource('sounds/$sound.mp3'));
      } catch (e) {
        debugPrint('Error playing sound: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentSound == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'เลือกเสียงแจ้งเตือน',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('เสียงนี้จะใช้สำหรับการแจ้งเตือนงานใหม่'),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: AppConstants.availableSounds.map((sound) {
              return RadioListTile<String>(
                title: Text(sound),
                value: sound,
                // ignore: deprecated_member_use
                groupValue: _currentSound,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) _setSound(val); // บันทึกและเล่นเสียงทันที
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
