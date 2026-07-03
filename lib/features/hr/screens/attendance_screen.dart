import 'package:s_link/utils/snackbar_utils.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'dart:developer';

class AttendanceScreen extends StatefulWidget {
  final bool showLogoutButton;
  
  const AttendanceScreen({super.key, this.showLogoutButton = false});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _service = AttendanceService();
  AttendanceLog? _todayLog;
  bool _isLoading = true;
  String _timeString = '';
  Timer? _timer;
  // พิกัดร้านโหลดจาก Firestore config/mobile_app โดย AttendanceService
  // (ไม่ต้อง hardcode ที่นี่อีกต่อไป)

  @override
  void initState() {
    super.initState();
    _timeString = _formatDateTime(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());

    // ฟัง AuthProvider ก่อน — ถ้า Auth ยังโหลดอยู่ (currentUser == null)
    // รอให้ Auth เสร็จแล้วค่อยโหลด log อีกรอบ
    Future.microtask(() {
      if (!mounted) return;
      final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
      if (authProvider.isLoading || authProvider.currentUser == null) {
        // รอ auth พร้อมผ่าน listener
        authProvider.addListener(_onAuthReady);
      } else {
        _loadTodayLog();
      }
    });
  }

  void _onAuthReady() {
    final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
    if (!authProvider.isLoading) {
      authProvider.removeListener(_onAuthReady);
      _loadTodayLog();
    }
  }

  void _getTime() {
    if (mounted) {
      setState(() {
        _timeString = _formatDateTime(DateTime.now());
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('HH:mm:ss').format(dt);
  }

  Future<void> _loadTodayLog() async {
    if (!mounted) return;
    final user = Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user != null) {
      try {
        final log = await _service.getTodayLog(user.id)
            .timeout(const Duration(seconds: 15));
        if (mounted) {
          setState(() {
            _todayLog = log;
            _isLoading = false;
          });
        }
      } catch (e) {
        log('AttendanceScreen: Error loading today log: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          SnackbarUtils.showLeft(context, 'โหลดข้อมูลไม่สำเร็จ: ${e.toString().contains('TimeoutException') ? 'เชื่อมต่อช้า กรุณาลองใหม่' : e.toString()}', isError: true);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showLeft(context, 'ไม่พบข้อมูลผู้ใช้ กรุณาล็อกอินใหม่', isError: true);
      }
    }
  }

  Future<Position?> _checkLocation() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('กรุณาเปิด GPS (Location Services)')));
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง')));
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('สิทธิ์ถูกปฏิเสธถาวร กรุณาไปเปิดในตั้งค่าระบบ')));
      return null;
    } 

    // ดึงพิกัดร้านจาก Firestore (cache 30 นาที)
    scaffoldMessenger.showSnackBar(const SnackBar(
      content: Text('กำลังตรวจสอบพิกัดร้าน...'),
      duration: Duration(seconds: 2),
    ));
    final storeConfig = await _service.getStoreConfig();
    final storeLat = storeConfig['lat']!;
    final storeLng = storeConfig['lng']!;
    final maxDistance = storeConfig['maxDistance']!;

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    
    double distanceInMeters = Geolocator.distanceBetween(
      storeLat, storeLng, position.latitude, position.longitude
    );

    if (distanceInMeters > maxDistance) {
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('คุณไม่ได้อยู่ที่ร้าน! (ระยะห่าง ${distanceInMeters.toStringAsFixed(0)} เมตร, สูงสุด ${maxDistance.toStringAsFixed(0)} เมตร)'),
        duration: const Duration(seconds: 4),
      ));
      return null;
    }

    return position;
  }

  // เตรียมโครงถ่ายเซลฟี่ (ยังไม่เปิดใช้งาน)
  // Future<String?> _takeSelfie() async {
  //   // final ImagePicker picker = ImagePicker();
  //   // final XFile? image = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
  //   // return image?.path;
  //   return null;
  // }

  Future<void> _handleCheckIn() async {
    final user = Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user == null) return;

    final pos = await _checkLocation();
    if (pos == null) return; // ไม่ผ่านเรื่องระยะทางหรือ GPS

    // final selfiePath = await _takeSelfie(); // รอเปิดใช้งานในอนาคต

    final log = AttendanceLog(
      id: '',
      userId: user.id,
      userName: user.name,
      checkInTime: DateTime.now(),
      checkInLat: pos.latitude,
      checkInLng: pos.longitude,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      status: 'PRESENT',
    );

    setState(() => _isLoading = true);
    await _service.checkIn(log);
    await _loadTodayLog();
  }

  Future<void> _handleCheckOut() async {
    final user = Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user == null || _todayLog == null) return;

    final pos = await _checkLocation();
    if (pos == null) return;

    setState(() => _isLoading = true);
    await _service.checkOut(user.id, pos.latitude, pos.longitude);
    await _loadTodayLog();
  }

  Future<void> _handleTempOut() async {
    final user = Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user == null || _todayLog == null) return;

    final pos = await _checkLocation();
    if (pos == null) return;

    setState(() => _isLoading = true);
    await _service.tempOut(user.id, pos.latitude, pos.longitude);
    await _loadTodayLog();
  }

  Future<void> _handleBackToWork() async {
    final user = Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user == null || _todayLog == null) return;

    final pos = await _checkLocation();
    if (pos == null) return;

    setState(() => _isLoading = true);
    await _service.backToWork(user.id, pos.latitude, pos.longitude);
    await _loadTodayLog();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // ล้าง listener กัน memory leak ถ้า widget ถูก dispose ก่อน auth เสร็จ
    try {
      Provider.of<AuthenticationProvider>(context, listen: false)
          .removeListener(_onAuthReady);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ลงเวลาเข้างาน'),
        actions: widget.showLogoutButton 
          ? [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => context.read<AuthenticationProvider>().logout(),
              )
            ]
          : null,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()), style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              Text(_timeString, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              
              if (_todayLog == null || _todayLog!.checkInTime == null)
                ElevatedButton.icon(
                  onPressed: _handleCheckIn,
                  icon: const Icon(Icons.login, size: 32),
                  label: const Text('กดเข้างาน', style: TextStyle(fontSize: 24)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                )
              else if (_todayLog!.checkOutTime == null)
                Column(
                  children: [
                    Text('เข้างานเมื่อ: ${_formatDateTime(_todayLog!.checkInTime!)}', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                    if (_todayLog!.tempOutTime != null) ...[
                      const SizedBox(height: 10),
                      Text('ออกชั่วคราวเมื่อ: ${_formatDateTime(_todayLog!.tempOutTime!)}', style: const TextStyle(fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold)),
                    ],
                    if (_todayLog!.backToWorkTime != null) ...[
                      const SizedBox(height: 10),
                      Text('กลับเข้างานเมื่อ: ${_formatDateTime(_todayLog!.backToWorkTime!)}', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 40),
                    
                    if (_todayLog!.tempOutTime == null) ...[
                      ElevatedButton.icon(
                        onPressed: _handleTempOut,
                        icon: const Icon(Icons.directions_run, size: 32),
                        label: const Text('ออกชั่วคราว', style: TextStyle(fontSize: 24)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else if (_todayLog!.backToWorkTime == null) ...[
                      ElevatedButton.icon(
                        onPressed: _handleBackToWork,
                        icon: const Icon(Icons.keyboard_return, size: 32),
                        label: const Text('กลับเข้างาน', style: TextStyle(fontSize: 24)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    ElevatedButton.icon(
                      onPressed: _handleCheckOut,
                      icon: const Icon(Icons.logout, size: 32),
                      label: const Text('กดออกงาน', style: TextStyle(fontSize: 24)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 64),
                    const SizedBox(height: 10),
                    const Text('วันนี้คุณลงเวลาครบแล้ว', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('เข้างาน: ${_formatDateTime(_todayLog!.checkInTime!)}', style: const TextStyle(fontSize: 16)),
                    if (_todayLog!.tempOutTime != null)
                      Text('ออกชั่วคราว: ${_formatDateTime(_todayLog!.tempOutTime!)}', style: const TextStyle(fontSize: 16)),
                    if (_todayLog!.backToWorkTime != null)
                      Text('กลับเข้างาน: ${_formatDateTime(_todayLog!.backToWorkTime!)}', style: const TextStyle(fontSize: 16)),
                    Text('ออกงาน: ${_formatDateTime(_todayLog!.checkOutTime!)}', style: const TextStyle(fontSize: 16)),
                  ],
                )
            ],
          ),
        ),
    );
  }
}
