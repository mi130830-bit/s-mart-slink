import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_link/core/services/mysql_service.dart';
import 'package:s_link/core/services/network_discovery_client.dart';

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '3306');
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: '1234');
  final _dbCtrl = TextEditingController(text: 'sorborikan');

  bool _isLoading = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostCtrl.text = prefs.getString('db_host') ?? '';
      _portCtrl.text = (prefs.getInt('db_port') ?? 3306).toString();
      _userCtrl.text = prefs.getString('db_user') ?? 'admin';
      _passCtrl.text = prefs.getString('db_pass') ?? '1234';
      _dbCtrl.text = prefs.getString('db_name') ?? 'sorborikan';
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final db = MySQLService();
    await db.saveConfig(
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? 3306,
      user: _userCtrl.text.trim(),
      pass: _passCtrl.text.trim(),
      db: _dbCtrl.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกการตั้งค่าเรียบร้อย')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    final db = MySQLService();
    final error = await db.testConnection(
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? 3306,
      user: _userCtrl.text.trim(),
      pass: _passCtrl.text.trim(),
      db: _dbCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _testResult =
            error == null ? '✅ เชื่อมต่อสำเร็จ!' : '❌ เชื่อมต่อล้มเหลว: $error';
      });
    }
  }

  Future<void> _autoScan() async {
    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    final ip = await discoverPosServer();

    if (mounted) {
      if (ip != null) {
        _hostCtrl.text = ip;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ พบเครื่อง POS ที่ IP: $ip')),
        );
        _testConnection(); // Auto test after found
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ ไม่พบเครือง POS ในวง WiFi นี้')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าการเชื่อมต่อ POS LAN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Card(
                color: Colors.blueAccent,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    '💡 กรุณากรอก IP Address ของเครื่องคอมพิวเตอร์ที่เปิดโปรแกรม POS อยู่ (ต้องเชื่อมต่อ WiFi วงเดียวกัน)',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _hostCtrl,
                decoration: const InputDecoration(
                  labelText: 'IP Address (Host)',
                  hintText: 'e.g. 192.168.1.105',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.computer),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'กรุณาระบุ IP Address' : null,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _autoScan,
                    icon: const Icon(Icons.wifi_find),
                    label: const Text('ค้นหาเครื่อง POS อัตโนมัติ (Auto Scan)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.orange.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Advanced Settings'),
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _portCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _dbCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Database Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _userCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller:
                              _passCtrl, // Obscure text? Maybe not for internal use ease
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_testResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testResult!.startsWith('✅')
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _testResult!.startsWith('✅')
                            ? Colors.green
                            : Colors.red),
                  ),
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                        color: _testResult!.startsWith('✅')
                            ? Colors.green[900]
                            : Colors.red[900]),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _testConnection,
                      icon: const Icon(Icons.network_check),
                      label: const Text('ทดสอบการเชื่อมต่อ'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('บันทึก'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
