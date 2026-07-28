import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_link/features/pos/services/promptpay_helper.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';

/// โมเดลที่เก็บ Config QR จาก POS Desktop (via API)
class _PaymentConfig {
  final String promptPayId;
  final String qrMode; // 'dynamic' | 'static'
  final Uint8List? staticQrImage; // decode จาก base64

  const _PaymentConfig({
    required this.promptPayId,
    required this.qrMode,
    this.staticQrImage,
  });

  // Smart Fallback: เป็น Static ถ้าระบุโหมด static มีรูป หรือโหมด dynamic แต่ไม่มี ID แล้วมีรูปแทน
  bool get isStatic => (qrMode == 'static' && staticQrImage != null) ||
      (qrMode == 'dynamic' && promptPayId.isEmpty && staticQrImage != null);

  bool get hasDynamic => promptPayId.isNotEmpty;
  
  bool get isNativeDynamic => qrMode == 'dynamic' && promptPayId.isNotEmpty;
}

/// หน้าแสดง QR PromptPay แบบ Fullscreen สำหรับคนขับรถเก็บเงินปลายทาง (COD)
///
/// ดึง Config จาก POS Desktop API (GET /api/v1/config/promptpay):
///   - Static mode: แสดงรูป QR คงที่ที่ Admin อัปโหลดผ่าน POS Desktop
///   - Dynamic mode: สร้าง QR จาก PromptPay ID + ล็อคยอด COD อัตโนมัติ
///
/// Fallback: ถ้าเชื่อมต่อ API ไม่ได้ → ดึง promptpay_id จาก SharedPreferences
class DriverQrScreen extends StatefulWidget {
  /// ยอด COD ที่ต้องเก็บ (จาก Job) — null = ไม่มียอด
  final double? codAmount;

  /// ชื่อลูกค้า (สำหรับแสดงบนหน้าจอ)
  final String? customerName;

  const DriverQrScreen({
    super.key,
    this.codAmount,
    this.customerName,
  });

  @override
  State<DriverQrScreen> createState() => _DriverQrScreenState();
}

class _DriverQrScreenState extends State<DriverQrScreen>
    with SingleTickerProviderStateMixin {
  _PaymentConfig? _config;
  String? _qrPayload;
  bool _isLoading = true;
  String? _error;

  // ถ้า Admin ตั้ง Static แต่ Driver อยากสลับ Dynamic (ล็อคยอด) ชั่วคราว
  bool _forceDynamic = false;

  // Animation QR pulse
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // เปิด Fullscreen Mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadConfig();
  }

  @override
  void dispose() {
    // คืนค่า System UI กลับ
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1️⃣ ดึงจาก POS Desktop API (Single Source of Truth)
      final result = await PosApiService().getPaymentConfig();

      if (result != null) {
        final promptPayId = result['promptpay_id'] as String? ?? '';
        final qrMode = result['qr_mode'] as String? ?? 'dynamic';
        final base64Str = result['static_qr_base64'] as String?;

        Uint8List? imageBytes;
        if (base64Str != null && base64Str.isNotEmpty) {
          try {
            imageBytes = base64Decode(base64Str);
          } catch (_) {}
        }

        if (!mounted) return;

        final config = _PaymentConfig(
          promptPayId: promptPayId,
          qrMode: qrMode,
          staticQrImage: imageBytes,
        );

        if (!config.isStatic && !config.hasDynamic) {
          setState(() {
            _isLoading = false;
            _error = 'ตั้งค่าการรับเงินไม่สมบูรณ์\nกรุณาระบุ PromptPay ID หรือ อัปโหลดรูป QR ใน POS Desktop';
          });
          return;
        }

        setState(() {
          _config = config;
          _isLoading = false;
          // ถ้าเป็น dynamic แต่แรก ให้ล็อคยอด COD อัตโนมัติไปเลย
          _forceDynamic = _config!.isNativeDynamic;
        });
        _buildDynamicPayload();
        return;
      }
    } catch (_) {}

    // 2️⃣ Fallback: ดึงจาก SharedPreferences เครื่องตัวเอง
    final prefs = await SharedPreferences.getInstance();
    final localId = prefs.getString('promptpay_id') ?? '';

    if (!mounted) return;

    if (localId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'การเชื่อมต่อขัดข้อง\nและยังไม่ได้ตั้งค่า Local PromptPay';
      });
      return;
    }

    setState(() {
      _config = _PaymentConfig(
        promptPayId: localId,
        qrMode: 'dynamic',
      );
      _isLoading = false;
      _forceDynamic = true; // ล็อคยอดอัตโนมัติเมื่อใช้ Fallback dynamic
    });
    _buildDynamicPayload();
  }

  void _buildDynamicPayload() {
    if (_config == null || _config!.promptPayId.isEmpty) return;

    final hasCod = widget.codAmount != null && widget.codAmount! > 0;
    final lockAmount = _forceDynamic && hasCod;

    final payload = PromptPayHelper.generatePayload(
      _config!.promptPayId,
      amount: lockAmount ? widget.codAmount : null,
    );
    setState(() => _qrPayload = payload);
  }

  bool get _showStaticQr =>
      _config != null &&
      _config!.isStatic &&
      !_forceDynamic;

  @override
  Widget build(BuildContext context) {
    final hasCod = widget.codAmount != null && widget.codAmount! > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'QR รับเงิน',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'โหลดใหม่',
            onPressed: _loadConfig,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildContent(hasCod),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.tealAccent),
          SizedBox(height: 16),
          Text('กำลังโหลดการตั้งค่าจาก POS...',
              style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_2_outlined, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadConfig,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool hasCod) {
    return SafeArea(
      child: Column(
        children: [
          // --- Banner ลูกค้า ---
          if (widget.customerName != null && widget.customerName!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline,
                      color: Colors.tealAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ลูกค้า: ${widget.customerName}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

          // --- Badge Mode ---
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _showStaticQr
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.teal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _showStaticQr ? Colors.blue : Colors.tealAccent,
                width: 1,
              ),
            ),
            child: Text(
              _showStaticQr ? '📷 Static QR (จากร้าน)' : '⚡ Dynamic QR (สร้างอัตโนมัติ)',
              style: TextStyle(
                color: _showStaticQr ? Colors.blue : Colors.tealAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const Spacer(),

          // --- QR Card ---
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (_showStaticQr ? Colors.blue : Colors.tealAccent)
                          .withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                // Static: แสดงรูปจาก POS / Dynamic: สร้าง QR จาก payload
                child: _showStaticQr
                    ? Image.memory(
                        _config!.staticQrImage!,
                        width: 240,
                        height: 240,
                        fit: BoxFit.contain,
                      )
                    : (_qrPayload != null
                        ? QrImageView(
                            data: _qrPayload!,
                            version: QrVersions.auto,
                            size: 240,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF1A237E),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: Color(0xFF1A237E),
                            ),
                          )
                        : const SizedBox(
                            width: 240,
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          )),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- Label ---
          const Text(
            'พร้อมเพย์',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),

          // --- ยอดเงิน ---
          if (hasCod) ...[
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: _forceDynamic
                    ? Colors.tealAccent.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: _forceDynamic ? Colors.tealAccent : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _forceDynamic ? Icons.lock : Icons.lock_open,
                    color: _forceDynamic ? Colors.tealAccent : Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _forceDynamic
                        ? '฿ ${widget.codAmount!.toStringAsFixed(2)} (ล็อคยอดแล้ว)'
                        : '฿ ${widget.codAmount!.toStringAsFixed(2)} (กรอกยอดเอง)',
                    style: TextStyle(
                      color: _forceDynamic
                          ? Colors.tealAccent
                          : Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // --- Buttons ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              children: [
                // ปุ่มสลับ Mode — มีได้หลายกรณี
                if (hasCod && _config != null && _config!.hasDynamic) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _forceDynamic = !_forceDynamic);
                        _buildDynamicPayload();
                      },
                      icon: Icon(
                        _forceDynamic 
                            ? (_config!.isStatic ? Icons.image : Icons.lock_open)
                            : Icons.lock,
                        size: 18,
                      ),
                      label: Text(
                        _forceDynamic
                            ? (_config!.isStatic 
                                ? 'กลับไปใช้รูป QR จากร้าน' 
                                : 'ปลดล็อคยอด (ลูกค้ากรอกเอง)')
                            : 'ล็อคยอด ${widget.codAmount!.toStringAsFixed(0)} บาทใน QR',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        side: const BorderSide(color: Colors.tealAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // คำแนะนำ
                Text(
                  _showStaticQr
                      ? '💡 QR นี้คงที่ ลูกค้าต้องกรอกยอดเองในแอปธนาคาร'
                      : _forceDynamic
                          ? '⚠️ QR ล็อคยอดแล้ว ลูกค้าไม่ต้องกรอกตัวเลข'
                          : '💡 ลูกค้าต้องกรอกยอดเองในแอปธนาคาร',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
