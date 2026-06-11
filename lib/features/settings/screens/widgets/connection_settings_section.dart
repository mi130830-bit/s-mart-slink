import 'package:s_link/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:s_link/core/config/app_constants.dart';
import 'package:s_link/core/providers/theme_provider.dart';
import 'package:s_link/core/services/startup_service.dart';
import 'package:s_link/features/settings/screens/widgets/settings_shared_ui.dart';

class ConnectionSettingsSection extends StatelessWidget {
  const ConnectionSettingsSection({super.key});

  Future<void> _showSoundPicker(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentSound =
        prefs.getString('notification_sound') ?? AppConstants.notificationSound;

    if (!context.mounted) return;

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
                      // ignore: deprecated_member_use
                      groupValue: tempSelected,
                      // ignore: deprecated_member_use
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => tempSelected = val);
                          // Play sound preview
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
                      SnackbarUtils.showLeft(context, 'บันทึกเสียง "$tempSelected" แล้ว (จะมีผลกับการแจ้งเตือนใหม่)');
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
      } catch (e) {
        // Already disposed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        SettingsSharedUI.buildSectionHeader('ทั่วไป (General)'),
        Card(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              FutureBuilder<String>(
                future: SharedPreferences.getInstance()
                    .then((prefs) => prefs.getString('promptpay_id') ?? ''),
                builder: (context, snapshot) {
                  final current = snapshot.data?.isNotEmpty == true
                      ? snapshot.data!
                      : 'ยังไม่ได้ตั้งค่า';
                  return SettingsSharedUI.buildModernTile(
                    icon: Icons.qr_code,
                    color: Colors.purple,
                    title: 'PromptPay ID (สำหรับ QR รับเงิน)',
                    subtitle: current,
                    onTap: () {
                      final controller =
                          TextEditingController(text: snapshot.data ?? '');
                      showDialog(
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
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('ยกเลิก')),
                            ElevatedButton(
                                onPressed: () async {
                                  final val = controller.text.trim();
                                  if (val.isNotEmpty) {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString('promptpay_id', val);
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      SnackbarUtils.showLeft(context, 'บันทึกเรียบร้อย');
                                    }
                                  }
                                },
                                child: const Text('บันทึก')),
                          ],
                        ),
                      ).then((_) {
                        (context as Element).markNeedsBuild();
                      });
                    },
                  );
                },
              ),
              SettingsSharedUI.buildDivider(),
              FutureBuilder<String>(
                future: SharedPreferences.getInstance()
                    .then((prefs) => prefs.getString('pos_device_id') ?? ''),
                builder: (context, snapshot) {
                  final current = snapshot.data?.isNotEmpty == true
                      ? snapshot.data!
                      : 'Auto (POS_MASTER)';
                  return SettingsSharedUI.buildModernTile(
                    icon: Icons.monitor_weight_outlined,
                    color: Colors.blueGrey,
                    title: 'POS Device ID (จับคู่เครื่อง)',
                    subtitle: current,
                    onTap: () {
                      final controller =
                          TextEditingController(text: snapshot.data);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('ระบุรหัสเครื่อง POS'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  labelText: 'Device UUID',
                                  hintText: 'ว่าง = ส่งหาเครื่องหลัก (MASTER)',
                                  helperText: 'ปล่อยว่างเพื่อใช้โหมดอัตโนมัติ',
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('ยกเลิก')),
                            ElevatedButton(
                                onPressed: () async {
                                  final val = controller.text.trim();
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  if (val.isEmpty) {
                                    await prefs.remove('pos_device_id');
                                  } else {
                                    await prefs.setString('pos_device_id', val);
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    SnackbarUtils.showLeft(context, 'บันทึกเรียบร้อย');
                                  }
                                },
                                child: const Text('บันทึก')),
                          ],
                        ),
                      ).then((_) {
                        (context as Element).markNeedsBuild();
                      });
                    },
                  );
                },
              ),
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
              FutureBuilder<String>(
                future: SharedPreferences.getInstance().then((prefs) =>
                    prefs.getString('notification_sound') ??
                    AppConstants.notificationSound),
                builder: (context, snapshot) {
                  final current = snapshot.data ?? 'Loading...';
                  return SettingsSharedUI.buildModernTile(
                    icon: Icons.notifications_active,
                    color: Colors.orange,
                    title: 'เสียงแจ้งเตือน',
                    subtitle: current,
                    onTap: () => _showSoundPicker(context),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
