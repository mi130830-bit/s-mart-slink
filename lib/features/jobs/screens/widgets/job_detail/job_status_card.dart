import 'package:flutter/material.dart';
import 'package:s_link/features/jobs/models/job.dart';

class JobStatusCard extends StatelessWidget {
  final Job job;
  final String? driverName;
  final bool canApprove;

  const JobStatusCard({
    super.key,
    required this.job,
    this.driverName,
    required this.canApprove,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = job.status == 'completed';

    Color cardColor;
    String text;
    IconData icon;

    if (isCompleted) {
      cardColor = Colors.grey;
      text = 'ส่งสำเร็จเรียบร้อย';
      icon = Icons.check_circle;
    } else if (!job.isDepartureApproved) {
      cardColor = Colors.purple;
      text = 'รอแอดมินอนุมัติออกส่ง (กำลังขึ้นของ)';
      icon = Icons.hourglass_top;
    } else {
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
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cardColor)),
          if (!job.isDepartureApproved && !isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                canApprove ? '(ตรวจสอบความเรียบร้อยแล้วกดปุ่มด้านล่าง)' : '(กรุณารอการอนุมัติปล่อยรถจากเจ้าหน้าที่)',
                style: TextStyle(fontSize: 12, color: cardColor),
              ),
            ),
        ],
      ),
    );
  }
}
