// ไฟล์: lib/screens/jobs/available_jobs_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/jobs/providers/job_provider.dart';
// ลบ import ที่ไม่ได้ใช้ออกแล้ว (../../models/job.dart)
import 'job_detail_screen.dart';

class AvailableJobsScreen extends StatelessWidget {
  const AvailableJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Jobs (Unassigned)'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Consumer<JobProvider>(
        builder: (context, jobProvider, child) {
          if (jobProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // กรองงานที่สถานะ Pending และไม่มี Driver (driverId เป็น null หรือว่าง)
          final unassignedJobs = jobProvider.pendingJobs
              .where((job) => job.driverId == null || job.driverId!.isEmpty)
              .toList();

          if (unassignedJobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined,
                      size: 80, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text('No new jobs available for claiming.',
                      style: TextStyle(fontSize: 18)),
                  const Text('Refresh later or wait for notification.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: unassignedJobs.length,
            itemBuilder: (context, index) {
              final job = unassignedJobs[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.inventory_2, color: Colors.orange),
                  title: Text(job.customer.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(job.customer.address,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // นำทางไป Job Detail เพื่อกด Claim Job
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => JobDetailScreen(job: job)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
