import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/jobs/screens/job_detail_screen.dart';

class PickupJobCard extends StatelessWidget {
  final Job job;

  const PickupJobCard({
    super.key,
    required this.job,
  });

  @override
  Widget build(BuildContext context) {
    final minutesElapsed = DateTime.now().difference(job.createdAt).inMinutes;
    final minutesLeft = 60 - minutesElapsed;
    final bool isCritical = minutesLeft < 15;

    return Card(
      elevation: 3,
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.purple.withValues(alpha: 0.1),
                    child: const Icon(Icons.store, color: Colors.purple),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.customer.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        if (job.customer.phoneNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '📞 ${job.customer.phoneNumber}',
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'รับเอง',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${DateFormat('HH:mm').format(job.createdAt)} น.',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Items List ──────────────────────────────────────
              if (job.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2,
                              size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'รายการสินค้า (${job.items.length} รายการ)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...job.items.map((item) {
                        final qty = item.qty % 1 == 0
                            ? item.qty.toInt().toString()
                            : item.qty.toStringAsFixed(1);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '• ${item.name}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              Text(
                                'x$qty',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ] else if (job.details != null && job.details!.isNotEmpty) ...[
                // Fallback: show raw details text if no items
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    job.details!,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],

              // ── Note ─────────────────────────────────────────
              if (job.details != null && job.details!.isNotEmpty && job.items.isNotEmpty)
                _buildNoteFromDetails(job.details!),

              // ── Footer: Timer ────────────────────────────────
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer,
                          size: 16,
                          color: isCritical ? Colors.red : Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        minutesLeft <= 0
                            ? 'หมดเวลา (จะถูกลบเร็วๆ นี้)'
                            : 'ลบอัตโนมัติใน: $minutesLeft นาที',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCritical ? Colors.red : Colors.orange,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'แตะเพื่อดูรายละเอียด',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ดึงบรรทัดแรกของ details ที่ไม่ใช่ item (เป็น note/หมายเหตุ)
  Widget _buildNoteFromDetails(String details) {
    final lines = details.split('\n');
    if (lines.isEmpty) return const SizedBox.shrink();
    final firstLine = lines.first.trim();
    if (firstLine.isEmpty || firstLine.startsWith('-')) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_note, size: 16, color: Colors.brown),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                firstLine,
                style: const TextStyle(
                    color: Colors.brown, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
