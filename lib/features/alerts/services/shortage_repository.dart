import 'dart:developer';
import 'package:s_link/features/alerts/models/shortage_log_model.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';

class ShortageRepository {
  final PosApiService _apiService = PosApiService();

  // --------------------------------------------------------
  // 1. READ (Via API)
  // --------------------------------------------------------

  Future<List<ShortageLogModel>> getOpenShortages() async {
    try {
      final List<Map<String, dynamic>> data = await _apiService.getShortages();
      return data.map((json) => ShortageLogModel.fromMap(json)).toList();
    } catch (e) {
      log('API Error (getOpenShortages): $e');
      return [];
    }
  }

  /// ค้นหาสินค้า (Via API)
  Future<List<ProductSearchResult>> searchProducts(String keyword) async {
    if (keyword.isEmpty) return [];

    try {
      final products =
          await _apiService.getProducts(search: keyword, limit: 10);

      return products
          .map((p) => ProductSearchResult(
                name: p.name,
                barcode: p.barcode,
              ))
          .toList();
    } catch (e) {
      log('API Search Error: $e');
      return [];
    }
  }

  // --------------------------------------------------------
  // 2. WRITE (Via API)
  // --------------------------------------------------------

  Future<void> createShortage(String itemName, String reporterId) async {
    try {
      await _apiService.createShortage(itemName, reporterId);
      log('✅ Created shortage via API: $itemName');
    } catch (e) {
      log('❌ Error creating shortage: $e');
      throw Exception('บันทึกข้อมูลไม่สำเร็จ: $e');
    }
  }

  // --------------------------------------------------------
  // 3. UPDATE / DELETE (Via API)
  // --------------------------------------------------------

  Future<void> markAsOrdered(int id) async {
    await _apiService.markShortageOrdered(id);
  }

  Future<void> markAsDone(int id) async {
    await _apiService.deleteShortage(id);
  }
}
