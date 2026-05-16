// ไฟล์: lib/services/startup_service.dart

import 'dart:developer';
// import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:firebase_app_check/firebase_app_check.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // [NEW]

import '../../firebase_options.dart';
import '../config/app_constants.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  log('Handling a background message: ${message.messageId}');

  // ✅ Handle Background/Terminated Notification (Data Message)
  // หากเป็น Data Message (message.notification == null) ระบบจะไม่แจ้งเตือนอัตโนมัติ เราต้องสร้าง Notification เอง
  // ✅ Check Quiet Hours for Background Messages
  if (!NotificationService.isWorkingHours()) {
    log('🚫 Background Notification suppressed: Outside working hours.');
    return;
  }

  if (message.notification == null) {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // 1. Initialize Plugin (Required in new Isolate)
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings =
          InitializationSettings(
              android: initializationSettingsAndroid,
              iOS: initializationSettingsDarwin);

      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      // 2. Get Preferences for Sound
      final prefs = await SharedPreferences.getInstance();
      final soundName = prefs.getString('notification_sound') ??
          AppConstants.notificationSound;

      // 3. Extract logic
      final String title = message.data['title'] ?? 'การแจ้งเตือน System';
      final String body = message.data['body'] ?? 'มีข้อมูลใหม่เข้ามาในระบบ';

      // 4. Show Notification
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundName),
      );

      final DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(sound: '$soundName.mp3');

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
        payload: message.data.toString(),
      );
      log('Background Notification Shown: $title');
    } catch (e) {
      log('Error showing background notification: $e');
    }
  }
}

class StartupService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initializeApp() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Locale
    try {
      await initializeDateFormatting('th', null);
    } catch (e) {
      log('⚠️ Locale Init Error: $e');
    }

    // 2. Firebase Init
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 3. Crashlytics
      /*
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      */

      // 4. Firestore Settings (Offline Persistence)
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // 5. App Check
      /*
      await FirebaseAppCheck.instance.activate(
        // เลือก Provider ตาม Platform (Debug/PlayIntegrity/AppAttest)
        // ignore: deprecated_member_use
        androidProvider: AndroidProvider.debug,
        // ignore: deprecated_member_use
        appleProvider: AppleProvider.debug,
      );
      */

      // 6. Notifications
      await _initNotifications();
      await setupNotificationChannel();

      // ขอสิทธิ์แจ้งเตือน (Android 13+)
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('Got a message whilst in the foreground!');
        log('Message data: ${message.data}');

        if (message.notification != null) {
          _showNotification(message);
        }
      });

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      log('✅ App Initialized Successfully');
    } catch (e) {
      log('🔥 Critical Init Error: $e');
    }
  }

  static Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        log('Notification clicked: ${response.payload}');
      },
    );
  }

  static Future<String> _getPreferredSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notification_sound') ??
        AppConstants.notificationSound;
  }

  static Future<void> setupNotificationChannel() async {
    final prefs = await SharedPreferences.getInstance();
    final soundName = await _getPreferredSound();

    // Check if we need to update the channel (sound changed)
    final lastAppliedSound = prefs.getString('last_applied_sound');

    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // If sound changed, we MUST delete the old channel to apply new sound
      // because Android Notification Channels are immutable after creation.
      if (lastAppliedSound != null && lastAppliedSound != soundName) {
        await androidPlugin.deleteNotificationChannel(
            channelId: AppConstants.notificationChannelId);
        log('Deleted old channel to update sound from $lastAppliedSound to $soundName');
      }

      // Create (or recreate) the channel with the current preferred sound
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        AppConstants.notificationChannelId, // Use the SAME ID as Manifest
        AppConstants.notificationChannelName,
        description: AppConstants.notificationChannelDesc,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundName),
      );

      await androidPlugin.createNotificationChannel(channel);

      // Save the current sound as applied
      await prefs.setString('last_applied_sound', soundName);
    }
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    final soundName = await _getPreferredSound();

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      AppConstants.notificationChannelId, // Use fixed ID
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundName),
    );

    // iOS handles sound differently (file name usually requires extension)
    // Assuming sound files are .mp3 or similar in main bundle
    final DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(sound: '$soundName.mp3');

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }
}
