class AttendanceLog {
  final String id;
  final String userId;
  final String userName;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final DateTime? tempOutTime;
  final DateTime? backToWorkTime;
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;
  final double? tempOutLat;
  final double? tempOutLng;
  final double? backToWorkLat;
  final double? backToWorkLng;
  final String status;
  final String date;
  final bool isSynced;

  final String? note;

  AttendanceLog({
    required this.id,
    required this.userId,
    required this.userName,
    this.checkInTime,
    this.checkOutTime,
    this.tempOutTime,
    this.backToWorkTime,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
    this.tempOutLat,
    this.tempOutLng,
    this.backToWorkLat,
    this.backToWorkLng,
    this.status = 'PRESENT',
    required this.date,
    this.isSynced = true,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'temp_out_time': tempOutTime?.toIso8601String(),
      'back_to_work_time': backToWorkTime?.toIso8601String(),
      'check_in_lat': checkInLat,
      'check_in_lng': checkInLng,
      'check_out_lat': checkOutLat,
      'check_out_lng': checkOutLng,
      'temp_out_lat': tempOutLat,
      'temp_out_lng': tempOutLng,
      'back_to_work_lat': backToWorkLat,
      'back_to_work_lng': backToWorkLng,
      'status': status,
      'date': date,
      'note': note ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory AttendanceLog.fromJson(Map<String, dynamic> json, String docId) {
    return AttendanceLog(
      id: docId,
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'])
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'])
          : null,
      tempOutTime: json['temp_out_time'] != null
          ? DateTime.parse(json['temp_out_time'])
          : null,
      backToWorkTime: json['back_to_work_time'] != null
          ? DateTime.parse(json['back_to_work_time'])
          : null,
      checkInLat: json['check_in_lat']?.toDouble(),
      checkInLng: json['check_in_lng']?.toDouble(),
      checkOutLat: json['check_out_lat']?.toDouble(),
      checkOutLng: json['check_out_lng']?.toDouble(),
      tempOutLat: json['temp_out_lat']?.toDouble(),
      tempOutLng: json['temp_out_lng']?.toDouble(),
      backToWorkLat: json['back_to_work_lat']?.toDouble(),
      backToWorkLng: json['back_to_work_lng']?.toDouble(),
      status: json['status'] ?? 'PRESENT',
      date: json['date'] ?? '',
      note: json['note'],
      isSynced: json['is_synced'] as bool? ?? true,
    );
  }
}
