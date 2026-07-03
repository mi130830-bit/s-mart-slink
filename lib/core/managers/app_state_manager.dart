// ไฟล์: lib/managers/app_state_manager.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/jobs/providers/job_provider.dart';
import 'package:s_link/features/master_data/providers/master_data_provider.dart';
import 'package:s_link/features/alerts/providers/alert_log_provider.dart';
import '../config/app_constants.dart';

class AppStateManager {
  bool _isListenersSetup = false;

  void manageDataListeners(BuildContext context) {
    // ใช้ Provider.of(listen: false) เพราะเราเรียกใน callback ไม่ใช่ใน build
    final authProvider =
        Provider.of<AuthenticationProvider>(context, listen: false);
    final jobProvider = Provider.of<JobProvider>(context, listen: false);
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    final alertLogProvider =
        Provider.of<AlertLogProvider>(context, listen: false);

    if (authProvider.isAuthenticated && !authProvider.isLoading) {
      if (_isListenersSetup) return;

      final user = authProvider.currentUser;
      final role = user?.role.name.toLowerCase();

      if (role == AppConstants.rolePending) return;
      // พนักงานปั้ม ไม่ต้องรับข้อมูลใดๆ เพิ่มเติม (ใช้แค่หน้าลงเวลาเข้างาน)
      if (role == 'gas_station' || role == 'gasstation') return;

      log('Starting data listeners for role: $role');

      if (user != null) {
        // Topic subscriptions handled by UserService._handlePostLogin
        jobProvider.startListeningToJobs(user);
        alertLogProvider.startListeningToAlertsAndLogs(role);
      }
      masterDataProvider.startListeningToMasterData();

      _isListenersSetup = true;
    } else {
      // User Logout หรือยังไม่ Login
      if (_isListenersSetup) {
        log('Stopping all listeners...');
        jobProvider.stopListening();
        masterDataProvider.stopListening();
        alertLogProvider.stopListening();
        _isListenersSetup = false;
      }
    }
  }
}
