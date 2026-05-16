// ไฟล์: lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/auth/screens/login_screen.dart';

// Import Dashboard ต่างๆ
import 'package:s_link/features/dashboard/screens/admin_dashboard.dart';
import 'package:s_link/features/dashboard/screens/requester_view.dart';
import 'package:s_link/features/dashboard/screens/driver_view.dart';

// Import Service & Shop Menu
import 'package:s_link/core/services/version_check_service.dart';
import 'package:s_link/features/pos/screens/shop_menu_screen.dart';
import 'package:s_link/features/settings/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // สั่งเช็คเวอร์ชันทันทีที่หน้านี้ถูกโหลด
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionCheckService.checkVersion(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final user = authProvider.currentUser;

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return const LoginScreen();
    }

    final roleName = user.role.name.toLowerCase();

    if (roleName == 'admin' || roleName == 'requester') {
      // ✅ Admin & Requester get Hybrid View (Delivery + POS)
      return PosNavigationWrapper(
        child: roleName == 'admin'
            ? const AdminDashboard()
            : const RequesterView(),
      );
    } else if (roleName == 'driver') {
      return const DriverView();
    } else if (roleName == 'pending') {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
              SizedBox(height: 20),
              Text('บัญชีของคุณกำลังรอการอนุมัติ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('กรุณาติดต่อ Admin เพื่อเปิดใช้งาน',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Unknown Role')),
        body: Center(
          child: Text('ไม่พบสิทธิ์การใช้งานสำหรับ: $roleName'),
        ),
      );
    }
  }
}

class PosNavigationWrapper extends StatefulWidget {
  final Widget child; // The original dashboard (Delivery)
  const PosNavigationWrapper({super.key, required this.child});

  @override
  State<PosNavigationWrapper> createState() => _PosNavigationWrapperState();
}

class _PosNavigationWrapperState extends State<PosNavigationWrapper> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Pages
    final pages = [
      widget.child, // 0: Dashboard (Delivery)
      const ShopMenuScreen(), // 1: Shop Menu (POS, Price, Stock)
      const SettingsScreen(), // 2: Settings (Configuration)
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'ส่งของ (Delivery)',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'หน้าร้าน (Shop)',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'ตั้งค่า (Settings)',
          ),
        ],
      ),
    );
  }
}
