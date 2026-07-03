import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:s_link/core/config/app_constants.dart';
import 'package:s_link/core/providers/theme_provider.dart';
import 'package:s_link/core/services/startup_service.dart';
import 'package:s_link/features/auth/providers/auth_provider.dart';
import 'package:s_link/features/settings/screens/widgets/settings_shared_ui.dart';

/// Section สำหรับการตั้งค่าทั่วไป (General Settings)
/// ซ่อน PromptPay/DeviceID จาก Driver — เพราะ Driver ไม่ได้จัดการ QR
class ConnectionSettingsSection extends StatefulWidget {
  const ConnectionSettingsSection({super.key});

  @override
  State<ConnectionSettingsSection> createState() =>
      _ConnectionSettingsSectionState();
}

class _ConnectionSettingsSectionState
    extends State<ConnectionSettingsSection> {
  String _promptPayId = '';
  String _posDeviceId = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _promptPayId = prefs.getString('promptpay_id') ?? '';
      _posDeviceId = prefs.getString('pos_device_id') ?? '';
      _loaded = true;
    });
  }

  Future<void> _showSoundPicker() async {
    final prefs = await SharedPreferences.getInstance();
    final currentSound =
        prefs.getString('notification_sound') ?? AppConstants.notificationSound;

    if (!mounted) return;

    final player = AudioPlayer();

    await showDialog(
      context: context,
      builder: (ctx) {
        String tempSelected = currentSound;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('เลือกเสียงแจ้งเตือน'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: AppConstants.availableSounds.length,
                  itemBuilder: (context, index) {
                    final sound = AppConstants.availableSounds[index];
                    return RadioListTile<String>(
                      title: Text(sound),
                      value: sound,
                      groupValue: tempSelected, // ignore: deprecated_member_use
                      onChanged: (val) { // ignore: deprecated_member_use
                        if (val != null) {
                          setState(() => tempSelected = val);
                          try {
                            player.stop();
                            player.play(AssetSource('sounds/$val.mp3'));
                          } catch (e) {
                            debugPrint('Error playing sound: $e');
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    player.dispose();
                    Navigator.pop(ctx);
                  },
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    player.dispose();
                    await prefs.setString('notification_sound', tempSelected);
                    await StartupService.setupNotificationChannel();
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      SnackbarUtils.showLeft(context,
                          'บันทึกเสียง "$tempSelected" แล้ว (จะมีผลกับการแจ้งเตือนใหม่)');
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      try {
        player.dispose();
      } catch (_) {}
    });
  }

  Future<void> _editPromptPay() async {
    final controller = TextEditingController(text: _promptPayId);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ตั้งค่า PromptPay ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              labelText: 'เบอร์โทรศัพท์ หรือ เลขบัตรประชาชน',
              hintText: '08xxxxxxxx หรือ 1xxxxxxxxxxxx'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('promptpay_id', val);
                if (!mounted) return;
                setState(() => _promptPayId = val);
                nav.pop();
                messenger.showSnackBar(const SnackBar(content: Text('บันทึกเรียบร้อย')));
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _editDeviceId() async {
    final controller = TextEditingController(text: _posDeviceId);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ระบุรหัสเครื่อง POS'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device UUID',
            hintText: 'ว่าง = ส่งหาเครื่องหลัก (MASTER)',
            helperText: 'ปล่อยว่างเพื่อใช้โหมดอัตโนมัติ',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);
              final prefs = await SharedPreferences.getInstance();
              if (val.isEmpty) {
                await prefs.remove('pos_device_id');
              } else {
                await prefs.setString('pos_device_id', val);
              }
              if (!mounted) return;
              setState(() => _posDeviceId = val);
              nav.pop();
              messenger.showSnackBar(const SnackBar(content: Text('บันทึกเรียบร้อย')));
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final auth = Provider.of<AuthenticationProvider>(context, listen: false);
    final isDriver = auth.isUserDriver;

    if (!_loaded) return const SizedBox.shrink();

    return Column(
      children: [
        SettingsSharedUI.buildSectionHeader('ทั่วไป (General)'),
        Card(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              // ซ่อนจาก Driver: Driver ไม่ได้ตั้งค่า QR / DeviceID
              if (!isDriver) ...[
                SettingsSharedUI.buildModernTile(
                  icon: Icons.qr_code,
                  color: Colors.purple,
                  title: 'PromptPay ID (สำหรับ QR รับเงิน)',
                  subtitle: _promptPayId.isNotEmpty ? _promptPayId : 'ยังไม่ได้ตั้งค่า',
                  onTap: _editPromptPay,
                ),
                SettingsSharedUI.buildDivider(),
                SettingsSharedUI.buildModernTile(
                  icon: Icons.monitor_weight_outlined,
                  color: Colors.blueGrey,
                  title: 'POS Device ID (จับคู่เครื่อง)',
                  subtitle: _posDeviceId.isNotEmpty ? _posDeviceId : 'Auto (POS_MASTER)',
                  onTap: _editDeviceId,
                ),
                SettingsSharedUI.buildDivider(),
              ],
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.dark_mode_outlined,
                      color: Colors.deepPurple),
                ),
                title: const Text('โหมดกลางคืน (Dark Mode)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  activeThumbColor: Colors.teal,
                  onChanged: (value) {
                    themeProvider.toggleTheme(value);
                  },
                ),
              ),
              SettingsSharedUI.buildDivider(),
              _SoundTile(onTap: _showSoundPicker),
            ],
          ),
        ),
      ],
    );
  }
}

/// แยก SoundTile ออกมาเพื่อ rebuild เฉพาะส่วน
class _SoundTile extends StatefulWidget {
  final Future<void> Function() onTap;
  const _SoundTile({required this.onTap});


  @override
  State<_SoundTile> createState() => _SoundTileState();
}

class _SoundTileState extends State<_SoundTile> {
  String _currentSound = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentSound =
          prefs.getString('notification_sound') ?? AppConstants.notificationSound;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSharedUI.buildModernTile(
      icon: Icons.notifications_active,
      color: Colors.orange,
      title: 'เสียงแจ้งเตือน',
      subtitle: _currentSound.isEmpty ? 'Loading...' : _currentSound,
      onTap: () async {
        await widget.onTap();
        await _load(); // Refresh หลัง dialog ปิด
      },
    );
  }
}
