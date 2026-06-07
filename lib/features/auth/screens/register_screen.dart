// ไฟล์: lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:s_link/features/auth/services/auth_service.dart';
import 'package:s_link/features/auth/models/user_role.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  // แก้ไข: บังคับเป็น pending เสมอ (ไม่ต้องให้ User เลือก)
  final UserRole _fixedRole = UserRole.pending;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final authService = AuthService();

      String username = _emailCtrl.text.trim().toLowerCase();
      if (username.contains('@')) {
        username = username.split('@')[0];
      }
      final registerEmail = '$username@s-link.local';

      // ส่งค่า _fixedRole (pending) ไป
      final user = await authService.registerWithEmail(
          registerEmail, _passCtrl.text.trim(), _nameCtrl.text.trim(), _fixedRole);

      if (user != null && mounted) {
        // กลับไปหน้า Login ทันที และแสดงข้อความให้ทราบ
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสำเร็จ! บัญชีรอการอนุมัติ กรุณาแจ้ง Admin'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถสมัครได้ อีเมลอาจซ้ำ')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครพนักงานใหม่')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.person_add, size: 60, color: Colors.blue),
              const SizedBox(height: 20),

              const Text(
                'กรุณากรอกข้อมูลเพื่อขอเปิดบัญชีใหม่',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 20),

              // ชื่อ
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ชื่อ-นามสกุล (หรือชื่อเล่น)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) => v!.isEmpty ? 'ระบุชื่อ' : null,
              ),
              const SizedBox(height: 16),

              // Username
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Username (ภาษาอังกฤษ/ตัวเลข เท่านั้น)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) {
                  if (v!.isEmpty) return 'กรุณาระบุ Username';
                  if (v.contains(RegExp(r'[ก-๙]'))) return 'ห้ามใช้ภาษาไทย';
                  if (v.contains(' ')) return 'ห้ามเว้นวรรค';
                  if (v.contains('@')) return 'ไม่ต้องใส่อีเมล (กรอกแค่ชื่อ)';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // รหัสผ่าน
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่าน (6 ตัวขึ้นไป)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (v) => v!.length < 6 ? 'รหัสผ่านสั้นเกินไป' : null,
              ),
              const SizedBox(height: 24),

              // **ลบ Dropdown เลือกตำแหน่งออก** // แทนที่ด้วยข้อความแจ้งเตือน
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ตำแหน่งของคุณจะถูกกำหนดโดย Admin หลังจากสมัครสมาชิกแล้ว',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ยื่นคำขอลงทะเบียน',
                          style: TextStyle(fontSize: 18)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
