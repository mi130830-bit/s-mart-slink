import 'dart:async';
import 'package:flutter/material.dart';
import 'package:s_link/features/dashboard/widgets/pickup_job_card.dart';
import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/jobs/services/job_service.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  final JobService _jobService = JobService();
  late Stream<List<Job>> _jobsStream;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _jobsStream = _jobService.getPickupJobs();
    // Refresh UI every 5 minutes to update countdown timers
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // กำหนดเวลาปัจจุบัน - 60 นาที (Jobs older than this will be hidden)
    final expirationTime = DateTime.now().subtract(const Duration(minutes: 60));

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการรับสินค้าเอง'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<List<Job>>(
        stream: _jobsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('ลองใหม่'),
                  )
                ],
              ),
            );
          }

          final allJobs = snapshot.data ?? [];

          // Filter out jobs created more than 10 minutes ago
          final jobs = allJobs.where((job) {
            return job.createdAt.isAfter(expirationTime);
          }).toList();

          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'ไม่มีรายการรับสินค้า',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (context, index) {
              final job = jobs[index];
              return PickupJobCard(
                job: job,
              );
            },
          );
        },
      ),
    );
  }
}
