// ไฟล์: lib/config/app_constants.dart

class AppConstants {
  // App Info
  static const String appName = 'ร้าน ส.บริการ';

  // Notification Channels
  static const String notificationChannelId = 'opsmate_alert_channel_v3';
  static const String notificationChannelName = 'OpsMate Alerts';
  static const String notificationChannelDesc = 'การแจ้งเตือนงานและสินค้าหมด';
  static const String notificationSound = 'sounda';
  static const List<String> availableSounds = [
    'sounda',
    'soundb',
    'soundc',
    'soundd',
    'sounde',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k'
  ];

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleDriver = 'driver';
  static const String roleRequester = 'requester';
  static const String rolePending = 'pending';

  // Notification Topics
  static const String topicDriverAlerts = 'driver_alerts';
  static const String topicAdminAlerts = 'admin_alerts';
  static const String topicRequesterAlerts = 'requester_alerts';

  // Assets
  static const String icLauncher = '@mipmap/ic_launcher';
}
