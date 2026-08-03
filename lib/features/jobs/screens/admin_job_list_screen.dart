// ไฟล์: lib/screens/jobs/admin_job_list_screen.dart

import 'package:s_link/utils/snackbar_utils.dart';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:s_link/features/jobs/providers/job_provider.dart';
import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/jobs/services/job_export_service.dart';
import 'job_detail_screen.dart';

/// ตัวเลือก Range วันที่
enum DateRangeOption { today, week, month, pickDay, custom }

class AdminJobListScreen extends StatefulWidget {
  const AdminJobListScreen({super.key});

  @override
  State<AdminJobListScreen> createState() => _AdminJobListScreenState();
}

class _AdminJobListScreenState extends State<AdminJobListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  // ✅ Date Range State
  DateRangeOption _selectedRange = DateRangeOption.today;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final now = DateTime.now();
    _startDate = now;
    _endDate = now;

    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ✅ คำนวณ start/end จาก Chip ที่เลือก
  void _onRangeSelected(DateRangeOption option) async {
    final now = DateTime.now();

    switch (option) {
      case DateRangeOption.today:
        _startDate = now;
        _endDate = now;
        break;

      case DateRangeOption.week:
        _startDate = now.subtract(const Duration(days: 6));
        _endDate = now;
        break;

      case DateRangeOption.month:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;

      case DateRangeOption.pickDay:
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime(2023),
          lastDate: DateTime(2030),
        );
        if (picked == null) return;
        _startDate = picked;
        _endDate = picked;
        break;

      case DateRangeOption.custom:
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2023),
          lastDate: DateTime(2030),
          initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
        );
        if (range == null) return;
        _startDate = range.start;
        _endDate = range.end;
        break;
    }

    setState(() => _selectedRange = option);
    if (mounted) {
      Provider.of<JobProvider>(context, listen: false)
          .fetchCompletedJobsByRange(_startDate, _endDate);
    }
  }

  /// สร้างข้อความแสดง range ที่เลือก
  String _getRangeLabel() {
    final fmt = DateFormat('d MMM', 'th');
    if (DateUtils.isSameDay(_startDate, _endDate)) {
      final now = DateTime.now();
      if (DateUtils.isSameDay(_startDate, now)) return 'วันนี้';
      return fmt.format(_startDate);
    }
    return '${fmt.format(_startDate)} - ${fmt.format(_endDate)}';
  }

  Future<void> _exportData() async {
    final jobProvider = Provider.of<JobProvider>(context, listen: false);
    final allJobs = [...jobProvider.pendingJobs, ...jobProvider.completedJobs];
    
    final displayJobs = allJobs.where((job) {
      if (_searchText.isNotEmpty) {
        final text = _searchText;
        return job.customer.name.toLowerCase().contains(text) ||
            job.customer.phoneNumber.contains(text) ||
            job.customer.address.toLowerCase().contains(text);
      }
      final jobDate = job.completedAt ?? job.createdAt;
      final startOfDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endOfDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      return jobDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
          jobDate.isBefore(endOfDay.add(const Duration(seconds: 1)));
    }).toList();

    if (displayJobs.isEmpty) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'ไม่มีข้อมูลให้ Export');
      }
      return;
    }

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await JobExportService.exportJobsToExcel(displayJobs, _startDate, _endDate);
      if (mounted) Navigator.pop(context); // close loader
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        SnackbarUtils.showLeft(context, 'เกิดข้อผิดพลาด: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการงานรายวัน'),
        actions: [
          // [M2] ปุ่ม Force Sync — ดึงงานจาก POS Backend มาเก็บใน Local SQLite
          Consumer<JobProvider>(
            builder: (context, jp, _) => jp.isSyncingDown
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.cloud_download_outlined),
                    tooltip: 'โหลดงานจากร้าน (Sync)',
                    onPressed: () async {
                      await jp.syncAndRefreshJobs();
                      if (context.mounted) {
                        SnackbarUtils.showLeft(context, 'โหลดงานล่าสุดแล้ว!');
                      }
                    },
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Report',
            onPressed: _exportData,
          )
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          '🔍 ค้นหา (ค้นจากประวัติทั้งหมด ไม่สนวันที่)...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchText.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(
                        text: 'กำลังดำเนินการ',
                        icon: Icon(Icons.run_circle_outlined)),
                    Tab(text: 'งานที่เสร็จแล้ว', icon: Icon(Icons.history)),
                  ],
                ),
              ],
            )),
      ),
      body: Column(
        children: [
          // ✅ Chip Selector สำหรับเลือกช่วงเวลา
          if (_searchText.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Row 1: Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChip(
                            'วันนี้', DateRangeOption.today, Icons.today),
                        const SizedBox(width: 6),
                        _buildChip(
                            'สัปดาห์', DateRangeOption.week, Icons.date_range),
                        const SizedBox(width: 6),
                        _buildChip('เดือน', DateRangeOption.month,
                            Icons.calendar_month),
                        const SizedBox(width: 6),
                        _buildChip(
                            'เลือกวัน', DateRangeOption.pickDay, Icons.event),
                        const SizedBox(width: 6),
                        _buildChip(
                            'กำหนดเอง', DateRangeOption.custom, Icons.tune),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Row 2: แสดงช่วงที่เลือก
                  Text(
                    '📅 ${_getRangeLabel()}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Consumer<JobProvider>(
              builder: (context, jobProvider, child) {
                if (jobProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    // [M2] Tab 1: งานกำลังดำเนินการ — อ่านจาก Local SQLite + Pull-to-refresh
                    RefreshIndicator(
                      onRefresh: () => jobProvider.syncAndRefreshJobs(),
                      child: _buildFilteredList(
                        jobProvider.activeLocalJobs.isNotEmpty
                            ? jobProvider.activeLocalJobs
                            : jobProvider.pendingJobs,
                        isHistory: false,
                      ),
                    ),
                    // Tab 2: งานที่เสร็จแล้ว — อ่านจาก MySQL History
                    _buildFilteredList(jobProvider.completedJobs,
                        isHistory: true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, DateRangeOption option, IconData icon) {
    final isSelected = _selectedRange == option;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.blue),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => _onRangeSelected(option),
    );
  }

  Widget _buildFilteredList(List<Job> allJobs, {required bool isHistory}) {
    final displayJobs = allJobs.where((job) {
      if (_searchText.isNotEmpty) {
        final text = _searchText;
        return job.customer.name.toLowerCase().contains(text) ||
            job.customer.phoneNumber.contains(text) ||
            job.customer.address.toLowerCase().contains(text);
      }
      // ✅ Filter ด้วย date range แทนทีละวัน
      final jobDate =
          isHistory ? (job.completedAt ?? job.createdAt) : job.createdAt;
      final startOfDay =
          DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endOfDay =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      final result = jobDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
          jobDate.isBefore(endOfDay.add(const Duration(seconds: 1)));
      
      // log('Job Filter: ID=${job.id}, Date=$jobDate, Start=$startOfDay, End=$endOfDay, Result=$result');
      return result;
    }).toList();

    log('AdminJobList: Showing ${displayJobs.length} jobs out of ${allJobs.length} (Range: $_startDate - $_endDate)');

    if (displayJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                _searchText.isNotEmpty
                    ? Icons.search_off
                    : Icons.calendar_today,
                size: 64,
                color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _searchText.isNotEmpty
                  ? 'ไม่พบข้อมูลที่ค้นหา'
                  : 'ไม่มีรายการในช่วงที่เลือก',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    displayJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: displayJobs.length,
      itemBuilder: (context, index) {
        final job = displayJobs[index];

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JobDetailScreen(job: job),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: isHistory
                  ? Colors.green.shade100
                  : (job.jobType == 'customer_pickup' || job.jobType == 'pickup'
                      ? Colors.teal.shade100
                      : (!job.isDepartureApproved
                          ? Colors.purple.shade100
                          : (job.driverId != null && job.driverId!.isNotEmpty
                              ? Colors.blue.shade100
                              : Colors.orange.shade100))),
              child: Icon(
                isHistory
                    ? Icons.check
                    : (job.jobType == 'customer_pickup' ||
                            job.jobType == 'pickup'
                        ? Icons.store
                        : (!job.isDepartureApproved
                            ? Icons.hourglass_top
                            : (job.driverId != null && job.driverId!.isNotEmpty
                                ? Icons.local_shipping
                                : Icons.person_search))),
                color: isHistory
                    ? Colors.green
                    : (job.jobType == 'customer_pickup' ||
                            job.jobType == 'pickup'
                        ? Colors.teal
                        : (!job.isDepartureApproved
                            ? Colors.purple
                            : (job.driverId != null && job.driverId!.isNotEmpty
                                ? Colors.blue
                                : Colors.orange))),
              ),
            ),
            title: Text(job.customer.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(job.customer.address,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchText.isNotEmpty ||
                              !DateUtils.isSameDay(_startDate, _endDate)
                          ? DateFormat('d MMM HH:mm').format(job.createdAt)
                          : 'เวลา: ${DateFormat('HH:mm').format(job.createdAt)} น.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (job.customer.phoneNumber.isNotEmpty)
                      Text(
                        '📞 ${job.customer.phoneNumber}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.blueGrey),
                      ),
                  ],
                ),
                // ✅ Show Driver Name if Released
                if (job.isDepartureApproved) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'คนขับ: ${job.deliveryTeam.firstWhere((e) => e.type != 'car', orElse: () => const DeliveryTeamItem(id: '', name: 'Unknown', type: 'driver')).name}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey),
          ),
        );
      },
    );
  }
}
