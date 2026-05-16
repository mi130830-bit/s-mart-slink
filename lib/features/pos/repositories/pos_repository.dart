import 'package:flutter/foundation.dart';
import 'package:s_link/features/pos/models/pos_customer.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';

class PosRepository {
  // Removed MySQLService dependency
  // final MySQLService _db = MySQLService();
  final PosApiService _api = PosApiService();

  Future<List<PosCustomer>> searchCustomers(String term) async {
    // 1. API Only (Tunnel)
    try {
      debugPrint('🔄 Searching Customers via API Tunnel...');
      return await _api.searchCustomers(term);
    } catch (e) {
      debugPrint('❌ API Search Customers Failed: $e');
      return [];
    }
  }

  Future<List<PosProduct>> getAllProducts({String searchTerm = ''}) async {
    // 1. API Only (Tunnel)
    try {
      debugPrint('🔄 Fetching Products via API Tunnel...');
      return await _api.getProducts(search: searchTerm, limit: 100);
    } catch (e) {
      debugPrint('❌ API Fetch Products Failed: $e');
      return [];
    }
  }

  Future<int> createOrder({
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String paymentMethod = 'CASH',
    int? customerId,
    String? note,
    int? userId = 1, // Default to 1 (Admin) if not provided
  }) async {
    // 1. API Only (Tunnel)
    try {
      debugPrint('🔄 Creating Order via API Tunnel...');

      // ✅ แก้ไข: กำหนด status ตาม paymentMethod
      // CREDIT → backend จะสร้างรายการหนี้ลูกค้า (ไม่ถือว่าจ่ายแล้ว)
      // อื่น ๆ (CASH, PROMPTPAY) → COMPLETED (จ่ายแล้ว)
      final orderStatus = (paymentMethod.toUpperCase() == 'CREDIT')
          ? 'CREDIT'
          : 'COMPLETED';

      final result = await _api.createOrder({
        'customerId':
            (customerId == null || customerId == 0) ? null : customerId,
        'total': totalAmount,
        'grandTotal': totalAmount, // Simple logic
        'paymentMethod': paymentMethod,
        'items': items,
        'userId': userId, // Pass userId
        'status': orderStatus, // ✅ ไม่ Force COMPLETED อีกต่อไป
      }, note: note); // Pass Note
      return int.tryParse(result['orderId'].toString()) ?? 0;
    } catch (e) {
      debugPrint('❌ API Create Order Failed: $e');
      return 0;
    }
  }

  Future<bool> updateStock(List<Map<String, dynamic>> items) async {
    // 1. API Only (Tunnel)
    try {
      debugPrint('🔄 Updating Stock via API Tunnel...');
      for (var item in items) {
        await _api.adjustStock(
          productId: item['productId'],
          newQuantity: (item['newStock'] as num).toDouble(),
          note: 'S-Link Stock Check (API)',
          user: 'App User',
        );
      }
      return true;
    } catch (e) {
      debugPrint('❌ API Update Stock Failed: $e');
      return false;
    }
  }

  Future<bool> addStock(List<Map<String, dynamic>> items) async {
    // 1. API Only (Tunnel)
    try {
      debugPrint('🔄 Adding Stock via API Tunnel...');
      for (var item in items) {
        await _api.increaseStock(
          productId: item['productId'],
          quantity: (item['quantity'] as num).toDouble(),
          note: 'S-Link Stock In (API)',
          user: 'App User',
        );
      }
      return true;
    } catch (e) {
      debugPrint('❌ API Add Stock Failed: $e');
      return false;
    }
  }
}
