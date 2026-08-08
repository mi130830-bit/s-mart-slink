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
  Timer? _autoPollTimer;
  bool _isPollingServer = false;
  // พิกัดร้านโหลดจาก Firestore config/mobile_app โดย AttendanceService
  // (ไม่ต้อง hardcode ที่นี่อีกต่อไป)

  @override
  void initState() {
    super.initState();
    _timeString = _formatDateTime(DateTime.now());
    _timer =
        Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
    // POS writes attendance directly to the backend, so refresh the local
    // Isar cache regularly while this screen is open.
    _autoPollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _pollServer());

    // Safety fallback: ป้องกันกรณีหมุนค้างนานเกิน 10 วินาที ให้ปลดหมุนและแจ้งเตือนทันที
    Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

    // ฟัง AuthProvider ก่อน — ถ้า Auth ยังโหลดอยู่ ให้รอผ่าน listener
    // ถ้า Auth โหลดเสร็จแล้ว ให้เรียก _loadTodayLog() ทันที (ไม่ค้างรอถ้า currentUser == null)
    Future.microtask(() {
      if (!mounted) return;
      final authProvider =
          Provider.of<AuthenticationProvider>(context, listen: false);
      if (authProvider.isLoading) {
        authProvider.addListener(_onAuthReady);
      } else {
        _loadTodayLog();
      }
    });
  }

  void _onAuthReady() {
    final authProvider =
        Provider.of<AuthenticationProvider>(context, listen: false);
    if (!authProvider.isLoading) {
      authProvider.removeListener(_onAuthReady);
      _loadTodayLog();
    }
  }

  Future<void> _pollServer() async {
    if (!mounted || _isPollingServer) return;
    final user =
        Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user == null) return;

    _isPollingServer = true;
    try {
      await _service.fetchTodayLogFromServer(user.id);
    } finally {
      _isPollingServer = false;
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

  StreamSubscription<AttendanceLog?>? _logSub;

  Future<void> _loadTodayLog() async {
    if (!mounted) return;
    final user =
        Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user != null) {
      _logSub?.cancel();
      _logSub = _service.todayLogStream(user.id).listen((logData) {
        if (mounted) {
          setState(() {
            _todayLog = logData;
            _isLoading = false;
          });
        }
      }, onError: (e) {
        log('AttendanceScreen: Error loading today log stream: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          SnackbarUtils.showLeft(
              context, 'เกิดข้อผิดพลาดในการดึงข้อมูล: ${e.toString()}',
              isError: true);
        }
      });
      // Subscribe first so the write below immediately updates the UI, then
      // fetch the authoritative record from POS instead of waiting for a tap.
      await _pollServer();
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showLeft(context, 'ไม่พบข้อมูลผู้ใช้ กรุณาล็อกอินใหม่',
            isError: true);
      }
    }
  }

  Future<Position?> _checkLocation() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('กรุณาเปิด GPS (Location Services)')));
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง')));
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('สิทธิ์ถูกปฏิเสธถาวร กรุณาไปเปิดในตั้งค่าระบบ')));
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
        storeLat, storeLng, position.latitude, position.longitude);

    if (distanceInMeters > maxDistance) {
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(
            'คุณไม่ได้อยู่ที่ร้าน! (ระยะห่าง ${distanceInMeters.toStringAsFixed(0)} เมตร, สูงสุด ${maxDistance.toStringAsFixed(0)} เมตร)'),
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
    final user =
        Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user == null) return;

    final pos = await _checkLocation();
    if (pos == null) return; // ไม่ผ่านเรื่องระยะทางหรือ GPS

    final logData = AttendanceLog(
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
    try {
      await _service.checkIn(logData);
      await _loadTodayLog();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showLeft(context, 'บันทึกข้อมูลไม่สำเร็จ: $e',
            isError: true);
      }
    }
  }

  Future<void> _handleCheckOut() async {
    final user =
        Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user == null || _todayLog == null) return;

    final pos = await _checkLocation();
    if (pos == null) return;

    setState(() => _isLoading = true);
    try {
      await _service.checkOut(user.id, pos.latitude, pos.longitude);
      await _loadTodayLog();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showLeft(context, 'บันทึกข้อมูลไม่สำเร็จ: $e',
            isError: true);
      }
    }
  }

  Future<void> _handleTempOut() async {
    final user =
        Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user == null || _todayLog == null) return;

    final pos = await _checkLocation();
    if (pos == null) return;

    setState(() => _isLoading = true);
    try {
      await _service.tempOut(user.id, pos.latitude, pos.longitude);
      await _loadTodayLog();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showLeft(context, 'บันทึกข้อมูลไม่สำเร็จ: $e',
            isError: true);
      }
    }
  }

  Future<void> _handleBackToWork() async {
    final user =
        Provider.of<AuthenticationProvider>(context, listen: false).currentUser;
    if (user == null || _todayLog == null) return;

    final pos = await _checkLocation();
    if (pos == null) return;

    setState(() => _isLoading = true);
    try {
      await _service.backToWork(user.id, pos.latitude, pos.longitude);
      await _loadTodayLog();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showLeft(context, 'บันทึกข้อมูลไม่สำเร็จ: $e',
            isError: true);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoPollTimer?.cancel();
    _logSub?.cancel();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'ซิงค์ข้อมูลล่าสุด',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('กำลังดึงข้อมูลล่าสุด...'),
                  duration: Duration(seconds: 1),
                ),
              );
              await _pollServer();
            },
          ),
          if (widget.showLogoutButton)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'ออกจากระบบ',
              onPressed: () => context.read<AuthenticationProvider>().logout(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _pollServer();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          DateFormat('EEEE, d MMMM yyyy')
                              .format(DateTime.now()),
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 10),
                      Text(_timeString,
                          style: const TextStyle(
                              fontSize: 48, fontWeight: FontWeight.bold)),
                      if (_todayLog != null && !_todayLog!.isSynced) ...[
                        const SizedBox(height: 16),
                        const Card(
                          color: Color(0xFFFFF3CD),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            child: Text(
                              'บันทึกในเครื่องแล้ว กำลังรอซิงก์กับ POS',
                              style: TextStyle(color: Color(0xFF664D03)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      if (_todayLog == null || _todayLog!.checkInTime == null)
                        ElevatedButton.icon(
                          onPressed: _handleCheckIn,
                          icon: const Icon(Icons.login, size: 32),
                          label: const Text('กดเข้างาน',
                              style: TextStyle(fontSize: 24)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                        )
                      else if (_todayLog!.checkOutTime == null)
                        Column(
                          children: [
                            Text(
                                'เข้างานเมื่อ: ${_formatDateTime(_todayLog!.checkInTime!)}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                            if (_todayLog!.tempOutTime != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                  'ออกชั่วคราวเมื่อ: ${_formatDateTime(_todayLog!.tempOutTime!)}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            ],
                            if (_todayLog!.backToWorkTime != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                  'กลับเข้างานเมื่อ: ${_formatDateTime(_todayLog!.backToWorkTime!)}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                            ],
                            const SizedBox(height: 40),
                            if (_todayLog!.tempOutTime == null) ...[
                              ElevatedButton.icon(
                                onPressed: _handleTempOut,
                                icon:
                                    const Icon(Icons.directions_run, size: 32),
                                label: const Text('ออกชั่วคราว',
                                    style: TextStyle(fontSize: 24)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 20),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ] else if (_todayLog!.backToWorkTime == null) ...[
                              ElevatedButton.icon(
                                onPressed: _handleBackToWork,
                                icon:
                                    const Icon(Icons.keyboard_return, size: 32),
                                label: const Text('กลับเข้างาน',
                                    style: TextStyle(fontSize: 24)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 20),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            ElevatedButton.icon(
                              onPressed: _handleCheckOut,
                              icon: const Icon(Icons.logout, size: 32),
                              label: const Text('กดออกงาน',
                                  style: TextStyle(fontSize: 24)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 20),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 64),
                            const SizedBox(height: 10),
                            const Text('วันนี้คุณลงเวลาครบแล้ว',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Text(
                                'เข้างาน: ${_formatDateTime(_todayLog!.checkInTime!)}',
                                style: const TextStyle(fontSize: 16)),
                            if (_todayLog!.tempOutTime != null)
                              Text(
                                  'ออกชั่วคราว: ${_formatDateTime(_todayLog!.tempOutTime!)}',
                                  style: const TextStyle(fontSize: 16)),
                            if (_todayLog!.backToWorkTime != null)
                              Text(
                                  'กลับเข้างาน: ${_formatDateTime(_todayLog!.backToWorkTime!)}',
                                  style: const TextStyle(fontSize: 16)),
                            Text(
                                'ออกงาน: ${_formatDateTime(_todayLog!.checkOutTime!)}',
                                style: const TextStyle(fontSize: 16)),
                          ],
                        )
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
