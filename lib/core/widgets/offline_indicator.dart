// ไฟล์: lib/widgets/offline_indicator.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineIndicatorWrapper extends StatefulWidget {
  final Widget child;
  const OfflineIndicatorWrapper({super.key, required this.child});

  @override
  State<OfflineIndicatorWrapper> createState() =>
      _OfflineIndicatorWrapperState();
}

class _OfflineIndicatorWrapperState extends State<OfflineIndicatorWrapper> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    // 1. เช็คสถานะเริ่มต้น
    _checkInitialStatus();

    // 2. เริ่มฟังการเปลี่ยนแปลง (เน็ตหลุด/เน็ตมา)
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  Future<void> _checkInitialStatus() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // ถ้าผลลัพธ์มี none แสดงว่าไม่มีเน็ต (หรือถ้า List ว่างเปล่า)
    final isNowOffline = results.contains(ConnectivityResult.none);

    if (_isOffline != isNowOffline) {
      if (mounted) {
        setState(() => _isOffline = isNowOffline);
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: widget.child),

        // ส่วนแสดงผลแถบแจ้งเตือน (จะโผล่มาเฉพาะตอน Offline)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isOffline ? 32 : 0, // ยืดหดได้
          color: Colors.redAccent,
          width: double.infinity,
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'ขาดการเชื่อมต่อ - ใช้งานโหมดออฟไลน์',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
