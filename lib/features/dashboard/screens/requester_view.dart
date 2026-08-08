// ไฟล์: lib/screens/dashboard/requester_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/jobs/providers/job_provider.dart';
// CreateJobScreen removed — สร้างงานจาก POS Desktop แทน
import 'package:s_link/features/jobs/screens/job_detail_screen.dart';
import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/alerts/screens/stock_alert_screen.dart';
// Removed attendance_screen.dart

class RequesterView extends StatefulWidget {
  const RequesterView({super.key});

  @override
  State<RequesterView> createState() => _RequesterViewState();
}

class _RequesterViewState extends State<RequesterView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkInitialHolidayStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialHolidayStatus() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('requester_alerts');
    } catch (e) {
      debugPrint('Error subscribing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ส.บริการ (พนักงานหน้าร้าน)'),
        actions: [
          IconButton(
            onPressed: () => authProvider.logout(),
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'ออกจากระบบ',
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'งาน\nจัดส่ง'),
            Tab(text: 'งานที่\nส่งแล้ว'),
            Tab(text: 'ของ\nหมด'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PendingJobsTab(),
          _CompletedJobsTab(),
          StockAlertScreen(isEmbedded: true),
        ],
      ),
    );
  }
}

class _PendingJobsTab extends StatelessWidget {
  const _PendingJobsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (context, jobProvider, child) {
        // ให้แสดงงานรอจัดส่งทั้งหมด (รวมรับของเองด้วย)
        final jobs = jobProvider.pendingJobs.toList();

        if (jobProvider.isLoading && jobs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            await jobProvider.refreshStreams();
          },
          child: _buildBody(context, jobProvider, jobs),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    JobProvider jobProvider,
    List<Job> jobs,
  ) {
    if (jobProvider.pendingJobsError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Center(
            child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล',
                style: TextStyle(fontSize: 18, color: Colors.red)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(jobProvider.pendingJobsError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
            ),
          ),
          const Center(child: Text('ลากลงเพื่อรีเฟรช 🔄')),
        ],
      );
    }

    if (jobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Center(
            child: Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('ไม่พบงานที่กำลังรอจัดส่ง',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
          const Center(
            child: Text('ลากลงเพื่อรีเฟรช 🔄',
                style: TextStyle(color: Colors.grey)),
          ),
        ],
      );
    }

    final dispatchedJobs = jobs.where((job) => job.isDepartureApproved).toList();
    final waitingJobs = jobs.where((job) => !job.isDepartureApproved).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (dispatchedJobs.isNotEmpty) ...[
          _buildSectionHeader(
            'กำลังจัดส่ง (${dispatchedJobs.length})',
            Icons.local_shipping,
            Colors.blue,
          ),
          ...dispatchedJobs.map(
            (job) => _buildJobTile(context, job, isDispatched: true),
          ),
        ],
        if (waitingJobs.isNotEmpty) ...[
          _buildSectionHeader(
            'รอจัดส่ง (${waitingJobs.length})',
            Icons.hourglass_top,
            Colors.orange,
          ),
          ...waitingJobs.map(
            (job) => _buildJobTile(context, job, isDispatched: false),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobTile(
    BuildContext context,
    Job job, {
    required bool isDispatched,
  }) {
    final driverName = job.deliveryTeam
        .where((member) => member.type == 'driver' || member.type == 'staff')
        .map((member) => member.name)
        .join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDispatched ? Colors.blue : Colors.orange,
          child: Icon(
            isDispatched ? Icons.local_shipping : Icons.hourglass_top,
            color: Colors.white,
          ),
        ),
        title: Text(job.customer.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          isDispatched
              ? 'กำลังจัดส่งโดย: ${driverName.isNotEmpty ? driverName : job.driverId ?? '-'}\n${job.customer.address}'
              : job.customer.address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
        ),
      ),
    );
  }
}

class _CompletedJobsTab extends StatefulWidget {
  const _CompletedJobsTab();

  @override
  State<_CompletedJobsTab> createState() => _CompletedJobsTabState();
}

class _CompletedJobsTabState extends State<_CompletedJobsTab> {
  DateTime _selectedDate = DateTime.now();

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    setState(() => _selectedDate = newDate);

    // Fetch data for the new date
    Provider.of<JobProvider>(context, listen: false)
        .fetchCompletedJobsByRange(newDate, newDate);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (context, jobProvider, child) {
        final allCompleted = jobProvider.completedJobs;

        final jobs = allCompleted.where((job) {
          final jobDate = job.completedAt ?? job.createdAt;
          return DateUtils.isSameDay(jobDate, _selectedDate);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                      'งานที่ส่งแล้ว (${DateFormat('d MMM yyyy').format(_selectedDate)})',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('เลือกวันที่: ',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      // ⬅️ Previous Day Button
                      IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: Color.fromARGB(255, 33, 159, 243)),
                        onPressed: () => _changeDate(-1),
                        tooltip: 'ย้อนหลัง 1 วัน',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 131, 180, 220)
                                  .withValues(alpha: 0.1),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                              if (!context.mounted) return;
                              // ✅ [NEW] เรียก Provider ให้ดึงข้อมูลใหม่ตามวันที่เลือก
                              Provider.of<JobProvider>(context, listen: false)
                                  .fetchCompletedJobsByRange(picked, picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                              DateFormat('d MMM').format(
                                  _selectedDate), // Shorten date for space
                              overflow: TextOverflow.ellipsis),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              visualDensity: VisualDensity.compact),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // ➡️ Next Day Button
                      const SizedBox(width: 4),
                      IconButton(
                        icon:
                            const Icon(Icons.chevron_right, color: Colors.blue),
                        onPressed:
                            DateUtils.isSameDay(_selectedDate, DateTime.now())
                                ? null // Disable if today
                                : () => _changeDate(1),
                        tooltip: 'วันถัดไป',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: jobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('ไม่พบงานในวันนี้',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('ลองเลือกวันที่อื่นเพื่อดูย้อนหลัง',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: jobs.length,
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: const CircleAvatar(
                                backgroundColor: Colors.green,
                                child: Icon(Icons.check, color: Colors.white)),
                            title: Text(job.customer.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text('ส่งโดย: ${job.driverId ?? "-"}'),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => JobDetailScreen(job: job))),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
