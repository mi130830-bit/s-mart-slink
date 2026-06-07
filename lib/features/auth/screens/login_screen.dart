// ไฟล์: lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'register_screen.dart'; // **เพิ่ม Import**

import 'package:s_link/features/settings/screens/connection_settings_screen.dart'; // **เพิ่ม Import**

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ไม่ต้องใช้ _isLoading ใน State เพราะใช้จาก AuthProvider

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider =
          Provider.of<AuthenticationProvider>(context, listen: false);

      String username = _emailController.text.trim().toLowerCase();
      String loginEmail;
      
      if (username.contains('@')) {
        // ถ้าระบุมี @ มาด้วย แสดงว่าเป็นระบบอีเมลเก่า (ให้เข้าได้เลย)
        loginEmail = username;
      } else {
        // ถ้าไม่มี @ แสดงว่าเป็นระบบ Username ใหม่ ให้เติม Dummy Domain
        loginEmail = '$username@s-link.local';
      }

      try {
        await authProvider.login(
            loginEmail, _passwordController.text.trim());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login Failed: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final bool isLoading = authProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ConnectionSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.local_shipping,
                      size: 80,
                      color: Colors.blue),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ร้าน ส.บริการ',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (val) {
                    if (val!.isEmpty) return 'กรุณาระบุ Username';
                    if (val.contains(RegExp(r'[ก-๙]'))) return 'ห้ามใช้ภาษาไทย';
                    if (val.contains(' ')) return 'ห้ามเว้นวรรค';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (val) =>
                      val!.isEmpty ? 'Please enter password' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Login', style: TextStyle(fontSize: 18)),
                  ),
                ),

                const SizedBox(height: 20),
                // **เพิ่ม: ปุ่มไปหน้าสมัครสมาชิก**
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text('ยังไม่มีไอดี? สมัครพนักงานใหม่'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
