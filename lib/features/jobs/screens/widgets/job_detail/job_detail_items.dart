import 'package:flutter/material.dart';
import 'package:s_link/features/jobs/models/job.dart';

class JobDetailItems extends StatelessWidget {
  final Job job;
  final Function(String) onOpenImage;

  const JobDetailItems({
    super.key,
    required this.job,
    required this.onOpenImage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (job.items.isNotEmpty) ...[
              Builder(builder: (context) {
                String? note;
                if (job.details != null && job.details!.isNotEmpty) {
                  final lines = job.details!.split('\n');
                  if (lines.isNotEmpty) {
                    final first = lines.first.trim();
                    if (first.isNotEmpty && !first.startsWith('-')) {
                      note = first;
                    }
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_note, color: Colors.brown),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                note,
                                style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ...job.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            Text(
                              'x${item.qty % 1 == 0 ? item.qty.toInt() : item.qty.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              }),
            ] else ...[
              if (job.details != null && job.details!.isNotEmpty)
                Text(job.details!, style: const TextStyle(fontSize: 16)),
            ],
            if (job.price != null && job.price! > 0) ...[
              const SizedBox(height: 10),
              const Divider(),
              Text(
                'ยอดเก็บเงิน (COD): ฿${job.price!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
            if (job.billImageUrl != null) ...[
              const SizedBox(height: 10),
              const Text('รูปบิล/ใบสั่งของ:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 5),
              GestureDetector(
                onTap: () => onOpenImage(job.billImageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(job.billImageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
