// ไฟล์: lib/screens/jobs/map_picker_screen.dart

import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _pickedLocation;
  late final MapController _mapController;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.initialLat != null && widget.initialLng != null) {
      // กรณีแก้ไข: ใช้พิกัดเดิมที่ส่งมา
      _pickedLocation = LatLng(widget.initialLat!, widget.initialLng!);
    } else {
      // กรณีสร้างใหม่: ให้วิ่งหา GPS ปัจจุบันทันที
      _determinePosition();
    }
  }

  // ✅ ฟังก์ชันหาพิกัดปัจจุบัน (แก้ไข Deprecated timeLimit)
  Future<void> _determinePosition() async {
    setState(() => _isLoadingLocation = true);

    bool serviceEnabled;
    LocationPermission permission;

    // 1. เช็คว่าเปิด GPS หรือยัง
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        SnackbarUtils.showLeft(context, 'กรุณาเปิด GPS');
      }
      return;
    }

    // 2. เช็ค Permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    // 3. อ่านพิกัดปัจจุบัน (ใส่ Timeout กันค้าง)
    try {
      // 🛠️ แก้ไขตรงนี้: ใช้ locationSettings แทน timeLimit โดยตรง
      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        currentPosition = await Geolocator.getLastKnownPosition();
      }

      if (currentPosition == null) throw 'ไม่สามารถระบุตำแหน่งได้';

      if (mounted) {
        _mapController.move(
          LatLng(currentPosition.latitude, currentPosition.longitude),
          15.0, // Zoom Level
        );
        setState(() {
          _pickedLocation =
              LatLng(currentPosition!.latitude, currentPosition.longitude);
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        SnackbarUtils.showLeft(context, 'ไม่สามารถระบุตำแหน่งปัจจุบันได้');
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _confirmSelection() {
    if (_pickedLocation != null) {
      Navigator.pop(context, _pickedLocation);
    } else {
      SnackbarUtils.showLeft(context, 'กรุณาแตะที่แผนที่เพื่อเลือกจุด');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter =
        (widget.initialLat != null && widget.initialLng != null)
            ? LatLng(widget.initialLat!, widget.initialLng!)
            : const LatLng(13.7563, 100.5018); // Default Bangkok

    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกตำแหน่งบนแผนที่'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirmSelection,
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _pickedLocation = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://mt1.google.com/vt/lyrs=m&hl=th&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.sorbolikan.slink',
              ),
              if (_pickedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickedLocation!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ปุ่มกลับมาตำแหน่งปัจจุบัน
          Positioned(
            right: 20,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'current_location_btn',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _isLoadingLocation ? null : _determinePosition,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirmSelection,
        icon: const Icon(Icons.check),
        label: const Text('ยืนยันจุดนี้'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
