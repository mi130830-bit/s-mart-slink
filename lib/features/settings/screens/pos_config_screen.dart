import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';

class PosConfigScreen extends StatefulWidget {
  const PosConfigScreen({super.key});

  @override
  State<PosConfigScreen> createState() => _PosConfigScreenState();
}

class _PosConfigScreenState extends State<PosConfigScreen> {
  final _urlCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _testResult;
  Color _resultColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await PosApiService().getBaseUrl();
    if (url != null) {
      _urlCtrl.text = url;
    }
  }

  Future<void> _saveAndTest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _testResult = 'Testing connection...';
      _resultColor = Colors.blue;
    });

    final url = _urlCtrl.text.trim();
    // Save first
    await PosApiService().setBaseUrl(url);

    // Test
    final success = await PosApiService().testConnection();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _testResult = '✅ Connection Successful!';
          _resultColor = Colors.green;
        } else {
          _testResult = '❌ Connection Failed.';
          _resultColor = Colors.red;
        }
      });
    }

    if (success) {
      try {
        await FirebaseFirestore.instance.collection('app_settings').doc('api_config').set({
          'base_url': url,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to sync to cloud: $e');
      }
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าการเชื่อมต่อ (Remote)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'API URL (Local / Tunnel)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  hintText: 'http://POS-SERVER.local:8080',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอก URL';
                  }
                  if (!value.startsWith('http')) {
                    return 'URL ต้องขึ้นต้นด้วย http:// หรือ https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'ใส่ URL หรือ IP เครื่องแม่ เช่น http://192.168.1.100:8080 หรือ http://SERVER.local:8080',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              if (_testResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _resultColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _resultColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _resultColor == Colors.green
                            ? Icons.check_circle
                            : Icons.error,
                        color: _resultColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _resultColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveAndTest,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label:
                      Text(_isLoading ? 'กำลังเชื่อมต่อ...' : 'บันทึกและทดสอบ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
