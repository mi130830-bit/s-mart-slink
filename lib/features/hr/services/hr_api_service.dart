import 'package:s_link/features/pos/services/pos_api_service.dart';

/// POS/MySQL is the single source of truth for HR transactions.
/// Firebase remains only for identity and user-directory information.
class HrApiService {
  HrApiService({PosApiService? api}) : _api = api ?? PosApiService();

  final PosApiService _api;

  Future<List<Map<String, dynamic>>> getLeaves() => _getList('/hr/leaves');

  Future<void> createLeave(Map<String, dynamic> data) =>
      _post('/hr/leaves', data);

  Future<void> updateLeaveStatus(String id, String status) =>
      _post('/hr/leaves/$id/status', {'status': status});

  Future<List<Map<String, dynamic>>> getAdvances() => _getList('/hr/advances');

  Future<void> createAdvance(Map<String, dynamic> data) =>
      _post('/hr/advances', data);

  Future<void> updateAdvanceStatus(String id, String status) =>
      _post('/hr/advances/$id/status', {'status': status});

  Future<List<Map<String, dynamic>>> getAttendance(String date) =>
      _getList('/hr/attendance/list?date=$date');

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final result = await _api.getRaw(path);
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    await _api.postRaw(path, body);
  }
}
