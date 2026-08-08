import 'package:isar/isar.dart';

part 'attendance_log_isar.g.dart';

@collection
class AttendanceLogIsar {
  Id id = Isar.autoIncrement; // Local ID
  
  @Index(unique: true, replace: true)
  String? syncId; // Unique ID to match with server, usually '${userId}_$date'

  String? userId;
  String? userName;
  String? date;

  DateTime? checkInTime;
  DateTime? checkOutTime;
  DateTime? tempOutTime;
  DateTime? backToWorkTime;
  
  double? checkInLat;
  double? checkInLng;
  double? checkOutLat;
  double? checkOutLng;
  double? tempOutLat;
  double? tempOutLng;
  double? backToWorkLat;
  double? backToWorkLng;
  
  String? status;
  String? note;
  
  // Sync Status
  bool isSynced = false;
  bool isDeleted = false; // For soft delete if needed
  DateTime? lastModified;
}
