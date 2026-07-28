// ไฟล์: lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'dart:io'; // Added
import 'package:flutter/foundation.dart'; // Added
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // 1. ตั้งค่าเริ่มต้น (Initialize)
  static Future<void> initialize() async {
    // ตั้งค่าสำหรับ Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ตั้งค่าสำหรับ iOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // ✅ Fix: Add Linux/Windows Settings to prevent initialization crash
    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const WindowsInitializationSettings windowsSettings =
        WindowsInitializationSettings(
      appName: 'S-Link',
      appUserModelId: 'com.sorborikan.s_link',
      guid: '81a95000-0000-0000-0000-000000000000',
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
      // Windows needs explicit settings
      windows: windowsSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        log('User tapped on notification: ${details.payload}');
      },
    );

    // ✅ Fix: Skip Firebase on Windows/Linux to prevent MissingPluginException
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('Got a message whilst in the foreground!');
        log('Message data: ${message.data}');

        if (message.notification != null) {
          log('Message also contained a notification: ${message.notification}');
          showLocalNotification(
              title: message.notification?.title,
              body: message.notification?.body);
        }
      });
    }
  }

  // 2. แสดงแจ้งเตือน (Show Notification)
  static Future<void> showLocalNotification(
      {String? title, String? body}) async {
    if (!isWorkingHours()) return;

    final prefs = await SharedPreferences.getInstance();
    final soundName =
        prefs.getString('notification_sound') ?? AppConstants.notificationSound;

    final String dynamicChannelId = '${AppConstants.notificationChannelId}_$soundName';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      dynamicChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundName),
    );

    final DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(sound: '$soundName.mp3');

    // ✅ Linux/Windows Details
    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails, iOS: iosDetails, linux: linuxDetails);

    await _localNotifications.show(
      id: 0,
      title: title ?? 'Notification',
      body: body ?? '',
      notificationDetails: platformDetails,
    );
  }

  // ... (isWorkingHours remains same) ...
  // ✅ Helper: Check Working Hours (07:00 - 17:00, Mon-Sat)
  static bool isWorkingHours() {
    final now = DateTime.now();
    // log('Checking Working Hours: ${now.toString()} (Weekday: ${now.weekday})');

    // 1. Sunday (7) is OFF
    if (now.weekday == DateTime.sunday) {
      // log('🚫 Notification suppressed: Sunday is non-working day.');
      return false;
    }

    // 2. Time (06:45 - 17:00)
    final int nowMinutes = now.hour * 60 + now.minute;
    const int startMinutes = 6 * 60 + 45; // 06:45
    const int endMinutes = 17 * 60; // 17:00

    if (nowMinutes < startMinutes || nowMinutes >= endMinutes) {
      // log('🚫 Notification suppressed: Outside working hours (${now.hour}:${now.minute}).');
      return false;
    }

    return true;
  }

  // 3. รับและบันทึก FCM Token ลง Firestore
  static Future<void> registerFCMToken(String userId) async {
    // ✅ Skip on non-mobile
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        log('User declined notification permissions');
        return;
      }

      final token = await messaging.getToken();
      if (token == null) {
        log('Failed to get FCM token');
        return;
      }

      log('FCM Token: $token');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': token});

      messaging.onTokenRefresh.listen((newToken) {
        log('FCM Token refreshed: $newToken');
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': newToken});
      });
    } catch (e) {
      log('Error registering FCM token: $e');
    }
  }

  // 4. ลบ FCM Token เมื่อ Logout
  static Future<void> removeFCMToken(String userId) async {
    // ✅ Skip on non-mobile
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': null});
      log('FCM Token removed from Firestore');
    } catch (e) {
      log('Error removing FCM token: $e');
    }
  }

}
