import 'package:flutter/material.dart';
import 'package:s_link/features/hr/screens/attendance_screen.dart';

class GasStationView extends StatelessWidget {
  const GasStationView({super.key});

  @override
  Widget build(BuildContext context) {
    return const AttendanceScreen(showLogoutButton: true);
  }
}
