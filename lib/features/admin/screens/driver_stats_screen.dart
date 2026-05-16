// ไฟล์: lib/screens/admin/driver_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/jobs/providers/job_provider.dart';
import 'package:s_link/features/master_data/providers/master_data_provider.dart';

class DriverStatsScreen extends StatefulWidget {
  const DriverStatsScreen({super.key});

  @override
  State<DriverStatsScreen> createState() => _DriverStatsScreenState();
}

class _DriverStatsScreenState extends State<DriverStatsScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ ดึงข้อมูลดิบจาก MySQL (history) เพื่อนำมาคำนวณแยกรายบุคคลแบบเดิม
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<JobProvider>(context, listen: false).fetchJobStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('สถิติการขนส่ง (สรุปทั้งหมด)'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'พนักงานขับรถ'),
              Tab(icon: Icon(Icons.local_shipping), text: 'รถขนส่ง'),
            ],
          ),
        ),
        body: Consumer<JobProvider>(
          builder: (context, jobProvider, child) {
            final jobs = jobProvider.statsJobs;
            final int totalJobs = jobs.length;

            if (jobProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (totalJobs == 0) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('ยังไม่มีข้อมูลสถิติในระบบ (Archive)'),
                  ],
                ),
              );
            }

            final masterData = Provider.of<MasterDataProvider>(context, listen: false);

            final driverCountMap = <String, int>{};
            final vehicleCountMap = <String, int>{};

            // ✅ Preset vehicles with 0 jobs
            for (var car in masterData.cars) {
              vehicleCountMap[car.name] = 0;
            }

            for (var job in jobs) {
              for (var member in job.deliveryTeam) {
                if (member.type == 'car') {
                  // Find actual car from master data to consolidate duplicate names/plates
                  String actualCarName = member.name;
                  try {
                    final matchedCar = masterData.cars.firstWhere(
                      (c) {
                        final cn = c.name;
                        final cl = c.licensePlate;
                        final mn = member.name;
                        if (cn == mn || cl == mn) return true;
                        if (cn.isNotEmpty && mn.contains(cn)) return true;
                        if (cl.isNotEmpty && mn.contains(cl)) return true;
                        if (mn.isNotEmpty && cn.contains(mn)) return true; // e.g. "ดั้มใหญ่ 81-3250".contains("81-3250")
                        if (mn.isNotEmpty && cl.contains(mn)) return true;
                        return false;
                      }
                    );
                    actualCarName = matchedCar.name;
                  } catch (_) {
                    // Not found, use original
                  }
                  
                  vehicleCountMap[actualCarName] = (vehicleCountMap[actualCarName] ?? 0) + 1;
                } else {
                  // ✅ Safeguard: ensure it's not a known car
                  final isCar = masterData.cars.any((c) {
                        final cn = c.name;
                        final cl = c.licensePlate;
                        final mn = member.name;
                        if (cn == mn || cl == mn) return true;
                        if (cn.isNotEmpty && mn.contains(cn)) return true;
                        if (cl.isNotEmpty && mn.contains(cl)) return true;
                        if (mn.isNotEmpty && cn.contains(mn)) return true;
                        if (mn.isNotEmpty && cl.contains(mn)) return true;
                        return false;
                  });
                  if (!isCar) {
                    driverCountMap[member.name] = (driverCountMap[member.name] ?? 0) + 1;
                  }
                }
              }
            }

            // Convert to format expected by _buildStatsList
            final drivers = driverCountMap.entries.map((e) => {
              'name': e.key,
              'count': e.value,
              'percentage': totalJobs > 0 ? (e.value / totalJobs * 100) : 0.0
            }).toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

            final vehicles = vehicleCountMap.entries.map((e) => {
              'name': e.key,
              'count': e.value,
              'percentage': totalJobs > 0 ? (e.value / totalJobs * 100) : 0.0
            }).toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));


            return TabBarView(
              children: [
                _buildStatsList(drivers, totalJobs, 'พนักงาน'),
                _buildStatsList(vehicles, totalJobs, 'รถขนส่ง'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsList(List<dynamic> items, int totalJobs, String label) {
    if (items.isEmpty) {
      return const Center(child: Text('ไม่มีข้อมูลในหมวดนี้'));
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          color: Colors.indigo.shade50,
          child: Column(
            children: [
              Text(
                '$totalJobs',
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo),
              ),
              Text('จำนวนงานทั้งหมดที่วิเคราะห์ ($label)',
                  style: const TextStyle(color: Colors.indigo)),
              const SizedBox(height: 4),
              const Text(
                '* ข้อมูลคำนวณจากประวัติการส่งของทั้งหมดในฐานข้อมูล MySQL',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final String name = item['name'] ?? 'ไม่ระบุ';
              final int count = item['count'] ?? 0;
              final double percentage =
                  (item['percentage'] as num?)?.toDouble() ?? 0.0;

              return _buildStatCard(index + 1, name, count, percentage / 100);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(int rank, String name, int count, double percent) {
    // กำหนดชุดสีพาสเทล 4 สี
    final List<Color> pastelColors = [
      Colors.red.shade200,
      Colors.orange.shade200,
      Colors.green.shade200,
      Colors.blue.shade200,
    ];

    // เลือกสีโดยวนลูปตามลำดับ
    Color barColor = pastelColors[(rank - 1) % pastelColors.length];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: barColor), // ✅ ไม่จำเป็นต้องกำหนด alpha 1.0
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('$count งาน',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade100,
                    color: barColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
