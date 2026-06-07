import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/hr/screens/attendance_screen.dart';

class GasStationView extends StatelessWidget {
  const GasStationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('พนักงานปั้ม (ลงเวลา)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthenticationProvider>().logout();
            },
          ),
        ],
      ),
      body: const AttendanceScreen(), // Reuse the existing attendance screen
    );
  }
}
