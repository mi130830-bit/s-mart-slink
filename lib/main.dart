// ไฟล์: lib/main.dart (ฉบับแก้ไขและสมบูรณ์)

//import 'dart:developer';
import 'dart:io';
import 'package:in_app_update/in_app_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'core/config/app_constants.dart';
import 'core/services/startup_service.dart';
import 'core/managers/app_state_manager.dart';

// Import Services & Providers
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/user_service.dart';
import 'features/jobs/services/job_service.dart';
import 'core/services/master_data_service.dart';
import 'features/alerts/services/alert_log_service.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/jobs/providers/job_provider.dart';
import 'features/master_data/providers/master_data_provider.dart';
import 'features/alerts/providers/alert_log_provider.dart';
import 'core/providers/theme_provider.dart'; // Core
import 'features/admin/providers/export_provider.dart'; // Admin feature
import 'features/pos/providers/cart_provider.dart'; // POS Remote Feature

// Screens
import 'features/home/screens/home_screen.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Logic การ Init ย้ายไป StartupService
  await StartupService.initializeApp();
  runApp(const RootAppSetup());
}

class RootAppSetup extends StatelessWidget {
  const RootAppSetup({super.key});

  @override
  Widget build(BuildContext context) {
    // Instantiate Services
    final AuthService authService = AuthService();
    final UserService userService = UserService();
    final JobService jobService = JobService();
    final MasterDataService masterDataService = MasterDataService();
    final AlertLogService alertLogService = AlertLogService();
    // final LocationService locationService = LocationService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthenticationProvider(authService, userService)),
        ChangeNotifierProvider(create: (_) => JobProvider(jobService)),
        ChangeNotifierProvider(
            create: (_) => MasterDataProvider(masterDataService)),
        ChangeNotifierProvider(
            create: (_) => AlertLogProvider(alertLogService)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
            create: (_) => ExportProvider(jobService, masterDataService)),
        // POS Feature
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppStateManager _appStateManager;
  String? _lastUserId;
  bool _isFirstRun = true;

  @override
  void initState() {
    super.initState();
    _appStateManager = AppStateManager();
    _checkForUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ ป้องกัน Loop: เรียก Manager เฉพาะเมื่อ User เปลี่ยน หรือรันครั้งแรก
    final authProvider =
        Provider.of<AuthenticationProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid;

    if (_isFirstRun || _lastUserId != currentUserId) {
      _isFirstRun = false;
      _lastUserId = currentUserId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _appStateManager.manageDataListeners(context);
      });
    }
  }

  Future<void> _checkForUpdate() async {
    if (kDebugMode) return;

    if (Platform.isAndroid) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable &&
            info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      } catch (e) {
        debugPrint('InAppUpdate Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey.shade50,
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
        ),
      ),
      home: _buildHome(authProvider),
    );
  }

  Widget _buildHome(AuthenticationProvider authProvider) {
    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (authProvider.isAuthenticated) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
